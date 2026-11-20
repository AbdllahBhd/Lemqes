// Shared by the live-queue integration paths: the UI helpers hardened in M2
// (settled routes, verified typing; see pro_profile_flow_test.dart) and raw
// Supabase clients that act as the other people in the queue.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/config/env.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test OTP numbers (supabase/config.toml, code 123456) and the seed's
/// accounts (supabase/tests/fixtures/live_seed.sql).
const code = '123456';
const password = 'lemqes-test-1';
const barberPhone = '0550000004';
const menCustomerPhone = '0550000005';
const womenCustomerPhone = '0550000006';
const controlPhone = '0550000008';
const menProId = 'b0000000-0000-4000-8000-000000000004';
const womenProId = 'b0000000-0000-4000-8000-000000000014';
const cutServiceId = 'c0000000-0000-4000-8000-000000000041';

/// Optional review captures: `--dart-define=LEMQES_SHOTS=fr_light` (or
/// `ar_dark`) with `LEMQES_SHOTS_DIR` set to an absolute folder.
const shots = String.fromEnvironment('LEMQES_SHOTS');
const shotsDir = String.fromEnvironment('LEMQES_SHOTS_DIR');

/// Live updates are promised within ~2 s; 3 s leaves room for the batch
/// window and a slow frame, never for a missed message.
const liveDeadline = Duration(seconds: 3);

/// `0550000004` as GoTrue stores it.
String e164(String local) => '+213${local.substring(1)}';

/// A client of its own (own session, own socket), as another device would be.
SupabaseClient rawClient() => SupabaseClient(
  Env.supabaseUrl,
  Env.supabaseAnonKey,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

/// A raw client signed in with a seeded password.
Future<SupabaseClient> signedIn(String phone) async {
  final c = rawClient();
  await c.auth.signInWithPassword(phone: e164(phone), password: password);
  return c;
}

/// A raw client signed up with a test OTP number, as the app does it.
Future<SupabaseClient> signedUp(
  String phone, {
  required String name,
  required String space,
}) async {
  final c = rawClient();
  await c.auth.signUp(phone: e164(phone), password: password);
  await c.auth.verifyOTP(phone: e164(phone), token: code, type: OtpType.sms);
  await c.rpc<Object?>(
    'complete_signup',
    params: {'p_full_name': name, 'p_space': space, 'p_role': 'customer'},
  );
  return c;
}

/// A raw private subscription to `pro:<id>`, recording what it gets.
class RawChannel {
  RawChannel(SupabaseClient client, String proId) {
    client
        .channel('pro:$proId', opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(
          event: 'live',
          callback: (m) {
            final payload = m['payload'];
            if (payload is Map) messages.add(Map.of(payload));
            if (!_message.isCompleted) _message.complete();
          },
        )
        .subscribe((status, error) {
          if (_status.isCompleted) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            _status.complete((status, null));
          } else if (status == RealtimeSubscribeStatus.channelError) {
            _status.complete((status, error));
          }
        });
  }

  final messages = <Map<Object?, Object?>>[];
  final _status = Completer<(RealtimeSubscribeStatus, Object?)>();
  var _message = Completer<void>();

  /// The join's answer: `subscribed`, or `channelError` and its error.
  Future<(RealtimeSubscribeStatus, Object?)> joined(Duration timeout) =>
      _status.future.timeout(timeout);

  /// Waits for the next message after this call.
  Future<Map<Object?, Object?>> next(Duration timeout) async {
    _message = Completer<void>();
    await _message.future.timeout(timeout);
    return messages.last;
  }
}

Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// The visible texts, to say where a timed-out wait was stuck.
String _texts() => [
  for (final e in find.byType(Text).hitTestable().evaluate())
    (e.widget as Text).data ?? '',
].where((t) => t.isNotEmpty).join(' | ');

/// Pumps real frames until [finder] matches; the backend answers in real time
/// and spinners never settle, so `pumpAndSettle` cannot be used.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder; on screen: ${_texts()}',
  );
}

Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder to go; on screen: '
    '${_texts()}',
  );
}

/// Pumps real frames until [condition] holds.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TestFailure('Timed out after $timeout waiting for $what');
}

/// Waits until [finder]'s route has finished its transition. Mid-transition
/// the outgoing page can still take a tap meant for the incoming one.
Future<void> waitForSettledRoute(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  bool settled() {
    final route = ModalRoute.of(finder.evaluate().first);
    return route == null ||
        (route.isCurrent &&
            (route.animation?.isCompleted ?? true) &&
            (route.secondaryAnimation?.isDismissed ?? true));
  }

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!settled()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Route of $finder never settled');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitForSettledRoute(tester, finder);
  await tester.ensureVisible(finder.first);
  await waitFor(tester, finder.hitTestable());
  await tester.tap(finder.hitTestable().first);
  await tester.pump();
}

Future<void> enter(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await waitForSettledRoute(tester, finder);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
  // Fail here, not 30 s later at a form that never submits.
  final field = tester.widget<EditableText>(
    find.descendant(of: finder, matching: find.byType(EditableText)).first,
  );
  expect(field.controller.text, text, reason: 'text typed into $key');
}

Future<void> signUpInApp(
  WidgetTester tester, {
  required String space,
  required String role,
  required String name,
  required String phone,
}) async {
  await tap(tester, find.byKey(const Key('tab_signup')));
  await tap(tester, find.byKey(Key('space_$space')));
  await tap(tester, find.byKey(const Key('primaryAction')));
  await tap(tester, find.byKey(Key('role_$role')));
  await tap(tester, find.byKey(const Key('primaryAction')));
  await enter(tester, const Key('nameField'), name);
  await enter(tester, const Key('phoneField'), phone);
  await enter(tester, const Key('passwordField'), password);
  await enter(tester, const Key('confirmField'), password);
  await tap(tester, find.byKey(const Key('primaryAction')));
  final field = find.descendant(
    of: find.byKey(const Key('codeField')),
    matching: find.byType(EditableText),
  );
  await waitForSettledRoute(tester, field);
  await tester.enterText(field, code);
  await tester.pump();
}

Future<void> logInInApp(WidgetTester tester, String phone) async {
  await enter(tester, const Key('phoneField'), phone);
  await enter(tester, const Key('passwordField'), password);
  await tap(tester, find.byKey(const Key('primaryAction')));
}

Future<void> scrollToTop(WidgetTester tester) async {
  for (final s in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (s as StatefulElement).state as ScrollableState;
    if (state.axisDirection == AxisDirection.down) state.position.jumpTo(0);
  }
  await tester.pump();
}

/// Saves the app (under [key]) as `<name>-<shots>.png` when captures are on.
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (shots.isEmpty || shotsDir.isEmpty) return;
  // Images and transitions settle in real time.
  await pumpFor(tester, const Duration(milliseconds: 1200));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.625);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$shotsDir/$name-$shots.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}
