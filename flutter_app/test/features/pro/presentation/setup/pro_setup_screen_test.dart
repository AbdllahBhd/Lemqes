import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/pro/data/pro_repository.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/features/pro/presentation/setup/pro_setup_flow.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ProRepository {}

class _Account extends AccountController {
  _Account(this._role);
  final AppRole _role;
  @override
  Future<Account?> build() async => Account(
    id: 'u1',
    fullName: 'Amine Benali',
    customerSpace: Space.men,
    proSpace: Space.men,
    activeRole: _role,
    roles: {AppRole.customer, AppRole.barber, _role},
  );
}

void main() {
  // A switch to a role without a pro kind (customer, salon owner) rebuilds a
  // setup step before the redirect takes it home: it must wait, not build a
  // form for a kind that does not exist.
  for (final role in [AppRole.customer, AppRole.salonOwner]) {
    testWidgets('a ${role.name} on a setup step sees loading, not the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountProvider.overrideWith(() => _Account(role)),
            proRepositoryProvider.overrideWithValue(_MockRepo()),
          ],
          child: MaterialApp(
            theme: lemqesTheme(Brightness.light),
            locale: const Locale('fr'),
            localizationsDelegates: appDelegates,
            supportedLocales: supportedLocales,
            home: const ProSetupScreen(step: 'profile'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileStep), findsNothing);
      expect(find.byType(LoadingView), findsOneWidget);
    });
  }
}
