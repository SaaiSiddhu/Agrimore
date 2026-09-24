// lib/auth/auth_copy.dart
//
// Phase DLV-C1 — the sentence for each [RiderAuthProblem], from the ARB file.
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

String authProblemText(AppLocalizations l, RiderAuthProblem p) => switch (p) {
      RiderAuthProblem.wrongCredentials => l.authWrongCredentials,
      RiderAuthProblem.invalidEmail => l.authInvalidEmail,
      RiderAuthProblem.tooManyAttempts => l.authTooManyAttempts,
      RiderAuthProblem.network => l.authNetwork,
      RiderAuthProblem.accountDisabled => l.authAccountDisabled,
      RiderAuthProblem.notDeliveryPartner => l.authNotDeliveryPartner,
      RiderAuthProblem.noPartnerRecord => l.authNoPartnerRecord,
      RiderAuthProblem.noProfile => l.authNoProfile,
      RiderAuthProblem.profileUnavailable => l.authProfileUnavailable,
      RiderAuthProblem.unknown => l.authUnknown,
    };
