import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import 'signup_draft.dart';

class SignupDraftStore {
  SignupDraftStore(this._prefs);

  static const String prefsKey = 'signup_draft';

  final SharedPreferences _prefs;

  SignupDraft? read() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null) return null;
    try {
      return SignupDraft.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      // A corrupt or outdated draft must never block sign-up: start over.
      _prefs.remove(prefsKey);
      return null;
    }
  }

  void write(SignupDraft draft) {
    _prefs.setString(prefsKey, jsonEncode(draft.toJson()));
  }

  void clear() {
    _prefs.remove(prefsKey);
  }
}

final signupDraftStoreProvider = Provider<SignupDraftStore>(
  (ref) => SignupDraftStore(ref.watch(sharedPreferencesProvider)),
);

final signupDraftProvider =
    NotifierProvider<SignupDraftController, SignupDraft?>(
      SignupDraftController.new,
    );

class SignupDraftController extends Notifier<SignupDraft?> {
  @override
  SignupDraft? build() => ref.watch(signupDraftStoreProvider).read();

  void update(SignupDraft Function(SignupDraft current) f) {
    final next = f(state ?? const SignupDraft());
    ref.read(signupDraftStoreProvider).write(next);
    state = next;
  }

  void clear() {
    ref.read(signupDraftStoreProvider).clear();
    state = null;
  }
}
