import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import 'media_storage.dart';
import 'photo_uploader.dart';
import 'pro_api.dart';
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

  Future<void> create({
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

  Future<void> updateProfile(ProProfilePatch patch) => _runOnProfile(
    (id) => ref.read(proRepositoryProvider).updateProfile(id, patch),
  );

  Future<void> upsertService(ProServiceDraft draft) => _runOnProfile(
    (id) => ref.read(proRepositoryProvider).upsertService(id, draft),
  );

  Future<void> archiveService(String serviceId) => _runOnProfile(
    (_) => ref.read(proRepositoryProvider).archiveService(serviceId),
  );

  Future<void> setHours(List<DayHours> week) =>
      _runOnProfile((id) => ref.read(proRepositoryProvider).setHours(id, week));

  Future<void> publish() =>
      _runOnProfile((id) => ref.read(proRepositoryProvider).publish(id));

  Future<void> uploadAvatar(XFile file) => _runOnProfile(
    (id) => ref.read(photoUploaderProvider).uploadAvatar(id, file),
  );

  Future<void> addWorkPhoto(XFile file) => _runOnProfile(
    (id) => ref.read(photoUploaderProvider).addWorkPhoto(id, file),
  );

  Future<void> removeWorkPhoto(ProPhoto photo) => _runOnProfile(
    (_) => ref.read(photoUploaderProvider).removeWorkPhoto(photo),
  );

  ProKind? get _kind {
    final role = ref.read(accountProvider).value?.activeRole;
    return role == null ? null : ProKind.forRole(role);
  }

  Future<void> _runOnProfile(Future<void> Function(String proId) action) {
    final id = state.value?.id;
    if (id == null) return Future.value();
    return _run(() => action(id));
  }

  // On failure the error is exposed while the previous profile stays in
  // `state.value`, so screens keep showing it.
  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      // Re-read the role: it may have changed while the action ran, and
      // `mine` must only be queried while acting as the pro role.
      final role = ref.read(accountProvider).value?.activeRole;
      final kind = role == null ? null : ProKind.forRole(role);
      final fresh = role == null || kind == null
          ? null
          : await ref.read(proRepositoryProvider).mine(kind, activeRole: role);
      if (!ref.mounted) return;
      state = AsyncData(fresh);
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError<ProProfile?>(e, st);
    }
  }
}
