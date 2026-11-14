import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'geo_api.dart';
import 'geo_models.dart';
import 'geo_repository.dart';

final geoRepositoryProvider = Provider<GeoRepository>(
  (ref) => GeoRepository(SupabaseGeoApi(ref.watch(supabaseClientProvider))),
);

final regionsProvider = FutureProvider.family<List<Region>, String>(
  (ref, country) => ref.watch(geoRepositoryProvider).regions(country),
);

final localitiesProvider =
    FutureProvider.family<
      List<Locality>,
      ({String country, String regionCode})
    >(
      (ref, key) => ref
          .watch(geoRepositoryProvider)
          .localities(key.country, key.regionCode),
    );
