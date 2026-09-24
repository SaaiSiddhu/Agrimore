# Mockup inspection notes (visual, image by image)

## 01 brand identity (01-brand-identity.png) — INSPECTED
- Wordmark: two-leaf mark (deep-teal leaf + leaf-green leaf) + "AgriMore" deep teal + letterspaced "SELLER" under it.
- Wordmark on dark bg: deep teal (#134E4A) panel, white mark. Compact app header: leaf mark + "AgriMore Seller".
- Palette: Primary #0F766E · Deep teal #134E4A · Leaf green #15803D · Mint #DDF3EA · Canvas #F5F8F7.
- Imagery: real produce, natural light. Illustration: simple organic (crate of veg with leaves on mint blob).
- Voice: Clear · Helpful · Grounded. Success card: check in mint circle, title "Your product is ready to sell." + body + full-width primary button ("View product"), radius ~8.

## 02 design tokens (01-design-tokens.png) — INSPECTED
- Semantic (light): Primary #0F766E · Strong #134E4A · Success #15803D · Mint #DDF3EA · Canvas #F5F8F7 · Surface #FFFFFF ·
  Text #142D2A · Muted #526660 · Border #D8E3DF · Warning #B45309 · Danger #B91C1C · Info #1D4ED8.
- Type (Inter): Display 32/40 w700 · Heading 24/32 w600 · Title 20/28 w600 · Body 16/24 w400 · Label 14/20 w600 · Caption 12/16 w400.
- Spacing 4 8 12 16 24 32 48 64; card padding 24.
- Sizing: icons 16/20/24; button height 48; touch target 48x48; avatar 40.
- Borders: default 1dp (#D8E3DF); focus = SAME border, 2dp, primary (single border, no ring).
- Radii 4 8 12 16 + full 999. Shadows: flat; raised 0/2/8 @8%; overlay 0/8/24 @12%; tint #134E4A.
- Opacity: content 100 · secondary 60 · disabled 38 · scrim 40.
- Z: base0 sticky10 menu20 scrim30 modal40 toast50.
- Motion: fast 120 · standard 200 · slow 320ms; ease-out cubic(0.2,0,0,1); reduced motion = 0ms.

## 03 themes (01-themes.png) — INSPECTED
- Theme mapping (light / dark): Canvas #F5F8F7/#050908 · Surface #FFFFFF/#0B1513 · Raised #FFFFFF/#12221E · Primary #0F766E/#5EEAD4 ·
  On-primary #FFFFFF/#042F2E · Text #142D2A/#ECFDF5 · Muted #526660/#A3B8B0 · Border #D8E3DF/#29433A.
- Status fg (light/dark): Success #15803D/#86EFAC · Warning #B45309/#FCD34D · Danger #B91C1C/#FCA5A5 · Info #1D4ED8/#93C5FD.
  Pills: tinted bg + fg text (dark: dark tint bg + bright fg).
- Theme behaviour: segmented System/Light/Dark (System default, "System follows device appearance"), preference preserved.
- Dark = black & teal: primary buttons bright teal #5EEAD4 with dark text; selected nav = deep teal fill + light text/icon.
  Light: selected nav = mint (#DDF3EA) fill + teal text/icon.
- Wide layout preview: header "AgriMore Seller" leaf logo + bell + avatar initial + chevron; left nav Home/Orders/Catalogue/Payments/Account.
  Home: "Good morning, <name>" + "Here's what needs your attention today."; "Needs you now" rows (icon tile, title, subtitle, count pill);
  "Recent orders" card (See all) rows "#AGM-1001 Tomato Seeds [Paid]"; search field; primary "View orders >" full width.
- Surface hierarchy: canvas → surface → raised; dark uses tonal steps (#050908 → #0B1513 → #12221E) not shadows.

## 04 responsive layouts (01-responsive-layouts.png) — INSPECTED
- Compact <600: 16px page inset, 4-col grid, BOTTOM TABS (Home Orders Catalogue Payments Account; selected = teal icon+label).
- Medium 600–839: 8 cols, NAVIGATION RAIL (supersedes ADR "bottom bar at 600–839"). Expanded ≥840: 12 cols, list + detail, 24px inset.
- Form max width 640; content max width 1200. "Use available width, not device name."
- Orders (phone): large left title "Orders"; search "Search orders…"; chips All(selected filled) · To accept 3 · Packing 5 (count inside chip);
  order card: "#1042" bold + amount right "₹640"; customer name; "1 items · 2 hours ago"; status pill bottom-right (To accept=info tint,
  Packing=amber, Delivered=green). Dark: black canvas, #0B1513 cards, teal selected tab.
- Tablet: rail (selected item mint pill behind icon) | list pane (selected card mint fill + teal border) | detail pane:
  "← Order 1042 ⋯", status pill, Customer (name, masked +91 •••••• 4321, city), Items(1) thumb row "Fresh tomatoes 1 × ₹640  ₹640",
  "Order total ₹640", primary "Accept order". Independent pane scrolling; selection stays visible; keep selection on resize.
- Safe areas follow device (no hardcoded insets). Keyboard: focused field visible, action sits above keyboard ("Save product").
- Sticky actions: app bar fixed, content scrolls, sticky bottom "+ Add product" with bottom content clearance.
- Phone: push detail; tablet: show both.

## 05 typography & content (01-typography-content.png) — INSPECTED
- Inter, same scale as 02. Script-aware fallback for non-Latin. Scale with device settings.
- In context: order detail "← Order 1042 ⋯", "To accept" pill = AMBER/warning tint here (04 showed blue) → ADR §5.4 says pending acceptance = warning; use warning.
  Item card: thumb 48, "Fresh tomatoes" + "Pack size: 5 kg" + amount bold right; primary "Accept order" full width.
- Labels: persistent label ABOVE field; helper text below; optional marked "(optional)"; currency field has "₹" prefix segment with divider.
- Amounts: tabular figures, Indian grouping ₹1,24,500; "₹64 / kg"; "5 × ₹64 = ₹320"; units kept with values.
- IDs & dates: Invoice "INV-2026-0042" + copy icon; bank "•••• 9012"; date "24 Sep 2026"; time "10:30 AM". Mask sensitive details.
- Validation: error field = red border (single) + red error icon inside right + red message below; success banner (success tint, check icon,
  "Product saved."); empty state = dashed-border box, icon + title + body ("No orders yet." / "When you receive orders, they'll appear here.").
- Localisation: buttons allow multi-line labels (flexible height); wrap labels; script-aware fallback.
- Text scaling: info card (icon tile + "Ready for pickup" + "We'll notify the buyer.") reflows at larger text.

## 06 icons, images, avatars (01-icons-images-avatars.png) — INSPECTED
- Lucide outline: Home=house · Orders=shopping-bag · Catalogue=package(box) · Payments=credit-card · Account=circle-user · Search ·
  Notifications=bell · Add=plus · Edit=pencil · Delete=trash-2 · Camera · Image · Phone · Message=message-square · Location=map-pin ·
  Calendar · Filter=funnel · Chevron-right. Sizes 16/20/24/32; 2px stroke, rounded caps; 24 icon in a 48 touch target.
- Avatars 32/40/56; fallback chain: logo → initials on mint ("KF") → generic store icon. Account row: avatar + shop name + "Seller account" + chevron.
- Product thumbs square 1:1 rounded ~8; row: thumb + name + "₹64 / kg" + chevron.
- Cover images wide, subject in safe zone; phone vs tablet crop.
- Image states (same frame size): Loaded · Loading (skeleton) · No image (image icon) · Failed (image-off icon + "Retry").
- Row actions: pencil (tinted primary) + more-vertical; dark tint = #5EEAD4.
- A11y: icon+label buttons ("Add photo" tonal mint); icon-only needs a label ("Delete product"); decorative images silent;
  bottom nav selected = icon inside mint pill + teal label (selection not colour-only).

## 07 navigation (01-navigation.png) — INSPECTED
- Phone bottom nav: Home · Orders · Catalogue · Payments · Account; persistent labels; SELECTED = icon + label inside a mint rounded
  container (dark: bright-teal container behind icon); count badge on Orders ("3", dark-teal circle, white text).
- Tablet rail (landscape): icon + label rows, selected row mint fill; list pane rows "Order 1042 / Ramesh Farm / Today, 10:24 >";
  detail pane: "Order 1042 [To accept]", Buyer, Items "4 items", Total ₹640, "Accept order".
- App bars: ROOT = title + search icon + more-vertical (no back). DETAIL = back arrow + "Order 1042" + phone + message icons.
  MODAL composer = close X + "New post" + text action "Post" (teal).
- Back returns to same list position; close dismisses modal; respect platform back gestures.
- Badges: count (dark teal), 99+ overflow (red), unread dot (red on bell), hide zero counts, keep badges clear of labels.
- Nested (not tabs): Orders→Order detail→Invoice · Account→Storefront→Preview · Home→Quotes→Quote detail. Preserve tab state.
- Contextual link rows: icon + title + subtitle + chevron ("View invoice / From order details"; "View order / After a quote becomes an order";
  "To be paid to you / Open Payments"). Masked phone "+91 ••••••1234" + "Change" link.

## 08 actions & selection (01-actions-selection.png) — INSPECTED
- Buttons: Primary filled teal (white text, radius ~8, 48 tall, full width) · Secondary outlined teal · Text (teal). One prominent action per decision.
- Icon button 48x48 = bordered rounded-square (surface bg, border) with 24 icon. FAB 56 round teal "+". Extended FAB "+ Add product" 56 tall pill.
- Destructive: outlined red "Delete product" with trash icon (entry) → confirm "Delete this product?" / "This action cannot be undone."
  [Cancel outlined] [Delete filled red]. Name the consequence.
- States: default · pressed (darker #134E4A) · focused (mockup shows outer ring = SUPERSEDED by phase-24 single border) · disabled (grey fill,
  grey text) · loading (mint fill, spinner + "Saving…" teal text, width stable).
- Switch: teal on / grey off (setting). Checkbox: unchecked border / checked teal+white check / mixed (minus). Radios ("Payout method":
  Bank account / UPI ID). Segmented (Today | 7 days | 30 days; selected = mint fill + teal text; bordered group).
- Chips: filter chips with count ("✓ All 24" selected = mint fill + check; "Active 18", "Low stock 4", "Drafts 2" outlined);
  removable tag "Farm fresh ×"; disabled chip grey. Wrap on narrow screens.
- Bulk selection: top bar "× 2 selected"; rows checkbox + thumb + name + "1 kg · Farm fresh" + ⋮; bottom bar [👁‍🗨 Hide outlined] [Publish filled];
  long-press to select; clear with X; bulk bar replaces the Add-product action.
- Dark: primary = bright teal + dark text; checkbox/switch bright teal.

## 09 forms & validation (01-forms-validation.png) — INSPECTED
- "Required unless marked optional." Label above, helper below, "(optional)" suffix; multiline description.
- Phone: "+91 |" prefix segment + "10-digit mobile number"; email with mail icon prefix; keyboard matches input.
- Password/API key: masked by default + eye toggle ("Show / hide"); "Keep your API key private."
- OTP: "Enter the 6-digit code" + masked number right; 6 boxes (focused box = teal border only); "Resend in 30s"; "Verify and continue".
- Currency: "₹" prefix segment; "Units in stock"; "Low-stock alert at"; numeric input.
- Address: Shop address · City or town | PIN code (2 cols) · State dropdown · tonal "📍 Use my current location".
- Bank & UPI: holder, bank name, account no. masked + re-enter, IFSC, "UPI alternative"; "Choose Bank or UPI."
- Dropdown opens radio list; slider "Delivery radius 10 km" shows value.
- Date/time: rows with calendar/clock icon + value + chevron; platform-appropriate pickers (Cancel/Done).
- Recovery: inline field error + red-tint banner "Couldn't save. Try again." + "Retry"; keep entered values.
- States: default / focused (teal 2px same border) / disabled (grey fill). Dark: bright-teal focused border + bright-teal button.
- Keyboard: scroll to focused field; labels wrap; errors stay above keyboard.

## 10 search, filtering, sorting (01-search-filtering-sorting.png) — INSPECTED
- Global search: back + field "Search orders, products, quotes"; hint "Type at least 2 characters."; exact order id → outlined
  "↗ Open order 1042" button. Local search placeholders: Orders "Order number, customer or product"; Catalogue; Help "Search help".
- Field states empty/focused(teal border)/filled; clear X is a 48x48 target; clear keeps focus + filters.
- Grouped results: "Orders · 1" (Order 1042 / Priya · 24 Sep / ₹640 >), "Products · 1" (Fresh tomatoes / 25 in stock / ₹64 / kg >),
  "Quotes · 1" (Fresh tomatoes / Green Valley Foods >); leading icons bag/shopping-bag/message.
- Order status chips w/ counts: All 24 · To accept 3 · To pack 2 · Packing 4 · Ready for pickup 2 · Out for delivery 3 · Delivered 8 ·
  Cancelled 2. Period chips: All time · Today · 7 days · 30 days. "Business (B2B)" chip (briefcase icon).
- Catalogue chips: All · Active · Drafts · Low stock · Out of stock · Inactive. Sort list (check on selected): Newest first · Name A–Z ·
  Price low→high · Price high→low · Stock lowest first. One active sort.
- No match ("Nothing matches 'x'" / "Try another product name." / "Clear search") ≠ empty ("No products yet" / "Add your first product
  to get started." / [Add product]).
- Loading: skeleton rows; error banner "Couldn't load results." + Retry; keep query + filters.

## 11 cards, lists, data (01-cards-lists-data.png) — INSPECTED
- Summary cards (Label → Value → Context): icon + "Sales" / "₹12,480" big / "↗ 12% vs previous period" (success); "Orders" / "24" / "Today";
  wide card wallet icon "To be paid to you" "₹3,840" + chevron.
- Operational rows: header "Needs you now" + count pill "7"; rows icon + title + subtitle + chevron: "3 orders to accept / Oldest placed 20
  minutes ago" · "2 quotes to answer / 1 expires today" · "2 products low on stock / Update available units". One action per row.
- Section headers: "Items [2] >", "Business details  Edit >", "Settlements  September 2026 >"; grouped day list "Today".
- Key/value: label left muted, value right; long values wrap right-aligned (Order · Customer · Payment · Delivery slot · Deliver to).
- Item breakdown: thumb 56 + "Fresh tomatoes" / "5 kg × ₹64" + line total; option chip "Option: 5 kg pack".
- Totals: Subtotal, Discount −₹20, Delivery, Tax, **Total**. Settlement: Order value, Commission −₹29, **You receive ₹551**.
  ("Sample amounts · No fee policy implied.")
- Expandable sections (icon + title + chevron): Delivery details · Buyer's note · Tax details (HSN "Not entered", GST "Not declared").
- Tablet table (Order|Date|Status|Net) vs phone stacked rows.
- Order card: icon tile + "Order 1042" + status pill + "Priya Sharma · 24 Sep" + chevron; footer "2 items ... ₹580".

## 12 status & progress (01-status-progress.png) — INSPECTED
- Badges = text + icon + colour. ORDERS: To accept = WARNING amber + clock · Packing = INFO blue + box · Delivered = SUCCESS + check-circle ·
  Cancelled = NEUTRAL grey + x. PAYMENTS: Pending = warning + clock · Paid = success + check. QUOTES: Your turn = info + message ·
  Waiting for buyer = neutral + clock · Expired = neutral + x.
- Unread: bell row + teal unread dot + "New order received / Order 1042 · 2 minutes ago" + "Mark read"; read row no dot.
  Unread ≠ order status. Count badge / 99+ overflow.
- Stock: "25 in stock" success check · "Only 3 left" warning triangle · "Out of stock" danger x-circle (threshold per product).
- Order stages (vertical): done = filled teal check; current = ring + "Current" pill (bold label); upcoming = hollow grey.
  Button shows next permitted action ("Mark ready for pickup").
- Onboarding: "Step 3 of 5" + "Documents"; horizontal 5-step (Business details · Location and delivery · Documents · Payout account ·
  Review and submit), done = teal check, current = ringed number, upcoming = grey number; "Save and continue".
- Settlement timeline: "Order delivered / Settlement created" ✓ → "Paid to your account / Pending" ○; "You receive ₹551" + Paid pill only
  "When payment is confirmed". Delivery and payment are separate events.
- Account health ring 86/100 + "Good" pill + "Last 30 days"; legend Good / Needs attention / At risk (icons). Thresholds TBC.
- Time remaining rows: "Offer expires in 2 hours [Respond soon]" · "Resend code in 30s [Resend](disabled)" · "Paused for 3 days [Resume]" ·
  chip "Offer expired". Never colour alone.

## 13 feedback & recovery (01-feedback-recovery.png) — INSPECTED
- Initial load: indeterminate ring + "Loading your seller account" (no invented %). Content load: skeleton rows (thumb block + 2 lines).
- Pull to refresh: inline "Refreshing…" at top, existing content stays visible.
- Empty ≠ no-match: "No products yet / Add your first product to get started. [+ Add product]" vs "No orders match. / Try changing your
  search or filters. / Clear search".
- Inline validation beside the field (icon + red text): "Enter a valid 10-digit mobile number." · "Account numbers don't match."
- Error banner: red tint, triangle icon, "Couldn't load orders." / "Please try again." + underlined "Retry"; field save error
  "Couldn't save your changes." + outlined [Try again]. Keep entered values.
- Toasts: success = success tint + check "Product saved."; failure = danger tint + error icon "Couldn't update stock."; on-screen toast
  is dark-teal (#134E4A) w/ white text + check, placed ABOVE bottom controls. Brief feedback; persistent errors stay visible.
- Submit states: Ready (teal) · disabled "Complete required fields" (grey) · "Saving…" spinner (teal). Prevent duplicates, width stable.
- Recovery in context: keep input → explain problem → offer next step ("Try again").
- Dark: error banner = dark red surface + light red text + Retry; success toast = dark surface + green check + white text.

## 14 overlays & confirmations (01-overlays-confirmations.png) — INSPECTED
- Bottom sheet: drag handle, title + close X, one focused task ("Update stock" / "Units in stock" / [Save]).
- Confirm dialog: title "Sign out?" + body "You can sign in again anytime." + [Cancel outlined][Sign out filled]. Explicit actions.
- Menus: "Sort products" menu with check on current; pickers platform-appropriate ("Quiet hours" time wheel, Cancel/Done).
- Storefront preview sheet: "How buyers see your store" + X; cover image, overlapping avatar (initials "KF"), shop name, highlight chips
  (mint, leaf/check icon: "Farm fresh", "Locally grown"). Preview without leaving editor.
- Destructive confirm: trash icon in red-tint circle, "Delete this product?", item card (thumb + name + "Product"), red "This action cannot
  be undone.", [Cancel][Delete red]. Name the item and consequence.
- Sheet with keyboard: "Business details" fields; Save stays visible above keyboard; body scrolls.
- Dismissal: X closes, swipe where supported, back returns; unsaved-edits guard "Discard changes? / You have unsaved changes."
  [Keep editing][Discard (red outline)]. Dismissal never confirms deletion.
- Focus: open → focus inside (announce title) → close restores focus to trigger (trigger shows single teal border).
- Dark sheet surface #0B1513, bright-teal Save.

## 15 media upload & location (01-media-upload-location.png) — INSPECTED
- "Add a photo" sheet (X): rows [camera] Take photo > · [image] Choose from gallery >. Empty tile = dashed border + image icon "Add a product photo".
- Permission: in-app pre-prompt "Camera access needed / Allow camera access to take a photo." [Continue] + "Choose from gallery" link →
  native prompt. Denied: danger tint "Camera access is off" + "Open settings".
- Photo preview: image + caption; [↻ Replace outlined teal] [🗑 Remove outlined red]. Review before continuing.
- Upload rows: thumb + state: "Uploading…" spinner · "Uploaded" success check · "Upload failed" danger triangle + "Retry" + ⋮.
  Success only when upload confirmed.
- Documents: required doc card ("ID proof" / red "Upload this photo to continue." / [Take photo][Choose from gallery]); uploaded row
  ("Shop or farm photo" thumb + "Uploaded" pill + >); optional row ("GST certificate (optional)" + "Add photo" link + >).
- Location: "← Location and delivery"; outlined "⌖ Use my current location" → "Finding your location…" (spinner row) → "Location pinned"
  (mint row, pin icon); "Review your address before continuing."
- Denied location: warning tint "Location access is off / Enter your address to continue." [Open settings][Try again]; manual fields
  (Shop address, City or town | PIN code, State ▾) always available.
- Replacement: keep current photo until replacement succeeds; failure "Replacement failed. Try again." + Retry. Radius slider "10 km".

## 16-01 access (01-access.png) — INSPECTED
- Mobile sign-in (centred column): logo lockup (leaf mark + "AgriMore" + "Seller"), farm illustration (house, trees, fields),
  title "Sell to farms and families across your district", body "Manage orders, stock and payments in one place.",
  label "Mobile number" + field ["+91 ▾" | "10-digit mobile number"], [Get OTP] primary, "OR" divider, [G Continue with Google] outlined,
  underlined link "Sign in with email instead", footer "By continuing, you agree to our Terms of Service and Privacy Policy." (links).
- Email sign-in: back arrow; centred "Sign in with email" + "For seller accounts created by AgriMore"; Email address; Password + eye;
  right-aligned "Forgot password?" link; [Sign in]; mint info banner "ⓘ After signing in, add your mobile number."
- Google verification: back; Google "G"; "Verify your mobile once" / "Link your Google sign-in to your mobile number."; mint info card
  (phone icon); Mobile number; [Get OTP]; "Cancel" link; terms footer.
- States: sending = spinner + "Sending OTP…" inside the field's right; invalid = red border + warning icon + "Enter a valid 10-digit Indian
  mobile number."

## 16-02 OTP & recovery (02-otp-recovery.png) — INSPECTED
- Enter OTP: back arrow; left-aligned "Enter the 6-digit code"; "Sent by SMS to +91 ••••••1234" + "Change" link (NOTE: channel copy must
  follow the server's real channel — voice-primary per D-DLT); 6 boxes (current = teal border); [Verify and continue]; "Resend code in 30s".
- Retry (dark): empty boxes + "That code didn't work. Try again." (error icon); links "Resend code | Get a call instead".
- Password recovery = bottom sheet over email sign-in ("Welcome back / Sign in to your seller account", logo top-left):
  "Reset your password" / "We'll email a reset link to <email>" [Send reset link][Cancel outlined].
- States: "Verifying… / Please wait while we verify your code." · "Reset link sent / We've emailed a reset link to <email>." ·
  "Couldn't send the link. Try again. / Please check your email and try again."

## 16-03 five-step application (03-five-step-application.png) — INSPECTED
- Intro card (mint): brand mark + "Start selling on AgriMore" / "About 5 minutes · Stop and continue anytime." + [Start application >].
- Step chrome: app bar back + centred "Seller application"; caption "Step N of 5"; 5-dot progress on a line (done/current teal, upcoming grey);
  left heading + description; sticky footer [Back outlined][Save and continue filled]. Draft retained between steps.
- 1 Business details: Your full name · Shop or business name · What do you mainly sell? (dropdown) · GSTIN (optional).
- 2 Location and delivery: [⌖ Use my current location] outlined · Shop address · City or town | PIN code · State ▾ · Delivery radius slider "10 km".
- 3 Documents: rows ID proof (✓ Uploaded) > · Shop or farm photo (✓ Uploaded) > · GST certificate (optional) with [Take photo][Choose from gallery].
- 4 Payout account: two-option toggle [🏛 Bank account][➤ UPI ID] (selected filled teal); Account holder name · Bank name · Account number
  (masked) · Re-enter account number · IFSC code.
- 5 Review and submit: cards (icon + title + summary + "Edit") for Business details / Location and delivery / Documents / Payout account
  (masked •••• 1234); checkbox consent "I confirm … AgriMore seller terms and conditions." (link); [Back][Submit application].

## 16-04 document collection (04-document-collection.png) — INSPECTED
- Header: back + centred "Documents" + "Step 3 of 5" + connected dot progress. Body lead "Upload the required documents to continue."
- Doc card: 64 placeholder tile (doc/store icon) or photo thumb; title ("ID proof" / "Photo of your shop or farm" / "GST certificate (optional)");
  description ("Aadhaar, PAN, voter ID or driving licence" / "Clear photo of your shop, farm or business location" / "Upload your GST
  certificate if available"); actions [📷 Take photo][🖼 Choose from gallery] small outlined.
- States: Uploading… spinner; "Upload failed" danger + Retry; "✓ Uploaded" + [↻ Replace]. Top danger banner "Upload this photo to continue."
- Footer [< Back][Save and continue] — disabled until every REQUIRED doc uploaded; optional can be added later.
- "Uploaded means received, not approved." Native camera/gallery.

## 16-05 review & submission (05-review-submission.png) — INSPECTED
- Header variant: back + 5-segment progress bar + "Step 5 of 5" right. Title "Review and submit" + "Please check your details before submitting
  your application."
- Summary cards (icon + title + multi-line summary + "Edit"): Business details (shop · category / Full name) · Location and delivery
  (address / PIN · State · radius) · Documents (ID proof: Uploaded / Shop photo: Uploaded / GST certificate: Not added (optional)) ·
  Payout account (bank · •••••1234 / Holder name).
- Consent checkbox "I confirm these details are correct and agree to AgriMore's seller terms" (link); [Submit application] disabled until
  checked; submitting = spinner "Submitting…" (Back stays).
- Flow Review → Confirm → Submit → Application under review. Failure banner "Couldn't submit your application. Try again." keep details.

## 16-06 pending approval (06-pending-approval.png) — INSPECTED
- Centred: logo lockup; illustration (document + clock outline over mint leaves); "Application under review" / "We're checking your details
  and documents."
- Timeline card: ✓ "Application submitted / Completed" · ◎ "Documents and details reviewed / In progress" (teal) · ○ "Approved — start selling /
  Pending". Mint info banner "ⓘ Check back here for your application status." [Check status] primary.
- Card "Contact AgriMore": rows [phone] Call support > · [mail] Email support >; caption "Contact details supplied by AgriMore." Text button "Sign out".
- Other states: "Checking status… / Please wait a moment." · info "Your application is still under review. We'll update this page once there's
  news." · danger "Couldn't check status. Try again. / Something went wrong. Please try again." [Retry] · sign-out confirm "Sign out? / You'll need
  to sign in again to view your application status." [Cancel][Sign out] · pull to refresh.

## 16-07 rejection (07-rejection.png) — INSPECTED
- Centred: logo lockup; illustration = document with red "!" badge inside a pale danger-tint circle; "Application not approved" / "Review your
  application details and contact AgriMore if you need help."
- Row card: [doc] "Application details / Check that your business details and documents are correct." > ; [Fix and resubmit] primary.
- "Contact AgriMore" card (headset icon): Call support > · Email support >. Text "Sign out".
- Correction journey: Open saved application → Edit details or documents → Review and submit → Application under review.
- Sign-out modal sheet "Sign out? / You'll be signed out of the app." [Cancel][Sign out]. Info: "A corrected application returns to review;
  submission does not guarantee approval." (Reason from admin shown when present — source contract.)

## 16-08 suspension (08-suspension.png) — INSPECTED
- Centred: logo lockup; illustration = shield with "!" over mint leaves; "Seller account suspended" / "Your listings are hidden and new orders
  are paused." / "Contact AgriMore for help with your account."
- Danger banner "⚠ Account access restricted". Card "Contact AgriMore": Call support > · Email support >. OUTLINED full-width [Sign out].
- What it means: [eye-off] "Listings hidden / Your listings are hidden and won't be visible to buyers." · [pause] "New orders paused / New orders
  are paused and you won't receive new orders."
- Sign-out confirm (native) "Sign out? / You'll need to sign in again to access your account." [Cancel][Sign out].
- "Use the supplied account explanation; do not invent a reason or reinstatement date."

## 17-01 order cards (01-order-cards.png) — INSPECTED
- Orders root: large "Orders" title (no back); search "Order number, customer or product" (filled/sunken field); status chips "All 24"
  (selected = filled teal + count pill) · "To accept 3" · "To pack 2" (outlined, count pill); period/type chips "All time · Today(selected) ·
  7 days · 30 days · B2B".
- Card: "#1042" bold + status pill (dot/icon + label; To accept amber, Packing blue, Delivered green, Cancelled grey) + chevron;
  "Priya Sharma · 24 Sep 2026, 10:30 AM"; "2 items · Prepaid" / "1 item · Cash on delivery" + total "₹580" bold right.
- Anatomy: identity · stage label · customer & time · payment method · total.
- Empty: open-box illustration "No orders yet / Try a different filter or check back later."
- Stages: Placed → Accepted → Packing → Ready for pickup → Out for delivery → Delivered.
- Bottom nav: Orders selected, badge on icon.

## 17-02 customer & delivery (02-customer-delivery.png) — INSPECTED
- Detail app bar: back + "Order 1042" + [phone] + [message] icon actions.
- Summary card: "₹580" large + "2 items · Prepaid" + status pill right.
- "Customer" card (user icon header), key/value rows: Name · Business phone (+91 •••••••1234 masked + call icon button) · Deliver to (pin +
  wrapped address) · Delivery slot (clock + "Today, 4 – 6 PM") · Buyer's note (doc icon + text) — empty: "No note from buyer".
- "Items (2)" card (basket icon) + "View items >" link: thumb + name + "Option: 5 kg" + "1 pack × ₹320" + line total.
- Sticky footer: [⊘ Reject] outlined danger + [Accept order] filled.
- Communication: "Call customer / Opens phone app" · "Message customer / Opens SMS app" (large targets).

## 17-03 item options (03-item-options.png) — INSPECTED
- Header variant: back + "Order #1042" + status pill ("Placed" amber) ; sub "24 Sep 2026 · 10:30 AM".
- Summary strip (bordered): [bag] "2 items" | [card] "Prepaid" | "₹580 / Total".
- "Items (2)" card: thumb 56 + name + "Option: 5 kg" + "1 pack × ₹320" + line total right; "Items subtotal ₹560".
- Buyer note card (message icon, mint/sunken): "Buyer note / Please call when you arrive."
- "Payment preview / Includes delivery and discount" + "Total ₹580". Footer [Reject][Accept order].
- Item without option: "Fresh coriander / 2 × ₹20 / ₹40". Info banner: "Ordered options and quantities stay read-only" (sellers cannot edit
  quantities/options/substitute here).

## 17-04 payment breakdowns (04-payment-breakdowns.png) — INSPECTED
- Accepted order: header card "Order 1042" + "Accepted" (success tint) + "24 Sep 2026, 10:30 AM"; two-column: [user] name + masked phone |
  [pin] address + "Delivery: 4 – 6 PM"; [store] "Seller: Kaveri Fresh".
- Items card lines; "Payment" card: Subtotal · Discount (−₹20, success colour) · Delivery · Tax · divider · **Total ₹580**.
- [📄 Generate invoice] outlined full width; footer [Cancel order (danger outline)][Start packing (filled)] — cancel only where permitted.
- Payment method tiles: "Prepaid / Paid by customer online" (card icon) vs "Cash on delivery / Customer pays on delivery" (cash icon) — display only.
- Info "Buyer order total is separate from seller settlement."

## 17-05 stage actions (05-stage-actions.png) — INSPECTED
- Header: back + centred "Order #1042" + payment pill ("Prepaid", mint). Stage block: stage icon + stage name + timestamp + guidance
  ("Waiting for your action" / "Prepare items for packing" / "Items are being packed") + compact vertical 6-step timeline
  (done teal check, current filled, upcoming hollow).
- Customer | Delivery two-column card; Items (2) + "View all"; Total.
- Footers by stage: Placed → [🗑 Reject order][✓ Accept order] · Accepted → [🗑 Cancel order][📦 Start packing] · Packing →
  [Cancel order][🚚 Mark ready for pickup]. Cancellation shown only when permitted by order rules.
- Later stages status-only with 6-dot horizontal progress: Ready for pickup (Awaiting pickup) · Out for delivery (Delivery in progress) ·
  Delivered (Order complete) · Cancelled (Order was cancelled; x marker, rest hollow).

## 17-06 rejection & cancellation (06-rejection-cancellation.png) — INSPECTED
- Bottom sheet (handle + X) over the order: "Reject this order?" / "Tell the buyer why. This is required."; summary box ([bag] "Order #1042 /
  Priya Sharma" | "₹580 / Prepaid"); radio reasons: Item out of stock · Can't deliver to this area · Price was wrong · Shop is closed ·
  Something else; "Note for the buyer (optional)" textarea; danger note "This prepaid order will be refunded." (prepaid only);
  [Keep order outlined][Reject order danger filled]. Cancel variant: "Cancel this order?" … [Keep order][Cancel order] — only where permitted.
- Validation: "Choose a reason to continue." (error icon, red) under the group; mockup also greys the button.
- Submitting: "Submitting…" spinner; failure "Couldn't update the order. Try again. / Keep the selected reason and note."

## 17-07 invoice (07-invoice.png) — INSPECTED
- Invoice screen: back + "Invoice"; doc type title ("Bill of Supply" when no GST / "Tax Invoice" when GST) — MUST come from server data;
  number + copy icon; "Issued <date>"; "For order <n>"; info banner (e.g. no GST charged); From | Bill to columns (name, address, GSTIN when
  present); table Item | Qty × Price | Amount (thumb, option, HSN/GST rate); Subtotal · Discount · Delivery · Tax (CGST/SGST or IGST);
  **Total**; footnote ("Prices include GST.").
- Order-detail invoice card: BEFORE = [doc] "Invoice / Generate an invoice for this order." [Generate invoice outlined]; AFTER = "Invoice /
  <number> [copy] / Issued <date>" [View invoice filled].
- Copy feedback: toast "✓ Invoice number copied ×". Tax labels only from validated order data.

## 18-01 product cards (01-product-cards.png) — INSPECTED
- Catalogue root: large "Catalogue" + [sort ⇅] icon + [+] filled-teal circular add icon; search "Search your products" (filled);
  chips (wrap): All(selected) · Active · Drafts · Low stock · Out of stock · Inactive.
- Product card: photo ~88 rounded left; name; "₹64" bold + "MRP ₹80" struck-through muted; stock badge ("25 in stock" success · "Only 3 left"
  danger/warn · "Out of stock" danger); switch "Visible to buyers"; footer action row divided: [layers] Stock · [pencil] Edit · [trash] Delete (red).
- Extended FAB "+ Add product" bottom-right above bottom nav.
- Delete dialog: red-tint circle trash icon, "Delete this product?", "This will remove <name> from your catalogue." [Cancel][Delete (danger)].

## 18-02 drafts & visibility (02-drafts-visibility.png) — INSPECTED (the SELECTED revision)
- Header variant: [user-circle] "Catalogue" + shop name + "City, State" + bell. Search "Search products, e.g. tomatoes".
  Tabs-as-chips with counts: All (8) · Drafts (2) · Active (5) · Inactive (1) (selected = mint pill).
- Card: photo, name, "DRAFT" amber tag, category ("Vegetables"), "Stock: 25", "₹64  MRP ₹80"; row "Visible to buyers ⓘ" + switch (draft = off);
  actions [✎ Edit] outlined wide + [⋯] outlined square (overflow).
- Bottom: wide tonal "+ Add product" (bright mint fill) above nav.
- Editor actions: [✓ Save product] filled + [📄 Save as draft] outlined ("Keep this listing as a draft").
- Feedback toasts with X: "Changes saved" (success tint) · "Couldn't update visibility. Try again." (danger tint).
- Rules: stock and visibility are SEPARATE states; out of stock can still be visible; drafts prepare a listing.

## 18-03 stock & bulk actions (03-stock-bulk-actions.png) — INSPECTED
- "Update stock" bottom sheet (X): product summary (thumb, name, price/MRP, "Current stock: 25"); "Units in stock" numeric field; [Save];
  numeric keypad. Invalid ("-1") → "Enter a valid stock quantity."; saving "Saving…"; failure "Couldn't update stock. Try again."
- Selection mode: app bar "← 2 selected … Cancel"; cards get a leading checkbox; stock badge ("25 in stock"/"3 in stock"/"0 in stock" danger);
  "Visible to buyers" switch; category tag; bottom bar [👁 Hide (2)] outlined + [⤴ Publish (2)] filled. Tip "Long-press to select products".
- DECISION (card actions): 18-02 is the selected revision → card = Edit (wide outlined) + ⋯ overflow (Update stock, Delete); stock badge from
  18-01/18-03 replaces plain "Stock: N".

## 18-04 product editor (04-product-editor.png) — INSPECTED
- ONE form for create & edit (not a stepper): "← New product" / "← Edit product ⋮".
- Photo row: primary photo tile (camera badge) + "Add photo" tile; edit shows [📷 Replace photo] + stock badge "25 in stock" + "Low stock alert: 5".
- Fields: Product name * · Description (multiline) · Category (dropdown, leaf icon) · Selling price (₹) * | MRP (₹) · Stock * | Low stock alert.
- Section link rows (icon + title + subtitle + chevron → sub-screens): Pack options ("Manage product packs and variants") · Pricing & tax
  ("Set additional pricing information") · Coverage ("Manage where this product is visible") · Wholesale ("Set wholesale buying options").
- Sticky footer: [Save as draft outlined][Save product filled] (new) / [Save as draft][Update product] (edit).
- Required error "Product name is required."; saving "Saving…"; error banner "Couldn't save product. Try again." + "Check your connection and
  try again. Your changes are not saved." Footer card: seller avatar + shop + city (context).

## 18-05 pack options (05-pack-options.png) — INSPECTED
- Sub-screen chrome: "← Edit product ⋮"; product summary header (thumb, name, "Vegetables · Kaveri Fresh", pin "City, State");
  tab strip Basic info · Pricing · Stock · Pack options (selected underline teal).
- "Pack options (2)" / "Each option has its own price and stock."; rows [box] "1 kg" / "₹64 · Stock 25" + [pencil] + [trash red];
  dashed "+ Add option"; [Save product].
- Add/Edit option = bottom sheet (X): Option name · Selling price (₹) · Stock · [Save].
- Empty: box icon "No pack options yet / Add pack options to offer this product in different sizes." [+ Add option].
- Errors: "This option name already exists." · "Enter a price greater than zero."
- Rule: each option has its own stock; product-level stock is NOT added to option stock.

## 18-06 pricing & tax (06-pricing-tax.png) — INSPECTED
- "← Pricing & tax" sub-screen; product summary card (thumb, name, category, pin "shop · city"); big "Selling price ₹64 | MRP ₹80".
- "Pricing by centre": Centre dropdown; three tiles Default · Area · Current (current highlighted mint); "Price source [Manual]" pill +
  [↺ Reset to mapped price]. Price source states: Default (product's default price) · Area (area mapped price) · Manual (set for this centre).
  → ONLY if the source model has centre/mapped prices (product_price_mappings / centers); otherwise not invented.
- "Tax details (optional)": HSN code (optional) (validation "Enter 4, 6 or 8 digits.") · GST rate (optional) dropdown ("Not declared", 0%, …);
  info "Use the tax details supplied for this product."; [Save changes].

## 18-07 coverage (07-coverage.png) — INSPECTED
- "← Coverage / <product name>" + product thumb at right; lead "Choose where this product is available to buyers."
- Segmented pills State · District · Radius (selected mint/bright teal).
- State: State dropdown → mint summary card [pin] "State coverage / Tamil Nadu / This product will be visible to buyers in Tamil Nadu."
- District: State + District dropdowns → "District coverage / Chennai, Tamil Nadu / … visible to buyers in Chennai, Tamil Nadu."
- Radius: State · Latitude | Longitude · [⌖ Use current location] outlined · "Radius (km) 10 km" slider 1–50 · "Radius coverage / Within 10 km of
  selected coordinates / … within 10 km of 13.0827, 80.2707."
- [Save changes]. Errors: "Select a district." (red dropdown border) · detecting "Detecting…" · "Couldn't get location. / Enter coordinates manually."

## 18-08 wholesale settings (08-wholesale-settings.png) — INSPECTED
- "← Wholesale settings" (centred); product summary card (thumb, name, price + MRP, stock badge, "Vegetables · shop / city").
- Card: [users] "Enable wholesale / Offer a separate price for bulk orders." + switch.
- Off: store+boxes illustration "Wholesale is off / Enable wholesale to set a separate price for bulk orders and a minimum order quantity."
- On: "Wholesale price (₹)" (helper "Must be lower than your selling price.") · "Minimum order quantity" (helper "Enter the minimum number of
  units per order.") · mint "Wholesale summary" card (tag icon): Wholesale price ₹56 · Minimum order 10 units. [Save changes].
- Errors: "Must be lower than ₹64." · "Enter a quantity greater than zero."

## 19-01 pending & paid (01-pending-paid-amounts.png) — INSPECTED
- Payments root: large "Payments". Hero card (mint light / dark-teal dark): "To be paid" / "₹551" (display) / "Amount from completed orders that are
  pending settlement." + clock icon in amber circle.
- Two metric cards: "Paid · last 30 days ₹304" · "Paid · all time ₹304" (small bar-chart icon).
- Row: [bank] "Payout account / Example Bank · •••• 4821". Row: [doc] "Monthly statements / September 2026" + amount + >.
- "Settlements" + "See all": rows [box] "Order #1042 / 24 Sep 2026" + amount + status (⏱ Pending amber / ✓ Paid green) + >.
- Zero: "To be paid ₹0 / No pending settlements." Loading skeleton "Loading payments data…". Error "Couldn't load payments. / Try again."
  [↻ Try again].

## 19-02 masked payout accounts (02-masked-payout-accounts.png) — INSPECTED
- Layout variant: "To be paid ₹551" tall mint tile left + stacked "Paid last 30 days ₹304" / "Paid all time ₹304" right.
- Payout account card (read-only): [bank tile] "Payout account / Example Bank · •••• 4821 / Account on file". Missing: "No payout account on file /
  Account details are not available." UPI: "UPI on file / ka•••••@bank" (masked).
- Month block "September 2026": Total gross ₹900 · Total commission ₹45 · Total net ₹855; table Order | Gross | Commission | Net | Status
  ("#1042 24 Sep 2026 ₹580 ₹29 ₹551 Pending"; "#1041 … Paid" + paid date).
- Info: "We show masked identifiers by default…"; show masked identifiers by default. NO reveal of full numbers.

## 19-03 settlement timelines (03-settlement-timelines.png) — INSPECTED
- Settlement detail: "← Order 1042" + status pill (Pending amber / Paid green).
- Card: "Order #1042 / Created 24 Sep 2026"; "Amount / ₹551 (display) / To receive" (paid: "Received").
- Timeline card: ✓ "Settlement created / 24 Sep 2026" → ○ "Payment pending / Awaiting payment record" (dashed connector) or ✓ "Paid / 23 Sep 2026".
- "Order financials": Order value · Commission (−) · divider · **You receive**.
- "Payment reference" (when paid): value field with copy icon.
- Node states: Completed (check, recorded date) · Pending (hollow, not completed). Dates only from recorded settlement events.

## 19-04 commission breakdowns (04-commission-breakdowns.png) — INSPECTED
- "← Order 1042"; mint hero "You receive / ₹551" + status pill; card: Order value ₹580 · Commission −₹29 · divider · **You receive ₹551**
  (primary colour) + "ⓘ Amounts shown for this order."; "Settlement status" mini timeline (created ✓ date / payment pending ○ "The payment for
  this order is pending.").
- Equation strip: "₹580 Order value − ₹29 Deduction (Commission for this order) = ₹551 Net settlement". Amounts exactly as per the settlement
  record (no client computation).

## 19-05 monthly statements (05-monthly-statements.png) — INSPECTED
- Statement detail: "← September 2026 / Monthly statement" + [copy] icon action in app bar.
- "Statement summary" card: Order value · Commission (−) · **You receive** · divider · Paid · Pending.
- "Orders in this month": rows [doc] "Order 1042 / Created 24 Sep 2026" + amount + status pill.
- Month entry row (from Payments): [doc] "September 2026 / 2 settlements" + "₹855" + >; empty month "August 2026 / No settlements for this month ₹0".
- Copy action: tonal [📄 Copy statement] → toast "✓ Statement copied" (dark teal). Months group settlements by CREATION month.

## 19-06 invoices & copy (06-invoices-copy-actions.png) — INSPECTED
- Invoice screen variant: centred title = doc type ("Bill of Supply" / "Tax Invoice"); number card "BOS-2026-1042" + copy button
  ("Issued on 24 Sep 2026 | For order 1042"); From | To card (GSTIN line when present); "Items" rows (name, "5 kg pack", "1 × ₹320", amount;
  HSN/GST line for tax invoices); totals (Subtotal · Discount · Delivery · Tax included) · **Total**; info note.
- Copy actions: tonal 48dp buttons [📋 Copy invoice number] → dismissible success toast "✓ Invoice number copied ×"; [📋 Copy statement] →
  "Statement copied"; error toast "Couldn't load invoice. Try again. ×".

## 19-07 payments overview (07-payments-overview.png) — INSPECTED (the ROOT layout)
- "Payments" large title; 3 tinted metric tiles in a row: "To be paid ₹551" · "Paid last 30 days ₹304" · "Paid all time ₹304"
  (adapt: 19-01 hero+2 when space/text-scale demands — amounts must never truncate).
- Row [bank] "Payout account / Example Bank · •••• 4821" >; row [doc] "Monthly statement / September 2026" + "₹855" >.
- "Recent settlements": "#1042 / 24 Sep 2026" + "₹551" + Pending pill >; "#1041 … ₹304 Paid / Paid 23 Sep 2026" >.
- Empty: tiles ₹0; sunken "No account on file / Your payout account details will appear here once added."; receipt illustration "No settlements yet /
  Settlements appear here after delivered orders."
- SCOPE: no wallet, withdrawals or payout-request controls.

## 20-01 quote inbox (01-quote-inbox.png) — INSPECTED
- "← Quotes" (pushed/nested, has back). Chip tabs with counts: Needs response 2 (selected filled) · Negotiating 1 · Accepted 1 · Closed 1.
- Quote card: product thumb 72; "Q-2048" bold + actor pill "Your turn" (amber tint); buyer org "Green Valley Foods"; product "Fresh tomatoes";
  "20 kg × ₹52" (latest buyer offer qty × rate); "Total ₹1,040" (calculated); "⏱ Expires in 3 days · 27 Sep 2026"; chevron.
- Empty: icon in mint circle "You're all caught up / No quotes need your response right now." Error: "Couldn't load your quotes / Try again." [Try again].

## 20-02 actor & status (02-actor-status-labels.png) — INSPECTED
- Quote detail "← Quote Q-2048". Header: initials avatar ("GV", mint) + buyer org + product + "Grade A · kg" (only if data exists).
- Offer grid: "Buyer's latest offer / 20 kg" | "Price per kg / ₹52" | "Total value / ₹1,040"; "Your listed price ₹56/kg" | "This offer is ~7% below ⓘ";
  "Minimum order quantity (MOQ) 10 kg".
- "From" author chip (GV Buyer / K You) + "Status" pill.
- "Negotiation history" timeline: entries "Buyer's offer / date time / 20 kg × ₹52 / ₹1,040"; "Your counter-offer"; pending "You haven't responded yet /
  Waiting for your reply".
- Footer when your turn: [Decline (danger text)] [Counter (outlined)] [Accept (filled)]. When waiting: info "Waiting for the buyer to respond to your
  offer." (no actions).
- Status badges: Your turn (warning, clock) · Waiting for buyer (info, clock) · Accepted (success, check) · Order placed (info, box/cal) ·
  Declined (danger, x-circle) · Offer expired (neutral, clock). Accepted ≠ Order placed.

## 20-03 offer summaries (03-offer-summaries.png) — INSPECTED
- Quote detail header: "← Quote Q-2048" + status pill in app bar ("⏱ Your turn"). Product card: thumb + product + buyer org + "Your B2B price ₹56/kg" |
  "Min order 10 kg".
- "Offer on the table" card + author pill ("From buyer"): Quantity 20 kg · Price per kg ₹52 · highlighted Total ₹1,040 + comparison "7% below your B2B
  price" · "📅 Expires 27 Sep 2026" · "Buyer note / “For our weekly kitchen supply.”"
- "Negotiation history" summary row (message icon): "Green Valley Foods offered / 24 Sep 2026, 10:15".
- Footer (3 equal): [✕ Decline outlined][⇄ Counter outlined][✓ Accept filled].
- No price proposed: "No price proposed / Send your offer to start the negotiation." + full-width [⇄ Counter].

## 20-04 negotiation history (04-negotiation-history.png) — INSPECTED
- Header "← Quote Q-2048" + "Waiting for buyer" pill; product card "Listed wholesale ₹56/kg · MOQ 10 kg".
- Mint "Your current offer / Valid until 1 Oct 2026": "20 kg × ₹54 / kg" + "₹1,080" / "You · 4% below listed".
- "Negotiation history" vertical timeline; each event card: "<Actor> · <Action>" (Buyer · Requested a quote / Buyer · Offered / You · Offered),
  date · time, terms "20 kg × ₹52 / kg = ₹1,040", quoted note. Node colours: request grey, buyer blue, you teal.
- Footer banner (hourglass) "Waiting for buyer to respond."
- Outcomes: "Buyer Accepted" (success card) · "You Declined" (danger card) with qty/unit/total/note. Each event keeps its own terms + timestamp.

## 20-05 counter-offers (05-counter-offers.png) — INSPECTED
- Detail header variant: buyer avatar "M" + org + "Buyer" + date; product row "Wholesale price ₹56/kg · MOQ 10 kg".
- Counter-offer bottom sheet (X): "<product> / to <buyer>"; "Price per kg (₹)"; "Quantity (kg)"; "Offer valid for" chips 3 · 7 (DEFAULT) · 15 · 30 days;
  "Note to buyer (optional)"; mint Total card "₹1,080" + "4% below your B2B price"; [Cancel][Send offer].
- Validity selector sheet: radio cards (calendar icon) "3 days / Valid for 3 days" … [Done].
- Validation: "Enter a price above ₹0" · "Enter a whole number above 0"; Total "—"; Send disabled.
- Sending: "Sending… / Please wait while we send your counter-offer." Success: mint check "Offer sent / Your counter-offer has been sent to <buyer>." +
  status row "Waiting for buyer" + [Done]. No order created at this stage.

## 20-06 expiry & minimum quantity (06-expiry-minimum-quantity.png) — INSPECTED
- Expiry warning card (warning tint, clock): "Expires in 1 day / Offer valid until 25 Sep 2026".
- "Buyer's latest offer" card + comparison pill "7% below listed"; Quantity · Price per kg · Total value.
- Footer as three stacked icon+label buttons: [⊗ Decline][⇄ Counter][✓ Accept].
- Expired: app-bar pill "Expired" (danger); danger card "Offer expired / This offer expired on 23 Sep 2026."; info "This offer has expired. Send a
  counter-offer with a new validity."; Accept DISABLED (Decline/Counter stay) — matches server: accepting expired refused, countering allowed.
- "Send counter-offer" full screen variant: Price per kg (₹ prefix) · Quantity (kg suffix) with MOQ WARNING "Below your minimum order of 10 kg /
  This is a warning. You can still send this offer." · Validity (calendar + number + "days ▾") · Total value "5 kg × ₹54 / kg ₹270" ·
  [Cancel][➤ Send offer].
- Rules: no automatic expiry extension; below-minimum is a warning, not a block; acceptance separate from order placement.
  Stale state: "The buyer has already responded. / The latest offer is shown now."

## 20-07 acceptance & decline (07-acceptance-decline.png) — INSPECTED
- Detail header variant: "← Quote Q-2048 [Your turn] ⋮"; buyer row ([building] "Buyer / Green Valley Foods" + date); product row (thumb, name, "Unit: kg" |
  "Listed price ₹56/kg" / "Min. order quantity 10 kg"); "Latest offer from buyer 20 kg × ₹52 ₹1,040 / 7% below your listed price".
- Accept confirm dialog: mint check circle, "Accept this offer?", product + "20 kg × ₹52" + total, "The buyer can then place the order at this price.
  This cannot be undone." [Cancel][Accept].
- Decline sheet: "Tell the buyer why" radio: Price is too low · Out of stock · Can't supply this quantity · Can't deliver to the buyer · Other;
  "Add a note (optional)"; caption "The buyer sees your reason. They can send a new quote request later."; [Decline quote (danger filled)] +
  "Keep negotiating" text button.  (Only if the server accepts a decline reason — check rfq.ts contract.)
- Accepted: pill "Accepted" (success); banner "✓ The buyer can now place the order."; "Quote summary" (Quantity, Price per kg, Total, Your listed price).
- Toasts: "Quote accepted" (success) · "Quote declined" (danger); dark toast "This quote was declined."

## 20-08 linked orders (08-linked-orders.png) — INSPECTED
- Accepted quote: "← Quote Q-2048 [Accepted]"; buyer row (avatar, org, "Buyer", >) · product row (thumb, "Fresh produce · B2B", >); success banner
  "✓ The buyer can now place the order. / You have accepted their latest offer."; "Agreed terms" (Quantity · Unit price · **Total value**) +
  comparison sub-card "Compared to your listed price / 7% below / Your listed wholesale price: ₹56 / kg"; "Accepted on 24 Sep 2026" · "Quote ID Q-2048".
- Order placed: pill "Order placed" (info); info banner "The buyer has placed an order for this quote. / You can view the linked order details below.";
  "Agreed terms (from quote)"; linked order card "[doc] Order 1050 / Linked to quote Q-2048 / Placed on 24 Sep 2026" [View order].
- Order detail from quote: "Order 1050 [Placed]"; Order summary (Quantity · Unit price · Product subtotal) + "Other charges / Shown in order breakdown >";
  "Order date" · "Linked quote Q-2048 >"; footer [✕ Reject][✓ Accept order].
- "View order appears only after an order is linked. Quote acceptance does not mean payment or fulfilment."

## 21-01 KPI cards (01-kpi-cards.png) — INSPECTED
- "← Insights" + [ⓘ] action (metric explanations). Segmented 7 days | 30 days | 90 days (selected filled teal). Range line "18 – 24 Sep 2026 vs 11 – 17 Sep 2026"
  + calendar icon.
- Wide "Total sales ⓘ ⋮" card: "₹14,000" + "↑ +25%" (success, arrow glyph) + "vs previous 7 days (₹11,200)" + area sparkline.
- Grid: Orders "28 / ↑ +12% / 3 more than before (25)" · Average order value "₹500 / ↑ +12% / vs previous period (₹448)" · B2B sales share "40%" + donut +
  "₹5,600 of ₹14,000" · Sales trend (mini bars).
- Insight card (mint, leaf icon): "Steady growth this week / Sales are up 25% compared to the previous 7 days." → only if derived from real numbers.
- States: zero "₹0 / No sales in this period." · loading skeleton · error "Couldn't load insights." [Try again].
- Definitions: Total sales = value of items sold in the period (not profit/payout) · Orders = customer orders placed · AOV = total sales ÷ orders (only when
  orders > 0) · B2B share = share of total sales from business buyers · Sales trend = daily sales for the period.

## 21-02 period selectors (02-period-selectors.png) — INSPECTED
- Segmented 7 / 30 / 90 days (selected = filled teal pill inside a sunken track). Title "18 – 24 Sep 2026" + "Compared with 11 – 17 Sep 2026".
- Sales comparison card: "Sales ₹14,000" + delta chip "↑ +25%" (mint); bars "Current (18 – 24 Sep) ₹14,000" (solid teal) vs "Previous (11 – 17 Sep) ₹11,200"
  (hatched grey) — non-colour cue via pattern.
- Info: "Choose a period to update your insights." · "Each period compares with the immediately preceding period of the same length." · "Account health uses
  a fixed 30-day activity window."

## 21-03 comparisons (03-comparisons.png) — INSPECTED
- Header variant: "← Insights" + dropdown "Last 7 days ▾"; "18 – 24 Sep 2026"; section "Comparisons / Compared to 11 – 17 Sep 2026".
- Comparison card per metric (Sales, Orders, Avg. order value): value + delta chip; two labelled bars Current (solid teal) / Previous (hatched).
- Delta states: Increase "↑ +25%" (success tint) · Decrease "↓ −25%" (danger tint) · Unchanged "– 0%" (neutral) · No baseline "ⓘ Nothing to compare with yet"
  (previous ₹0 → NO percentage). Formula ((current − previous) / previous) × 100.

## 21-04 sparklines & sales charts (04-sparklines-sales-charts.png) — INSPECTED
- Header variant: date-range dropdown "📅 18 – 24 Sep 2026 ▾". "Sales ₹14,000" + "↑ +25%" pill + "vs ₹11,200".
- Line chart: this period = solid teal line + dots; previous = dashed grey line + dots (non-colour: dashed); y-axis ₹ ticks, x-axis per day ("18 Sep");
  end-point label; legend "● This period  ‑●‑ Previous period". Tooltip on touch: date + both values.
- B2B share card: donut + "40%" + "₹5,600 of ₹14,000" + >.
- Zero-sales: flat line at ₹0 (still drawn). Missing data: dashed box + bar icon "Sales data unavailable" (no fake line).

## 21-05 stage bars (05-stage-bars.png) — INSPECTED
- Header: "← Insights" + period dropdown "7 days ▾" + range caption "18 – 24 Sep 2026".
- "Orders by stage / 30 orders": rows stage icon + label + horizontal bar (length ∝ count, max = largest stage) + count right: Placed · Accepted · Packing ·
  Ready for pickup · Out for delivery · Delivered · Cancelled (each stage its own tint; icon carries meaning).
- Info: "Current stage of orders placed in this period. Includes cancelled orders." · "Count, not conversion rate."
- Empty: doc icon in circle "No orders in this period / There are no orders to show for 18 – 24 Sep 2026."

## 21-06 ranked products (06-ranked-products.png) — INSPECTED
- "Top products / Ranked by item revenue"; card "Total item revenue ₹14,000" (tinted).
- Rows: rank circle (mint, number) + thumb + name + "100 units" + revenue right. Sorted by revenue, then units; cancelled excluded.
- Empty: sprout/box icon "No product sales in this period / Products will appear here once you receive sales in the selected period."

## 21-07 rating distributions (07-rating-distributions.png) — INSPECTED
- "← Buyer ratings" + pill "All time". Summary card "4.5 / 5" (display) + 5 stars (half star) + "20 reviews".
- Rows per bucket 5→1: "5 ★ / 12 reviews" + proportion bar + "60%".
- Empty: star outline "— / 5 / No ratings yet". Limited sample: bar icon "2 reviews / More reviews are needed for the account-health rating metric."

## 21-08 score rings (08-score-rings.png) — INSPECTED
- "← Account health" + "Last 30 days". Ring "91 / out of 100" + "Good" pill; copy "A healthy account helps you trade with confidence. / Only measures with enough
  data count."
- Tiles: [star] "Your rating 4.5 / 5" · [box] "Listing snapshot 75% complete".
- "Performance measures" rows: icon + label + value + "Target ≥ 95%" + status icon (✓ met green / ! amber) + >: Orders delivered · Cancellations (≤) ·
  Buyer rating · Complete listings · Quotes answered within a day.
- Bands: Good (teal) · Needs attention (amber) · At risk (red) — word + colour. Insufficient: "—" ring + "Not enough activity yet".
- "The score averages normalized contributions from eligible measures." NOTE: ADR D-ACCOUNT-HEALTH open (safe default = no composite) → check what
  SELLER-HOME-1c actually shipped before adding a composite.

## 21-09 metric explanations (09-metric-explanations.png) — INSPECTED
- Tapping a metric (ⓘ) opens a bottom sheet: title, value, "How it's calculated" (e.g. "Sales ÷ Orders"), "Example" (₹14,000 ÷ 28 = ₹500), info when unavailable
  ("Average order value is unavailable when there are no orders."), optional Tip, [Got it].
- Health sheet: "Orders delivered / Measured 90% | Target At least 95% / Definition Delivered ÷ (delivered + cancelled) / Example 72 ÷ (72 + 8) = 90% /
  Uses orders placed in the last 30 days. Needs at least 5 delivered or cancelled orders. / Tip: Accept only what you can deliver."
- Definitions ("reflect current app logic"): Cancellations = cancelled ÷ all orders in window, target ≤5%, min 5 orders · Buyer rating = avg out of 5, target ≥4,
  min 3 reviews · Complete listings = complete live ÷ all live, target ≥80% (checks photo, description, HSN, GST) · Quote responsiveness = recent quotes not
  overdue awaiting seller ÷ recent quotes, target ≥90%, last 30 days. → VERIFY against insights_rules.dart / health_screen.dart.

## 22-01 store availability (01-store-availability.png) — INSPECTED (ACCOUNT ROOT)
- Account root: large "Account" + [⚙ settings] icon top-right. Store header row: store photo 56 + shop name + "City, State" + > (→ storefront/business).
- Store status card: OPEN = success-tint card, green dot "Store status / Taking orders / Your store is open to receive orders and quotes." ·
  PAUSED = warning banner "⏸ Your store is paused / New orders and quotes are paused." [Resume] + status "Paused — not taking orders" ·
  SCHEDULED CLOSED = info card (calendar) "Weekly off today / Your store is closed today as per your schedule. / Manage schedule >" + status "Closed today" (red
  dot) + row "Manual availability / Accept orders when open" + switch.
- Menu rows (icon + label + >): Weekly off & holidays · Business details · Delivery fees · Storefront editor · Reviews & replies · Followers & posts.
- "Existing orders are not affected by a manual pause."

## 22-02 pause durations (02-pause-durations.png) — INSPECTED
- "Store status" bottom sheet (X): row "Accepting orders" + switch + "Buyers see your store but cannot place orders." (when off); "Pause for" 4-option segmented:
  1 day · 3 days (selected) · 7 days · Until I resume; warning banner "New orders and quotes cannot be placed while paused. Existing orders are not affected.";
  [Pause my store] filled + [Cancel] outlined.
- Resume: "Accepting orders" on + "Scheduled closures still apply." [Cancel][Save]. Indefinite: "Paused until you resume." (toggle off).
- Note: this board shows bottom nav with Account selected & sheet above — do not duplicate nav inside sheet (render sheet over nav).

## 22-03 weekly closures (03-weekly-closures.png) — INSPECTED
- Full screen "← Weekly closures" + store header (photo, name, city). Card "Weekly off days / Your store takes no orders on these days every week." —
  day toggle chips Mon…Sun (selected = teal fill + check); summary row (calendar) "Closed every Sunday".
- "Holidays / No holidays planned." + [+ Add holiday] outlined.
- Info "Buyers can still see your products but cannot place orders on a day off. Days follow Indian time."; [Save].
- All 7 selected → danger "Keep at least one day open. / To stop orders for a while, pause your store instead."; success "Schedule saved / Your weekly
  closures and holidays have been updated."

## 22-04 holidays (04-holidays.png) — INSPECTED
- Same screen, second section: "Holidays / Add specific dates when your store will be closed." rows [calendar] "02 Oct 2026" + [trash red]; dashed
  [⊕ Add holiday]; info "Holidays follow Indian time (IST)."; [Save]. Weekly-off round day circles (compact variant) Sun…Sat.
- Date picker bottom sheet "Select date" (month nav, grid, selected = teal circle) [Cancel][Add]. Past dates disabled (reasonable).
- Empty: calendar-plus illustration "No holidays planned / Add your store holidays to keep customers informed." [+ Add holiday] + "You can plan up to 30 holidays."
- DECISION: 22-03 + 22-04 = ONE "Weekly off & holidays" screen (menu row name in 22-01).

## 22-05 business details (05-business-details.png) — INSPECTED
- Full screen "← Business details": Business name * · Phone · GSTIN (optional) (helper "Leave blank if not applicable.") · City · State · Opens | Closes
  (clock + time + ▾, native time picker) · Delivery radius (km) * ; [Save] + "Cancel" text.
- Required error "Enter your business name" (red border + icon). Success toast "✓ Business details updated ×".
- Fields MUST match what business_details_sheet.dart / sellers doc supports (check phone/hours/radius exist).

## 22-06 delivery fees (06-delivery-fees.png) — INSPECTED
- Full screen "← Delivery fees" + store header. Segmented "Flat fee | By order value" (selected mint / bright teal).
- Flat: card "Flat fee" big currency field "₹40" + "Charged on every order, whatever its value."
- By order value: table header "Min. order | Fee"; tier rows (₹0 → ₹40; ₹500 → ₹20; ₹1,000 → ₹0) as editable row pairs; dashed [⊕ Add tier]; helper
  "Include a tier starting at ₹0."; [Save].
- Messages: info "₹0 fee = free delivery / Set the fee to ₹0 to offer free delivery on eligible orders." · error "Include a ₹0 minimum-order tier / Please add
  a tier starting at ₹0." · success "Delivery fee updated / Your delivery fee has been saved."
- Existing: delivery_fee_sheet.dart + delivery_fee_validation.dart (D-DELIVERY-FEE lists flat/slab/distance) — keep the shapes the server supports.

## 22-07 storefront editor & preview (07-storefront-editor-preview.png) — INSPECTED
- "← Storefront" + text action "Preview" (teal). Cover photo (16:9-ish, rounded) + [📷 Edit photo] pill overlay; round logo overlapping the cover bottom-left
  with camera badge. Store name field; About (multiline); "Highlights (up to 3)" + "3 of 3 highlights added" counter; removable chips (mint, ×); "Up to 3
  highlights"; [Save changes].
- Store preview (full-screen modal, X): cover, centred logo, name, "City, State", "✓ Preview" pill, About, Highlights chips, footer "ⓘ Preview only / This is
  how your store appears to buyers." Nothing is published from preview.
- Add logo = dashed circle + camera. Save toast "Storefront updated / Your store details have been saved."

## 22-08 reviews & replies (08-reviews-replies.png) — INSPECTED
- "← Reviews" + store header; summary "4.5 ★★★★½ from 20 reviews"; filter chips All · 5★ · 4★ · 3★ · 2★ · 1★ · Unanswered.
- Review card: initials avatar "PS" + name "Priya S." + "2 days ago" + "✓ Verified purchase" pill (only if data supports it); stars; product name; text;
  [💬 Reply publicly] outlined full-width.
- Reply sheet "Reply publicly" (X): review excerpt; caption "Buyers see your reply under the review. You can edit it for 24 hours."; textarea; "Up to 500
  characters"; [Cancel][Post reply].
- Replied: nested "Your reply" card (store logo) + text + "Posted just now" + "Edit reply" link (only within 24 h).
- Footer "Public reply · Editable for 24 hours after first posting."

## 22-09 followers & posts (09-followers-posts.png) — INSPECTED
- "← Followers & posts"; mint stat card [users] "248 followers" + "↑ +18 in last 30 days".
- "Your posts": card with photo (trash icon button overlay top-right), text, "2 hours ago", product tag chip (tag icon + name). Extended FAB "+ New post".
- New post modal: "✕ New post [Post]" (Post filled small); textarea "Up to 500 characters"; photo preview with [🗑 Remove photo]; "Tag product (optional)"
  dropdown; info "Text, a photo or a tagged product is required to post."
- Delete confirm dialog: red trash circle "Delete this post? / Followers will no longer see it." [Cancel][Delete].

## 23-01 AI activation, connection, chat (01-ai-activation-connection-chat.png) — INSPECTED
- Not activated (mobile): "← AI assistant"; sparkles icon in mint circle; "Activate your AI assistant / Connect your own ChatGPT or Gemini API key for
  business questions."; info "Activation is available on agrimore.in. The app does not process this payment." (website-only policy; no checkout).
- Connection: "← AI connection"; green check "AI assistant connected / Your assistant is ready to help with your business questions."; "AI provider" dropdown
  (Google Gemini); "API key" masked dots (never re-displayed); success "Connected successfully / You can now ask questions about your products and orders.";
  [↪ Disconnect] danger outline.
- Chat: "← AI assistant [● Connected]"; user bubble (teal, right, avatar) + time; assistant bubble (sparkles avatar, surface) + time; "Illustrative response"
  label is mockup-only; composer "Ask about your products or orders" + round send button.
- States: "Connecting… / Setting up your AI assistant." · "Thinking… / Your assistant is working." · "Could not connect. Try again. / Please check your API key
  and try again."

## 23-02 notification inbox & preferences (02-notification-inbox-preferences.png) — INSPECTED
- Inbox "← Notifications" + text action "Mark all read"; chips All · Orders · Quotes · Payments · Account; groups "Today" / "Earlier"; item: unread dot (teal) /
  read dot (grey) + category icon + title + time + body + >.
- Preferences "← Notification preferences": "Choose which push alerts you receive. Inbox entries are always kept."; switch rows with icons: Orders · Quotes ·
  Payments · Stock · Reviews · Announcements; card "Quiet hours / Pause notifications for a while." + switch.
- Empty "You are all caught up / We'll let you know when there's something new." Error "Could not save. / Previous setting restored." (optimistic rollback).

## 23-03 quiet hours (03-quiet-hours.png) — INSPECTED
- In "Notification preferences": card [moon] "Quiet hours / No alerts on your phone during these hours." + switch; when on: "From" row "10:00 PM >" · "Until"
  row "7:00 AM >"; info "Notifications remain in your inbox. Ends the following morning." (cross-midnight wording only when until < from).
- Time picker bottom sheet (X, "From", wheel hour/min/AM-PM) [Cancel][Done]. Summary chip "10:00 PM – 7:00 AM".
- Error: "Could not save. Previous setting restored." inline in the card.

## 23-04 theme settings (04-theme-settings.png) — INSPECTED
- "← Settings": "Appearance" segmented System | Light | Dark (selected = filled teal/bright teal + check); caption per choice ("Follows your device appearance." /
  "Always use light appearance." / "Always use dark appearance."); rows (bordered cards): Notification preferences · Help & support · Open-source licences;
  "App version / 1.0.0 (100)". Updates immediately.

## 23-05 FAQs (05-faqs.png) — INSPECTED
- "← Help & support": search "Search FAQs" (clear ×); "Frequently asked questions" list of bordered expandable rows (question + chevron; expanded = mint tint
  + answer). Search shows "1 result"; empty "No matching FAQs / Try a different search." (doc-search icon in mint circle).
- Answers must match real behaviour (e.g. "one public reply per review, editable for 24 hours; ratings calculated by AgriMore").

## 23-06 support contacts (06-support-contacts.png) — INSPECTED
- "← Help & support": headset icon in mint circle "Contact AgriMore / Get help with your seller account."; bordered rows: [phone] "Call support / <configured number>" > ·
  [mail] "Email support / <configured email>" >; caption "Opens your phone or email app."; divider; [doc] "Browse FAQs" >.
- Numbers/emails from agrimore_core support constants (never hard-coded in screen). External handoff via url_launcher (tel:/mailto:).
- DECISION: Help & support = one screen: contact card header + FAQ search/list (23-05) + contacts (23-06) + policies (23-07).

## 23-07 policies (07-policies.png) — INSPECTED
- "← Seller policies": numbered mint cards (number circle + text + shield-check icon): 1 "Keep product details, prices and stock accurate." · 2 "Accept and pack orders
  on time." · 3 "Settlements are paid for delivered orders, after AgriMore's commission."; divider; "Legal documents": bordered rows [doc] Terms ↗ · Privacy Policy ↗;
  caption "Opens in your browser." URLs must be real configured destinations.

## 23-08 account actions (08-account-actions.png) — INSPECTED
- Account hub lower half: grouped card rows AI assistant · Notification preferences · Help & support · Settings · Seller policies; then separate bordered danger row
  [↪ Sign out] (red text/icon, red border) + >.
- NOTE: this board shows a back arrow on "Account" — Account is a ROOT tab (22-01 has no back) → no back arrow on root (prompt §7 rule).
- Sign-out confirm bottom sheet: "Sign out? / You'll need your phone number to sign in again." [Sign out (danger filled)][Cancel (outlined)].
- States: "Signing out…" (disabled, spinner) · banner "Could not sign out. Try again. ×" · info "Good to know / You'll need your phone number to sign in again after
  signing out."
- Account root (combined 22-01 + 23-08): store header → store status card → store menu (Weekly off & holidays, Business details, Delivery fees, Storefront editor,
  Reviews & replies, Followers & posts) → tools/support menu (AI assistant, Notification preferences, Help & support, Settings, Seller policies) → Sign out.
  Where are Quotes/Insights? Quotes under Orders/Home; Insights from Home (ADR-S08).

## 24-01 keyboard navigation (01-keyboard-navigation.png) — INSPECTED
- Traversal order = visual order: back(1) → Product name(2) → Stock(3) → Price(4) → Save changes(5). Tab forward, Shift+Tab back, Enter activates focused button.
  Keep focused control visible (scroll into view).
- The focused field/button here shows a DOUBLE outline (inner border + outer glow ring) — SUPERSEDED by 24-02 single-border rule. Do NOT copy.

## 24-02 visible focus (02-visible-focus.png) — INSPECTED (CORRECTED single-border revision — AUTHORITATIVE)
- Focused list row ("Help & support") = the row's OWN border becomes thicker (≈2.5–3px) and primary colour (light #0F766E; dark bright teal #5EEAD4). No outer ring, no glow, no gap.
- Component states for an outlined button: Default = 1.5px teal border; Focused = SAME border, thicker (≈3px) — geometry unchanged; Pressed = filled teal.
- Rules: focus visible on light and dark surfaces; keep focus clear of overlays; return focus to the trigger after closing a dialog.
- Settings rows here have subtitles ("Choose what you want to hear about.", "Get help and contact our team.", "Read our terms and policies.").

## 24-03 screen-reader labels (03-screen-reader-labels.png) — INSPECTED
- Preference rows merged into ONE semantic node: "Orders, switch, on" (label + subtitle + toggle state); row focus = single border (consistent with 24-02).
- Icon-only back button label "Back"; bell with badge "Notifications, 3 unread, button".
- Expose name/role/state; group related content; hide decorative icons; test with VoiceOver and TalkBack.

## 24-04 contrast, touch, text scaling (04-contrast-touch-text-scaling.png) — INSPECTED
- Large system text: labels wrap onto 2 lines ("Business / name"), field height grows, button grows; no clipping; content scrolls.
- 48×48 logical px shared target (icon 24 centred). Contrast targets: normal text ≥4.5:1, large ≥3:1, meaningful controls ≥3:1.
- Allow content to wrap and scroll; respect system text size.

## 24-05 reduced motion (05-reduced-motion.png) — INSPECTED
- Reduce-motion ON: in-progress = static hourglass icon + "Saving…" in a disabled button + caption "Saving your changes." (no spinner rotation);
  complete = persistent inline confirmation card "✓ Changes saved." (not a vanishing toast).
- Avoid sliding/zooming transitions; replace shimmer with STATIC placeholders; keep progress & completion messages; don't rely on animation for status.

## 24-06 non-colour status cues (06-non-colour-status-cues.png) — INSPECTED
- Each status = distinct ICON SHAPE + text + subtle tint: New (circle-dot) · Packing (package) · Delivered (circle-check) · Cancelled (circle-x); stock: "Stock is required"
  (triangle-alert) / "Stock updated" (check). Recognisable in monochrome. "Use text + icon + colour. Never rely on red versus green alone."

## 24-07 accessible charts & forms (07-accessible-charts-forms.png) — INSPECTED (board 7 = charts & forms, replaces duplicate)
- Chart card: title "Orders · Last 3 days" + summary "12 orders in total"; direct value labels on bars; matching DATA TABLE (Day | Orders) below.
- Form error summary banner at top: "1 field needs attention" + link to the field ("Stock quantity"); labels carry "(required)"; field error = red border + triangle
  icon + "Enter a stock quantity" + helper "Use zero if out of stock." (single border).
- Move focus to the first invalid field after submit; announce updates without stealing focus.

# ===== ALL 86 IMAGES INSPECTED (2026-09-24) =====

# Cross-cutting conclusions
1. PALETTE (seller brand) — light: canvas #F5F8F7, surface #FFF, raised #FFF, primary #0F766E, pressed/strong #134E4A, mint #DDF3EA (selected/tonal), text #142D2A,
   muted #526660, border #D8E3DF; dark: canvas #050908, surface #0B1513, raised #12221E, primary #5EEAD4 w/ on-primary #042F2E, text #ECFDF5, muted #A3B8B0,
   border #29433A. Status fg light/dark: success #15803D/#86EFAC, warning #B45309/#FCD34D, danger #B91C1C/#FCA5A5, info #1D4ED8/#93C5FD.
   → current Workspace seller dark (slate #0F172A, primary #2DD4BF) must change to the black+teal scheme; SA brand must stay pixel-identical.
2. TYPE: Inter; Display 32/40 w700 · Heading 24/32 · Title 20/28 · Body 16/24 · Label 14/20 w600 · Caption 12/16. Tabular figures for money.
3. SHAPE: button/field radius 8 (mockups show ~8), cards 12–16, sheets 16–24; buttons 48 tall; touch 48.
4. FOCUS: single existing border → 2dp primary (light #0F766E, dark #5EEAD4); no ring/glow/gap. 24-01 double ring is superseded.
5. NAV: phone bottom bar 5 tabs, selected = mint pill behind icon + teal label (dark: teal pill + dark icon); rail at ≥600; list+detail ≥840.
   Root screens: large left title, NO back arrow; pushed: back arrow + title.
6. STATUS: text + distinct icon + tint. Orders: To accept/Placed = warning+clock, Accepted = success?/info, Packing = info+package, Ready = info+store?, Out for delivery =
   info+truck, Delivered = success+check-circle, Cancelled/Rejected = neutral/danger + x-circle.
7. FEEDBACK: dark-teal toast (#134E4A) w/ white text + icon, above bottom controls; dismissible; persistent inline banners for errors; reduced motion → static.
8. SCOPE GUARDS: no wallet / withdraw / payout request; AI activation web-only info; illustrative data never hard-coded; invoice doc type from server data;
   pause 1/3/7/until resume; ≥1 weekly open day; ≤30 holidays IST; ≤3 highlights; 24h reply edit; post needs text|photo|product.
