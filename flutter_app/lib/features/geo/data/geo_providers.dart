import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'geo_api.dart';
import 'geo_models.dart';
import 'geo_repository.dart';

final geoRepositoryProvider = Provider<GeoRepository>(
  (ref) => GeoRepository(SupabaseGeoApi(ref.watch(supabaseClientProvider))),
);

// No automatic retry: the picker sheets show the error with their own retry.
final regionsProvider = FutureProvider.family<List<Region>, String>(
  (ref, country) => ref.watch(geoRepositoryProvider).regions(country),
  retry: (_, _) => null,
);

final localitiesProvider =
    FutureProvider.family<
      List<Locality>,
      ({String country, String regionCode})
    >(
      (ref, key) => ref
          .watch(geoRepositoryProvider)
          .localities(key.country, key.regionCode),
      retry: (_, _) => null,
    );

/// One commune by id, e.g. to show a saved profile's place (its wilaya
/// comes with it).
final localityProvider = FutureProvider.family<Locality?, int>(
  (ref, id) => ref.watch(geoRepositoryProvider).locality(id),
  retry: (_, _) => null,
);
