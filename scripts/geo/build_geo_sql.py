#!/usr/bin/env python3
"""Generate the geo seed migration for one country from a vendored dataset plus patches.

Usage:
  python3 -I scripts/geo/build_geo_sql.py --country DZ \
    --source supabase/data/geo/dz/algeria_cities.json \
    --patches supabase/data/geo/dz/patches.json \
    --out supabase/migrations/20261115000110_geo_dz_seed.sql

Stdlib only and deterministic (sorted rows, no timestamps): regenerating must give a
byte-identical file, so a `git diff --exit-code` on the output proves the seed is reproducible.

Patches are applied in three stages, each op asserting the value it replaces (`from`) so an
upstream dataset change cannot be silently overwritten:
  record   -> fixes a raw dataset field before anything is derived from it
  region   -> sets a derived region field (name, parent)
  locality -> sets a derived locality field (e.g. region_code from an official text)
"""

import argparse
import hashlib
import json
import os
import sys
from collections import Counter, defaultdict


class GeoBuildError(Exception):
    pass


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def sha256_of(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def region_code(value):
    return f"{int(value):02d}"


def official_code(value):
    return f"{int(value):04d}"


def clean(value, what):
    text = str(value).strip()
    if not text:
        raise GeoBuildError(f"empty {what}")
    return text


def apply_op(obj, op, label):
    field, old, new = op["field"], op["from"], op["to"]
    if obj.get(field) != old:
        raise GeoBuildError(
            f"patch {label}.{field}: expected {old!r}, found {obj.get(field)!r} "
            "(dataset changed? review the patch)"
        )
    obj[field] = new


def build(source, patches):
    ops = patches["patches"]
    for op in ops:
        if op.get("target") not in ("record", "region", "locality"):
            raise GeoBuildError(f"unknown patch target in {op!r}")
        if not op.get("source"):
            raise GeoBuildError(f"patch without a source citation: {op!r}")

    # Stage 1: raw record fixes, keyed by the dataset's code_commune as published.
    records = {}
    for rec in source:
        key = int(rec["code_commune"])
        if key in records:
            raise GeoBuildError(f"duplicate code_commune {key} in source")
        records[key] = dict(rec)
    for op in (o for o in ops if o["target"] == "record"):
        key = int(op["key"])
        if key not in records:
            raise GeoBuildError(f"record patch for unknown code_commune {key}")
        apply_op(records[key], op, f"record[{key}]")

    # Stage 2: regions, derived from the (fixed) records' wilaya fields.
    regions = {}
    for rec in records.values():
        code = region_code(rec["wilaya_code"])
        names = (clean(rec["wilaya_name"], f"region {code} name_ar"),
                 clean(rec["wilaya_name_fr"], f"region {code} name_fr"))
        if regions.setdefault(code, names) != names:
            raise GeoBuildError(f"region {code} has conflicting names {regions[code]} vs {names}")
    regions = {
        code: {"code": code, "parent_code": None, "name_ar": ar, "name_fr": fr}
        for code, (ar, fr) in regions.items()
    }
    for op in (o for o in ops if o["target"] == "region"):
        code = op["key"]
        if code not in regions:
            raise GeoBuildError(f"region patch for unknown region {code}")
        apply_op(regions[code], op, f"region[{code}]")

    # Stage 3: localities. id = official commune code so later coordinate fixes keep FKs.
    localities = {}
    for rec in records.values():
        lid = int(rec["code_commune"])
        if lid in localities:
            raise GeoBuildError(f"duplicate official code {lid} after record patches")
        localities[lid] = {
            "id": lid,
            "region_code": region_code(rec["wilaya_code"]),
            "official_code": official_code(lid),
            "name_ar": clean(rec["commune_name"], f"locality {lid} name_ar"),
            "name_fr": clean(rec["commune_name_fr"], f"locality {lid} name_fr"),
            "lat": float(rec["Lat"]),
            "lng": float(rec["Long"]),
        }
    for op in (o for o in ops if o["target"] == "locality"):
        lid = int(op["key"])
        if lid not in localities:
            raise GeoBuildError(f"locality patch for unknown id {lid}")
        apply_op(localities[lid], op, f"locality[{lid}]")

    validate(regions, localities, patches["expected"])
    return regions, localities


def validate(regions, localities, expected):
    if len(regions) != expected["regions"]:
        raise GeoBuildError(f"expected {expected['regions']} regions, got {len(regions)}")
    if len(localities) != expected["localities"]:
        raise GeoBuildError(f"expected {expected['localities']} localities, got {len(localities)}")
    dup = [c for c, n in Counter(l["official_code"] for l in localities.values()).items() if n > 1]
    if dup:
        raise GeoBuildError(f"duplicate official_code: {sorted(dup)}")
    per_region = defaultdict(int)
    for loc in localities.values():
        if loc["region_code"] not in regions:
            raise GeoBuildError(f"locality {loc['id']} points at unknown region {loc['region_code']}")
        per_region[loc["region_code"]] += 1
    empty = sorted(set(regions) - set(per_region))
    if empty:
        raise GeoBuildError(f"regions without localities: {empty}")
    for reg in regions.values():
        if reg["parent_code"] is not None and reg["parent_code"] not in regions:
            raise GeoBuildError(f"region {reg['code']} has unknown parent {reg['parent_code']}")
    for code, want in sorted(expected.get("localities_per_region", {}).items()):
        if per_region.get(code) != want:
            raise GeoBuildError(f"region {code}: expected {want} localities, got {per_region.get(code)}")


def sql_text(value):
    if value is None:
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def sql_float(value):
    return repr(float(value))


def render(country, regions, localities, source_hash, patches_hash, args):
    cc = country["code"]
    out = [
        f"-- GENERATED by scripts/geo/build_geo_sql.py: do not edit by hand, regenerate instead.",
        # Only content hashes and file names: the output must not depend on where it is written.
        f"-- country {cc}; usage in scripts/geo/build_geo_sql.py",
        f"-- source  {os.path.basename(args.source)} sha256 {source_hash}",
        f"-- patches {os.path.basename(args.patches)} sha256 {patches_hash}",
        f"-- {len(regions)} regions, {len(localities)} localities. Provenance: supabase/data/geo/"
        f"{cc.lower()}/SOURCE.md",
        "",
        "insert into public.geo_countries (code, name_ar, name_fr, name_en, timezone, currency) values",
        "  (" + ", ".join(sql_text(country[k]) for k in
                          ("code", "name_ar", "name_fr", "name_en", "timezone", "currency")) + ");",
        "",
        "insert into public.geo_regions (country_code, code, parent_code, name_ar, name_fr) values",
    ]
    rows = [
        f"  ({sql_text(cc)}, {sql_text(r['code'])}, {sql_text(r['parent_code'])}, "
        f"{sql_text(r['name_ar'])}, {sql_text(r['name_fr'])})"
        for r in sorted(regions.values(), key=lambda r: r["code"])
    ]
    out.append(",\n".join(rows) + ";")
    out += [
        "",
        "insert into public.geo_localities",
        "  (id, country_code, region_code, official_code, name_ar, name_fr, lat, lng) values",
    ]
    rows = [
        f"  ({l['id']}, {sql_text(cc)}, {sql_text(l['region_code'])}, {sql_text(l['official_code'])}, "
        f"{sql_text(l['name_ar'])}, {sql_text(l['name_fr'])}, {sql_float(l['lat'])}, {sql_float(l['lng'])})"
        for l in sorted(localities.values(), key=lambda l: l["id"])
    ]
    out.append(",\n".join(rows) + ";")
    return "\n".join(out) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--country", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--patches", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    try:
        patches = read_json(args.patches)
        country = patches["country"]
        if country["code"] != args.country:
            raise GeoBuildError(f"patches are for {country['code']}, not {args.country}")
        regions, localities = build(read_json(args.source), patches)
        sql = render(country, regions, localities,
                     sha256_of(args.source), sha256_of(args.patches), args)
    except (GeoBuildError, KeyError, ValueError, OSError) as exc:
        print(f"build_geo_sql: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    print(f"wrote {args.out}: {len(regions)} regions, {len(localities)} localities")
    return 0


if __name__ == "__main__":
    sys.exit(main())
