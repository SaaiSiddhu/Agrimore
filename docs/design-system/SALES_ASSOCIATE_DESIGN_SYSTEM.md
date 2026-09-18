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

## 9. Screen Implementation Guide

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

---

## 10. Canonical Screen Implementation Map (Phase EMP-2)

Phase EMP-2 implemented complete canonical design system consumption across all 18 numbered screen groups (20 canonical visual surfaces):

| # | Screen Group / Canonical Board | Implementation File | Key Features & Backend Grounding |
| :- | :--- | :--- | :--- |
| **01** | `01_login_phone` | `screens/auth/login_screen.dart` | Phone OTP segmented tab, 10-digit validation, `EmployeeAuthProvider.signInWithPhone()`. |
| **02** | `02_login_otp_sms` | `screens/auth/associate_otp_screen.dart` | 6-digit matrix, masked phone, SMS resend countdown cooldown, `verifyOtp()`. |
| **03** | `03_login_otp_voice_call` | `screens/auth/associate_otp_screen.dart` | Seamless voice call fallback channel toggle, `requestVoiceOtp()`. |
| **04** | `04_login_email_password` | `screens/auth/login_screen.dart` | Segmented email/password sign-in with password visibility toggle and validation. |
| **05** | `05_forgot_password` | `screens/auth/forgot_password_screen.dart` | Email reset link dispatch with info banner for phone-based associates. |
| **06** | `06_pending_approval` | `screens/auth/pending_approval_screen.dart` | Application pending warning state, 3-step timeline, direct support links. |
| **07** | `07_account_suspended` | `screens/auth/suspended_screen.dart` | Explicit suspension notice, paused attribution notice, support channels. |
| **08** | `08_home_dashboard` | `screens/home/dashboard_screen.dart` | Referral share card, active code copy, earnings summary, recent orders list. |
| **09** | `09_orders_list` | `screens/orders/orders_screen.dart` | Attributed orders stream (`orders.employeeUid == uid`), search, B2B/Retail filters. |
| **10** | `10_order_detail` | `screens/orders/order_detail_screen.dart` | Order summary, B2B/B2C status badges, commission pending card, itemized lines. |
| **11** | `11_wallet_overview` | `screens/wallet/wallet_screen.dart` | Display balance (`₹XX,XXX.00`), quick action payouts, recent settlements list. |
| **12** | `12_payout_request_amount` | `screens/wallet/payout_request_screen.dart` | Balance deduction preview, max amount shortcut, available funds validation. |
| **13** | `13_payout_review` | `screens/wallet/payout_review_screen.dart` | Final confirmation card, destination summary, Cloud Function `requestEmployeePayout`. |
| **14** | `14_payout_history` | `screens/wallet/payout_history_screen.dart` | Payout requests stream (`payout_requests.employeeId == uid`), status pills. |
| **15** | `15_payout_details` | `screens/wallet/payout_details_screen.dart` | Request tracking, reference ID, timestamps, destination breakdown. |
| **16** | `16_payout_account` | `screens/wallet/payout_account_screen.dart` | Bank account (IFSC, account #) vs UPI ID destination form stored to `employees/{uid}`. |
| **17** | `17_profile_account` | `screens/profile/profile_screen.dart` | Associate ID card, department, KYC summary, sign-out dialog. |
| **18** | `18_onboarding_status` | `screens/profile/onboarding_status_screen.dart` | ₹500 fee gate status card, B2B vs Retail attribution rules explanation. |
| **19** | `19_help_support` | `screens/support/help_support_screen.dart` | Direct phone & email cards with one-tap clipboard copy, security notice, FAQs. |
| **20** | `20_notifications` | `screens/notifications/notifications_screen.dart` | Inbox stream (`users/{uid}/notifications`), unread indicators, mark-all-as-read batch. |
| **—** | `Shell Architecture` | `screens/shell/employee_shell_screen.dart` | 4 persistent tabs (Home, Orders, Wallet, Profile) with `EmployeeShellController`. |

### Test Verification
Screen tests located in `apps/employee/test/screens/`:
- `auth_screens_test.dart` (Login, OTP, Pending Approval, Suspended, Forgot Password)
- `shell_and_sales_screens_test.dart` (Shell navigation, Dashboard metrics, Onboarding Status)
- `wallet_screens_test.dart` (Payout Request, Payout Account, Payout Review)
- `orders_and_support_screens_test.dart` (Orders List, Order Detail, Notifications, Support, Profile)
- `catalogue_test.dart` (Catalogue navigation, components, text scale stress tests)
Total: 33 tests, 100% passing.

