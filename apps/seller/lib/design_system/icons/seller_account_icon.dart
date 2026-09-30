import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Canonical transparent artwork and measured visible bounds in the 1254px source.
enum SellerAccountIconKind {
  storeStatus('store-status', Rect.fromLTRB(123, 165, 1131, 1089)),
  weeklyOffHolidays('weekly-off-holidays', Rect.fromLTRB(167, 133, 1087, 1120)),
  businessDetails('business-details', Rect.fromLTRB(110, 306, 1146, 948)),
  deliveryFee('delivery-fee', Rect.fromLTRB(100, 298, 1182, 1008)),
  storefront('storefront', Rect.fromLTRB(122, 176, 1166, 1079)),
  reviews('reviews', Rect.fromLTRB(181, 176, 1068, 1075)),
  followersPosts('followers-posts', Rect.fromLTRB(212, 217, 1042, 1039)),
  quotes('quotes', Rect.fromLTRB(160, 169, 1096, 1072)),
  payoutAccount('payout-account', Rect.fromLTRB(109, 119, 1145, 1136)),
  askAi('ask-ai', Rect.fromLTRB(172, 175, 1106, 1080)),
  settings('settings', Rect.fromLTRB(110, 111, 1144, 1130)),
  notification('notification', Rect.fromLTRB(183, 130, 1072, 1095)),
  helpSupport('help-support', Rect.fromLTRB(125, 152, 1130, 1086)),
  sellerPolicies('seller-policies', Rect.fromLTRB(220, 151, 1066, 1124));

  const SellerAccountIconKind(this.fileName, this.bounds);
  final String fileName;
  final Rect bounds;
  String get assetPath => 'assets/images/clay-icons/normalized/$fileName.png';
}

/// Decorative Account-row artwork. Normalizes visible artwork, not PNG canvas
/// padding, to a 40px extent inside a 48px slot. Row text supplies semantics.
class SellerAccountIcon extends StatelessWidget {
  const SellerAccountIcon(this.kind, {super.key});
  final SellerAccountIconKind kind;

  @override
  Widget build(BuildContext context) {
    final bounds = kind.bounds;
    final scale = 40 / math.max(bounds.width, bounds.height);
    final side = 1254 * scale;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 48,
        child: ClipRect(
          child: Stack(children: [
            Positioned(
              left: 24 - bounds.center.dx * scale,
              top: 24 - bounds.center.dy * scale,
              width: side,
              height: side,
              child: Image.asset(
                kind.assetPath,
                cacheWidth:
                    (side * MediaQuery.devicePixelRatioOf(context)).ceil(),
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
