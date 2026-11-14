import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import 'media_storage.dart';
import 'photo_uploader.dart';
import 'pro_api.dart';
import 'pro_failure.dart';
import 'pro_models.dart';
import 'pro_repository.dart';

final proApiProvider = Provider<ProApi>(
  (ref) => SupabaseProApi(ref.watch(supabaseClientProvider)),
);

final proRepositoryProvider = Provider<ProRepository>(
  (ref) => ProRepository(ref.watch(proApiProvider)),
);

final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => PhotoUploader(
    ref.watch(proApiProvider),
    SupabaseMediaStorage(ref.watch(supabaseClientProvider)),
  ),
);

final presetsProvider =
    FutureProvider.family<List<ServicePreset>, ({Space space, bool home})>(
      (ref, key) =>
          ref.watch(proRepositoryProvider).presets(key.space, home: key.home),
    );

/// The profile of the account's active pro role (barber / home artist);
/// null for other roles or before it is created.
final myProProvider = AsyncNotifierProvider<MyProController, ProProfile?>(
  MyProController.new,
);

class MyProController extends AsyncNotifier<ProProfile?> {
  @override
  Future<ProProfile?> build() async {
    // Awaited so the profile stays loading (not null) until the account is
    // known.
    final role = await ref.watch(
      accountProvider.selectAsync((a) => a?.activeRole),
    );
    final kind = role == null ? null : ProKind.forRole(role);
    if (role == null || kind == null) return null;
    return ref.read(proRepositoryProvider).mine(kind, activeRole: role);
  }

  Future<ProFailure?> create({
    required String displayName,
    required WorkplaceType workplaceType,
  }) {
    final kind = _kind;
    if (kind == null) return Future.value();
    return _run(
      () => ref
          .read(proRepositoryProvider)
          .create(kind, displayName: displayName, workplaceType: workplaceType),
    );
  }

  Future<ProFailure?> updateProfile(ProProfilePatch patch) => _runOnProfile(
    (id) => ref.read(proRepositoryProvider).updateProfile(id, patch),
  );

  /// A new service goes after the others: customers read them ordered by
  /// `sort`, so ties would show in an arbitrary order.
  Future<ProFailure?> upsertService(ProServiceDraft draft) {
    final services = state.value?.services ?? const <ProService>[];
    final placed = draft.id != null || draft.sort != null
        ? draft
        : draft.placedAt(
            services.fold(-1, (top, s) => s.sort > top ? s.sort : top) + 1,
          );
    return _runOnProfile(
      (id) => ref.read(proRepositoryProvider).upsertService(id, placed),
    );
  }

  Future<ProFailure?> archiveService(String serviceId) => _runOnProfile(
    (_) => ref.read(proRepositoryProvider).archiveService(serviceId),
  );

  Future<ProFailure?> setHours(List<DayHours> week) =>
      _runOnProfile((id) => ref.read(proRepositoryProvider).setHours(id, week));

  Future<ProFailure?> publish() =>
      _runOnProfile((id) => ref.read(proRepositoryProvider).publish(id));

  Future<ProFailure?> uploadAvatar(XFile file) => _runOnProfile(
    (id) => ref.read(photoUploaderProvider).uploadAvatar(id, file),
  );

  Future<ProFailure?> addWorkPhoto(XFile file) => _runOnProfile(
    (id) => ref.read(photoUploaderProvider).addWorkPhoto(id, file),
  );

  Future<ProFailure?> removeWorkPhoto(ProPhoto photo) => _runOnProfile(
    (_) => ref.read(photoUploaderProvider).removeWorkPhoto(photo),
  );

  ProKind? get _kind {
    final role = ref.read(accountProvider).value?.activeRole;
    return role == null ? null : ProKind.forRole(role);
  }

  Future<ProFailure?> _runOnProfile(
    Future<void> Function(String proId) action,
  ) {
    final profile = state.value;
    // While a role switch reloads, the value is still the previous role's
    // profile: writing through it would edit the wrong row.
    if (profile == null || profile.kind != _kind) {
      const failure = UnknownProFailure('no profile for the active role');
      state = AsyncError<ProProfile?>(failure, StackTrace.current);
      return Future.value(failure);
    }
    return _run(() => action(profile.id));
  }

  /// Runs a write, then reloads the profile. Returns the write's failure, or
  /// null when the write went through, even if the reload then failed.
  ///
  /// A failed write is exposed while the previous profile stays in
  /// `state.value`, so screens keep showing it. A failed reload is not the
  /// write's failure (reported as one, a retry would store the photo or
  /// service twice): the profile is loaded again, and a second failure is
  /// that load's error.
  Future<ProFailure?> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object catch (e, st) {
      if (ref.mounted) state = AsyncError<ProProfile?>(e, st);
      return e is ProFailure ? e : UnknownProFailure('$e');
    }
    try {
      // Re-read the role: it may have changed while the action ran, and
      // `mine` must only be queried while acting as the pro role.
      final role = ref.read(accountProvider).value?.activeRole;
      final kind = role == null ? null : ProKind.forRole(role);
      final fresh = role == null || kind == null
          ? null
          : await ref.read(proRepositoryProvider).mine(kind, activeRole: role);
      if (ref.mounted) state = AsyncData(fresh);
    } on Object catch (e, st) {
      developer.log(
        'profile reload after a write failed',
        error: e,
        stackTrace: st,
      );
      if (ref.mounted) ref.invalidateSelf();
    }
    return null;
  }
}
