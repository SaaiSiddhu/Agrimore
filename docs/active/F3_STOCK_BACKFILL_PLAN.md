# F3 stock completeness backfill — safe rollout plan

**Status:** policy selected; the read-only audit, safe seller edit handling for unknown base/variant counts, and local tests are implemented. Live catalog audit, owner-counted backfill, and fail-closed enforcement remain deliberately incomplete.
**Owner policy:** backfill actual inventory first, then reject purchasability when stock is absent or invalid.
**Safety boundary:** this plan does not read or write the live Firebase project. No inventory count may be guessed from a model default.

## Verified source behavior

- `functions/src/customer/orderPricing.ts` accepts missing/non-numeric stock as available.
- `functions/src/customer/createOrder.ts` decrements base/variant stock only when the stored field is already a finite number.
- `functions/src/customer/createOrderFromRfq.ts` has the same missing-stock availability behavior and only decrements numeric stock.
- `packages/agrimore_core/lib/models/product_model.dart` parses missing base-product stock as `999`, but missing variant stock as `0`.
- Before the preparation changes, `apps/seller/lib/screens/products/seller_products_screen.dart` prefilled its stock editor from parsed `ProductModel.stock`, conflating missing stock with the `999` display fallback. It now reads the raw stored value; see implemented preparation and widget verification below.
- `firestore.rules` lets an authenticated product owner update their own product and denies seller changes to protected trust fields. It does not enforce an inventory schema or a finite non-negative integer stock value.

## Backfill must not overwrite sales

An absolute stock count can race with a checkout. For a product with missing stock, checkout currently does not decrement anything; therefore the count must be taken while that SKU cannot be purchased. The safe per-SKU sequence is:

1. Identify the document and whether it sells base stock, variant stock, or both.
2. Temporarily make the affected product unpurchasable while inventory is physically counted. Do not infer availability from the `999` or `0` model defaults.
3. Enter the verified on-hand quantity for every purchasable SKU, including each variant. Require a finite non-negative integer.
4. Independently verify the raw Firestore field is numeric and matches the recorded physical count. Only then may that product be republished.
5. Repeat a read-only completeness audit. Do not enable the fail-closed checkout guard until every sellable base SKU and variant has a valid field, or the owner has explicitly kept the incomplete SKU unpublished.

The preparation changes below make the seller stock sheet surface “stock not configured,” start an unknown count empty, and refuse saving until an explicit count is entered. The variant editor also distinguishes a missing stored count from a real zero. Those changes support step 3; they do not supply physical counts or prevent checkout races while an SKU remains published.

## Implemented preparation work (2026-10-02)

- `functions/scripts/report_stock_completeness.js` pages through the products collection and reports only product ID, SKU field path, and issue code. It never writes. It refuses live reads unless the operator adds `--allow-live-read` and an explicit project ID; this session used only a demo-project emulator.
- `stockCompleteness.ts` rejects absent, null, nonnumeric, non-finite, fractional, negative, and unsafe stock values; an explicit zero is valid. The audit examines sellable base stock and every raw variant entry while excluding inactive/draft products.
- The seller base-stock edit reads the raw product document. Missing/invalid stock now opens with a blank field and “Stock count not configured,” instead of pre-filling the model's `999` fallback. The variant model carries an in-memory `stockConfigured` flag so the variant editor also starts unknown stock blank; saving requires an explicit integer. Serialization omits stock for an unknown legacy variant instead of turning the display fallback `0` into a factual count.
- Verification: 15 pure/audit safety checks and one emulator pagination/no-write check pass; 15 shared model tests and 29 seller stock/delivery validation tests pass; the repository quick gate passes (Functions build, all five app analyzers, zero errors, unchanged baseline diagnostics). No live catalog read or write was attempted.

## Stock editor continuation (2026-10-03)

The full seller suite exposed the old widget fixture opening the editor without an authenticated owner. The fixture now supplies an explicit synthetic seller and native Firestore response, with no live transport or inferred stock. New widget coverage checks unknown raw stock against the model's `999` fallback, explicitly stored zero, empty/unsafe count refusal, account switch during the raw-stock read, and account switch before saving. The screen rechecks the current owner after the read and before stock update; late success/error feedback is also owner-fenced. Its save validation uses the same finite, safe whole-unit contract as raw stock parsing. No auth requirement was removed to make the old fixture pass.

The source-read/save/safe-count guards are independently exercised with deliberate temporary mutations and byte-for-byte source restoration. Final focused and full-suite results are recorded in `MOBILE_FOUNDATION_PROGRESS.md`. Seller theme components, localized feedback and layouts are preserved. These checks do not prove physical inventory counts, live Firestore rule parity, or safe owner backfill while sales continue.

## Validation contract for the eventual guard

- Accept only a JavaScript number that is finite, a safe integer, and at least zero.
- Missing fields, `null`, strings (including digit strings), `NaN`, infinities, fractions, negatives, and malformed variant entries are not purchasable.
- For a variant line, validate and decrement that selected variant's own stock. Never fall back to base stock if the selected variant's field is missing or invalid.
- Reject before order, payment-consumption, hold, counter, or stock effects. The order and RFQ paths must agree.
- Preserve an explicit `stock: 0` as valid data that correctly refuses a positive quantity.
- Keep order reservation/decrement atomic with order creation; retain cancellation/return idempotency.

## Required evidence before enforcement

1. A read-only, privacy-minimized completeness report covering every sellable product and each variant, with no write mode.
2. Seller/admin backfill UX that exposes raw absence, not parser defaults, and validates explicit counts.
3. Owner-reviewed counts and an operational sequence that prevents sales during each missing-count correction.
4. A fresh read-only audit showing no missing or invalid stock remains among sellable SKUs.
5. Callable emulator tests for createOrder, RFQ conversion, credit quote/hold, variant selection, and concurrent last-unit checkout; prove rejected records produce no order/payment/hold/stock side effects.
6. Only after the audit: deploy the named server functions and then ship any client copy changes. No deploy has been performed.

## Current open operational dependency

The actual live-catalog completeness and seller-verified quantities are unknown. This must be resolved by an owner-run, reviewable inventory backfill. The repository agent must not invent quantities or apply production writes. Fail-closed code remains deferred until the read-only audit proves the catalog is ready.
