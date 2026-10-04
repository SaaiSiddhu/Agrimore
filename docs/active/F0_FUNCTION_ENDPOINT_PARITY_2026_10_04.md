# Current function endpoint and cloud parity — 2026-10-04

Classification: VERIFIED_REPOSITORY_FACT for network-blocked compiled source and client traces; dated read-only cloud metadata for live functions/indexes. Full F0–F9 acceptance remains OPEN.

Execution: SINGLE AGENT; no subagents, delegation, workflows or background agents. Source commit `4766754f`; source startup on isolated `v22.23.3`, zero attempted network connections. No function invoked. Machine evidence: [F0_FUNCTION_ENDPOINT_PARITY_2026_10_04.json](F0_FUNCTION_ENDPOINT_PARITY_2026_10_04.json).

## Function parity

| Measure | Result |
| --- | ---: |
| Actual SDK source endpoints | 152 |
| Live functions | 87 |
| Matching names | 81 |
| Source-only endpoints | 71 |
| Live-only orphans | 6 |
| Matching-name generation mismatches | 0 |
| Matching-name region mismatches | 0 |
| Matching-name runtime mismatches (source declares Node22) | 15 |

Both read-only Firebase CLI calls returned terminal exit0/success, captured 2026-10-04T09:38:58.199413+00:00. Source exports:111 v2/41 v1;115 callable/7 HTTPS/23 events/7 schedules. Live runtimes:72 Node22/15 Node20. Metadata matching does not certify deployed code equality, current function configuration, managed runtime execution or journey compatibility.

### Node20 owner migration inventory

These15 functions exist in current source and live on Node20; generations match. They need release validation and an owner-operated explicit-name runtime migration. This list is a metadata inventory, not approval to deploy the branch's changed implementation.

- `completeUserProfile`
- `createAssociateOnboardingPayment`
- `creditSignupBonus`
- `getAssociateOnboardingConfig`
- `recordAssociateOnboardingRefund`
- `redeemReferralCode`
- `verifyAssociateCode`
- `verifyEmailForProfile`
- `waiveAssociateOnboardingFee`
- `createEmployeeByAdmin`
- `createSellerByAdmin`
- `requestAssociateOnboardingRefundOnSuspend`
- `requestEmployeePayout`
- `sendEmailOTP`
- `verifyEmailOTP`

### Live-only source-absent functions

- `retryFailedNotifications`
- `sendAfternoonGreeting`
- `sendEveningGreeting`
- `sendMorningGreeting`
- `sendNightGreeting`
- `subscriptionChecker`

Preserve them. Never use a broad functions deployment; it can propose removing functions whose source is absent. Orphan runtime status is in machine evidence; no deletion or provider interaction occurred.

## Client dependency mapping

The inventory has99 callable invocation sites:87 literal sites plus12 dynamic private wrappers. Local callers of all12 wrappers were manually traced, including owned profile commands, rider contact, RFQ, payout, support and payment recovery. They resolve to97 distinct current source callable names;52 of those names are absent from live. 53 invocation sites can select at least one source-only callable. This is source dependency mapping; flags, platform constraints and actual enabled journey reachability still need individual acceptance. No client command was executed.

| Source-only callable with a current client dependency | Sites |
| --- | ---: |
| `addSupportCaseNote` | 1 |
| `adminUpdateOrderStatus` | 1 |
| `aiChatProxy` | 1 |
| `assignSupportCase` | 1 |
| `attachDeliveryProof` | 1 |
| `attachSupportCaseEvidence` | 1 |
| `cancelEmployeePayoutChange` | 1 |
| `changeDateOfBirth` | 1 |
| `changeEmailAddress` | 1 |
| `changePhoneNumber` | 1 |
| `changeSupportCaseStatus` | 1 |
| `claimScratchCard` | 1 |
| `confirmOrderReturnReceived` | 1 |
| `connectAiProvider` | 1 |
| `connectSellerAiProvider` | 1 |
| `createOnboardingWebHandoff` | 1 |
| `createSellerAiActivationOrder` | 1 |
| `createSupportCase` | 4 |
| `createSupportCaseFromSource` | 1 |
| `disconnectAiProvider` | 2 |
| `ensureCheckoutSubscriptions` | 1 |
| `financeReconciliationRecheckFinding` | 1 |
| `financeReconciliationScan` | 1 |
| `linkSupportCaseRecord` | 1 |
| `markEmployeePayoutPaid` | 2 |
| `markRiderPayoutPaid` | 1 |
| `quoteDeliveryFees` | 2 |
| `recoverCheckoutPayment` | 2 |
| `recoverWalletTopupPayment` | 2 |
| `redeemOnboardingWebHandoff` | 1 |
| `rejectEmployeePayout` | 1 |
| `reopenSupportCase` | 1 |
| `reportDeliveryException` | 1 |
| `requestEmployeePayoutChange` | 1 |
| `requestRiderIdentityChange` | 1 |
| `resolveSupportCase` | 1 |
| `retryCommissionException` | 1 |
| `reviewDocumentSubmission` | 2 |
| `reviewEmployeePayoutChange` | 2 |
| `reviewRiderIdentityChange` | 2 |
| `riderMoneySummary` | 1 |
| `sellerAiChatProxy` | 1 |
| `setBenefitFeatureFlag` | 1 |
| `setComplianceStatus` | 1 |
| `setUserRole` | 1 |
| `submitDocumentReplacement` | 1 |
| `submitRiderApplication` | 1 |
| `submitSupportRequest` | 1 |
| `unlinkSupportCaseRecord` | 1 |
| `updateDeliveryException` | 1 |
| `updateRiderContact` | 1 |
| `updateSupportRequest` | 1 |

Direct literal calls adjacent to wrappers remain separate inventory sites; e.g. rider deleteUserData and bank review are not mistakenly assigned to the contact/identity wrappers. Shared auth wrapper callers cover5 own-profile commands; saved payment recovery covers goods and wallet recovery.

## Index parity and owner WIP

CLI lists58 normalized live indexes; the committed source at4766754f contains75 and owner working source78. Committed source has17 signatures absent from live. Working source has20 absent from live, including3 owner WIP additions. Live-only normalized signatures:0; owner WIP removals:0. The machine report records each missing signature separately for committed source and working source and preserves file hashes. No index file was edited or staged.

Comparison excludes Firebase's implicit __name__ field and density for signature matching only. CLI output does not expose readiness state, so this refresh does not claim58 READY indexes. Density semantics, deployment compatibility, single-field overrides and query/rules permission still need review. Earlier dated readiness/rules evidence is not silently refreshed by this command.

## Remaining acceptance

Complete semantic enabled journey/query/rules/index contracts; refresh live rules and recovery evidence; reconcile source code/version and owner-approved named deployment plan. Shared account lifecycle barrier must precede personal cleanup and preserve legitimate captured/earned funds. Tax, verified physical SKU backfill, mobile credit expiry recovery, native/device/signing/permission/push, backup/restore and connected release/rollback remain OPEN. No source change, live write, deployment, push, merge, signing, device run or rollout flag change. Deployment consequence: NONE.


F0 endpoint parity final standard postcommit gate atef8377c7 on isolatedNode22 completed terminal0/failed0. Allfive analyzers0errors:marketplace127w278i/admin74w499i/seller0/delivery0/employee2w0i; Functions build/all integrity-secret-fee-deploy-delivery guards/three canonical ratchets/ledger0warnings pass. Inventory832/1170/896/99check0,diffcheck0,158union endpoint rows validated,99exact source references/12manual wrappers,metadata allowlist and JWTabsence checks pass. Both read-only cloud calls exit0/success; ownerindex working/committed hashes preserved. Exactfive-file evidence scope, no source/index/rules/config changes. Bounded SOURCE_AUDIT_VERIFIED only; allparentF0-F9OPEN/originalgoalACTIVE. Next shared lifecycle/semantic journey contracts and owner release prerequisites. No live writes/deploy/provider/device/sign/push/merge/flag/control changes; SINGLE AGENT/ownerWIP preserved.
