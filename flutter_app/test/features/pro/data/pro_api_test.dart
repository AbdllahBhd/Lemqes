import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/pro/data/pro_api.dart';

void main() {
  test('the public read embeds the place with its shown fields only', () {
    const select = SupabaseProApi.publicSelect;
    expect(
      select,
      contains('pro_places(place_mode, lat, lng, area_radius_m, landmark)'),
    );
    // The search point is server-side only, and a customer has no use for
    // the owner's edit time.
    expect(select, isNot(contains('search_point')));
    expect(select, isNot(contains('updated_at')));
    expect(select, contains('pro_hours('));
    expect(select, contains('pro_photos('));
    // Services come from their own public view, not the profile read.
    expect(select, isNot(contains('pro_services(')));
  });
}
