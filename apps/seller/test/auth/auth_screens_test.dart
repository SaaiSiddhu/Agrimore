import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/app/app.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/auth/account_restricted_screen.dart';
import 'package:seller/screens/auth/application_status_screen.dart';
import 'package:seller/screens/auth/email_sign_in_screen.dart';
import 'package:seller/screens/auth/seller_sign_in_screen.dart';
import 'package:seller/screens/onboarding/apply_intro_screen.dart';

/// SELLER-AUTH-1a screen tests: every auth screen renders without overflow
/// or exceptions in light and dark, at phone and desktop widths, at 1.0× and
/// 2.0× text (ADR §16), and shows the copy its state calls for.
const _phone = Size(390, 844);
const _desktop = Size(1440, 900);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget screen, {
  required SellerAuthProvider provider,
  Brightness brightness = Brightness.light,
  Size size = _phone,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late AppLocalizations l10n;
  await tester.pumpWidget(
    ChangeNotifierProvider<SellerAuthProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, brightness),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return screen;
        }),
      ),
    ),
  );
  await tester.pump();
  return l10n;
}

void main() {
  final matrix = <(String, Brightness, Size, double)>[
    ('light phone 1x', Brightness.light, _phone, 1.0),
    ('dark phone 1x', Brightness.dark, _phone, 1.0),
    ('light phone 2x', Brightness.light, _phone, 2.0),
    ('dark desktop 1x', Brightness.dark, _desktop, 1.0),
  ];

  group('A-01 sign in', () {
    for (final (name, b, size, scale) in matrix) {
      testWidgets('phone step renders — $name', (tester) async {
        final l10n = await _pump(tester, const SellerSignInScreen(),
            provider: SellerAuthProvider.preview(), brightness: b, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.getOtpCta), findsOneWidget);
        expect(find.text(l10n.googleCta), findsOneWidget);
        expect(find.text(l10n.emailSignInLink), findsOneWidget);
      });
    }

    testWidgets('desktop shows the brand panel value propositions', (tester) async {
      final l10n = await _pump(tester, const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(), size: _desktop);
      expect(find.text(l10n.authValueOrders), findsOneWidget);
      expect(find.text(l10n.authValuePayments), findsOneWidget);
    });

    testWidgets('invalid number is rejected before any request', (tester) async {
      final l10n = await _pump(tester, const SellerSignInScreen(), provider: SellerAuthProvider.preview());
      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text(l10n.getOtpCta));
      await tester.pump();
      expect(find.text(l10n.phoneErrorInvalid), findsOneWidget);
    });
  });

  group('A-02 verify OTP', () {
    for (final (name, b, size, scale) in matrix) {
      testWidgets('otp step renders — $name', (tester) async {
        final l10n = await _pump(
          tester,
          const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(pendingPhone: '+919876543210'),
          brightness: b,
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.otpTitle), findsOneWidget);
        expect(find.byType(WsOtpInput), findsOneWidget);
        expect(find.text(l10n.otpSentSms(AgFormat.maskPhone('+919876543210'))), findsOneWidget);
      });
    }

    testWidgets('test mode shows the ribbon; real delivery does not', (tester) async {
      final l10n = await _pump(tester, const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(pendingPhone: '+919876543210', testOtp: '123456'));
      expect(find.text(l10n.testModeRibbon), findsOneWidget);

      final l10n2 = await _pump(tester, const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(pendingPhone: '+919876543210'));
      expect(find.text(l10n2.testModeRibbon), findsNothing);
    });

    testWidgets('voice delivery says so', (tester) async {
      final l10n = await _pump(tester, const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(pendingPhone: '+919876543210', otpChannel: 'voice'));
      expect(find.text(l10n.otpSentVoice(AgFormat.maskPhone('+919876543210'))), findsOneWidget);
    });

    testWidgets('network error is shown inline in plain language', (tester) async {
      final l10n = await _pump(tester, const SellerSignInScreen(),
          provider: SellerAuthProvider.preview(pendingPhone: '+919876543210', error: SellerAuthError.network));
      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });
  });

  group('A-04 email sign in', () {
    for (final (name, b, size, scale) in matrix) {
      testWidgets('renders — $name', (tester) async {
        final l10n = await _pump(tester, const EmailSignInScreen(),
            provider: SellerAuthProvider.preview(), brightness: b, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.emailTitle), findsOneWidget);
        expect(find.text(l10n.forgotPassword), findsOneWidget);
      });
    }

    testWidgets('reset without an email asks for one inline', (tester) async {
      final l10n = await _pump(tester, const EmailSignInScreen(), provider: SellerAuthProvider.preview());
      await tester.tap(find.text(l10n.forgotPassword));
      await tester.pump();
      expect(find.text(l10n.resetNeedsEmail), findsOneWidget);
    });
  });

  group('A-06 application status', () {
    for (final (name, b, size, scale) in matrix) {
      testWidgets('renders timeline and support — $name', (tester) async {
        final l10n = await _pump(tester, const ApplicationStatusScreen(),
            provider: SellerAuthProvider.preview(access: SellerAccess.pending),
            brightness: b, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.statusTitle), findsOneWidget);
        expect(find.byType(WsTimeline), findsOneWidget);
        expect(find.text(l10n.supportTitle), findsOneWidget);
        expect(find.text(l10n.signOut), findsOneWidget);
      });
    }
  });

  group('A-07 account restricted', () {
    for (final reason in RestrictionReason.values) {
      for (final (name, b, size, scale) in matrix) {
        testWidgets('$reason renders — $name', (tester) async {
          await _pump(tester, AccountRestrictedScreen(reason: reason),
              provider: SellerAuthProvider.preview(access: SellerAccess.noApplication, phone: '+919876543210'),
              brightness: b, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('each reason shows its own title', (tester) async {
      var l10n = await _pump(tester, const AccountRestrictedScreen(reason: RestrictionReason.rejected),
          provider: SellerAuthProvider.preview(access: SellerAccess.rejected));
      expect(find.text(l10n.restrictedRejectedTitle), findsOneWidget);
      expect(find.text(l10n.applyReopenCta), findsOneWidget, reason: 'rejected sellers can fix and resubmit');
      l10n = await _pump(tester, const AccountRestrictedScreen(reason: RestrictionReason.suspended),
          provider: SellerAuthProvider.preview(access: SellerAccess.suspended));
      expect(find.text(l10n.restrictedSuspendedTitle), findsOneWidget);
      expect(find.text(l10n.applyReopenCta), findsNothing, reason: 'suspension is not self-service');
    });
  });

  group('auth gate', () {
    final expectations = <SellerAccess, Type>{
      SellerAccess.signedOut: SellerSignInScreen,
      SellerAccess.noApplication: ApplyIntroScreen,
      SellerAccess.pending: ApplicationStatusScreen,
      SellerAccess.rejected: AccountRestrictedScreen,
      SellerAccess.suspended: AccountRestrictedScreen,
    };
    expectations.forEach((access, screen) {
      testWidgets('$access routes to $screen', (tester) async {
        await _pump(tester, const SellerAuthGate(), provider: SellerAuthProvider.preview(access: access));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
      });
    });

    testWidgets('loading shows progress, not a screen', (tester) async {
      await _pump(tester, const SellerAuthGate(), provider: SellerAuthProvider.preview(access: SellerAccess.loading));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(SellerSignInScreen), findsNothing);
    });
  });
}
