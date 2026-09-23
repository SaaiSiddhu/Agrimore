import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/screens/seller/seller_handoff_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// SELLER-AUTH-1 marketplace hand-off: Android goes to the Play listing,
/// everything else to the seller web app.
void main() {
  test('android → Play Store listing of com.agrimore.seller', () {
    final u = SellerHandoffScreen.targetFor(web: false, platform: TargetPlatform.android);
    expect(u.toString(), AppConstants.sellerAppPlayUrl);
    expect(u.queryParameters['id'], AppConstants.sellerAppPackageId);
  });

  test('web and iOS → seller web app', () {
    expect(SellerHandoffScreen.targetFor(web: true, platform: TargetPlatform.android).toString(), AppConstants.sellerWebUrl);
    expect(SellerHandoffScreen.targetFor(web: false, platform: TargetPlatform.iOS).toString(), AppConstants.sellerWebUrl);
  });
}
