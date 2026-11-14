import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/account/data/account.dart';
import '../../features/pro/data/pro_models.dart';
import '../../features/signup/data/signup_draft.dart';

/// The wizard steps in order; their names are the `/signup/:step` paths.
const signupSteps = ['space', 'role', 'credentials', 'code'];

/// The pro setup steps in order; their names are the `/pro/setup/:step` paths.
const proSetupSteps = ['profile', 'services', 'hours'];

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

  // A first load, or the reload that signing in starts from "no account":
  // neither proves the profile is missing, so wait on home, not the wizard.
  if (account.isLoading && account.value == null) {
    // Verification just signed the user in: the code step shows its own
    // progress while the profile is created, instead of a detour via home.
    if (location == '/signup/code') return null;
    // A cold start mid sign-up goes straight back to the code step, which
    // resumes the profile creation.
    if (draft?.phone != null && draft?.fullName != null) return '/signup/code';
    return location == '/home' ? null : '/home';
  }
  if (account.isLoading && location == '/signup/code') return null;
  // Only a failure with no account to show; a failed switch keeps the
  // account and must leave settings and sign-out reachable.
  if (account.hasError && account.value == null) {
    return location == '/home' ? null : '/home';
  }

  if (account.value == null) {
    return inSignup ? null : '/signup/${draft?.resumeStep ?? 'space'}';
  }

  final hasProProfile = ProKind.forRole(account.value!.activeRole) != null;
  // Setup follows sign-up for the roles that have a profile; afterwards it is
  // only offered (dashboard, role sheet), never imposed on /home.
  if (inSignup && hasProProfile) return '/pro/setup/profile';
  if (location.startsWith('/pro/setup') && !hasProProfile) return '/home';
  if (inAuth || inSignup || location == '/') return '/home';
  return null;
}

/// The first setup step that [gaps] point to, or null when there are none.
String? setupStepForGaps(Set<ProfileGap> gaps) {
  if (gaps.contains(ProfileGap.locality) ||
      gaps.contains(ProfileGap.customerMix)) {
    return 'profile';
  }
  if (gaps.contains(ProfileGap.services)) return 'services';
  if (gaps.contains(ProfileGap.hours)) return 'hours';
  return null;
}

String? _firstGapStep(ProProfile? profile) =>
    profile == null ? 'profile' : setupStepForGaps(profile.gaps);

/// `/pro/setup` resumes at the first step with a gap; a complete profile has
/// nothing to set up. Null while the profile loads.
String? proSetupEntry(AsyncValue<ProProfile?> profile) {
  if (!profile.hasValue) return null;
  final step = _firstGapStep(profile.value);
  return step == null ? '/home' : '/pro/setup/$step';
}

/// Keeps setup from opening a step whose earlier steps are unfinished;
/// returns the step to open instead, or null to stay.
String? proSetupStepRedirect({
  required String step,
  required AsyncValue<ProProfile?> profile,
}) {
  final index = proSetupSteps.indexOf(step);
  if (index < 0) return '/pro/setup/profile';
  if (!profile.hasValue) return null;
  final reachable = _firstGapStep(profile.value) ?? proSetupSteps.last;
  if (index > proSetupSteps.indexOf(reachable)) return '/pro/setup/$reachable';
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
