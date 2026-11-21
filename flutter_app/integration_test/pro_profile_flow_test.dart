import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/bootstrap.dart';
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/pro/data/price_parse.dart';
import 'package:lemqes/features/pro/presentation/edit/hours_editor.dart';
import 'package:lemqes/features/pro/presentation/edit/photo_gallery_editor.dart';
import 'package:lemqes/shared/widgets/ltr.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test OTP numbers only (supabase/config.toml): the code is always 123456.
const _barberPhone = '0550000002';
const _customerPhone = '0550000003';

/// The number the barber gives customers: not her login number.
const _contactPhone = '0661234567';
const _contactShown = '+213 661 23 45 67';
const _code = '123456';
const _password = 'lemqes-test-1';

/// Bou Saâda, wilaya 68 (supabase/migrations/..._geo_dz_seed.sql).
const _region = '68';
const _bouSaada = 2820;

/// Optional review captures: `--dart-define=LEMQES_SHOTS=fr_light` (or
/// `ar_dark`) with `LEMQES_SHOTS_DIR` set to an absolute folder. The flow
/// then runs in that language and theme and saves one PNG per screen.
const _shots = String.fromEnvironment('LEMQES_SHOTS');
const _shotsDir = String.fromEnvironment('LEMQES_SHOTS_DIR');

/// A 64 x 64 JPEG (lagoon square, sand disc), so the photo really decodes.
final _workJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIf'
  'IiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7'
  'Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCABAAEADASIA'
  'AhEBAxEB/8QAGQABAQEBAQEAAAAAAAAAAAAAAAYEAwUH/8QAKxAAAQQBAgUDAwUAAAAAAAAAAQAC'
  'AwQRBSEGEjFBUWFxgaGy8BMikdHh/8QAGAEBAQEBAQAAAAAAAAAAAAAABAYBAgX/xAAlEQACAgIB'
  'AwUAAwAAAAAAAAABAgADBBExIUFRBRITM/BxgfH/2gAMAwEAAhEDEQA/APAREXsyVhF1rVbFyYQ1'
  'oXSvPZo6dsnwN+qoKvBVqRnNZtRwEgENa3nI8g9PplHtyaafsbUTRiX3/Wu/3mTSKnn4InawGC7H'
  'I7O4kYWDHuCV4Fyhb0+QR2oHRE9Ceh9j0PVZVlU3HSNubfh30Ddi6H7xM6IiTCwutWtJctR1oRl8'
  'jg0ddvU+g6rkqXgqq2S7YsuwTCwNaC3OC7O4PbYEfKPk2/DS1niJxKPnvWvz+MpNK0qvpNX9GEcz'
  '3bySEbvP9eAtyIox3Z2LMdky9RFrUIg0BCz3qNfUarq1lnMx24I6tPkeq0IsVip2OZrKGBVhsGfM'
  '9T0+TS7z6sh5uXdr8EBwPQ/ncFZFX8bVWmtWtjAc15jP7d3AjI39MH+VIKxw7zfSHPPeQmdjjHyG'
  'Qcdv4hU/BE7W2bcBB5nsa8HthpIP3BTC0ULj9PvQ2oxkxuyR5HQj5GQusqo3Usg7znDvFF62Hgf5'
  'Pp6LPRvV9Rqts1n8zHbEHq0+D6rQoxlKnR5l6rBgGU7BhEXOxYiqwPnnkEcbBlzj2WAEnQmkgDZk'
  '9xtO1tCtAQeZ8peD2w0YP3BRq361qZ1XUX2AC2MANjacZDR/uT8rArHCpNNAVuZCeoZAvyGdeOB/'
  'UIiJkFNen6nb0uYyVZOXmxzNIy1wHkfh3VJV42gLMW6kjXADeIhwce+xxj6qQREvw6bztx18xmPn'
  'ZGONI3Tx2llPxtUawGCpNI7O4kIYMe4ypzU9au6qQLDwI2nLY2DDQcYz6/PkrAiynCopPuVes3I9'
  'QyLx7Xbp4HSEREyCn//Z',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // This binding leaves the real (GTK) text input attached so a person can
  // type; the test types through `enterText`, so the input is the test's.
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);

  final locale = Locale(_shots.startsWith('ar') ? 'ar' : 'fr');
  final dark = _shots.endsWith('dark');
  final l10n = lookupAppLocalizations(locale);
  final shotKey = GlobalKey();

  testWidgets('women barber publishes; only Femmes customers see her', (
    tester,
  ) async {
    // `supabase db reset` leaves the previous run's session on disk; cleared
    // before Supabase starts (see auth_flow_test.dart).
    await (await SharedPreferences.getInstance()).clear();
    final prefs = await bootstrap();
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await prefs.setString(LocaleController.prefsKey, locale.languageCode);
    await prefs.setString(
      ThemeModeController.prefsKey,
      dark ? ThemeMode.dark.name : ThemeMode.light.name,
    );

    // A phone-sized surface, so layouts (and captures) are the real ones.
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // Time answers for the hours step, in tap order (the dialog itself is
    // covered by Flutter; the seam is `timePickProvider`).
    final times = <TimeOfDay>[];
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            timePickProvider.overrideWithValue(
              (_, _) async => times.isEmpty ? null : times.removeAt(0),
            ),
            // The gallery picker is bypassed: these bytes go through the
            // real PhotoUploader and Storage.
            workPhotoPickerProvider.overrideWithValue(
              () async => XFile.fromData(
                _workJpeg,
                name: 'work.jpg',
                mimeType: 'image/jpeg',
              ),
            ),
          ],
          child: const LemqesApp(),
        ),
      ),
    );

    Future<void> shot(String name) => _capture(tester, shotKey, name);

    // --- Sign up a women barber -------------------------------------------
    await _signUp(
      tester,
      space: 'women',
      role: 'barber',
      name: 'Nadia',
      phone: _barberPhone,
    );

    // Setup 1/3: profile. The display name comes from sign-up.
    await _waitFor(tester, find.byKey(const Key('displayNameField')));
    await shot('setup_profile');
    await _tap(tester, find.byKey(const Key('pickRegion')));
    await _enter(tester, const Key('pickerSearch'), _region);
    await _tap(tester, find.byKey(const Key('option_$_region')));
    // The commune sheet opens on its own once the wilaya is picked.
    await _waitForGone(tester, find.byKey(const Key('option_$_region')));
    await _enter(tester, const Key('pickerSearch'), 'Bou Saada');
    await _tap(tester, find.byKey(const Key('option_$_bouSaada')));
    await _waitForGone(tester, find.byKey(const Key('pickerSearch')));
    await _tap(tester, find.byKey(const Key('mix_adults_and_kids')));
    await _tap(tester, find.byKey(const Key('setupContinue')));

    // Setup 2/3: two presets and a custom service priced in Arabic digits.
    await _waitFor(tester, find.byKey(const Key('addCustomService')));
    await _addService(
      tester,
      find.byKey(const Key('preset_women_salon_cut_blowdry')),
    );
    await _addService(
      tester,
      find.byKey(const Key('preset_women_salon_russian_manicure')),
    );
    await _addService(
      tester,
      find.byKey(const Key('addCustomService')),
      name: 'Soin au henné',
      price: '٤٥٠',
      duration: '٤٠',
    );
    await _waitFor(tester, find.text(formatDzd(450, locale)));
    await shot('setup_services');
    await _tap(tester, find.byKey(const Key('setupContinue')));

    // Setup 3/3: the offered week is Sat-Thu 09:00-19:00, Friday closed. A
    // 13:00-14:00 break on Saturday, copied to every day.
    await _waitFor(tester, find.byKey(const Key('day_6_addBreak')));
    expect(
      tester.widget<Switch>(find.byKey(const Key('day_5_open'))).value,
      isFalse,
    );
    await _tap(tester, find.byKey(const Key('day_6_addBreak')));
    times.addAll(const [
      TimeOfDay(hour: 13, minute: 0),
      TimeOfDay(hour: 14, minute: 0),
    ]);
    await _tap(tester, find.byKey(const Key('day_6_breakStart')));
    await _tap(tester, find.byKey(const Key('day_6_breakEnd')));
    expect(times, isEmpty);
    await _tap(tester, find.byKey(const Key('day_6_copy')));
    for (final wd in [7, 1, 2, 3, 4]) {
      expect(find.byKey(Key('day_${wd}_breakStart')), findsOneWidget);
    }
    expect(find.byKey(const Key('day_5_breakStart')), findsNothing);
    await _scrollToTop(tester);
    await shot('setup_hours');
    await _tap(tester, find.byKey(const Key('setupPublish')));

    // Published: the pro home opens on Today; "Mon profil" is the dashboard.
    await _tap(tester, find.byKey(const Key('proNavProfile')));
    await _waitFor(tester, find.byKey(const Key('visibilityCard')));
    await _waitFor(tester, find.text(l10n.dashboardPublished));

    // One work photo, through the real uploader.
    await _scrollTo(tester, find.byKey(const Key('photoAdd')));
    await _tap(tester, find.byKey(const Key('photoAdd')));
    await _waitFor(tester, find.byKey(const Key('photoUploading_0')));
    await _waitForGone(tester, find.byKey(const Key('photoUploading_0')));
    expect(find.byKey(const Key('photoFailed_0')), findsNothing);
    final photos = await client.from('pro_photos').select('id, path');
    expect(photos, hasLength(1));
    final barberProId =
        (await client.from('pro_profiles').select('id')).single['id'] as String;
    expect(photos.single['path'], startsWith('$barberProId/'));
    await _scrollToTop(tester);
    await shot('dashboard');

    // Stored as typed: Sat-Thu with the break, Friday absent (closed).
    final hours = await client
        .from('pro_hours')
        .select('weekday, opens, closes, break_start, break_end')
        .eq('pro_id', barberProId)
        .order('weekday', ascending: true);
    expect([for (final h in hours) h['weekday']], [1, 2, 3, 4, 6, 7]);
    for (final h in hours) {
      expect(
        [h['opens'], h['closes'], h['break_start'], h['break_end']],
        ['09:00:00', '19:00:00', '13:00:00', '14:00:00'],
      );
    }
    final services = await client
        .from('pro_services')
        .select('preset_key, name, price_dzd')
        .eq('pro_id', barberProId);
    expect(services, hasLength(3));
    expect(
      services.where((s) => s['name'] == 'Soin au henné').single,
      containsPair('price_dzd', 450),
    );

    // RLS + grants from the real client: the space is never client-writable.
    await expectLater(
      client
          .from('pro_profiles')
          .update({'space': 'men'})
          .eq('id', barberProId),
      // No column grant on `space`: refused before RLS.
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect(
      (await client.from('pro_profiles').select('space')).single['space'],
      'women',
    );
    // A public phone needs a contact number of her own (CHECK), and the
    // column is not selectable, not even by her.
    await expectLater(
      client
          .from('pro_profiles')
          .update({'phone_visibility': 'public'})
          .eq('id', barberProId),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
    );
    await expectLater(
      client.from('pro_profiles').select('contact_phone'),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );

    // Storage API limits, in the barber's own folder (so only the limit can
    // refuse): a disallowed type, then a file over 5 MB.
    final storage = client.storage.from('work-photos');
    await expectLater(
      storage.uploadBinary(
        '$barberProId/not-an-image.txt',
        Uint8List.fromList(utf8.encode('hello')),
        fileOptions: const FileOptions(contentType: 'text/plain'),
      ),
      _storageRefusal('415'),
    );
    await expectLater(
      storage.uploadBinary(
        '$barberProId/too-big.jpg',
        Uint8List(5 * 1024 * 1024 + 1)..setAll(0, _workJpeg),
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      ),
      _storageRefusal('413'),
    );
    // A folder that is no profile of hers.
    await expectLater(
      storage.uploadBinary(
        '00000000-0000-4000-8000-000000000000/x.jpg',
        _workJpeg,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      ),
      _storageRefusal('403'),
    );
    expect(await client.from('pro_photos').select('id'), hasLength(1));

    // Editing the profile from the dashboard saves and comes back to it (the
    // save's reload must not undo the pop).
    await _scrollToTop(tester);
    await _tap(tester, find.byKey(const Key('dashEditProfile')));
    await _enter(tester, const Key('workplaceNameField'), 'Salon Nadia');
    await _tap(tester, find.byKey(const Key('setupContinue')));
    await _waitForGone(tester, find.byKey(const Key('displayNameField')));
    await _waitFor(
      tester,
      find.byKey(const Key('dashEditProfile')).hitTestable(),
    );
    await _scrollToTop(tester);
    await _waitFor(tester, find.byKey(const Key('visibilityCard')));
    expect(find.text(l10n.dashboardPublished), findsOneWidget);
    expect(
      (await client.from('pro_profiles').select('workplace_name'))
          .single['workplace_name'],
      'Salon Nadia',
    );

    await _signOut(tester);

    // --- A men customer ---------------------------------------------------
    await _signUp(
      tester,
      space: 'men',
      role: 'customer',
      name: 'Karim',
      phone: _customerPhone,
    );
    final card = find.byKey(Key('proCard_$barberProId'));
    await _waitFor(tester, find.byKey(const Key('spaceSwitch_women')));
    await _waitForResults(tester);
    expect(card, findsNothing);
    final menSearch = await client.rpc<List<dynamic>>('search_pros');
    expect(menSearch, isEmpty);

    // Femmes: listed.
    await _tap(tester, find.byKey(const Key('spaceSwitch_women')));
    await _waitFor(tester, card);
    await shot('explore');

    // Kids filter keeps her (adults + kids).
    await _tap(tester, find.byKey(const Key('filterKids')));
    await _waitForResults(tester);
    expect(card, findsOneWidget);

    // Bou Saâda (wilaya 68) keeps her.
    await _tap(tester, find.byKey(const Key('filterPlace')));
    await _tap(tester, find.byKey(const Key('pickRegion')));
    await _enter(tester, const Key('pickerSearch'), _region);
    await _tap(tester, find.byKey(const Key('option_$_region')));
    await _waitForGone(tester, find.byKey(const Key('option_$_region')));
    await _enter(tester, const Key('pickerSearch'), 'Bou Saada');
    await _tap(tester, find.byKey(const Key('option_$_bouSaada')));
    await _waitForGone(tester, find.byKey(const Key('pickRegion')));
    await _waitForResults(tester);
    expect(card, findsOneWidget);

    // The public profile: services, hours, the photo; the phone is hidden
    // (the default), so there is no call button.
    await _tap(tester, card);
    final page = find.byType(ProPublicProfileScreen);
    Finder onPage(Finder f) => find.descendant(of: page, matching: f);
    await _waitFor(tester, onPage(find.text(l10n.proPublicServices)));
    expect(onPage(find.text('Soin au henné')), findsOneWidget);
    expect(onPage(find.text(formatDzd(450, locale))), findsOneWidget);
    expect(onPage(find.text(l10n.proPublicHours)), findsOneWidget);
    // Six open days at 09:00-19:00 with the break; Friday closed.
    expect(onPage(find.text('09:00 – 19:00')), findsNWidgets(6));
    expect(onPage(find.text('13:00 – 14:00')), findsNWidgets(6));
    await _waitFor(tester, find.byKey(const Key('proPhoto_0')));
    await tester.ensureVisible(find.byKey(const Key('proPhoto_0')));
    await _waitFor(
      tester,
      find.descendant(
        of: find.byKey(const Key('proPhoto_0')),
        matching: find.byWidgetPredicate(
          (w) => w is RawImage && w.image != null,
        ),
      ),
    );
    expect(find.byKey(const Key('photoError')), findsNothing);
    expect(find.byKey(const Key('callPro')), findsNothing);
    // Customers see the services in the order the pro added them.
    final listed = await client.rpc<List<dynamic>>(
      'pro_public_services',
      params: {'p_pro_id': barberProId},
    );
    expect(
      [
        for (final s in listed.cast<Map<String, dynamic>>())
          s['preset_key'] ?? s['name'],
      ],
      [
        'women_salon_cut_blowdry',
        'women_salon_russian_manicure',
        'Soin au henné',
      ],
    );
    expect(find.byKey(const Key('phoneRetry')), findsNothing);
    await _scrollToTop(tester);
    await shot('profile');
    await _tap(tester, find.byKey(const Key('proBack')));

    // Storage: a customer cannot write into the barber's folder.
    await expectLater(
      client.storage
          .from('work-photos')
          .uploadBinary(
            '$barberProId/intruder.jpg',
            _workJpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          ),
      _storageRefusal('403'),
    );

    // Back in Hommes: not even a direct select by id reaches her row.
    await _tap(tester, find.byKey(const Key('spaceSwitch_men')));
    await _waitFor(tester, find.text(l10n.homeSpaceLabel('men')));
    final direct = await client
        .from('pro_profiles')
        .select('id')
        .eq('id', barberProId);
    expect(direct, isEmpty);
    for (final table in ['pro_hours', 'pro_photos']) {
      expect(
        await client.from(table).select('pro_id').eq('pro_id', barberProId),
        isEmpty,
        reason: table,
      );
    }

    await _signOut(tester);

    // --- The barber makes a contact number public ---------------------------
    await _logIn(tester, _barberPhone);
    await _tap(tester, find.byKey(const Key('proNavProfile')));
    await _waitFor(tester, find.byKey(const Key('visibilityCard')));
    await _scrollTo(tester, find.byKey(const Key('phone_public')));
    await _tap(tester, find.byKey(const Key('phone_public')));
    await _enter(tester, const Key('contactPhoneField'), _contactPhone);
    await _tap(tester, find.byKey(const Key('contactPhoneSave')));
    await _waitFor(tester, find.byKey(const Key('contactPhoneNumber')));
    expect(find.text(_contactShown), findsOneWidget);
    expect(
      await client.rpc<String?>(
        'own_pro_contact_phone',
        params: {'p_pro_id': barberProId},
      ),
      '+213661234567',
    );
    await _scrollToTop(tester);
    await _signOut(tester);

    // --- The Femmes customer now gets the call, with that number -----------
    await _logIn(tester, _customerPhone);
    await _waitFor(tester, find.byKey(const Key('spaceSwitch_women')));
    await _tap(tester, find.byKey(const Key('spaceSwitch_women')));
    await _waitFor(tester, card);
    await _tap(tester, card);
    await _waitFor(tester, find.byKey(const Key('callPro')));
    expect(
      find.ancestor(of: find.text(_contactShown), matching: find.byType(Ltr)),
      findsOneWidget,
    );
    expect(
      await client.rpc<String?>(
        'pro_contact_phone',
        params: {'p_pro_id': barberProId},
      ),
      '+213661234567',
    );
    await expectLater(
      client.from('pro_profiles').select('contact_phone').eq('id', barberProId),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await _tap(tester, find.byKey(const Key('proBack')));
    await _signOut(tester);
  });
}

/// A Storage API refusal with [status] (415 type, 413 size, 403 policy), so
/// a refusal for another reason does not pass for this one.
Matcher _storageRefusal(String status) => throwsA(
  isA<StorageException>().having((e) => e.statusCode, 'statusCode', status),
);

Future<void> _signUp(
  WidgetTester tester, {
  required String space,
  required String role,
  required String name,
  required String phone,
}) async {
  await _tap(tester, find.byKey(const Key('tab_signup')));
  await _tap(tester, find.byKey(Key('space_$space')));
  await _tap(tester, find.byKey(const Key('primaryAction')));
  await _tap(tester, find.byKey(Key('role_$role')));
  await _tap(tester, find.byKey(const Key('primaryAction')));
  await _enter(tester, const Key('nameField'), name);
  await _enter(tester, const Key('phoneField'), phone);
  await _enter(tester, const Key('passwordField'), _password);
  await _enter(tester, const Key('confirmField'), _password);
  await _tap(tester, find.byKey(const Key('primaryAction')));
  final field = find.descendant(
    of: find.byKey(const Key('codeField')),
    matching: find.byType(EditableText),
  );
  await _waitForSettledRoute(tester, field);
  await tester.enterText(field, _code);
  await tester.pump();
}

/// Opens the service editor with [open], optionally fills it, and saves.
Future<void> _addService(
  WidgetTester tester,
  Finder open, {
  String? name,
  String? price,
  String? duration,
}) async {
  await _tap(tester, open);
  await _waitFor(tester, find.byKey(const Key('serviceSave')));
  if (name != null) await _enter(tester, const Key('serviceNameField'), name);
  if (price != null) {
    await _enter(tester, const Key('servicePriceField'), price);
  }
  if (duration != null) {
    await _enter(tester, const Key('serviceDurationField'), duration);
  }
  await _tap(tester, find.byKey(const Key('serviceSave')));
  await _waitForGone(tester, find.byKey(const Key('serviceSave')));
  // The step saves and reloads with its suggestions off (progress bar on);
  // the next one can only be opened once that has settled.
  await _waitForGone(tester, find.byType(LinearProgressIndicator));
}

/// Waits until the explore list has answered (no skeleton, no progress).
Future<void> _waitForResults(WidgetTester tester) async {
  await _waitForGone(tester, find.byKey(const Key('exploreSkeleton')));
  await _waitForGone(tester, find.byType(LinearProgressIndicator));
  // A debounced search may start a beat later.
  await _pumpFor(tester, const Duration(milliseconds: 600));
  await _waitForGone(tester, find.byType(LinearProgressIndicator));
}

/// Scrolls the screen's list down until [finder] is built (lazy lists only
/// build what is near the viewport).
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final list = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  await tester.dragUntilVisible(
    finder,
    list.hitTestable().first,
    const Offset(0, -300),
  );
  await tester.pump();
}

Future<void> _scrollToTop(WidgetTester tester) async {
  for (final s in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (s as StatefulElement).state as ScrollableState;
    if (state.axisDirection == AxisDirection.down) state.position.jumpTo(0);
  }
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (_shots.isEmpty || _shotsDir.isEmpty) return;
  // Images and transitions settle in real time.
  await _pumpFor(tester, const Duration(milliseconds: 1200));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.625);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$_shotsDir/$name-$_shots.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Pumps real frames until [finder] matches; the backend answers in real time
/// and spinners never settle, so `pumpAndSettle` cannot be used.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder; on screen: ${_texts()}',
  );
}

/// The visible texts, to say where a timed-out wait was stuck.
String _texts() => [
  for (final e in find.byType(Text).hitTestable().evaluate())
    (e.widget as Text).data ?? '',
].where((t) => t.isNotEmpty).join(' | ');

Future<void> _waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder to go; on screen: '
    '${_texts()}',
  );
}

/// Waits until [finder]'s route has finished its transition. Mid-transition
/// the outgoing page can still take a tap meant for the incoming one: a
/// field then never gets focus and the text typed into it is lost (the form
/// later refuses to submit, seen as a sign-up that never reaches the code).
Future<void> _waitForSettledRoute(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitForSettledRoute(tester, finder);
  await tester.ensureVisible(finder.first);
  await _waitFor(tester, finder.hitTestable());
  await tester.tap(finder.hitTestable().first);
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await _waitForSettledRoute(tester, finder);
  // A sheet replacing one with the same field keeps both onstage until the
  // transition ends.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().length > 1 && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
  // Fail here, not 30 s later at a form that never submits.
  final field = tester.widget<EditableText>(
    find.descendant(of: finder, matching: find.byType(EditableText)).first,
  );
  expect(field.controller.text, text, reason: 'text typed into $key');
}

Future<void> _logIn(WidgetTester tester, String phone) async {
  await _enter(tester, const Key('phoneField'), phone);
  await _enter(tester, const Key('passwordField'), _password);
  await _tap(tester, find.byKey(const Key('primaryAction')));
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('settings')));
  await _tap(tester, find.byKey(const Key('signOut')));
  await _tap(tester, find.byKey(const Key('confirmSignOut')));
  await _waitFor(tester, find.byKey(const Key('tab_login')));
}
