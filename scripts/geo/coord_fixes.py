#!/usr/bin/env python3
"""Check commune coordinates and emit the migration that corrects them.

Usage (from the repo root, defaults point at the DZ data):
  python3 -I scripts/geo/coord_fixes.py --check
  python3 -I scripts/geo/coord_fixes.py --emit supabase/migrations/20261122000100_geo_coords_fix.sql

Rules, applied to the seed as build_geo_sql.py derives it (dataset + patches.json):
  bounds      every point inside the country bounds
  whole-deg   no lat or lng that is a whole number (a rounded coordinate)
  shared      no two communes on the same point
  far         distance to the wilaya's median point <= max(4 x wilaya spread, 60 km), where
              spread = median distance of the wilaya's communes to that median point

coord_fixes.json maps a commune id to {lat, lng, source} (corrected) or {verified: reason}
(the point is genuinely far, e.g. a Saharan commune; may accompany a fix). `verified` only excuses the `far` rule.
--check exits 1 while a raw point is flagged without an entry, or while the corrected data still
breaks a rule. Stdlib only; the seed script and its inputs are never modified.
"""

import argparse
import json
import math
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # -I drops the script directory from sys.path
import build_geo_sql  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
DZ = os.path.join(ROOT, "supabase", "data", "geo", "dz")
# min_lng, min_lat, max_lng, max_lat
BBOX = {"DZ": (-8.7, 18.9, 12.0, 37.2)}
FAR_FLOOR_KM = 60.0
FAR_FACTOR = 4.0


def haversine_km(lat1, lng1, lat2, lng2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = (math.sin((p2 - p1) / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lng2 - lng1) / 2) ** 2)
    return 12742.0 * math.asin(math.sqrt(a))


def find_flags(localities, bbox):
    """Return {id: set(rule names)} for the given {id: locality} map."""
    min_lng, min_lat, max_lng, max_lat = bbox
    flags = defaultdict(set)
    by_point = defaultdict(list)
    by_region = defaultdict(list)
    for loc in localities.values():
        lat, lng = loc["lat"], loc["lng"]
        if not (min_lat <= lat <= max_lat and min_lng <= lng <= max_lng):
            flags[loc["id"]].add("bounds")
        if lat == int(lat) or lng == int(lng):
            flags[loc["id"]].add("whole-degree")
        by_point[(lat, lng)].append(loc["id"])
        by_region[loc["region_code"]].append(loc)
    for ids in by_point.values():
        if len(ids) > 1:
            for i in ids:
                flags[i].add("shared")
    for locs in by_region.values():
        mlat = statistics.median(l["lat"] for l in locs)
        mlng = statistics.median(l["lng"] for l in locs)
        dist = {l["id"]: haversine_km(l["lat"], l["lng"], mlat, mlng) for l in locs}
        limit = max(FAR_FACTOR * statistics.median(dist.values()), FAR_FLOOR_KM)
        for i, d in dist.items():
            if d > limit:
                flags[i].add("far")
    return flags


def load(args):
    patches = build_geo_sql.read_json(args.patches)
    _, localities = build_geo_sql.build(build_geo_sql.read_json(args.source), patches)
    fixes = build_geo_sql.read_json(args.fixes)
    return patches["country"]["code"], localities, fixes


def apply_fixes(localities, fixes):
    fixed = {i: dict(l) for i, l in localities.items()}
    for key, fix in fixes.items():
        if "lat" in fix:
            fixed[int(key)]["lat"] = float(fix["lat"])
            fixed[int(key)]["lng"] = float(fix["lng"])
    return fixed


def validate_fixes(localities, fixes):
    problems = []
    for key, fix in fixes.items():
        if int(key) not in localities:
            problems.append(f"{key}: unknown commune id")
        if "verified" not in fix and "lat" not in fix:
            problems.append(f"{key}: needs lat/lng/source or verified")
        if "verified" in fix and not str(fix["verified"]).strip():
            problems.append(f"{key}: empty verified reason")
        if "lat" in fix and not (isinstance(fix.get("lat"), (int, float)) and isinstance(fix.get("lng"), (int, float))
                  and str(fix.get("source", "")).startswith("osm:")):
            problems.append(f"{key}: fix needs numeric lat, lng and source 'osm:<type>/<id>'")
    return problems


def check(args):
    cc, localities, fixes = load(args)
    raw = find_flags(localities, BBOX[cc])
    problems = validate_fixes(localities, fixes)
    for i in sorted(raw):
        mark = "ok" if str(i) in fixes else "UNRESOLVED"
        print(f"{i:>5} {localities[i]['name_fr']:<28} {','.join(sorted(raw[i])):<14} {mark}")
        if str(i) not in fixes:
            problems.append(f"{i}: flagged ({','.join(sorted(raw[i]))}) without a fix")
    verified = {int(k) for k, v in fixes.items() if "verified" in v}
    for i, rules in sorted(find_flags(apply_fixes(localities, fixes), BBOX[cc]).items()):
        if str(i) not in fixes:
            continue  # already reported as unresolved above, or newly shifted by a neighbour's fix
        left = rules - {"far"} if i in verified else rules
        if left:
            problems.append(f"{i}: still breaks {sorted(left)} after fixes")
    for p in problems:
        print(f"coord_fixes: {p}", file=sys.stderr)
    print(f"{len(raw)} flagged, {len(fixes)} fix entries ({len(verified)} verified)")
    return 1 if problems else 0


def emit(args):
    cc, localities, fixes = load(args)
    if check(args):
        return 1
    bbox = BBOX[cc]
    moved = sorted((int(k), v) for k, v in fixes.items() if "lat" in v)
    verified = sorted((int(k), v["verified"]) for k, v in fixes.items() if "verified" in v)
    q = lambda s: "'" + s.replace("'", "''") + "'"
    out = [
        "-- GENERATED by scripts/geo/coord_fixes.py from supabase/data/geo/dz/coord_fixes.json:",
        "-- do not edit by hand. Ids never change; only lat/lng of flagged communes do.",
        "-- Corrected points: OpenStreetMap contributors (ODbL), see supabase/data/geo/dz/SOURCE.md.",
        "",
        "alter table public.geo_countries add column bbox double precision[]",
        "  check (bbox is null or array_length(bbox, 1) = 4);",
        f"update public.geo_countries set bbox = array[{', '.join(repr(b) for b in bbox)}]",
        f"  where code = {q(cc)};",
        "",
        "-- Communes whose point is far from their wilaya median on purpose (checked, not moved).",
        "create table public.geo_coord_verified (",
        "  locality_id integer primary key references public.geo_localities (id),",
        "  reason text not null check (char_length(btrim(reason)) > 0)",
        ");",
        "alter table public.geo_coord_verified enable row level security;",
        "revoke all on public.geo_coord_verified from anon, authenticated;",
        "",
    ]
    for i, f in moved:
        out.append(f"update public.geo_localities set lat = {float(f['lat'])!r}, lng = {float(f['lng'])!r}"
                   f" where id = {i}; -- {f['source']}")
    if verified:
        out += ["", "insert into public.geo_coord_verified (locality_id, reason) values"]
        out.append(",\n".join(f"  ({i}, {q(r)})" for i, r in verified) + ";")
    with open(args.emit, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(f"wrote {args.emit}: {len(moved)} moved, {len(verified)} verified")
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--emit", metavar="PATH")
    p.add_argument("--source", default=os.path.join(DZ, "algeria_cities.json"))
    p.add_argument("--patches", default=os.path.join(DZ, "patches.json"))
    p.add_argument("--fixes", default=os.path.join(DZ, "coord_fixes.json"))
    args = p.parse_args(argv)
    try:
        return check(args) if args.check else emit(args)
    except (build_geo_sql.GeoBuildError, KeyError, ValueError, OSError) as exc:
        print(f"coord_fixes: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
