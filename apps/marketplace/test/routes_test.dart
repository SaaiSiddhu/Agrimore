// Regression lock for apps/marketplace's routing layer (Phase M1).
//
// Why this file exists: apps/marketplace had ZERO routing coverage, and that is
// precisely how two defects reached production and survived multiple phases.
//
//   M-1  main.dart's notification-tap handler passed `arguments: {'orderId': id}`
//        — a Map — to a route case that did `settings.arguments as String?`. The
//        _CastError was swallowed by onGenerateRoute's own try/catch and turned
//        into the 404 screen, so EVERY background and terminated-state push
//        notification tap dead-ended on NotFoundScreen.
//
//   M-2  '/order/track' could never be reached. The dynamic `/order/` prefix
//        handler runs BEFORE the static switch and read the literal word "track"
//        as an order id, silently rendering an order-detail screen for an order
//        that does not exist.
//
// Both guards below are named for their defect. If one of them starts failing,
// the corresponding bug has come back.
//
// These tests assert on the WIDGET onGenerateRoute resolves to, and deliberately
// never mount it: MaterialPageRoute.builder is invoked directly to get the widget
// instance, so no initState runs and no Firebase, Firestore or provider tree is
// required. Trying to actually pump these screens would need far more mocking
// than a routing contract warrants — see product_provider_test.dart for the
// setupFirebaseCoreMocks() pattern that becomes necessary the moment you do.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_marketplace/app/routes.dart';
import 'package:agrimore_marketplace/screens/employee/onboarding/associate_onboarding_screen.dart';
import 'package:agrimore_marketplace/screens/not_found_screen.dart';
import 'package:agrimore_marketplace/screens/user/orders/order_details_screen.dart';
import 'package:agrimore_marketplace/screens/user/shop/product_details_screen.dart';
import 'package:agrimore_marketplace/screens/user/shop/shop_screen.dart';

void main() {
  /// Resolves [name]/[arguments] through the real AppRoutes.onGenerateRoute and
  /// returns the widget the resulting route would build.
  ///
  /// A real BuildContext is needed because MaterialPageRoute.builder is a
  /// WidgetBuilder. We pump a trivial host app purely to borrow one; the widget
  /// under test is returned, never inserted into the tree.
  Future<Widget> resolve(
    WidgetTester tester,
    String name, {
    Object? arguments,
  }) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final route = AppRoutes.onGenerateRoute(
      RouteSettings(name: name, arguments: arguments),
    );
    expect(route, isA<MaterialPageRoute>(),
        reason: 'onGenerateRoute must always return a MaterialPageRoute');

    return (route as MaterialPageRoute).builder(hostContext);
  }

  group('M-1 guard — notification-tap argument shapes must not 404', () {
    testWidgets(
        'orderDetails accepts a bare String id — the shape every in-app call '
        'site passes (product.id, order.id). If this fails, ordinary in-app '
        'navigation to an order is broken.', (tester) async {
      final widget = await resolve(
        tester,
        AppRoutes.orderDetails,
        arguments: 'ORD-12345',
      );
      expect(widget, isA<OrderDetailsScreen>());
      expect((widget as OrderDetailsScreen).orderId, 'ORD-12345');
    });

    testWidgets(
        'M-1: orderDetails accepts a {"orderId": ...} Map. This is the exact '
        'shape main.dart\'s notification handler used to send, and the exact '
        'input that used to throw a _CastError and land the user on the 404 '
        'screen. If this fails, notification taps are broken again.',
        (tester) async {
      final widget = await resolve(
        tester,
        AppRoutes.orderDetails,
        arguments: const {'orderId': 'ORD-12345'},
      );
      expect(widget, isA<OrderDetailsScreen>());
      expect((widget as OrderDetailsScreen).orderId, 'ORD-12345');
    });

    testWidgets('orderDetails with null arguments falls back to NotFoundScreen',
        (tester) async {
      final widget = await resolve(tester, AppRoutes.orderDetails);
      expect(widget, isA<NotFoundScreen>());
    });

    testWidgets(
        'orderDetails with a blank id falls back to NotFoundScreen rather than '
        'constructing an order screen that can never load', (tester) async {
      expect(await resolve(tester, AppRoutes.orderDetails, arguments: ''),
          isA<NotFoundScreen>());
      expect(await resolve(tester, AppRoutes.orderDetails, arguments: '   '),
          isA<NotFoundScreen>());
      expect(
          await resolve(tester, AppRoutes.orderDetails,
              arguments: const {'orderId': ''}),
          isA<NotFoundScreen>());
    });

    testWidgets(
        'orderDetails with a Map carrying the WRONG key is a 404, not a crash — '
        'the resolver must type-check, never cast', (tester) async {
      final widget = await resolve(
        tester,
        AppRoutes.orderDetails,
        arguments: const {'productId': 'ORD-12345'},
      );
      expect(widget, isA<NotFoundScreen>());
    });

    testWidgets('productDetails accepts a bare String id', (tester) async {
      final widget = await resolve(
        tester,
        AppRoutes.productDetails,
        arguments: 'PROD-999',
      );
      expect(widget, isA<ProductDetailsScreen>());
      expect((widget as ProductDetailsScreen).productId, 'PROD-999');
    });

    testWidgets(
        'M-1: productDetails accepts a {"productId": ...} Map — the second half '
        'of the same notification-tap defect', (tester) async {
      final widget = await resolve(
        tester,
        AppRoutes.productDetails,
        arguments: const {'productId': 'PROD-999'},
      );
      expect(widget, isA<ProductDetailsScreen>());
      expect((widget as ProductDetailsScreen).productId, 'PROD-999');
    });

    testWidgets('productDetails with null or blank id is NotFoundScreen',
        (tester) async {
      expect(await resolve(tester, AppRoutes.productDetails),
          isA<NotFoundScreen>());
      expect(await resolve(tester, AppRoutes.productDetails, arguments: ''),
          isA<NotFoundScreen>());
    });
  });

  group('Dynamic path routes — the deep-link and notification surface', () {
    testWidgets(
        '/order/<id> resolves to OrderDetailsScreen. This is the most common '
        'deep link in the app and is what main.dart now pushes for order '
        'notifications — it must not regress.', (tester) async {
      final widget = await resolve(tester, '/order/ORD-777');
      expect(widget, isA<OrderDetailsScreen>());
      expect((widget as OrderDetailsScreen).orderId, 'ORD-777');
    });

    testWidgets('/order/<id> strips a query string and fragment',
        (tester) async {
      final widget = await resolve(tester, '/order/ORD-777?from=push#top');
      expect(widget, isA<OrderDetailsScreen>());
      expect((widget as OrderDetailsScreen).orderId, 'ORD-777');
    });

    testWidgets(
        'M-2: /order/track must NOT be read as an order whose id is the word '
        '"track". The reserved-segment guard sends it to the switch, where no '
        'such route exists, so it honestly 404s instead of silently rendering '
        'an order screen for a non-existent order.', (tester) async {
      final widget = await resolve(tester, '/order/track');
      expect(widget, isA<NotFoundScreen>());
    });

    testWidgets(
        'M-2 boundary: an order id that merely CONTAINS a reserved word still '
        'resolves — the guard matches whole segments only', (tester) async {
      final widget = await resolve(tester, '/order/track123');
      expect(widget, isA<OrderDetailsScreen>());
      expect((widget as OrderDetailsScreen).orderId, 'track123');
    });

    testWidgets('/product/<id> resolves to ProductDetailsScreen',
        (tester) async {
      final widget = await resolve(tester, '/product/PROD-42');
      expect(widget, isA<ProductDetailsScreen>());
      expect((widget as ProductDetailsScreen).productId, 'PROD-42');
    });

    testWidgets('/category/<id> resolves to ShopScreen for that category',
        (tester) async {
      final widget = await resolve(tester, '/category/CAT-7');
      expect(widget, isA<ShopScreen>());
      expect((widget as ShopScreen).categoryId, 'CAT-7');
    });
  });

  group('ONBOARD-1 guard — associate onboarding web handoff query string', () {
    testWidgets(
        'the bare path (no query string) still resolves to '
        'AssociateOnboardingScreen with a null handoffCode — the pre-existing, '
        'exact-match case in the switch. If this fails, ordinary in-app '
        'navigation to Profile → "Become a Sales Associate" is broken.',
        (tester) async {
      final widget = await resolve(tester, AppRoutes.associateOnboarding);
      expect(widget, isA<AssociateOnboardingScreen>());
      expect((widget as AssociateOnboardingScreen).handoffCode, isNull);
    });

    testWidgets(
        'ONBOARD-1: a `?handoff=<code>` query string resolves to '
        'AssociateOnboardingScreen with that code. Dart\'s switch only matches '
        'the bare path by exact equality, so this exercises the dedicated '
        'default-branch parsing added for the mobile-to-web handoff button — '
        'if this regresses to NotFoundScreen, the button leads to a 404 for '
        'every visitor.', (tester) async {
      final widget = await resolve(
        tester,
        '${AppRoutes.associateOnboarding}?handoff=abc123',
      );
      expect(widget, isA<AssociateOnboardingScreen>());
      expect((widget as AssociateOnboardingScreen).handoffCode, 'abc123');
    });

    testWidgets(
        'a query string present but with no `handoff` key resolves with a '
        'null handoffCode, not a crash', (tester) async {
      final widget = await resolve(
        tester,
        '${AppRoutes.associateOnboarding}?other=xyz',
      );
      expect(widget, isA<AssociateOnboardingScreen>());
      expect((widget as AssociateOnboardingScreen).handoffCode, isNull);
    });

    testWidgets(
        'an empty `handoff=` value resolves with an empty-string handoffCode, '
        'not null — the screen itself treats empty the same as absent before '
        'attempting redemption', (tester) async {
      final widget = await resolve(
        tester,
        '${AppRoutes.associateOnboarding}?handoff=',
      );
      expect(widget, isA<AssociateOnboardingScreen>());
      expect((widget as AssociateOnboardingScreen).handoffCode, '');
    });
  });

  group('Unknown routes', () {
    testWidgets('an unrecognised route resolves to NotFoundScreen',
        (tester) async {
      expect(await resolve(tester, '/definitely-not-a-route'),
          isA<NotFoundScreen>());
    });

    testWidgets(
        'the unrouted literal placeholder /product/ does not construct a '
        'product screen with an empty id', (tester) async {
      final widget = await resolve(tester, '/product/');
      expect(widget, isNot(isA<ProductDetailsScreen>()));
    });
  });
}
