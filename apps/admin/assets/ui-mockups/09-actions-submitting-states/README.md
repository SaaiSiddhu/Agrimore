# Agrimore Admin — C09 actions and submitting states

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 identity remains approved and locked. These static boards illustrate a target, not migrated application widgets.

Identity: Professional institutional blue with cyan and steel/slate support.

| Theme | Board |
| --- | --- |
| Light | [Open light](agrimore-admin-actions-submitting-states-light.png) |
| Dark | [Open dark](agrimore-admin-actions-submitting-states-dark.png) |

[Exact prompts](prompts.md) · [Manifest](manifest.json) · [All five apps](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_BOARDS_2026-10-03.md) · [Domain mapping](../../../../../docs/design-system/ACTIONS_SUBMITTING_STATES_DOMAIN_MAP_2026-10-03.md) · [C01 approval](../../../../../docs/design-system/COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Current implementation

Product editor uses raw ElevatedButton/OutlinedButton with _isLoading callback gating, Cancel disabled while saving and spinner-only save content. _saveProduct validates Basic Info, images and coverage before setting loading, without an early busy guard. The header Delete action stays available while saving. Existing errors can include e.toString. Creation delegates to AdminProvider; no create-operation replay/recovery guarantee is established by the button. AdminService derives a name slug, checks whether that document exists, then sets it; this is a duplicate-name precheck, not a transactional logical-request replay contract.

## Target direction

Keep one save commitment per editor with a labeled progress state, adjacent prerequisites and an explicit destructive confirmation boundary. Gate competing Save/Delete/navigation actions consistently, add a handler guard and reconcile unknown create results before retry.

| Panel | Specimen intent |
| --- | --- |
| 01 · Editor commands | Annotated variants: PRIMARY muted professional-blue filled 'Save changes'; SECONDARY neutral outline 'Cancel'; TERTIARY blue text 'Preview'; DESTRUCTIVE outlined Error-colored 'Delete product'. Tiny cyan rule; no vivid electric cobalt. Caption 'One primary decision per editor'. |
| 02 · Explain missing fields | Disabled neutral 'Add product' as policy specimen; helper 'Add required details, an image and delivery coverage.' Enabled outline 'Review required fields'. Caption 'Show field errors where they occur'. No filled-success or saved state. |
| 03 · Saving changes | Filled primary button with spinner and exact label 'Saving changes…'; neighboring 'Cancel' disabled neutral; small separate outlined 'Delete product' also disabled neutral. Helper 'Wait for the save result.' Annotation 'Repeated taps blocked'. Tiny static-hourglass alternative with same busy label. |
| 04 · Unknown save result | Information callout 'Save status unclear'; body 'Check Products before creating this record again.' Enabled outline 'Check Products'; text action 'Keep draft'. Small flow 'Edit → Save → Reconcile'; caption 'Confirm before destructive changes'. No fake Synced/Saved badge or success toast. |

Source gaps and preservation rules:

- Spinner-only save loses the action label; add a precise progress label and keep control width/reading order stable.
- Current editor validates on tap. Disabled Add product is a proposed example, not an instruction to make every invalid form permanently untappable.
- An early handler busy-return and shared action ownership should cover Save, Delete and navigation; current header Delete is not gated by _isLoading.
- Preserve entered data and reconcile unknown create/update outcomes; no universal retry-safe admin create API is claimed.
- Remove raw e.toString from feedback during later implementation and keep confirmation separate from the destructive action's busy state.

Keep one primary commitment per decision. Every disabled state has readable adjacent reasoning and a reachable resolution. Busy actions retain a meaningful label, block callbacks and need an early handler guard; this is separate from server replay protection. Reconcile unknown outcomes before a new commitment, preserve user inputs and reuse logical request identity where supported. Minimum 48px hit regions and growing label height are proposed. Reduced motion uses a static progress symbol with the same label. Actual accessibility, keyboard/input methods, rapid tapping, retry and process-death recovery require later runtime verification.

## Light

![Agrimore Admin C09 light](agrimore-admin-actions-submitting-states-light.png)

## Dark

![Agrimore Admin C09 dark](agrimore-admin-actions-submitting-states-dark.png)

