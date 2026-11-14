import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/account/data/account.dart';
import '../../features/signup/data/signup_draft.dart';

/// The wizard steps in order; their names are the `/signup/:step` paths.
const signupSteps = ['space', 'role', 'credentials', 'code'];

/// Whether the user is signed in. Until the session stream emits (cold start),
/// the stored session answers synchronously, so a signed-in user never sees
/// a frame of /auth.
bool resolveHasSession(
  AsyncValue<Session?> session,
  Session? Function() storedSession,
) {
  if (session.hasValue) return session.value != null;
  return storedSession() != null;
}

/// Pure routing rules; returns the location to redirect to, or null to stay.
String? authRedirect({
  required bool hasSession,
  required AsyncValue<Account?> account,
  required SignupDraft? draft,
  required String location,
}) {
  // The reset code signs the user in before the new password is set: the
  // screen must survive the session and any profile state arriving.
  if (location == '/auth/reset') return null;

  final inAuth = location.startsWith('/auth');
  final inSignup = location.startsWith('/signup');

  if (!hasSession) {
    if (draft?.phone != null && (location == '/' || location == '/auth')) {
      return '/signup/code';
    }
    return inAuth || inSignup ? null : '/auth';
  }

  if (account.isLoading) {
    // Verification just signed the user in and the account reloads (with or
    // without a previous value): the code step shows its own progress while
    // the profile is created, instead of a detour via home.
    if (location == '/signup/code') return null;
    if (!account.hasValue) return location == '/home' ? null : '/home';
  }
  if (account.hasError) {
    return location == '/home' ? null : '/home';
  }

  if (account.value == null) {
    return inSignup ? null : '/signup/${draft?.resumeStep ?? 'space'}';
  }

  if (inAuth || inSignup || location == '/') return '/home';
  return null;
}

/// Keeps the wizard from opening a step whose earlier answers are missing;
/// returns the step to open instead, or null to stay.
String? signupStepRedirect({
  required String step,
  required SignupDraft? draft,
  required bool hasSession,
}) {
  final index = signupSteps.indexOf(step);
  if (index < 0) return '/signup/space';
  final current = draft ?? const SignupDraft();
  var reachable = current.resumeStep;
  // Signed in, the code is already verified; that step only finishes the
  // profile, which needs the names from the credentials step.
  if (hasSession && reachable == 'code' && current.fullName == null) {
    reachable = 'credentials';
  }
  if (index > signupSteps.indexOf(reachable)) return '/signup/$reachable';
  return null;
}
