# Seller Account navigation icons

The active set is the 14 transparent PNGs in `normalized/`. The `*-v1.png`
files are retained as original design references; the app does not use them.

Style: front-facing, shallow matte clay, simplified silhouettes, teal #0F766E,
mint #DDF3EA and ivory #FFF9EE. No background tile. Store status and notification
artwork are neutral; actual status remains in the row text.

Use `SellerAccountIcon` from the seller design system. It centers each icon by
its measured visible bounds and renders a 40 logical-pixel maximum artwork
extent within a 48 logical-pixel slot. It requests a device-scale decode size.
Do not render the original padded PNG directly or add another surrounding tile.
The icon is decorative: the Account row supplies its accessible label and tap target.

All 14 icons are used across 15 Account rows (settings is shared by AI connection
and Settings). Header buttons, chevrons and bottom navigation retain the compact
vector icon system.

`account-icons-preview.png` is Flutter-rendered evidence showing every icon on
light/dark menu surfaces. Regenerate from apps/seller with:

```
flutter test --dart-define=ICON_EVIDENCE=true test/design_system/seller_account_icon_test.dart
```

Validation: the icon rendering test and existing Account tests pass (5 tests).
Scoped Flutter static analysis passed. Preview visually inspected at navigation
size. This is widget-render verification, not a physical iOS/Android device run.
