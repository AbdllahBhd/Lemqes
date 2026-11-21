import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

sealed class LiveFailure implements Exception {
  const LiveFailure();
}

class NotOwner extends LiveFailure {
  const NotOwner();
}

class NotOpen extends LiveFailure {
  const NotOpen();
}

class InvalidBreakUntil extends LiveFailure {
  const InvalidBreakUntil();
}

class RequestReused extends LiveFailure {
  const RequestReused();
}

class QueueEmpty extends LiveFailure {
  const QueueEmpty();
}

class NothingToUndo extends LiveFailure {
  const NothingToUndo();
}

class NothingServing extends LiveFailure {
  const NothingServing();
}

class NotRemote extends LiveFailure {
  const NotRemote();
}

class InvalidService extends LiveFailure {
  const InvalidService();
}

class InvalidName extends LiveFailure {
  const InvalidName();
}

class NotListable extends LiveFailure {
  const NotListable();
}

class OwnQueue extends LiveFailure {
  const OwnQueue();
}

class ProNotOpen extends LiveFailure {
  const ProNotOpen();
}

class QueuePaused extends LiveFailure {
  const QueuePaused();
}

class AlreadyInQueue extends LiveFailure {
  const AlreadyInQueue();
}

class JoinLimitReached extends LiveFailure {
  const JoinLimitReached();
}

class AbsentBlock extends LiveFailure {
  const AbsentBlock();
}

class TooManyIds extends LiveFailure {
  const TooManyIds();
}

/// The entry already ended (or is not the caller's own remote entry).
class EntryNotActive extends LiveFailure {
  const EntryNotActive();
}

/// "Absent" on an entry that was never called: only the called customer
/// can be missing.
class EntryNotCalled extends LiveFailure {
  const EntryNotCalled();
}

/// The server refused this pro's channel and does not return it either
/// (other space, unpublished): the pro has no live line for this caller.
/// Terminal until the space or account changes.
class LiveUnavailable extends LiveFailure {
  const LiveUnavailable();
}

class LiveNetworkFailure extends LiveFailure {
  const LiveNetworkFailure();
}

class UnknownLiveFailure extends LiveFailure {
  const UnknownLiveFailure(this.debug);
  final String debug;
}

/// Every SQL error code of the live migrations (bare
/// `raise exception '<code>'`), in one place so it can be diffed against
/// `supabase/migrations/` with a grep (a test does it). Codes that only a
/// client bug can trigger are in [liveUnmappedCodes] instead.
///
/// Import with a prefix or `hide NotOwner` where `pro_failure.dart` is also
/// imported: both declare a `NotOwner`.
const liveFailureCodes = <String, LiveFailure>{
  'not_owner': NotOwner(),
  'not_open': NotOpen(),
  'invalid_break_until': InvalidBreakUntil(),
  'request_reused': RequestReused(),
  'queue_empty': QueueEmpty(),
  'nothing_to_undo': NothingToUndo(),
  'nothing_serving': NothingServing(),
  'not_remote': NotRemote(),
  'invalid_service': InvalidService(),
  'invalid_name': InvalidName(),
  'not_listable': NotListable(),
  'own_queue': OwnQueue(),
  'pro_not_open': ProNotOpen(),
  'queue_paused': QueuePaused(),
  'already_in_queue': AlreadyInQueue(),
  'join_limit_reached': JoinLimitReached(),
  'absent_block': AbsentBlock(),
  'too_many_ids': TooManyIds(),
  'entry_not_active': EntryNotActive(),
  'entry_not_called': EntryNotCalled(),
};

/// Raised by the live migrations but deliberately left to
/// [UnknownLiveFailure]: `request_id_required` and `invalid_status` mean the
/// app sent a null argument (a bug, not a user situation), and
/// `history_is_kept` guards a delete no client can issue.
const liveUnmappedCodes = {
  'request_id_required',
  'invalid_status',
  'history_is_kept',
};

/// Whether retrying the same action may succeed or may already have
/// succeeded server-side: the request id must then be reused.
bool isRetryable(LiveFailure f) =>
    f is LiveNetworkFailure || f is UnknownLiveFailure;

/// Runs [body] and turns every escaping error into a [LiveFailure].
Future<T> guardLive<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on LiveFailure {
    rethrow;
  } on PostgrestException catch (e) {
    throw _map(e);
  } on SocketException {
    throw const LiveNetworkFailure();
  } on TimeoutException {
    throw const LiveNetworkFailure();
  } on Object catch (e) {
    // package:http's ClientException is matched by name: http is not a direct
    // dependency of this package.
    if (e.runtimeType.toString() == 'ClientException') {
      throw const LiveNetworkFailure();
    }
    throw UnknownLiveFailure(e.toString());
  }
}

// Whole-token match: `not_open` must not fire inside `pro_not_open`.
final _token = RegExp('[a-z][a-z_]*');

LiveFailure _map(PostgrestException e) {
  for (final m in _token.allMatches(e.message)) {
    final f = liveFailureCodes[m.group(0)];
    if (f != null) return f;
  }
  return UnknownLiveFailure(e.message);
}
