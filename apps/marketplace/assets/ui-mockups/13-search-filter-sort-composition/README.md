# Agrimore Marketplace — C13 search, filter and sort composition

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C13 owner approval is pending.

Spacious professional-green product discovery, natural-stone fields and restrained gold scope guidance.

[Ten-board gallery](../../../../../docs/design-system/SEARCH_FILTER_SORT_COMPOSITION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/SEARCH_FILTER_SORT_COMPOSITION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SearchScreen provides local product-name/description/category search and suggestions. SearchResultsScreen fetches a bounded 100-product catalog and applies local filters/sort; initial search includes description but _applyFilters only tests name/category. SearchFilters stages edits and clears its draft; shop FilterDrawer Reset commits immediately. SortBottomSheet chooses immediately.

## Target direction

Compose query, committed category chips and visible sort order into one discovery header. Stage modal category changes, Apply/Cancel honestly, and distinguish Clear query, Clear draft and Reset filters. Name loaded-catalog scope; do not claim a full-catalog search.

| Panel | Domain specimen |
| --- | --- |
| Discovery header | Wide clean search field labelled Search products, entered synthetic query seeds with a clear X whose label is Clear query. Beside it buttons Filters and Sort: Newest first. Under it small caption Search within loaded products. No numeric results or filter-count badges. |
| Staged category filters | Inset mini sheet with heading Filters, small Draft changes label. Category checkbox Seeds checked; Fertilizers unchecked. Three distinct footer actions Clear draft, Cancel, Apply filters. Helper Apply commits; Cancel keeps applied filters. Make staged controls visually different from applied chip strip. |
| Sort composition | Single-choice Sort by rows: Newest first selected radio, Price: low to high unselected radio, Price: high to low unselected radio. Helper Choosing a sort updates order immediately. No Apply or Cancel buttons for this immediate sort choice. Tiny note Query and filters stay unchanged. |
| Applied state and recovery | Applied chips row Category: Seeds with removable X. Reset filters button with helper Clears filters; keeps query and sort. Small separate examples Searching loaded products, No matches in loaded products with Clear query, Search unavailable with Retry. Never a no-match state for failure. Small guidance No invented result counts. |

Preservation and gaps:

- Reapply the same query predicate and committed filters on submit, retry and clear; current initial versus filtered predicates differ.
- Current _performSearch bypasses existing _filters and only sorts; the target requires composition from one canonical query/filter/sort state.
- Search and shop reset payloads differ (minPrice/maxPrice versus priceRange) and relevance is an unsorted default, not a verified ranking algorithm.
- Clear query preserves filter/sort in the target; current SearchResultsScreen clear instead empties its result list. Treat this as a future behavior change.

## Light

![Agrimore Marketplace C13 light](agrimore-marketplace-search-filter-sort-composition-light.png)

## Dark

![Agrimore Marketplace C13 dark](agrimore-marketplace-search-filter-sort-composition-dark.png)

