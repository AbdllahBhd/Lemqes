import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_api.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockApi extends Mock implements ProApi {}

Map<String, Object?> _row({
  Object? services,
  Object? hours,
  Object? photos,
  bool withOwner = false,
}) => {
  'id': 'p1',
  if (withOwner) 'owner_id': 'u1',
  'kind': 'barber',
  'space': 'men',
  'display_name': 'Karim',
  'bio': null,
  'experience_years': 5,
  'workplace_type': 'salon',
  'workplace_name': 'Chez Karim',
  'locality_id': 1601,
  'customer_mix': 'adults_and_kids',
  'service_radius_km': null,
  'travel_fee_dzd': null,
  'avatar_path': null,
  'phone_visibility': 'public',
  'show_prices': true,
  'is_verified': false,
  'published_at': '2026-11-15T10:00:00+00:00',
  'pro_services': services ?? <Object?>[],
  'pro_hours': hours ?? <Object?>[],
  'pro_photos': photos ?? <Object?>[],
};

Map<String, Object?> _service({String? archivedAt, int? price = 800}) => {
  'id': 's1',
  'preset_key': 'men_salon_classic_cut',
  'name': null,
  'category': 'hair',
  'price_dzd': price,
  'duration_min': 25,
  'active': true,
  'archived_at': archivedAt,
  'sort': 0,
};

void main() {
  late _MockApi api;
  late ProRepository repo;

  setUp(() {
    api = _MockApi();
    repo = ProRepository(api);
  });

  group(
    'error mapping (strings raised by 20261115000200_pro_profiles.sql)',
    () {
      final cases = <String, Matcher>{
        'role_not_held': isA<ProRoleNotHeld>(),
        'profile_missing': isA<ProAccountMissing>(),
        'pro_profile_exists': isA<ProProfileExists>(),
        'not_owner': isA<NotOwner>(),
        'invalid_hours': isA<InvalidHours>(),
        'invalid_weekday': isA<InvalidWeekday>(),
        'invalid_break': isA<InvalidBreak>(),
        'too_many_services': isA<TooManyServices>(),
        'too_many_photos': isA<TooManyPhotos>(),
        'preset_space_mismatch': isA<PresetSpaceMismatch>(),
      };
      cases.forEach((message, matcher) {
        test(message, () async {
          when(() => api.rpc(any(), any()))
              .thenThrow(PostgrestException(message: message));
          await expectLater(repo.publish('p1'), throwsA(matcher));
        });
      });

      test('profile_incomplete carries the gaps from DETAIL', () async {
        when(() => api.rpc(any(), any())).thenThrow(
          const PostgrestException(
            message: 'profile_incomplete',
            details: 'locality,services,hours',
          ),
        );
        await expectLater(
          repo.publish('p1'),
          throwsA(
            isA<ProfileIncomplete>().having((f) => f.gaps, 'gaps', {
              ProfileGap.locality,
              ProfileGap.services,
              ProfileGap.hours,
            }),
          ),
        );
      });

      test('profile_incomplete with no usable detail has no gaps', () async {
        when(() => api.rpc(any(), any()))
            .thenThrow(const PostgrestException(message: 'profile_incomplete'));
        await expectLater(
          repo.publish('p1'),
          throwsA(
            isA<ProfileIncomplete>().having((f) => f.gaps, 'gaps', isEmpty),
          ),
        );
      });

      test('network errors', () async {
        for (final e in <Object>[
          const SocketException('x'),
          TimeoutException('x'),
        ]) {
          when(() => api.rpc(any(), any())).thenThrow(e);
          await expectLater(
            repo.publish('p1'),
            throwsA(isA<ProNetworkFailure>()),
          );
        }
      });

      test('unknown errors keep the debug text', () async {
        when(() => api.rpc(any(), any()))
            .thenThrow(const PostgrestException(message: 'weird'));
        await expectLater(
          repo.publish('p1'),
          throwsA(
            isA<UnknownProFailure>().having((f) => f.debug, 'debug', 'weird'),
          ),
        );
      });
    },
  );

  test('create calls the RPC and parses the returned row', () async {
    when(() => api.rpc('create_pro_profile', any()))
        .thenAnswer((_) async => _row(withOwner: true));
    final p = await repo.create(
      ProKind.barber,
      displayName: 'Karim',
      workplaceType: WorkplaceType.salon,
    );
    verify(
      () => api.rpc('create_pro_profile', {
        'p_kind': 'barber',
        'p_display_name': 'Karim',
        'p_workplace_type': 'salon',
      }),
    ).called(1);
    expect(p.id, 'p1');
    expect(p.ownerId, 'u1');
    expect(p.space, Space.men);
  });

  test('mine parses children, drops archived services, sorts photos', () async {
    when(() => api.selectMine('barber')).thenAnswer(
      (_) async => _row(
        services: [
          _service(),
          {..._service(), 'id': 's2', 'archived_at': '2026-11-15T00:00:00Z'},
        ],
        hours: [
          {
            'weekday': 7,
            'opens': '22:00:00',
            'closes': '02:30:00',
            'break_start': null,
            'break_end': null,
          },
          {
            'weekday': 1,
            'opens': '09:00:00',
            'closes': '18:00:00',
            'break_start': '13:00:00',
            'break_end': '14:00:00',
          },
        ],
        photos: [
          {'id': 'b', 'path': 'p1/b.jpg', 'sort': 1},
          {'id': 'a', 'path': 'p1/a.jpg', 'sort': 0},
        ],
      ),
    );
    final p = (await repo.mine(ProKind.barber, activeRole: AppRole.barber))!;
    expect(p.ownerId, isNull);
    expect(p.services.map((s) => s.id), ['s1']);
    expect(p.hours.map((h) => h.weekday), [1, 7]);
    expect(p.hours.first.breakStart, const TimeOfDay(hour: 13, minute: 0));
    expect(p.hours.first.pastMidnight, isFalse);
    expect(p.hours.last.pastMidnight, isTrue);
    expect(p.photos.map((x) => x.id), ['a', 'b']);
    expect(p.gaps, isEmpty);
    expect(p.publishedAt, DateTime.utc(2026, 11, 15, 10));
  });

  test('mine never queries unless acting as that kind\'s pro role', () async {
    for (final role in [
      AppRole.customer,
      AppRole.salonOwner,
      AppRole.homeArtist,
    ]) {
      expect(await repo.mine(ProKind.barber, activeRole: role), isNull);
    }
    verifyNever(() => api.selectMine(any()));
  });

  test('services are sorted by sort', () async {
    when(() => api.selectMine('barber')).thenAnswer(
      (_) async => _row(
        services: [
          {..._service(), 'id': 'b', 'sort': 2},
          {..._service(), 'id': 'a', 'sort': 1},
        ],
      ),
    );
    final p = (await repo.mine(ProKind.barber, activeRole: AppRole.barber))!;
    expect(p.services.map((s) => s.id), ['a', 'b']);
  });

  test('storage errors map to typed failures', () async {
    final cases = {
      '413': isA<PhotoTooLarge>(),
      '415': isA<UnsupportedImage>(),
      '403': isA<NotOwner>(),
      '500': isA<UnknownProFailure>(),
    };
    for (final e in cases.entries) {
      await expectLater(
        guardPro<void>(() => throw StorageException('x', statusCode: e.key)),
        throwsA(e.value),
      );
    }
  });

  test('mine is null when there is no profile', () async {
    when(() => api.selectMine(any())).thenAnswer((_) async => null);
    expect(
      await repo.mine(ProKind.homeArtist, activeRole: AppRole.homeArtist),
      isNull,
    );
  });

  test('gaps list what blocks publishing', () async {
    when(() => api.selectMine(any())).thenAnswer(
      (_) async => {
        ..._row(),
        'locality_id': null,
        'customer_mix': null,
        'published_at': null,
      },
    );
    final p = (await repo.mine(ProKind.barber, activeRole: AppRole.barber))!;
    expect(p.gaps, ProfileGap.values.toSet());
  });

  test('updateProfile sends only the set fields', () async {
    when(() => api.update(any(), any(), any())).thenAnswer((_) async => {});
    await repo.updateProfile(
      'p1',
      const ProProfilePatch(bio: 'Hi', showPrices: false, localityId: 1601),
    );
    verify(
      () => api.update('pro_profiles', 'p1', {
        'bio': 'Hi',
        'show_prices': false,
        'locality_id': 1601,
      }),
    ).called(1);
  });

  test('patch can explicitly clear a nullable field', () {
    expect(const ProProfilePatch().toDb(), isEmpty);
    expect(const ProProfilePatch(bio: null).toDb(), isEmpty);
    expect(
      const ProProfilePatch(clear: {PatchField.bio, PatchField.workplaceName})
          .toDb(),
      {'bio': null, 'workplace_name': null},
    );
  });

  test('upsertService inserts a draft without id (with pro_id)', () async {
    when(() => api.insert('pro_services', any()))
        .thenAnswer((_) async => _service());
    final s = await repo.upsertService(
      'p1',
      const ProServiceDraft(
        presetKey: 'men_salon_classic_cut',
        category: ServiceCategory.hair,
        priceDzd: 800,
        durationMin: 25,
      ),
    );
    verify(
      () => api.insert('pro_services', {
        'pro_id': 'p1',
        'preset_key': 'men_salon_classic_cut',
        'name': null,
        'category': 'hair',
        'price_dzd': 800,
        'duration_min': 25,
        'active': true,
      }),
    ).called(1);
    expect(s.priceDzd, 800);
  });

  test('upsertService updates when the draft has an id', () async {
    when(() => api.update('pro_services', 's1', any()))
        .thenAnswer((_) async => _service());
    await repo.upsertService(
      'p1',
      const ProServiceDraft(
        id: 's1',
        customName: 'Soin',
        category: ServiceCategory.skincare,
        priceDzd: 900,
        durationMin: 30,
        active: false,
      ),
    );
    verify(
      () => api.update('pro_services', 's1', {
        'preset_key': null,
        'name': 'Soin',
        'category': 'skincare',
        'price_dzd': 900,
        'duration_min': 30,
        'active': false,
      }),
    ).called(1);
  });

  test('archiveService sets archived_at and never deletes', () async {
    when(() => api.update(any(), any(), any())).thenAnswer((_) async => {});
    await repo.archiveService('s1');
    final v =
        verify(() => api.update('pro_services', 's1', captureAny()))
                .captured
                .single
            as Map<String, Object?>;
    expect(v.keys, ['archived_at']);
    expect(v['archived_at'], isA<String>());
    verifyNever(() => api.delete(any(), any()));
  });

  test('setHours sends the jsonb shape of set_pro_hours', () async {
    when(() => api.rpc(any(), any())).thenAnswer((_) async => null);
    await repo.setHours('p1', const [
      DayHours(
        weekday: 1,
        opens: TimeOfDay(hour: 9, minute: 0),
        closes: TimeOfDay(hour: 18, minute: 30),
        breakStart: TimeOfDay(hour: 13, minute: 0),
        breakEnd: TimeOfDay(hour: 14, minute: 0),
      ),
      DayHours(
        weekday: 7,
        opens: TimeOfDay(hour: 22, minute: 0),
        closes: TimeOfDay(hour: 2, minute: 5),
      ),
    ]);
    verify(
      () => api.rpc('set_pro_hours', {
        'p_pro_id': 'p1',
        'p_week': [
          {
            'weekday': 1,
            'opens': '09:00',
            'closes': '18:30',
            'break_start': '13:00',
            'break_end': '14:00',
          },
          {'weekday': 7, 'opens': '22:00', 'closes': '02:05'},
        ],
      }),
    ).called(1);
  });

  test('publish returns the timestamp', () async {
    when(() => api.rpc('publish_pro_profile', {'p_pro_id': 'p1'}))
        .thenAnswer((_) async => '2026-11-15T10:00:00+00:00');
    expect(await repo.publish('p1'), DateTime.utc(2026, 11, 15, 10));
  });

  test('contactPhone returns the RPC string or null', () async {
    when(() => api.rpc('pro_contact_phone', any()))
        .thenAnswer((_) async => '+213551234567');
    expect(await repo.contactPhone('p1'), '+213551234567');
    when(() => api.rpc('pro_contact_phone', any()))
        .thenAnswer((_) async => null);
    expect(await repo.contactPhone('p1'), isNull);
  });

  test(
    'publicProfile reads services through the RPC; hidden price is null',
    () async {
      when(() => api.selectPublic('p1')).thenAnswer((_) async => _row());
      when(() => api.rpc('pro_public_services', {'p_pro_id': 'p1'})).thenAnswer(
        (_) async => [
          {
            'id': 's1',
            'preset_key': 'men_salon_classic_cut',
            'name': null,
            'category': 'hair',
            'price_dzd': null,
            'duration_min': 25,
            'sort': 0,
          },
        ],
      );
      final p = (await repo.publicProfile('p1'))!;
      expect(p.services.single.priceDzd, isNull);
      expect(p.services.single.active, isTrue);
      verifyNever(() => api.selectMine(any()));
    },
  );

  test('publicProfile is null when not visible', () async {
    when(() => api.selectPublic(any())).thenAnswer((_) async => null);
    expect(await repo.publicProfile('x'), isNull);
    verifyNever(() => api.rpc('pro_public_services', any()));
  });

  test('presets are parsed and displayName follows the locale', () async {
    when(() => api.selectPresets('men', false)).thenAnswer(
      (_) async => [
        {
          'key': 'men_salon_classic_cut',
          'space': 'men',
          'home': false,
          'category': 'hair',
          'name_ar': 'قصة كلاسيكية',
          'name_fr': 'Coupe Classique',
          'name_en': 'Classic haircut',
          'name_kab': 'Tukksa',
          'default_price_dzd': 800,
          'default_duration_min': 25,
          'sort': 1,
        },
      ],
    );
    final presets = await repo.presets(Space.men, home: false);
    final byKey = {for (final p in presets) p.key: p};
    const preset = ProService(
      id: 's1',
      presetKey: 'men_salon_classic_cut',
      category: ServiceCategory.hair,
      priceDzd: 800,
      durationMin: 25,
      active: true,
    );
    expect(preset.displayName(const Locale('ar'), byKey), 'قصة كلاسيكية');
    expect(preset.displayName(const Locale('fr'), byKey), 'Coupe Classique');
    expect(preset.displayName(const Locale('en'), byKey), 'Classic haircut');
    expect(preset.displayName(const Locale('kab'), byKey), 'Tukksa');
    const custom = ProService(
      id: 's2',
      customName: 'Soin maison',
      category: ServiceCategory.skincare,
      priceDzd: 1,
      durationMin: 5,
      active: true,
    );
    expect(custom.displayName(const Locale('ar'), byKey), 'Soin maison');
  });

  test('enums round-trip through the DB strings', () {
    expect(ProKind.homeArtist.toDb(), 'home_artist');
    expect(ProKind.fromDb('home_artist'), ProKind.homeArtist);
    expect(WorkplaceType.ownStudio.toDb(), 'own_studio');
    expect(CustomerMix.adultsAndKids.toDb(), 'adults_and_kids');
    expect(CustomerMix.fromDb('kids_only'), CustomerMix.kidsOnly);
    expect(PhoneVisibility.fromDb('followers'), PhoneVisibility.followers);
    expect(ServiceCategory.fromDb('skincare'), ServiceCategory.skincare);
    expect(const Locale('ar'), isNotNull);
  });
}
