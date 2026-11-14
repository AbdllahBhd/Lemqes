import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/account/data/account_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AccountRepository {}

Account _account(Space customerSpace) => Account(
  id: 'u1',
  fullName: 'Lina',
  customerSpace: customerSpace,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer},
);

final _session = Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => Stream.value(_session)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountProvider, (_, _) {});
  });

  test('switchSpace calls repo then refetches', () async {
    var space = Space.men;
    when(() => repo.fetchMine()).thenAnswer((_) async => _account(space));
    when(() => repo.setCustomerSpace(Space.women)).thenAnswer((_) async {
      space = Space.women;
    });
    await container.read(sessionProvider.future);
    await container.read(accountProvider.future);
    await container.read(accountProvider.notifier).switchSpace(Space.women);
    verify(() => repo.setCustomerSpace(Space.women)).called(1);
    expect(container.read(accountProvider).value!.currentSpace, Space.women);
  });

  test('repo failure leaves AsyncError and keeps previous value', () async {
    when(() => repo.fetchMine()).thenAnswer((_) async => _account(Space.men));
    when(() => repo.setCustomerSpace(Space.women))
        .thenThrow(const SpaceLocked());
    await container.read(sessionProvider.future);
    await container.read(accountProvider.future);
    await container.read(accountProvider.notifier).switchSpace(Space.women);
    final state = container.read(accountProvider);
    expect(state.hasError, isTrue);
    expect(state.value!.currentSpace, Space.men);
  });
}
