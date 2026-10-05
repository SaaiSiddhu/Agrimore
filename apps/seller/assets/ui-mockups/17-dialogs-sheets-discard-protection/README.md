# Agrimore Seller — C17 dialogs, sheets and discard protection

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C17 owner approval is pending.

Compact blue-teal merchant confirmations, copper consequences, cool-neutral stock sheets and operational sticky footers.

[Ten-board gallery](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/DIALOGS_SHEETS_DISCARD_PROTECTION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

sellerConfirm/sellerConfirmDiscard provide named route/header semantics, consequence copy and responsive action layout. SellerDiscardGuard uses PopScope; StoreSchedule uses dirty && !saving and clears dirty after confirmed save. showSellerSheet supports safe areas, keyboard-aware frame, close, scrim/drag through isDismissible. StockSheet saves inside the sheet, retains failure/input and pops true only after onSave returns true, but has no dirty/PopScope guard. Store-status sheet returns a choice; the profile caller performs the mutation afterward.

## Target direction

Reuse existing guard and sheet/confirmation equivalents, extending lifecycle deliberately. Protect changed stock edits and pending saves; clear dirty only after confirmation. A separate pause-ordering confirmation makes the existing store-state consequence explicit without claiming that its modal is currently implemented.

| Panel | Domain specimen |
| --- | --- |
| Confirmation | Centered modal "Pause ordering?". Body "Customers cannot place orders while your store is paused." OUTLINED "Keep store open" in blue-teal and PRIMARY "Pause ordering" in blue-teal. Copper board note "Separate store-status example" and "Confirm before updating". No dates, pause durations, inventory change or already-paused success. |
| Editable sheet | Compact bottom sheet titled "Update stock", labelled close X, neutral product context "Sample product", field "Stock quantity" with no numeric value and small "Values omitted in this specimen". OUTLINED "Cancel" and blue-teal PRIMARY "Save stock". Scrolling body plus sticky actions with a labelled keyboard-clearance strip. No price, counts or quantity chips. |
| Discard protection | Dialog "Discard stock edit?", body "Your unsaved stock edit will be removed." OUTLINED blue-teal "Keep editing" and OUTLINED danger "Discard edit". Copper board note "Extend the existing discard guard". Do not invent product deletion or remote Undo. |
| Submission recovery | Separate "Pending variant" with disabled outlined spinner control "Saving stock" and "Failed variant" notice "Stock couldn’t be saved" with helper "Keep the entered value". Copper note "Close only after confirmed save". No stock numbers, optimistic saved tick or additional Retry mutation. Any failed-variant action is secondary "Keep editing", returning to retained editor input, never server retry or discard. |

Preservation and gaps:

- SellerDiscardGuard has no explicit one-dialog-in-flight guard in the inspected implementation; test repeated back/close attempts.
- StoreSchedule passes hasChanges=false while saving, which permits leaving during an in-flight save; pending exit needs a separate policy.
- StockSheet close/scrim/drag and changed input are not guarded by the shared dirty wrapper today.
- Confirming a store-status choice closes the sheet before profile persistence; do not render chosen state as saved while the write is pending.

## Light

![Agrimore Seller C17 light](agrimore-seller-dialogs-sheets-discard-protection-light.png)

## Dark

![Agrimore Seller C17 dark](agrimore-seller-dialogs-sheets-discard-protection-dark.png)

