# Seller redesign — verification report

Phase **SELLER-REDESIGN-1**. Every result below is from a command run in this session; nothing is carried
over from memory or documents. "Simulated" means a test double stood in for an external service and the
real service was **not** exercised.

## Baseline (before any change) — branch at `ab600a5` (= develop `358d3da` + claim row)

Command: `bash .claude/skills/agrimore/scripts/gate.sh --full` (logs `/tmp/sredesign-gate-baseline/`),
then `cd apps/seller && flutter test`.

| Check | Result |
|---|---|
| functions:build | exit 0 |
| analyze marketplace | 0 errors · 141 warnings · 322 infos |
| analyze admin | 0 errors · 88 warnings · 532 infos |
| analyze seller | 0 errors · 0 warnings · 21 infos |
| analyze delivery | 0 errors · 0 warnings · 20 infos |
| analyze employee | 0 errors · 2 warnings · 0 infos |
| guards (client-secrets, secret-bindings, fee-truthfulness, deploy-bundle, delivery-states) | all exit 0 |
| canon seller / employee / delivery (ratchet) | exit 0 (seller 0 literals) |
| ledger validator | 2 warnings (ambient: branches of concurrent phases not yet on develop) |
| tests: marketplace, agrimore_ui, employee, agrimore_core, delivery, admin, core-web | all exit 0 |
| seller `flutter test` | 217 passed, 0 failed |

## Tooling available on this machine

| Tool | State |
|---|---|
| Flutter | 3.44.8 stable, Dart 3.12.2 |
| Android | SDK present, AVD `Pixel_8_API_35` (API 35) running as `emulator-5554` |
| iOS | **Not available**: `xcode-select -p` → `/Library/Developer/CommandLineTools`; `xcodebuild` requires Xcode; no `simctl`. |
| JDK 21 (Firebase emulators) | `/opt/homebrew/opt/openjdk@21` (hazards.md) — to be confirmed when the emulators start |

## Results after the redesign

_Filled in as work lands; see `progress.md`._

## Journeys (brief §15)

| # | Journey | How | Result |
|---|---|---|---|
| 1–25 | _pending_ | | |
