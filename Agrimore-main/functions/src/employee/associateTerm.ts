// ============================================================
//  Sales Associate naming — Phase 16A, Decision D1
// ============================================================
//
// User-facing strings for this feature must say "Sales Associate" /
// "AgriMore Sales Associate", never "Employee" — but every INTERNAL
// identifier (the `employee` role value, the `employees` collection,
// `employee_payouts`, `employeeUid`, `employeeCode`, `EmployeeModel`,
// `apps/employee`, and every existing Cloud Function name) stays exactly
// as-is. Renaming any of those would require a production data migration
// across deployed firestore.rules, nine live Cloud Functions, and five
// apps, for zero user-facing benefit. New functions introduced by this
// phase (createAssociateOnboardingPayment, activateAssociateOnboarding,
// etc.) use "Associate" in THEIR OWN names — new names carry no migration
// cost — while still reading and writing the `employees` collection
// underneath. Use this constant for every human-readable string this
// feature produces (HttpsError messages, log lines, notification bodies,
// copy-deck defaults) instead of writing "Sales Associate" as a literal in
// multiple places.
export const ASSOCIATE_DISPLAY_TERM = "AgriMore Sales Associate";
