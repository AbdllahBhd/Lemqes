import '../../../core/l10n/gen/app_localizations.dart';
import '../data/pro_failure.dart';

/// The words for whatever a pro action threw; never the raw exception.
String proFailureMessage(AppLocalizations l10n, Object? error) =>
    switch (error) {
      ProNetworkFailure() => l10n.errorNetwork,
      TooManyServices() => l10n.proErrorTooManyServices,
      InvalidHours() ||
      InvalidBreak() ||
      InvalidWeekday() => l10n.proErrorInvalidHours,
      ProfileIncomplete() => l10n.setupIncomplete,
      UnsupportedImage() => l10n.proErrorImage,
      PhotoTooLarge() => l10n.proErrorImageTooLarge,
      _ => l10n.errorGeneric,
    };
