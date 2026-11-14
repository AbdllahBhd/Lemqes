import '../../account/data/account.dart';
import 'pro_api.dart';
import 'pro_failure.dart';
import 'pro_models.dart';

class ProRepository {
  ProRepository(this._api);

  final ProApi _api;

  Future<ProProfile?> mine(ProKind kind) => guardPro(() async {
    final row = await _api.selectMine(kind.toDb());
    return row == null ? null : ProProfile.fromRow(row);
  });

  Future<ProProfile> create(
    ProKind kind, {
    required String displayName,
    required WorkplaceType workplaceType,
  }) => guardPro(() async {
    final row = await _api.rpc('create_pro_profile', {
      'p_kind': kind.toDb(),
      'p_display_name': displayName,
      'p_workplace_type': workplaceType.toDb(),
    });
    return ProProfile.fromRow(row! as Map<String, Object?>);
  });

  Future<void> updateProfile(String proId, ProProfilePatch patch) =>
      guardPro(() async {
        final values = patch.toDb();
        if (values.isEmpty) return;
        await _api.update('pro_profiles', proId, values);
      });

  Future<ProService> upsertService(String proId, ProServiceDraft draft) =>
      guardPro(() async {
        final id = draft.id;
        final row = id == null
            ? await _api.insert('pro_services', {
                'pro_id': proId,
                ...draft.toDb(),
              })
            : await _api.update('pro_services', id, draft.toDb());
        return ProService.fromRow(row);
      });

  /// Services are never deleted (bookings will reference them).
  Future<void> archiveService(String serviceId) => guardPro(
    () => _api.update('pro_services', serviceId, {
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  Future<void> setHours(String proId, List<DayHours> week) => guardPro(
    () => _api.rpc('set_pro_hours', {
      'p_pro_id': proId,
      'p_week': [for (final d in week) d.toJson()],
    }),
  );

  Future<DateTime> publish(String proId) => guardPro(() async {
    final at = await _api.rpc('publish_pro_profile', {'p_pro_id': proId});
    return DateTime.parse(at! as String).toUtc();
  });

  Future<String?> contactPhone(String proId) => guardPro(() async {
    final phone = await _api.rpc('pro_contact_phone', {'p_pro_id': proId});
    return phone as String?;
  });

  Future<ProProfile?> publicProfile(String proId) => guardPro(() async {
    final row = await _api.selectPublic(proId);
    if (row == null) return null;
    final rows = await _api.rpc('pro_public_services', {'p_pro_id': proId});
    final services = [
      for (final r in (rows as List<Object?>? ?? const []))
        ProService.fromRow(r! as Map<String, Object?>),
    ];
    return ProProfile.fromRow(row, services: services);
  });

  Future<List<ServicePreset>> presets(Space space, {required bool home}) =>
      guardPro(
        () async => [
          for (final r in await _api.selectPresets(space.toDb(), home))
            ServicePreset.fromRow(r),
        ],
      );
}
