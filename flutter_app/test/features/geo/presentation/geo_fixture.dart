import 'dart:io';

import 'package:lemqes/features/geo/data/geo_models.dart';

String _unquote(String s) => s.replaceAll("''", "'");

/// Regions and localities read from the shipped seed, so the picker tests run
/// on the real dataset names (accents and all).
({List<Region> regions, List<Locality> localities}) loadSeed() {
  final sql = File('../supabase/migrations/20261115000110_geo_dz_seed.sql')
      .readAsStringSync();
  final regionRe = RegExp(
    r"^\s+\('DZ', '(\d+)', (null|'\d+'), '((?:[^']|'')*)', '((?:[^']|'')*)'\)",
    multiLine: true,
  );
  final localityRe = RegExp(
    r"^\s+\((\d+), 'DZ', '(\d+)', '\d+', '((?:[^']|'')*)', '((?:[^']|'')*)', ",
    multiLine: true,
  );
  return (
    regions: [
      for (final m in regionRe.allMatches(sql))
        Region(
          countryCode: 'DZ',
          code: m[1]!,
          nameAr: _unquote(m[3]!),
          nameFr: _unquote(m[4]!),
        ),
    ],
    localities: [
      for (final m in localityRe.allMatches(sql))
        Locality(
          id: int.parse(m[1]!),
          regionCode: m[2]!,
          nameAr: _unquote(m[3]!),
          nameFr: _unquote(m[4]!),
        ),
    ],
  );
}
