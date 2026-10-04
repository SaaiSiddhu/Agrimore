# Native compilation evidence — 2026-10-04

Execution mode: SINGLE AGENT. Subagents, delegation, background agents and workflows NO.

## Scope and verdict

CURRENT_IMPLEMENTATION: marketplace iOS compiles for arm64 device architecture in debug and release with code signing disabled. Marketplace Android now compiles an unsigned release APK with production signing and Crashlytics artifact uploads disabled; final Android gate evidence is recorded below. Final release artifact has the registered customer bundle, matching native Firebase SDK configuration and OAuth return URL, and minimum iOS15. This proves one app compiler path only. F8/five-app signing, store upload, actual device/auth/payment/push/permission/background journeys and F9 connected release acceptance remain OPEN.

The artifact was built from the current foundation branch plus preserved owner WIP, including the shared ProductModel change. It does not certify a clean commit or isolated release tree. No app was installed/launched. No signing, provisioning, Firebase app creation/change, live data writes, deployment or push occurred. Client config values were never printed in evidence.

## Commands and results

| Check | Evidence |
|---|---|
| Tool inventory | Flutter3.44.8/Dart3.12.2; Xcode27.0 build27A266a; CocoaPods1.17.0 |
| Initial locked dependencies | `pod install --deployment --no-repo-update` exit1: lock would remove plugins because SDK metadata enables Swift Package Manager; no compiler pass |
| SDK configuration regeneration | `flutter build ios --config-only --no-codesign --no-pub --debug` exit0; corrected ignored old checkout path, generated hybrid SPM/CocoaPods integration; this command also runs Pods, not just a text-only config update |
| First unsigned debug compile | `flutter build ios --no-codesign --no-pub --debug` exit1, SDK target-integrity diagnostics: minimum14 below supported15..27 range |
| Corrected unsigned debug compile | Same command exit0, Xcode89.6s, Runner.app; before final OAuth callback/optional SDK field cleanup |
| Final unsigned release compile | `flutter build ios --release --no-codesign --no-pub` exit0; Xcode184.7s, Runner.app118.1MB |
| Artifact inspection | Mach-O arm64; bundle com.customer.agrimore; version1.0.10/build2026092301; minimum15.0; callback and embedded native SDK match fetched registration |
| Signature inspection | Read-only codesign inspection exit1: unsigned; no embedded provisioning profile |
| Source and inventory | diff whitespace check passes;825files/1141collection accesses/896query-cursor sites/99callables; deterministic exact check passes |

Logs retained locally: `/tmp/agrimore-native-marketplace-pods.log`, `/tmp/agrimore-native-ios-config.log`, `/tmp/agrimore-native-marketplace-ios-debug.log`, `/tmp/agrimore-native-marketplace-pods-current.log`, `/tmp/agrimore-native-marketplace-ios-debug-current.log`, `/tmp/agrimore-native-marketplace-ios-release.log`. Sanitized facts: `/tmp/agrimore-f8-current-native-facts.json`. These paths are local diagnostics, not durable artifact distribution.

## Identity and SDK configuration

Read-only `firebase apps:list IOS --project agrimore-66a4e --json` succeeded and returned one registered iOS app: com.customer.agrimore. Marketplace source previously used com.agroconnect.agroconnect in Xcode and com.agrimore.agrimore in Dart options, and its Dart iOS appId did not match this registration. Its Google sign-in return scheme also differed. Marketplace now aligns project and test-target identifiers, the iOS-only FirebaseOptions block, ignored native SDK plist and OAuth callback with the existing registration. Seven SDK fields match by equality checks without printing values. Other platform FirebaseOptions blocks are unchanged. Missing optional databaseURL was removed from iOS options instead of retaining unrelated stale configuration.

The fetched native `apps/marketplace/ios/Runner/GoogleService-Info.plist` remains gitignored and is not committed. Owner builds need to reconstruct it from the existing customer registration. Installed CLI help confirms `firebase apps:sdkconfig IOS <CUSTOMER_IOS_APP_ID> --project agrimore-66a4e --out apps/marketplace/ios/Runner/GoogleService-Info.plist`; retrieve the existing app id through read-only apps:list, not a new app registration. Native SDK values are referenced by file/key name only. No OAuth client or Firebase app was created or modified.

## Native dependency and minimum changes

Only marketplace minimums changed to15 in Podfile/project, required by the installed SDK/compiler diagnostics. This removes iOS14 support for this candidate; owner release review must include that device-support change. Other four app minima are unchanged.

Flutter's default enabled SPM migration moved compatible plugins from Podfile.lock into18 SPM pins; seven plugin wrappers remain on CocoaPods. Remaining Pod versions compared with the original lock have zero changes/new names. Firebase stays11.15.0. SPM transitive packages are not equivalent to the old CocoaPods lock: GoogleDataTransport10.1.0→10.1.1, Promises2.4.0→2.4.1 and ecosystem-specific leveldb/nanopb labels differ; SwiftProtobuf is a newly explicit SPM pin. The original no-version-change assumption was contradicted by automatic tooling and amended before identity/minimum fixes; no dependency-upgrade command ran. Both Xcode project/workspace Package.resolved files have18 pins and identical content/hash00813af80b07359d1ef806145d6b2acd2f647e4ea169e9baa8a13214890737fa. This locks the tested graph; it is not a transitive runtime/security acceptance claim.

SDK-generated AppFrameworkInfo minimum was removed by the tool, and SPM framework/project/scheme integration was added. These changes were reviewed and compiled. No permission/role/server policy was broadened.

## Remaining native gates

- Signing/provisioning/Apple owner action, release/store declarations and clean isolated artifact provenance.
- Actual device/customer login, Google return, OTP, AppCheck, Razorpay, photos, notification permissions/APNs/taps/background/resume and accessibility.
- SDK reports razorpay-core-pod lacks arm64 simulator support needed by Apple Silicon iOS26+ simulators. Device arm64 compile passed; simulator compatibility remains OPEN, no architecture bypass or dependency upgrade attempted.
- Seven plugin wrappers lack SPM support; hybrid Pods works in this compiler evidence, future SDK compatibility remains open. UIScene migration warning is recorded, not claimed resolved.
- No entitlements files exist in any of the five iOS source trees; APNs signing/capability/transport evidence remains absent. No production capability/provisioning change made.
- Other four apps have no verified native build/device journey. Admin Xcode still uses legacy com.agroconnect.agroconnect and its Dart iOS options differ; seller/delivery/employee have role bundle IDs but no observed iOS SDK options in their local options files. Only customer iOS registration exists live; role-app registrations/configuration require owner-controlled cloud action, which this repository prohibits the agent from performing.
- Android native builds, owner upload-keystore rotation/signing, real devices and release identity/manifest verification remain OPEN. An independent owner Android compiler process was observed and left untouched; it is not this scope's build evidence.

Postcommit foundation gate is pending until recorded below. Full F0–F9 goal stays ACTIVE.


## Generated build analyzer boundary

Initial postcommit default gate at d341f2e6 completed exit1/failed1. Marketplace analysis scanned FlutterFire source/examples/tests downloaded by SPM into build/ios/SourcePackages/checkouts and reported5782 errors,356warnings356infos; all5782 errors were under generated build, zero outside. Other checks were not treated as a broad gate pass. An incorrect relative-path edit attempt did not change options; its subsequent analyzer run still saw generated code and is excluded from final evidence.

Marketplace analysis_options.yaml now excludes only generated build/**. No app/library/test subtree or diagnostic/lint rule is excluded; zero tracked files match the new exclusion. Fresh full marketplace analysis completes with0errors/127warnings278infos (tool exit1 on diagnostics), the exact pre-native app-source baseline. Evidence /tmp/agrimore-native-marketplace-analyze-exact-final.log. Native release inputs/artifact remain unchanged by this analysis-only configuration. Fresh postcommit default gate still required and pending until recorded below.

Security/native configuration review PASS_WITH_FINDINGS: existing live customer SDK registration only; no roles/rules/permissions/providers/cloud creation or live data changes. Ignored client plist stays excluded from commits; public client values are not printed. Source-file scope classifier reports none for these native/config paths; security review applied explicitly despite that classifier limitation. No UI layout changes/native screenshot claim. Hybrid transitive migration/minimum15, signing/clean-tree provenance, other apps and provider/device/push/simulator adoption stay release gates.


## Final postcommit foundation gate

Fresh default gate at0b70cbd0 completed exit0/failed0 after analyzer correction (/tmp/agrimore-native-postcommit-gate-final.log). Functions build passes; all five analyzers0errors: marketplace127warnings278infos, admin74/499, seller0/0, delivery0/0, employee2/0. Analysis-integrity/client-secret/secret-binding/fee/deploy/delivery guards, three canonical ratchets and ledger0warnings pass. Source inventory exact check and diff check pass. The earlier d341f2e6 gate failed1 and is superseded for analyzer scope only; its failed result is retained. Native source unchanged after final unsigned release build; the only later implementation change was analysis_options generated-build exclusion, which does not enter the binary. No new synthetic test claimed: native compiler/artifact/SDK equality and full-source analysis are this scope's verification. Prior full marketplace2211 belonged to the feed scope before iOS client/config edits, not a new final-native suite run.

Local native compiler/configuration scope BUILT+SELF_GATED. Full F8/F9 acceptance, clean-tree provenance, signing, runtime/provider/device/adoption and owner release decisions remain OPEN. Goal ACTIVE. Next bounded native work: Android compiler/manifest evidence with production signing and Crashlytics artifact uploads disabled; no ownership/provisioning/live-provider action inferred from prior compilation.


## Android unsigned release — 2026-10-04

CURRENT_IMPLEMENTATION: customer Dart Android SDK fields align with the existing registered com.customer.agrimore native configuration. Read-only live apps:list ANDROID succeeds with7 registered packages. Native ignored google-services.json exactly equals fetched sdkconfig and its customer appId matches live registration; original Dart Android appId differed. Five corrected SDK fields match by boolean comparison; source customer iOS/Web/macOS blocks are unchanged. No Firebase app/OAuth client/keystore/provider or live data action occurred. Exact SDK options analyzer completes with no issues.

Verification used external `/tmp/agrimore-unsigned-android.init.gradle`: release signingConfig=null, both mapping/native symbol upload flags false, every Crashlytics upload task disabled and unconditional onlyIf false, task-graph assertions before execution. The first dry run failed safely because the included Flutter Gradle plugin build lacks :app; fixed by applying app signing assertions only to the app graph while preserving upload assertions in every graph. No upload/sign task executed. Final dry run completed exit0 in7m54s after public dependency downloads, verified signing disabled and0 selected upload tasks. Read-only daemon thread diagnostics verified active downloads; the existing handle was preserved, no restart/owner interruption for silence/timeouts.

Actual `./gradlew --init-script /tmp/agrimore-unsigned-android.init.gradle :app:assembleRelease` completed exit0 in3m33s:1181tasks,849executed/135cached/197up-to-date. Guard marker confirms null release signing/zero selected Crashlytics upload tasks. No validateSigningRelease task selected. This compiles normal release optimization/native libraries with upload/signing suppressed only for verification; tracked production signing/upload configuration is unchanged. External init includes no credential values. Its absence makes the command fail before build; do not replace it with an unguarded owner release invocation.

| APK artifact check | Result |
|---|---|
| Path | apps/marketplace/build/app/outputs/apk/release/app-release-unsigned.apk; Flutter output copy app-release.apk is also unsigned |
| Bytes | 120773287 |
| SHA256 | b8c9f872eb49977ceb864aa32e254366adafdf464051958bc77e9a795162c783 |
| Identity/version | com.customer.agrimore;1.0.10/build2026092301 |
| SDK | min24, target36, compile36 |
| Native ABIs | arm64-v8a,armeabi-v7a,x86_64;9 native libraries |
| Release flags | Not debuggable; allowBackup=false; usesCleartextTraffic=false |
| Native SDK | Registered customer appId embedded in resource table |
| Archive integrity | ZIP corruption check none |
| Unsigned | apksigner verify exit1 with Missing META-INF/MANIFEST.MF;0v1 signature entries/no v2-v3 signing-block magic |
| ZIP alignment | Build-tools36 zipalign -c -P16 4 passes exit0 |
| ELF alignment | Every 64bit PT_LOAD alignment >=16384; no below16KB library |

Read-only aapt2/apksigner/zipalign and ELF header parsing inspect the APK; no install/sign/run/provider call. Actual runtime/16KB device acceptance is not inferred. The artifact includes preserved owner ProductModel WIP and is not a clean isolated release tree. Source version/store-upload eligibility not verified against the store. Native minimum24 unchanged on Android; prior iOS minimum15 change remains separately documented.

Local logs: /tmp/agrimore-native-android-dry-run.log (failed included-build guard), /tmp/agrimore-native-android-dry-run-final.log (passed), /tmp/agrimore-native-android-release.log, /tmp/agrimore-android-sdk-options-analyze.log, /tmp/agrimore-android-unsigned-artifact-facts.json. Manifest/resources/badging/signature/alignment diagnostics remain in /tmp; resource dump contains public client configuration and is never printed or committed. Native SDK configuration stays ignored. No synthetic unit run is claimed; compiler/artifact/live-metadata equality/source analysis are the verification scope. Source inventory825/1141/896/99 exact check passes.

Build warnings retained, not bypassed: Gradle8.12 uses deprecated features, AGP8.7.3 tested through compile35 while app compiles36, KGP2.1.0 future Flutter compatibility warning and embedded SDK Kotlin mismatch, R8 location companion-object warning. No dependency validation bypass/suppression/upgrade issued. Device GPS/payment/background/adoption remain open.

Merged manifest has21 Android permission names, including microphone/location/camera/notification, legacy storage max32, and SDK advertising/attribution/NFC/basic-phone-state entries. This is artifact presence only, not permission grant/request behavior or store declaration acceptance. Source permissions were not broadened by these SDK identity edits; owner privacy/store review remains open.

Additional role-app native audit: admin explicit Android options match its native SDK. Seller/delivery native SDK configuration matches registered package/project, their mobile initialization uses native options (no local firebase_options.dart). Employee source package com.agrimore.salesassociate has a matching native client entry but is absent from the7 live Android registrations; live com.agrimore.employee is distinct. This requires owner registration/restore versus migration disposition, never a silent package rename/app creation. No app was created/renamed or owner artifact adopted. Other role app compiler/device proof remains open.

Final Android postcommit default gate pending until recorded; full F8/F9 and original F0–F9 goal ACTIVE. Next bounded local native work: other registered role Android compile/config checks without signing/uploads; employee registration and four role iOS registrations/signing/device/provider release gates remain owner-controlled.


Final Android default gate at5c0904f9 completed exit0/failed0 (/tmp/agrimore-android-postcommit-gate-final.log). All five analyzers0errors: marketplace127warnings278infos, admin74/499, seller0/0, delivery0/0, employee2/0; Functions build, analysis-integrity/security/fee/deploy/delivery guards, canonical ratchets and ledger0warnings pass. Earlier run began at claim5cb8f5ab before source commit, retained as baseline only; terminal exact-commit gate above is authoritative. Local Android compiler/configuration scope BUILT+SELF_GATED, full F8/F9 and original ten-phase goal remain OPEN. No deployment consequence for this client configuration scope.
