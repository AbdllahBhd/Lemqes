import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/features/pro/data/pro_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ProRepository {}

class _FakeAccount extends AccountController {
  _FakeAccount(this._account);
  final Account _account;
  @override
  Future<Account?> build() async => _account;
}

class _PendingAccount extends AccountController {
  @override
  Future<Account?> build() => Completer<Account?>().future;
}

Account _account(AppRole role) => Account(
  id: 'u1',
  fullName: 'Karim',
  customerSpace: Space.men,
  proSpace: Space.men,
  activeRole: role,
  roles: {AppRole.customer, role},
);

ProProfile _profile({String name = 'Karim'}) => ProProfile(
  id: 'p1',
  kind: ProKind.barber,
  space: Space.men,
  displayName: name,
  workplaceType: WorkplaceType.salon,
  phoneVisibility: PhoneVisibility.hidden,
  showPrices: true,
  isVerified: false,
);

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  ProviderContainer make(AppRole role) {
    final c = ProviderContainer(
      overrides: [
        proRepositoryProvider.overrideWithValue(repo),
        accountProvider.overrideWith(() => _FakeAccount(_account(role))),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myProProvider, (_, _) {});
    return c;
  }

  setUp(() {
    repo = _MockRepo();
    registerFallbackValue(const ProProfilePatch());
    registerFallbackValue(ProKind.barber);
    registerFallbackValue(AppRole.barber);
  });

  test('loads the profile of the active pro role', () async {
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => _profile());
    container = make(AppRole.barber);
    expect((await container.read(myProProvider.future))?.id, 'p1');
    verify(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .called(1);
  });

  test('stays loading (not null) while the account is loading', () async {
    final c = ProviderContainer(
      overrides: [
        proRepositoryProvider.overrideWithValue(repo),
        accountProvider.overrideWith(_PendingAccount.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myProProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(myProProvider).isLoading, isTrue);
    verifyNever(() => repo.mine(any(), activeRole: any(named: 'activeRole')));
  });

  test(
    'a role switch during a mutation never queries in customer mode',
    () async {
      when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
          .thenAnswer((_) async => _profile());
      container = make(AppRole.barber);
      await container.read(myProProvider.future);
      when(() => repo.publish('p1')).thenAnswer((_) async {
        container.read(accountProvider.notifier).state = AsyncData(
          _account(AppRole.customer),
        );
        return DateTime.utc(2026);
      });
      await container.read(myProProvider.notifier).publish();
      await container.pump();
      expect(container.read(myProProvider).value, isNull);
      verify(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
          .called(1);
      verifyNever(() => repo.mine(any(), activeRole: AppRole.customer));
    },
  );

  test('a write while the profile still belongs to the previous role is '
      'refused, never sent', () async {
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => _profile());
    when(() => repo.mine(ProKind.homeArtist, activeRole: AppRole.homeArtist))
        .thenAnswer((_) => Completer<ProProfile?>().future);
    container = make(AppRole.barber);
    await container.read(myProProvider.future);

    container.read(accountProvider.notifier).state = AsyncData(
      _account(AppRole.homeArtist),
    );
    await container.pump();
    // Riverpod keeps the barber profile as the value while reloading.
    expect(container.read(myProProvider).value?.kind, ProKind.barber);

    await container
        .read(myProProvider.notifier)
        .updateProfile(const ProProfilePatch(displayName: 'Lina'));

    verifyNever(() => repo.updateProfile(any(), any()));
    expect(container.read(myProProvider).hasError, isTrue);
  });

  test('home artist role loads the home_artist kind', () async {
    when(() => repo.mine(ProKind.homeArtist, activeRole: AppRole.homeArtist))
        .thenAnswer((_) async => null);
    container = make(AppRole.homeArtist);
    expect(await container.read(myProProvider.future), isNull);
    verify(() => repo.mine(ProKind.homeArtist, activeRole: AppRole.homeArtist))
        .called(1);
  });

  test('a non-pro role has no profile and no query', () async {
    container = make(AppRole.customer);
    expect(await container.read(myProProvider.future), isNull);
    verifyNever(() => repo.mine(any(), activeRole: any(named: 'activeRole')));
  });

  test('updateProfile calls the repo then refetches', () async {
    var name = 'Karim';
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => _profile(name: name));
    when(() => repo.updateProfile('p1', any())).thenAnswer((_) async {
      name = 'Karim B';
    });
    container = make(AppRole.barber);
    await container.read(myProProvider.future);
    await container
        .read(myProProvider.notifier)
        .updateProfile(const ProProfilePatch(displayName: 'Karim B'));
    verify(() => repo.updateProfile('p1', any())).called(1);
    verify(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .called(2);
    expect(container.read(myProProvider).value?.displayName, 'Karim B');
  });

  test(
    'a failed mutation keeps the previous value and exposes the error',
    () async {
      when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
          .thenAnswer((_) async => _profile());
      when(() => repo.publish('p1'))
          .thenThrow(const ProfileIncomplete({ProfileGap.hours}));
      container = make(AppRole.barber);
      await container.read(myProProvider.future);
      await container.read(myProProvider.notifier).publish();
      final s = container.read(myProProvider);
      expect(s.hasError, isTrue);
      expect(s.error, isA<ProfileIncomplete>());
      expect(s.value?.id, 'p1');
      verify(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
          .called(1);
    },
  );

  test('a write that went through is not reported as failed when the reload '
      'fails; the profile loads again', () async {
    var reloads = 0;
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async {
          reloads++;
          if (reloads == 2) throw const ProNetworkFailure();
          return _profile();
        });
    when(() => repo.publish('p1'))
        .thenAnswer((_) async => DateTime.utc(2026, 11, 14));
    container = make(AppRole.barber);
    await container.read(myProProvider.future);
    final failure = await container.read(myProProvider.notifier).publish();
    expect(failure, isNull);
    await container.read(myProProvider.future);
    expect(container.read(myProProvider).hasError, isFalse);
    expect(reloads, 3);
  });

  test('a failed write returns its failure', () async {
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => _profile());
    when(() => repo.publish('p1'))
        .thenThrow(const ProfileIncomplete({ProfileGap.hours}));
    container = make(AppRole.barber);
    await container.read(myProProvider.future);
    final failure = await container.read(myProProvider.notifier).publish();
    expect(failure, isA<ProfileIncomplete>());
  });

  test('create refetches', () async {
    ProProfile? stored;
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => stored);
    when(
      () => repo.create(
        ProKind.barber,
        displayName: 'Karim',
        workplaceType: WorkplaceType.salon,
      ),
    ).thenAnswer((_) async => stored = _profile());
    container = make(AppRole.barber);
    expect(await container.read(myProProvider.future), isNull);
    await container
        .read(myProProvider.notifier)
        .create(displayName: 'Karim', workplaceType: WorkplaceType.salon);
    expect(container.read(myProProvider).value?.id, 'p1');
  });

  test('mutations without a profile are a no-op', () async {
    when(() => repo.mine(ProKind.barber, activeRole: AppRole.barber))
        .thenAnswer((_) async => null);
    container = make(AppRole.barber);
    await container.read(myProProvider.future);
    await container.read(myProProvider.notifier).publish();
    verifyNever(() => repo.publish(any()));
  });

  test(
    'presetsProvider asks the repository for the space and home flag',
    () async {
      when(() => repo.presets(Space.men, home: true))
          .thenAnswer((_) async => []);
      container = make(AppRole.barber);
      final r = await container.read(
        presetsProvider((space: Space.men, home: true)).future,
      );
      expect(r, isEmpty);
      verify(() => repo.presets(Space.men, home: true)).called(1);
    },
  );
}
