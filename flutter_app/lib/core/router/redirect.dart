import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/data/account.dart';
import '../../features/signup/data/signup_draft.dart';

/// Pure routing rules; returns the location to redirect to, or null to stay.
String? authRedirect({
  required bool hasSession,
  required AsyncValue<Account?> account,
  required SignupDraft? draft,
  required String location,
}) {
  final inAuth = location.startsWith('/auth');
  final inSignup = location.startsWith('/signup');

  if (!hasSession) {
    if (draft?.phone != null && (location == '/' || location == '/auth')) {
      return '/signup/code';
    }
    return inAuth || inSignup ? null : '/auth';
  }

  if (account.isLoading && !account.hasValue) {
    return location == '/home' ? null : '/home';
  }
  if (account.hasError) {
    return location == '/home' ? null : '/home';
  }

  if (account.value == null) {
    return inSignup ? null : '/signup/${draft?.resumeStep ?? 'space'}';
  }

  if (location == '/auth/reset') return null;
  if (inAuth || inSignup || location == '/') return '/home';
  return null;
}
