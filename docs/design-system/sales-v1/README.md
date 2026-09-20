# Sales mockups

Three concept screens generated with the built-in image generator: Home dashboard, Orders search/filters, Order details. Fictional data; no application changes.

## Implementation notes
- Reuse one floating Home / Orders / Wallet / Profile navigation component. Orders remains selected on order details.
- Use actual Lucide outline icons, including selected states. Generated filled icons are not authoritative.
- Blur only content behind the lower navigation area with a clipped backdrop filter and subtle scrim. Keep navigation labels sharp. These static PNGs illustrate the effect, not actual scrolling.
- Provide bottom scroll padding so every row can move above the overlay. Use an opaque fallback when transparency reduction or performance requires it.
- Ignore ghosted duplicate text in the generated blur region; do not duplicate content in the implementation.
- Search/filter controls are proposed features. Show an active-filter dot only when filters are actually applied; the default All view should not show it.
- Dates on list rows should have explicit consistent meaning. For ORD-1042, detail sample is placed 16 Sep and delivered 18 Sep. The 18 Sep list date should be labeled Delivered, or use the placed date consistently.
- Commission credit is a wallet credit, not a bank payout. Use actual backend values; sample arithmetic does not establish a commission policy.
- Reference prompt direction: premium AgriMore Sales Associate operational UI, cobalt #2563EB, navy #0F172A, slate #475569, background #F8FAFC, white bordered cards, semantic green/amber, Inter typography, text-only order rows, identical floating rounded four-item navigation and progressively frosted lower scroll region. Each deliverable shows one screen only.
