# AgriMore Sales Associate Canonical Design System

## Overview

This specification establishes the canonical design system foundation for the **AgriMore Sales Associate** Flutter application (`apps/employee`). It translates the 7 canonical visual reference boards into clean, reusable, production-ready tokens and components, strictly isolated from other AgriMore applications.

---

## 1. Architectural Isolation Guarantee

The Sales Associate app introduces a blue-primary brand identity (`#2563EB`) without polluting the shared marketplace emerald green palette:

| Invariant | Implementation | Guarantee |
| :--- | :--- | :--- |
| **Shared Palette** | `AppColors.primary = Color(0xFF0D9B5C)` | **Untouched**. Marketplace, Admin, Seller, and Delivery retain emerald green branding. |
| **Shared Theme** | `AppTheme.lightTheme` | **Untouched**. Other apps never see or inherit Sales Associate styling. |
| **Sales Associate Theme** | `SalesAssociateTheme.lightTheme` | **Opt-in**. Exclusively consumed by `apps/employee/lib/app/app.dart` and the catalogue. |
| **Token Access** | `SaTokens` & `SalesAssociateTokens` extension | Constant tokens and `Theme.of(context).extension<SalesAssociateTokens>()`. |

---

## 2. Color Token Reference

All colors are light-theme only and mapped to `SaTokens` constants and `SalesAssociateTokens` theme extension:

### Primary Palette
- **Primary**: `#2563EB` (`SaTokens.primary`) — Main actions, active navigation, focused outlines.
- **Primary Pressed**: `#1D4ED8` (`SaTokens.primaryPressed`) — Pressed button and interactive states.
- **Primary Subtle**: `#EFF6FF` (`SaTokens.primarySubtle`) — Info containers, active pill backgrounds, selected highlights.

### Neutral Foundations
- **Page Background**: `#F8FAFC` (`SaTokens.pageBackground`) — Slate-tinted neutral page background.
- **Surface**: `#FFFFFF` (`SaTokens.surface`) — Pure white cards, bottom sheets, and app bars.
- **Text Primary**: `#0F172A` (`SaTokens.textPrimary`) — High-contrast slate heading and body text.
- **Text Secondary**: `#475569` (`SaTokens.textSecondary`) — Field captions, supporting descriptions, timestamps.
- **Subtle Divider**: `#E2E8F0` (`SaTokens.divider`) — Card outlines, list separators, subtle borders.
- **Input Border**: `#64748B` (`SaTokens.inputBorder`) — Form control boundaries and resting field borders.

### Semantic Accents
- **Success**: Foreground `#15803D` (`SaTokens.successFg`), Surface `#F0FDF4` (`SaTokens.successBg`).
- **Warning**: Foreground `#B45309` (`SaTokens.warningFg`), Surface `#FFFBEB` (`SaTokens.warningBg`).
- **Error**: Foreground `#B91C1C` (`SaTokens.errorFg`), Surface `#FEF2F2` (`SaTokens.errorBg`).

---

## 3. Typography Scale (Inter)

All typography utilizes **Inter** across a rigorous 6-level scale:

| Level | Size (sp) | Line Height | Weight | Usage |
| :--- | :---: | :---: | :---: | :--- |
| **Display amount** | 32 | 40 | Semibold 600 | Financial wallet balances, earnings figures (`₹12,500.00`). |
| **Screen title** | 24 | 32 | Semibold 600 | Page headers, modal sheet titles (`Welcome back`). |
| **Section heading**| 18 | 26 | Semibold 600 | Card titles, group dividers (`Account details`). |
| **Body** | 16 | 24 | Regular 400 | Descriptive paragraphs, explanations, instruction text. |
| **Label** | 14 | 20 | Medium 500 | Form field headers, button text, table column labels. |
| **Caption** | 12 | 18 | Regular 400 | Timestamps, metadata, validation hints, status notes. |

---

## 4. Icon System (`SaIcons`)

The 20 canonical Lucide outline icons are available via `SaIcons`:

```dart
import 'package:agrimore_ui/agrimore_ui.dart';

Icon(SaIcons.phone, size: SaTokens.iconControl);
```

### Catalogue
- **Authentication / Identity**: `SaIcons.phone`, `SaIcons.mail`, `SaIcons.lockKeyhole`, `SaIcons.user`
- **Navigation & Actions**: `SaIcons.arrowLeft`, `SaIcons.x`, `SaIcons.logOut`, `SaIcons.copy`, `SaIcons.share2`
- **Inputs & Visibility**: `SaIcons.eye`, `SaIcons.eyeOff`
- **Feedback & Notices**: `SaIcons.info`, `SaIcons.circleAlert`, `SaIcons.triangleAlert`, `SaIcons.circleCheck`, `SaIcons.rotateCcw`
- **Domain Entities**: `SaIcons.wallet`, `SaIcons.shoppingBag`, `SaIcons.bell`, `SaIcons.headphones`

### Standard Sizing
- **Supporting (in-list, hints)**: 16 px (`SaTokens.iconSupporting`)
- **Controls (buttons, inputs)**: 20 px (`SaTokens.iconControl`)
- **Navigation (app bars, bottom tabs)**: 24 px (`SaTokens.iconNav`)
- **Minimum Touch Target**: Centered within a 48 × 48 px container (`SaTokens.minTouchTarget`).

---

## 5. Shape, Spacing & Layout Constants

- **Standard Control Height**: 52 px (`SaTokens.controlHeight`)
- **Horizontal Page Padding**: 20 px (`SaTokens.pagePadding`)
- **Spacing Scale**: 4, 8, 12, 16, 24, 32, 48 px (`SaTokens.space4` through `SaTokens.space48`)
- **Corner Radii**:
  - Input fields & buttons: 12 px (`SaTokens.radiusInput`)
  - Cards & modals: 16 px (`SaTokens.radiusCard`)
  - Bottom sheet top corners: 24 px (`SaTokens.radiusBottomSheet`)
- **Card Styling**: Flat background (`#FFFFFF`), subtle border (`#E2E8F0`, 1px), 0 elevation.

---

## 6. Shared Components

### `SaLoadingButton`
A high-order action button supporting primary (filled `#2563EB`) and outlined variants with built-in loading spinner, loading text, and accessibility semantics:

```dart
SaLoadingButton(
  text: 'Continue',
  variant: SaButtonVariant.primary,
  isLoading: isSubmitting,
  loadingText: 'Signing in...',
  onPressed: () => submitForm(),
)
```

### `SaInfoBanner`
An inline contextual feedback container (info, warning, error, success) pairing semantic colors and icons with clear recovery text:

```dart
SaInfoBanner(
  title: 'Payout Details Required',
  message: 'Please link your bank account to request a payout.',
  variant: SaBannerVariant.warning,
  actionLabel: 'Link Account',
  onAction: () => navigateToBankSetup(),
)
```

---

## 7. Content & Privacy Conventions (`SaFormatters`)

- **Currency Formatting**: Always format financial amounts using `SaFormatters.formatCurrency(num)`:
  - Output: `₹12,500.00` (Indian number grouping with 2 decimals).
- **Date Formatting**: `SaFormatters.formatDate(DateTime)`:
  - Output: `18 Sep 2026` (Day-month-year with abbreviated month).
- **Masked Phone**: `SaFormatters.formatMaskedPhone(String)`:
  - Output: `+91 •••••• 4321`.
- **Masked Account**: `SaFormatters.formatMaskedAccount(String)`:
  - Output: `Account ending 4321`.

---

## 8. Developer Component Catalogue

A standalone component catalogue is included in `apps/employee/lib/catalogue/`. It boots with zero Firebase initialization, requires no production login, and uses mock data:

### Run the Catalogue
```bash
cd apps/employee
flutter run -t lib/catalogue/main_catalogue.dart
```

Tabs include:
1. **Brand & Tokens**: Interactive palette swatches, spacing scale, and radius specimens.
2. **Typography**: Live 6-level Inter typography scale with a real-time system text-scale slider (80%–200%).
3. **Icons**: 20-icon interactive catalogue with touch target verification and size specimens.
4. **Components**: Interactive `SaLoadingButton` (with live spinner toggle), form input states, feedback banners, and financial transaction cards.
5. **Content & Privacy**: Masked field specimens and Indian formatting convention demonstrations.

---

## 9. Future Screen Implementation Guide

When refactoring or authoring screens in `apps/employee/lib/screens/`:

1. **Import `agrimore_ui`**:
   ```dart
   import 'package:agrimore_ui/agrimore_ui.dart';
   import '../utils/sa_formatters.dart';
   ```
2. **Read Theme Tokens**:
   ```dart
   final tokens = Theme.of(context).extension<SalesAssociateTokens>()!;
   ```
3. **Buttons**: Use `SaLoadingButton` instead of raw `ElevatedButton` or `CustomButton`.
4. **Banners & Warnings**: Use `SaInfoBanner` for inline messages. Use `SnackbarHelper` for temporary notifications.
5. **Icons**: Use `SaIcons.<iconName>` with standard sizes (16, 20, 24 px).
6. **Cards**: Use standard `Card` widget (which inherits 16px radius, flat elevation, and `#E2E8F0` border from `SalesAssociateTheme`).
7. **Text**: Use `Theme.of(context).textTheme.<style>` to ensure full compatibility with system text scaling.
