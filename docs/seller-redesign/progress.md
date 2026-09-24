# Seller redesign — progress log

Resume point for a fresh context: read this file, then `implementation-plan.md` §6 and `screen-matrix.md`.
Worktree `/Users/saai_siddharth/Projects/Clients/Agrimore-sredesign`, branch `agrimore/sredesign1-seller-ui`.
The single folder `/Users/saai_siddharth/Projects/Clients/Agrimore` must stay on `develop` (others merge there).

## 2026-09-24

- Read CLAUDE.md, the /agrimore skill (worker, uiux, feedback, merge, hazards, decisions) and the seller ADR.
- Inspected all 86 mockups image by image; notes → `mockup-inspection-notes.md` (86 sections).
- Collision check: DLV-P1 (Agrimore-dlvp1) and UI-SA1 (Agrimore-sadark) ACTIVE, both touching shared
  Workspace files; plan in `implementation-plan.md` §6.
- Worktree + branch created from `develop` `358d3da`; claim row committed `ab600a5` (identity verified,
  no trailer).
- Dependencies: `npm ci` (functions) + `flutter pub get` ×8 — clean, no lockfile drift.
- Baseline gate `--full`: failed=0 (see `verification-report.md` §Baseline); seller suite 217/217.
- Read every seller source file; findings folded into `decisions.md` D6–D12 and `screen-matrix.md`.
- Palette finalised with a contrast script (decisions D1/D2).
- Tooling: Android AVD `Pixel_8_API_35` running as `emulator-5554` (shared machine — check the foreground
  app before screenshots); **no Xcode** (Command Line Tools only) → iOS build/run blocked.

- Owner decision D-SELLER-OWN-DS: the design system moved inside the app (`67876b3`, D0).
- Foundation and components (`69b4756`, `2884b91`); app, shell and Home (`b7eeae8`); Orders (`aa918a3`);
  Catalogue (`faba613`) and the product editor (`944fca4`); Payments (`1a61299`, then `6d2caf5`, which fixed a
  failing test and a canon violation that `1a61299` went in with; after that, every commit runs only once the
  gate passes); Quotes (`2f07521`); Insights and health (`6dac7fd`); Account and store (`5e3a0b6`); storefront,
  reviews and posts (`99c7743`); AI, notifications, settings, help, policies and search (`8d112f8`); onboarding
  and status (`d70ddb3`); Workspace bridge removed (`6393678`).
- Owner, in chat: leave sign-in as it is (D16); asked for mock OTP in production, which was not built (D17,
  OPEN — account-takeover risk).
- Android device tour (`integration_test/screens_tour_test.dart`, 18 screens, `emulator-5554` Pixel 8 API 35)
  → `evidence/android/`. The first run found three problems:
  - Home greeting cut off in the app bar;
  - "Catalogue" nav label wrapping mid-word;
  - Orders preview trying Firestore and showing an error with the wrong retry label.

  All three are fixed (`478bfcb`, `5dc784d`); rerun passed and the screenshots were re-inspected.
- iOS scaffold `apps/seller/ios` (`9addff9`), bundle `com.agrimore.seller`, usage strings; build BLOCKED.

## Still open

1. End-to-end journeys against isolated emulators (brief §15) are **not executed**:
   - the D13 emulator switch is not built;
   - the OTP sign-in flow is frozen by D16.

   The screens are covered by widget tests with test doubles (labelled simulated) and by the device tour.
   These are not journeys against a backend.
2. iOS build and run: needs Xcode, plus a Firebase iOS app registered for `com.agrimore.seller`. The
   shared iOS options target the marketplace bundle.
3. TalkBack/VoiceOver pass by hand (semantics are covered by tests only).
4. D17 needs the owner's decision.
