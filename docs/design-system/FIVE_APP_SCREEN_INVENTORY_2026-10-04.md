# Agrimore five app screen inventory

This inventory lists the existing screen definitions and navigation structures for the five Agrimore apps, with each screen linked to its source. It is the source checklist for planning screen-by-screen UI/UX work. The current collection contains **211 screen-widget definitions and five application shells**, including ten Marketplace mobile/web variant implementations. Named dialogs/sheets, nested journeys, private full-page hosts, developer tooling and reusable embedded views are listed separately.

**CURRENT_IMPLEMENTATION / VERIFIED_REPOSITORY_FACT for source existence only. Collected 2026-10-04.** [CSV inventory](FIVE_APP_SCREEN_INVENTORY_2026-10-04.csv) · [JSON source snapshot](FIVE_APP_SCREEN_INVENTORY_2026-10-04.json).

Screen names here are readable inventory labels; the class/source column is authoritative. A route declaration, constructor call, title string or filename does not prove runtime reachability, working backend data or completed design-system adoption. There are two Marketplace definitions with no production constructor caller found in app lib: SplashScreen and the responsive SearchScreen under user/search. Their child mobile/web search variants inherit that parent uncertainty. No screens were launched and no live accounts, OTP, payments, support/delivery commands or backend operations were exercised.

## App totals

| App | Screen definitions | Shells | Platform variants included in screens | Named dialog and sheet definitions | Modal call sites including helper APIs |
| --- | --- | --- | --- | --- | --- |
| Marketplace | 72 | 1 | 10 | 9 | 53 |
| Seller | 37 | 1 | 0 | 8 | 23 |
| Delivery | 21 | 1 | 0 | 9 | 31 |
| Sales Associate | 18 | 1 | 0 | 0 | 1 |
| Admin | 63 | 1 | 0 | 18 | 92 |

Do not add the variant column to the screen count. Likewise, named overlays and modal call sites are different measures: one shared helper can serve many calls, and raw helper internals are included as implementation call sites. Multiple calls do not equal distinct user journeys. One source file can define several screens. The screen count does not include root app containers, generic design-system Page widgets, private hosts, tooling, shared splash or inline fallbacks.

## What was researched

All five app lib trees: 573 eligible Dart files / 201740 lines. Generated .g/.freezed and app_localizations files, plus firebase_options, are excluded. Lexical scanning handles comments, strings, nested interpolation and balanced route/class blocks. Screen declarations, paired State bodies, constructor references, direct imports for duplicate names, route switch cases, GoRoute builders, shell tab composition, native/helper modal calls and embedded widget declarations were indexed. Targeted semantic reads checked roots, Marketplace route aliases/auth/responsive search, Seller shell/application/product/payment flows, Delivery shell/registration/blocked-status/safety routes, Associate shell/auth/payout/catalogue and Admin route/settings/support composition. This is broad source research plus targeted semantic inspection, not a line-by-line interpretation of every file or a rendered screen audit.

Collection HEAD: 725e70f7aa9cb2966c2a5f590c6cb76117c6bc70; branch: agrimore/foundation-f3c-distance-delivery-pricing. Another chat is actively changing the shared checkout. Individual source hashes are recorded in the JSON; this collection is not asserted to be one immutable Git revision. Import/call matches and modal method labels remain source evidence, not compiler-derived navigation graphs. No percentage of routes covered or screens adopted is claimed.

## Five app screen tables

Each row is one screen or shell definition. Platform variants and screens without a constructor caller are explicitly labelled. Input fields and state words are optional source-inspection hints rather than tested state coverage. All light/dark/viewport, accessibility, interaction and backend verification remain pending for subsequent implementation.

### Marketplace

**Identity:** Professional green; warm gold and natural stone.

| ID | Area | Screen or shell | Purpose | Entry source | Definition |
| --- | --- | --- | --- | --- | --- |
| MKP-001 | user | Customer main shell (Application shell) | Five-tab customer shell: Home, Shop, Categories, Cart, Profile. | Route source: /, /main, /home, /shop, /shop/search, /cart, /profile, /category/:id, /categories | [MainScreen:23](../../apps/marketplace/lib/screens/user/main_screen.dart) |
| MKP-002 | auth | Complete Profile (Screen) | Complete the required customer profile after authentication. | Route source: /complete-profile | [CompleteProfileScreen:23](../../apps/marketplace/lib/screens/auth/complete_profile_screen.dart) |
| MKP-003 | auth | Enable Notifications (Screen) | Notification-permission onboarding. | Construction source: [login_screen.dart:560](../../apps/marketplace/lib/screens/auth/login_screen.dart) | [EnableNotificationsScreen:15](../../apps/marketplace/lib/screens/auth/enable_notifications_screen.dart) |
| MKP-004 | auth | Sign in and OTP verification (Screen) | Phone entry and OTP states in one sign-in screen, with Google entry. | Route source: /login, /complete-profile, /forgot-password | [LoginScreen:74](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| MKP-005 | auth | Mobile Number (Screen) | Collect a mobile number during onboarding. | Route source: /mobile-number | [MobileNumberScreen:15](../../apps/marketplace/lib/screens/auth/mobile_number_screen.dart) |
| MKP-006 | auth | Onboarding Address (Screen) | Onboarding address and profile/checkout add or edit address modes. | Route source: /onboarding-address, /profile/add-address, /profile/edit-address, /checkout/add-address | [OnboardingAddressScreen:17](../../apps/marketplace/lib/screens/auth/onboarding_address_screen.dart) |
| MKP-007 | auth | Signup (Screen) | Customer registration form. | Route source: /signup | [SignupScreen:13](../../apps/marketplace/lib/screens/auth/signup_screen.dart) |
| MKP-008 | business | Business Feed (Screen) | Following feed for business posts. | Route source: /business-feed | [BusinessFeedScreen:10](../../apps/marketplace/lib/screens/business/business_feed_screen.dart) |
| MKP-009 | business | Business Profile (Screen) | Seller public storefront and profile. | Route source: /business/:id | [BusinessProfileScreen:25](../../apps/marketplace/lib/screens/business/business_profile_screen.dart) |
| MKP-010 | chat | AI Chat (Screen) | AI conversation and support entry. | Route source: /support | [AIChatScreen:12](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| MKP-011 | chat | Chat History (Screen) | Saved AI conversation history. | Route source: /chat-history | [ChatHistoryScreen:6](../../apps/marketplace/lib/screens/chat/chat_history_screen.dart) |
| MKP-012 | employee | Sales Associate application entry (Screen) | Presentation for sales associate application entry. | Route source: /employee/apply | [EmployeeApplyScreen:6](../../apps/marketplace/lib/screens/employee/employee_apply_screen.dart) |
| MKP-013 | employee / onboarding | Sales Associate registration (Screen) | Presentation for sales associate registration. | Route source: /employee/onboarding, /employee/onboarding?handoff=… | [AssociateOnboardingScreen:44](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |
| MKP-014 | landing | Landing (Screen) | Public marketing and sign-in landing view. | Route source: /landing | [LandingScreen:9](../../apps/marketplace/lib/screens/landing/landing_screen.dart) |
| MKP-015 | legal | Privacy Policy (Screen) | Privacy document. | Route source: /privacy-policy | [PrivacyPolicyScreen:8](../../apps/marketplace/lib/screens/legal/privacy_policy_screen.dart) |
| MKP-016 | legal | Terms (Screen) | Terms and conditions document. | Route source: /terms | [TermsScreen:8](../../apps/marketplace/lib/screens/legal/terms_screen.dart) |
| MKP-017 |  | Not Found (Screen) | Unknown route or invalid route-argument fallback. | Construction source: [app.dart:71](../../apps/marketplace/lib/app/app.dart) | [NotFoundScreen:15](../../apps/marketplace/lib/screens/not_found_screen.dart) |
| MKP-018 | onboarding | Onboarding (Screen) | Introductory onboarding slides. | Route source: /onboarding | [OnboardingScreen:7](../../apps/marketplace/lib/screens/onboarding/onboarding_screen.dart) |
| MKP-019 | seller | Open the Seller app (Screen) | Presentation for open the seller app. | Route source: /seller/apply, /seller/panel, /seller/dashboard | [SellerHandoffScreen:14](../../apps/marketplace/lib/screens/seller/seller_handoff_screen.dart) |
| MKP-020 | splash | Splash (Screen) | Standalone splash implementation retained in source. | Definition present; production constructor caller not found | [SplashScreen:7](../../apps/marketplace/lib/screens/splash/splash_screen.dart) |
| MKP-021 | user / cart | Blinkit Coupon (Screen) | Alternative coupon interface. | Construction source: [mobile_cart_screen.dart:1964](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) | [BlinkitCouponScreen:11](../../apps/marketplace/lib/screens/user/cart/blinkit_coupon_screen.dart) |
| MKP-022 | user / cart | Cart (Screen) | Presentation for cart. | Cart tab; Construction source: [main_screen.dart:101](../../apps/marketplace/lib/screens/user/main_screen.dart) | [CartScreen:6](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart) |
| MKP-023 | user / cart | Coupon Selection (Screen) | Coupon selection for checkout. | Route source: /cart/coupons | [CouponSelectionScreen:13](../../apps/marketplace/lib/screens/user/cart/coupon_selection_screen.dart) |
| MKP-024 | user / cart | Mobile Cart (Platform variant) | Presentation for mobile cart. | Platform implementation inside a wrapper; Construction source: [cart_screen.dart:27](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart) | [MobileCartScreen:63](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) |
| MKP-025 | user / cart | Web Cart (Platform variant) | Presentation for web cart. | Platform implementation inside a wrapper; Construction source: [cart_screen.dart:23](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart) | [WebCartScreen:15](../../apps/marketplace/lib/screens/user/cart/web_cart_screen.dart) |
| MKP-026 | user / categories | Categories (Screen) | Presentation for categories. | Categories tab; Construction source: [main_screen.dart:98](../../apps/marketplace/lib/screens/user/main_screen.dart) | [CategoriesScreen:21](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| MKP-027 | user / checkout | Add Address (Screen) | Separate address-entry form retained alongside OnboardingAddressScreen. | Construction source: [saved_addresses_screen.dart:489](../../apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart) | [AddAddressScreen:20](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| MKP-028 | user / checkout | Checkout (Screen) | Checkout address and order-review composition. | Route source: /checkout | [CheckoutScreen:18](../../apps/marketplace/lib/screens/user/checkout/checkout_screen.dart) |
| MKP-029 | user / checkout | Order Success (Screen) | Order result presentation requiring order data. | Route source: /order-success | [OrderSuccessScreen:14](../../apps/marketplace/lib/screens/user/checkout/order_success_screen.dart) |
| MKP-030 | user / checkout | Payment Method (Screen) | Payment choice, delivery slot, totals and associate-code composition. | Route source: /checkout/payment | [PaymentMethodScreen:27](../../apps/marketplace/lib/screens/user/checkout/payment_method_screen.dart) |
| MKP-031 | user / flash_sale | Flash Sale (Screen) | Flash-sale discovery. | Route source: /flash-sale | [FlashSaleScreen:6](../../apps/marketplace/lib/screens/user/flash_sale/flash_sale_screen.dart) |
| MKP-032 | user / help | Help (Screen) | Help, FAQ and support presentation for this app. | Construction source: [order_details_screen.dart:463](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) | [HelpScreen:10](../../apps/marketplace/lib/screens/user/help/help_screen.dart) |
| MKP-033 | user / home | Home (Screen) | Presentation for home. | Home tab; Construction source: [main_screen.dart:82](../../apps/marketplace/lib/screens/user/main_screen.dart) | [HomeScreen:6](../../apps/marketplace/lib/screens/user/home/home_screen.dart) |
| MKP-034 | user / home | Mobile Home (Platform variant) | Presentation for mobile home. | Platform implementation inside a wrapper; Construction source: [home_screen.dart:12](../../apps/marketplace/lib/screens/user/home/home_screen.dart) | [MobileHomeScreen:32](../../apps/marketplace/lib/screens/user/home/mobile_home_screen.dart) |
| MKP-035 | user / home / search | Search Results (Screen) | Presentation for search results. | Route source: /search/results, /search?q=… | [SearchResultsScreen:12](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart) |
| MKP-036 | user / home / search | Search — routed search flow (Screen) | Presentation for search — routed search flow. | Route source: /search | [SearchScreen:13](../../apps/marketplace/lib/screens/user/home/search/search_screen.dart) |
| MKP-037 | user / home | Web Home (Platform variant) | Presentation for web home. | Platform implementation inside a wrapper; Construction source: [home_screen.dart:13](../../apps/marketplace/lib/screens/user/home/home_screen.dart) | [WebHomeScreen:30](../../apps/marketplace/lib/screens/user/home/web_home_screen.dart) |
| MKP-038 | user / notifications | Notifications (Screen) | Presentation for notifications. | Route source: /notifications | [NotificationsScreen:5](../../apps/marketplace/lib/screens/user/notifications/notifications_screen.dart) |
| MKP-039 | user / offers | Offers (Screen) | Offer discovery. | Route source: /offers | [OffersScreen:21](../../apps/marketplace/lib/screens/user/offers/offers_screen.dart) |
| MKP-040 | user / orders | Live Tracking (Screen) | Live rider/order map tracking. | Construction source: [order_details_screen.dart:1044](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) | [LiveTrackingScreen:36](../../apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart) |
| MKP-041 | user / orders | Order Details (Screen) | Customer order detail and action entry points. | Route source: /order-details, /order/:id | [OrderDetailsScreen:22](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) |
| MKP-042 | user / orders | Order Tracking (Screen) | Order progress presentation. | Route source: /order-tracking | [OrderTrackingScreen:9](../../apps/marketplace/lib/screens/user/orders/order_tracking_screen.dart) |
| MKP-043 | user / orders | Orders (Screen) | Presentation for orders. | Route source: /orders, /my-orders | [OrdersScreen:17](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart) |
| MKP-044 | user / orders | Rate Order (Screen) | Order rating and review form. | Route source: /rate-order | [RateOrderScreen:7](../../apps/marketplace/lib/screens/user/orders/rate_order_screen.dart) |
| MKP-045 | user / profile | Change Email (Screen) | Owned email-change and verification flow. | Construction source: [edit_profile_screen.dart:1245](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) | [ChangeEmailScreen:31](../../apps/marketplace/lib/screens/user/profile/change_email_screen.dart) |
| MKP-046 | user / profile | Change Password (Screen) | Password-change form. | Route source: /profile/change-password | [ChangePasswordScreen:10](../../apps/marketplace/lib/screens/user/profile/change_password_screen.dart) |
| MKP-047 | user / profile | Change Phone (Screen) | Owned phone-change and verification flow. | Construction source: [edit_profile_screen.dart:1222](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) | [ChangePhoneScreen:27](../../apps/marketplace/lib/screens/user/profile/change_phone_screen.dart) |
| MKP-048 | user / profile | Delete Account (Screen) | Account deletion presentation and confirmation. | Construction source: [profile_screen.dart:468](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) | [DeleteAccountScreen:20](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart) |
| MKP-049 | user / profile | Edit Profile (Screen) | Profile editing and account-ownership states. | Route source: /profile/edit | [EditProfileScreen:13](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) |
| MKP-050 | user / profile | Profile (Screen) | Presentation for profile. | Profile tab; Construction source: [home_app_bar.dart:536](../../apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart) | [ProfileScreen:69](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) |
| MKP-051 | user / profile | Saved Addresses (Screen) | Saved delivery-address management. | Route source: /profile/addresses | [SavedAddressesScreen:12](../../apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart) |
| MKP-052 | user / profile | Settings (Screen) | Presentation for settings. | Route source: /settings | [SettingsScreen:15](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| MKP-053 | user / rewards | Rewards (Screen) | Rewards presentation. | Route source: /rewards | [RewardsScreen:7](../../apps/marketplace/lib/screens/user/rewards/rewards_screen.dart) |
| MKP-054 | user / rfq | My Quote Requests (Screen) | Customer quote-request list. | Route source: /my-rfqs | [MyRfqsScreen:13](../../apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart) |
| MKP-055 | user / rfq | Quote Detail (Screen) | Customer quote detail and offer actions. | Route source: /rfq-detail | [RfqDetailScreen:25](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| MKP-056 | user / search | Mobile Search (Platform variant) | Presentation for mobile search. | Platform implementation inside a wrapper; Construction source: [search_screen.dart:12](../../apps/marketplace/lib/screens/user/search/search_screen.dart); Responsive parent wrapper has no caller found in app lib | [MobileSearchScreen:13](../../apps/marketplace/lib/screens/user/search/mobile_search_screen.dart) |
| MKP-057 | user / search | Search — responsive search wrapper (Screen) | Presentation for search — responsive search wrapper. | Definition present; production constructor caller not found; Responsive parent wrapper has no caller found in app lib | [SearchScreen:6](../../apps/marketplace/lib/screens/user/search/search_screen.dart) |
| MKP-058 | user / search | Web Search (Platform variant) | Presentation for web search. | Platform implementation inside a wrapper; Construction source: [search_screen.dart:13](../../apps/marketplace/lib/screens/user/search/search_screen.dart); Responsive parent wrapper has no caller found in app lib | [WebSearchScreen:5](../../apps/marketplace/lib/screens/user/search/web_search_screen.dart) |
| MKP-059 | user / settings | Language (Screen) | Language-selection presentation. | Route source: /language | [LanguageScreen:3](../../apps/marketplace/lib/screens/user/settings/language_screen.dart) |
| MKP-060 | user / shop | Mobile Shop (Platform variant) | Presentation for mobile shop. | Platform implementation inside a wrapper; Construction source: [order_success_screen.dart:96](../../apps/marketplace/lib/screens/user/checkout/order_success_screen.dart) | [MobileShopScreen:18](../../apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart) |
| MKP-061 | user / shop | Product Details (Screen) | Product information, variants, delivery and reviews. | Route source: /product-details, /product/:id | [ProductDetailsScreen:23](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart) |
| MKP-062 | user / shop | Shop (Screen) | Presentation for shop. | Shop tab; category/recent/deals modes; Route source: /recently-viewed, /deals, /category/:id | [ShopScreen:6](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) |
| MKP-063 | user / shop | Web Shop (Platform variant) | Presentation for web shop. | Platform implementation inside a wrapper; Construction source: [shop_screen.dart:39](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) | [WebShopScreen:12](../../apps/marketplace/lib/screens/user/shop/web_shop_screen.dart) |
| MKP-064 | user / subscriptions | My Subscriptions (Screen) | Recurring-order subscription list. | Route source: /my-subscriptions | [MySubscriptionsScreen:5](../../apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart) |
| MKP-065 | user / subscriptions | Subscription Setup (Screen) | Configure a product subscription. | Route source: /subscription-setup | [SubscriptionSetupScreen:5](../../apps/marketplace/lib/screens/user/subscriptions/subscription_setup_screen.dart) |
| MKP-066 | user / wallet | Add Money (Screen) | Wallet top-up form. | Route source: /wallet/add-money | [AddMoneyScreen:16](../../apps/marketplace/lib/screens/user/wallet/add_money_screen.dart) |
| MKP-067 | user / wallet | Product Credit (Screen) | Separate product-credit history. | Route source: /wallet/product-credit | [ProductCreditScreen:15](../../apps/marketplace/lib/screens/user/wallet/product_credit_screen.dart) |
| MKP-068 | user / wallet | Referral (Screen) | Referral information and sharing. | Route source: /wallet/referral | [ReferralScreen:11](../../apps/marketplace/lib/screens/user/wallet/referral_screen.dart) |
| MKP-069 | user / wallet | Transaction History (Screen) | Wallet transaction history. | Route source: /wallet/history | [TransactionHistoryScreen:11](../../apps/marketplace/lib/screens/user/wallet/transaction_history_screen.dart) |
| MKP-070 | user / wallet | Wallet (Screen) | Presentation for wallet. | Route source: /wallet | [WalletScreen:28](../../apps/marketplace/lib/screens/user/wallet/wallet_screen.dart) |
| MKP-071 | user / wishlist | Mobile Wishlist (Platform variant) | Presentation for mobile wishlist. | Platform implementation inside a wrapper; Construction source: [wishlist_screen.dart:12](../../apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart) | [MobileWishlistScreen:15](../../apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart) |
| MKP-072 | user / wishlist | Web Wishlist (Platform variant) | Presentation for web wishlist. | Platform implementation inside a wrapper; Construction source: [wishlist_screen.dart:13](../../apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart) | [WebWishlistScreen:13](../../apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart) |
| MKP-073 | user / wishlist | Wishlist (Screen) | Presentation for wishlist. | Route source: /wishlist | [WishlistScreen:6](../../apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart) |

#### Nested journeys and screen modes

| Parent | View or mode | Relationship | Source |
| --- | --- | --- | --- |
| LoginScreen | Phone entry | AnimatedSwitcher states in the same screen; not two route widgets. | [login_screen.dart](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| LoginScreen | OTP verification | AnimatedSwitcher states in the same screen; not two route widgets. | [login_screen.dart](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| OnboardingAddressScreen | New-user address | Mode/argument variants of the same widget; checkout named route uses this widget. | [routes.dart](../../apps/marketplace/lib/app/routes.dart) |
| OnboardingAddressScreen | Add profile address | Mode/argument variants of the same widget; checkout named route uses this widget. | [routes.dart](../../apps/marketplace/lib/app/routes.dart) |
| OnboardingAddressScreen | Edit existing address | Mode/argument variants of the same widget; checkout named route uses this widget. | [routes.dart](../../apps/marketplace/lib/app/routes.dart) |
| OnboardingAddressScreen | Checkout address entry | Mode/argument variants of the same widget; checkout named route uses this widget. | [routes.dart](../../apps/marketplace/lib/app/routes.dart) |
| ShopScreen | Category-filtered shop | Mode variants, with separate mobile/web implementations. | [shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) |
| ShopScreen | Search-in-shop | Mode variants, with separate mobile/web implementations. | [shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) |
| ShopScreen | Recently viewed | Mode variants, with separate mobile/web implementations. | [shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) |
| ShopScreen | Deals | Mode variants, with separate mobile/web implementations. | [shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) |
| AssociateOnboardingScreen | Public programme introduction | Conditional sections and step widgets in Marketplace, separate from the associate app. | [associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |
| AssociateOnboardingScreen | Associate details | Conditional sections and step widgets in Marketplace, separate from the associate app. | [associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |
| AssociateOnboardingScreen | Onboarding payment | Conditional sections and step widgets in Marketplace, separate from the associate app. | [associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |
| AssociateOnboardingScreen | Confirmation and current account status | Conditional sections and step widgets in Marketplace, separate from the associate app. | [associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |

#### Named dialogs and sheets

| No | Presentation | Source class | Definition |
| --- | --- | --- | --- |
| 1 | Autofill Number Sheet | _AutofillNumberSheet | [login_screen.dart:1121](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| 2 | Auto Location Sheet | _AutoLocationSheet | [mobile_home_screen.dart:750](../../apps/marketplace/lib/screens/user/home/mobile_home_screen.dart) |
| 3 | Address Bottom Sheet | AddressBottomSheet | [address_bottom_sheet.dart:15](../../apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart) |
| 4 | Logout Dialog | _LogoutDialog | [profile_screen.dart:1400](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) |
| 5 | AI Connect Form Sheet | _AiConnectFormSheet | [settings_screen.dart:601](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| 6 | Request Quote Sheet | RequestQuoteSheet | [request_quote_sheet.dart:11](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart) |
| 7 | Add Review Dialog | AddReviewDialog | [add_review_dialog.dart:18](../../apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart) |
| 8 | Delete Review Dialog | _DeleteReviewDialog | [review_card.dart:379](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) |
| 9 | Sort Bottom Sheet | SortBottomSheet | [sort_bottom_sheet.dart:9](../../apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart) |

#### Modal presentation call sites

Raw Flutter presentation APIs and known Agrimore helpers are listed individually. A method label is a lexical enclosing-method candidate, not a reviewed user-facing title. Helper definitions are excluded, while calls inside shared/local helper implementations can appear. Not all popup menus, OS permission prompts or third-party plugin UIs are modelled by this list.

| No | Presentation API | Context candidate | Named widget candidates | Source |
| --- | --- | --- | --- | --- |
| 1 | showDialog | setB2B | AlertDialog | [market_mode_provider.dart:55](../../apps/marketplace/lib/providers/market_mode_provider.dart) |
| 2 | showModalBottomSheet | _showAutofillSheet | _AutofillNumberSheet | [login_screen.dart:176](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| 3 | showDialog | if | AlertDialog | [ai_chat_screen.dart:337](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| 4 | showModalBottomSheet | _showMessageOptions | Inline or helper content | [ai_chat_screen.dart:636](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| 5 | showDialog | _deleteSession | AlertDialog | [chat_history_screen.dart:43](../../apps/marketplace/lib/screens/chat/chat_history_screen.dart) |
| 6 | showDialog | _showRatingDialog | AlertDialog | [message_bubble.dart:403](../../apps/marketplace/lib/screens/chat/widgets/message_bubble.dart) |
| 7 | showDialog | _showComingSoon | Inline or helper content | [landing_screen.dart:79](../../apps/marketplace/lib/screens/landing/landing_screen.dart) |
| 8 | showDialog | _showClearCartDialog | AlertDialog | [mobile_cart_screen.dart:386](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) |
| 9 | showModalBottomSheet | _openBlinkitCouponScreen | Inline or helper content | [mobile_cart_screen.dart:1960](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) |
| 10 | showModalBottomSheet | _showPaymentMethodSheet | Inline or helper content | [mobile_cart_screen.dart:2738](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) |
| 11 | showDialog | _showClearCartDialog | AlertDialog | [web_cart_screen.dart:68](../../apps/marketplace/lib/screens/user/cart/web_cart_screen.dart) |
| 12 | showDialog | _handleRemove | AlertDialog | [cart_item_card.dart:64](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart) |
| 13 | showModalBottomSheet | _showAvailableCoupons | Inline or helper content | [cart_summary.dart:156](../../apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart) |
| 14 | showDialog | if | AlertDialog | [add_address_screen.dart:567](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 15 | showDialog | _showLocationServiceDialog | AlertDialog | [add_address_screen.dart:955](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 16 | showDialog | _showPermissionDeniedDialog | AlertDialog | [add_address_screen.dart:988](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 17 | showModalBottomSheet | _showStateSelector | Inline or helper content | [add_address_screen.dart:1029](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 18 | showModalBottomSheet | if | Inline or helper content | [add_address_screen.dart:1062](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 19 | showModalBottomSheet | if | Inline or helper content | [add_address_screen.dart:1093](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| 20 | DialogHelper.showConfirmation | if | Inline or helper content | [saved_checkout_card.dart:58](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart) |
| 21 | showModalBottomSheet | _showAutoLocationBottomSheet | _AutoLocationSheet | [mobile_home_screen.dart:734](../../apps/marketplace/lib/screens/user/home/mobile_home_screen.dart) |
| 22 | showModalBottomSheet | _showFilterSheet | Inline or helper content | [search_results_screen.dart:94](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart) |
| 23 | showModalBottomSheet | _showSortSheet | Inline or helper content | [search_results_screen.dart:326](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart) |
| 24 | showModalBottomSheet | show | AddressBottomSheet | [address_bottom_sheet.dart:19](../../apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart) |
| 25 | showModalBottomSheet | _showProductSelectionModal | Inline or helper content | [order_details_screen.dart:205](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) |
| 26 | showModalBottomSheet | _pickGender | Inline or helper content | [edit_profile_screen.dart:363](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) |
| 27 | showModalBottomSheet | _pickImage | Inline or helper content | [edit_profile_screen.dart:452](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) |
| 28 | showDialog | _logout | _LogoutDialog | [profile_screen.dart:253](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) |
| 29 | showModalBottomSheet | _showShareBottomSheet | Inline or helper content | [profile_screen.dart:1285](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) |
| 30 | showDialog | _deleteAddress | Inline or helper content | [saved_addresses_screen.dart:128](../../apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart) |
| 31 | DialogHelper.showConfirmation | _clearCache | Inline or helper content | [settings_screen.dart:70](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| 32 | showModalBottomSheet | _showAiConnectSheet | _AiConnectFormSheet | [settings_screen.dart:557](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| 33 | DialogHelper.showConfirmation | _confirmDisconnectAi | Inline or helper content | [settings_screen.dart:569](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| 34 | DialogHelper.showConfirmation | if | Inline or helper content | [settings_screen.dart:639](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) |
| 35 | showDialog | _showScratchDialog | Inline or helper content | [rewards_screen.dart:275](../../apps/marketplace/lib/screens/user/rewards/rewards_screen.dart) |
| 36 | DialogHelper.showConfirmation | if | Inline or helper content | [rfq_detail_screen.dart:90](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| 37 | DialogHelper.showConfirmation | if | Inline or helper content | [rfq_detail_screen.dart:100](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| 38 | DialogHelper.showConfirmation | if | Inline or helper content | [rfq_detail_screen.dart:131](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| 39 | showModalBottomSheet | _showSortBottomSheet | Inline or helper content | [mobile_shop_screen.dart:814](../../apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart) |
| 40 | showModalBottomSheet | _showShareWidget | Inline or helper content | [product_details_screen.dart:320](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart) |
| 41 | showModalBottomSheet | _showRequestQuoteSheet | RequestQuoteSheet | [product_details_screen.dart:1366](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart) |
| 42 | showDialog | _showDeleteDialog | _DeleteReviewDialog | [review_card.dart:360](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) |
| 43 | showDialog | _showEditDialog | AddReviewDialog | [review_card.dart:370](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) |
| 44 | showDialog | _showAddReviewDialog | AddReviewDialog | [reviews_section.dart:63](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart) |
| 45 | showModalBottomSheet | _showAllReviews | DraggableScrollableSheet | [reviews_section_inline.dart:72](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart) |
| 46 | showDialog | _showAddReviewDialog | AddReviewDialog | [reviews_section_inline.dart:151](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart) |
| 47 | showModalBottomSheet | SizedBox | SortBottomSheet | [shop_app_bar.dart:295](../../apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart) |
| 48 | showDialog | _handleCancel | AlertDialog | [my_subscriptions_screen.dart:53](../../apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart) |
| 49 | DialogHelper.showConfirmation | if | Inline or helper content | [add_money_screen.dart:542](../../apps/marketplace/lib/screens/user/wallet/add_money_screen.dart) |
| 50 | showDialog | _showClearConfirmation | AlertDialog | [mobile_wishlist_screen.dart:298](../../apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart) |
| 51 | showDialog | _moveAllToCart | Inline or helper content | [mobile_wishlist_screen.dart:478](../../apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart) |
| 52 | showDialog | _showClearConfirmation | AlertDialog | [web_wishlist_screen.dart:234](../../apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart) |
| 53 | showModalBottomSheet | _handleExternalWallet | Inline or helper content | [razorpay_service.dart:427](../../apps/marketplace/lib/services/razorpay_service.dart) |

### Seller

**Identity:** Blue teal; copper and cool neutrals.

| ID | Area | Screen or shell | Purpose | Entry source | Definition |
| --- | --- | --- | --- | --- | --- |
| SEL-001 | shell | Seller Shell (Application shell) | Five-tab merchant shell: Home, Orders, Catalogue, Payments, Account. | Construction source: [app.dart:72](../../apps/seller/lib/app/app.dart) | [SellerShell:24](../../apps/seller/lib/screens/shell/seller_shell.dart) |
| SEL-002 | account | Help (Screen) | Help, FAQ and support presentation for this app. | Construction source: [settings_screen.dart:62](../../apps/seller/lib/screens/account/settings_screen.dart) | [HelpScreen:10](../../apps/seller/lib/screens/account/help_screen.dart) |
| SEL-003 | account | Notification Settings (Screen) | Notification preferences and quiet hours. | Construction source: [settings_screen.dart:57](../../apps/seller/lib/screens/account/settings_screen.dart) | [NotificationSettingsScreen:16](../../apps/seller/lib/screens/account/notification_settings_screen.dart) |
| SEL-004 | account | Seller Policies (Screen) | Merchant legal documents. | Construction source: [help_screen.dart:58](../../apps/seller/lib/screens/account/help_screen.dart) | [SellerPoliciesScreen:10](../../apps/seller/lib/screens/account/policies_screen.dart) |
| SEL-005 | account | Seller Settings (Screen) | Merchant appearance, app information and links. | Construction source: [seller_profile_screen.dart:338](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [SellerSettingsScreen:14](../../apps/seller/lib/screens/account/settings_screen.dart) |
| SEL-006 | account | Store Schedule (Screen) | Store operating schedule, weekly off and holidays. | Construction source: [seller_profile_screen.dart:169](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [StoreScheduleScreen:89](../../apps/seller/lib/screens/account/store_schedule.dart) |
| SEL-007 | ai | Seller AI Chat (Screen) | Merchant AI conversation. | Construction source: [seller_profile_screen.dart:405](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [SellerAiChatScreen:12](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) |
| SEL-008 | auth | Rejected or suspended account (Screen) | Presentation for rejected or suspended account. | Construction source: [app.dart:70](../../apps/seller/lib/app/app.dart) | [AccountRestrictedScreen:17](../../apps/seller/lib/screens/auth/account_restricted_screen.dart) |
| SEL-009 | auth | Application Status (Screen) | Merchant application review status. | Construction source: [app.dart:69](../../apps/seller/lib/app/app.dart) | [ApplicationStatusScreen:14](../../apps/seller/lib/screens/auth/application_status_screen.dart) |
| SEL-010 | auth | Email Sign In (Screen) | Merchant email/password sign-in and reset sheet. | Construction source: [seller_sign_in_screen.dart:122](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) | [EmailSignInScreen:12](../../apps/seller/lib/screens/auth/email_sign_in_screen.dart) |
| SEL-011 | auth | Seller Sign In (Screen) | Merchant sign-in entry. | Construction source: [app.dart:66](../../apps/seller/lib/app/app.dart) | [SellerSignInScreen:23](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) |
| SEL-012 | home | Add or edit product (Screen) | Create/edit product with stock, images, pricing and linked editor subpages. | Construction source: [dashboard_screen.dart:446](../../apps/seller/lib/screens/home/dashboard_screen.dart) | [AddProductScreen:44](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| SEL-013 | home | Dashboard (Screen) | Merchant operational home and quick actions. | Home tab; Construction source: [seller_shell.dart:44](../../apps/seller/lib/screens/shell/seller_shell.dart) | [DashboardScreen:33](../../apps/seller/lib/screens/home/dashboard_screen.dart) |
| SEL-014 | insights | Health (Screen) | Merchant store-health indicators. | Construction source: [dashboard_screen.dart:193](../../apps/seller/lib/screens/home/dashboard_screen.dart) | [HealthScreen:51](../../apps/seller/lib/screens/insights/health_screen.dart) |
| SEL-015 | insights | Insights (Screen) | Merchant sales and order insights. | Construction source: [dashboard_screen.dart:199](../../apps/seller/lib/screens/home/dashboard_screen.dart) | [InsightsScreen:21](../../apps/seller/lib/screens/insights/insights_screen.dart) |
| SEL-016 | notifications | Notifications (Screen) | Presentation for notifications. | Construction source: [notifications_screen.dart:36](../../apps/seller/lib/screens/notifications/notifications_screen.dart) | [NotificationsScreen:49](../../apps/seller/lib/screens/notifications/notifications_screen.dart) |
| SEL-017 | onboarding | Application (Screen) | Five-step merchant application host. | Construction source: [app.dart:68](../../apps/seller/lib/app/app.dart) | [ApplicationScreen:16](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| SEL-018 | onboarding | Apply Intro (Screen) | Merchant application introduction. | Construction source: [app.dart:67](../../apps/seller/lib/app/app.dart) | [ApplyIntroScreen:13](../../apps/seller/lib/screens/onboarding/apply_intro_screen.dart) |
| SEL-019 | orders | Invoice (Screen) | Seller order invoice. | Construction source: [order_invoice_card.dart:92](../../apps/seller/lib/screens/orders/widgets/order_invoice_card.dart) | [InvoiceScreen:11](../../apps/seller/lib/screens/orders/invoice_screen.dart) |
| SEL-020 | orders | Seller Order Detail (Screen) | Merchant order details and stage actions. | Construction source: [notifications_screen.dart:107](../../apps/seller/lib/screens/notifications/notifications_screen.dart) | [SellerOrderDetailScreen:20](../../apps/seller/lib/screens/orders/seller_order_detail_screen.dart) |
| SEL-021 | orders | Seller Orders (Screen) | Merchant order list. | Orders tab; Construction source: [seller_shell.dart:45](../../apps/seller/lib/screens/shell/seller_shell.dart) | [SellerOrdersScreen:62](../../apps/seller/lib/screens/orders/seller_orders_screen.dart) |
| SEL-022 | payments | Payments (Screen) | Merchant payments, wallet and settlement composition. | Payments tab; Construction source: [seller_shell.dart:47](../../apps/seller/lib/screens/shell/seller_shell.dart) | [PaymentsScreen:88](../../apps/seller/lib/screens/payments/payments_screen.dart) |
| SEL-023 | payments | All Settlements (Screen) | Full merchant settlement list. | Construction source: [payments_screen.dart:332](../../apps/seller/lib/screens/payments/payments_screen.dart) | [AllSettlementsScreen:344](../../apps/seller/lib/screens/payments/payments_screen.dart) |
| SEL-024 | payments | Settlement Detail (Screen) | Single settlement detail and timeline. | Construction source: [payments_screen.dart:190](../../apps/seller/lib/screens/payments/payments_screen.dart) | [SettlementDetailScreen:361](../../apps/seller/lib/screens/payments/payments_screen.dart) |
| SEL-025 | payments | Statement (Screen) | Statement detail for the supplied statement context. | Construction source: [payments_screen.dart:324](../../apps/seller/lib/screens/payments/payments_screen.dart) | [StatementScreen:56](../../apps/seller/lib/screens/payments/statements.dart) |
| SEL-026 | payments | Payout Account (Screen) | Payout destination form or account presentation. | Construction source: [wallet.dart:322](../../apps/seller/lib/screens/payments/wallet.dart) | [PayoutAccountScreen:544](../../apps/seller/lib/screens/payments/wallet.dart) |
| SEL-027 | posts | Create Post (Screen) | Create a merchant feed post. | Construction source: [followers_screen.dart:172](../../apps/seller/lib/screens/posts/followers_screen.dart) | [CreatePostScreen:16](../../apps/seller/lib/screens/posts/create_post_screen.dart) |
| SEL-028 | posts | Followers and merchant posts (Screen) | Presentation for followers and merchant posts. | Construction source: [seller_profile_screen.dart:398](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [FollowersScreen:97](../../apps/seller/lib/screens/posts/followers_screen.dart) |
| SEL-029 | products | Product catalogue (Screen) | Presentation for product catalogue. | Catalogue tab; Construction source: [seller_shell.dart:46](../../apps/seller/lib/screens/shell/seller_shell.dart) | [SellerProductsScreen:39](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| SEL-030 | profile | Delivery Fee (Screen) | Store delivery-fee settings. | Construction source: [delivery_fee_sheet.dart:26](../../apps/seller/lib/screens/profile/delivery_fee_sheet.dart) | [DeliveryFeeScreen:43](../../apps/seller/lib/screens/profile/delivery_fee_sheet.dart) |
| SEL-031 | profile | Seller AI Integration (Screen) | Merchant AI-provider integration. | Construction source: [seller_ai_chat_screen.dart:95](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) | [SellerAiIntegrationScreen:44](../../apps/seller/lib/screens/profile/seller_ai_integration_screen.dart) |
| SEL-032 | profile | Seller Profile (Screen) | Presentation for seller profile. | Account tab; Construction source: [seller_shell.dart:48](../../apps/seller/lib/screens/shell/seller_shell.dart) | [SellerProfileScreen:56](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) |
| SEL-033 | reviews | Seller Reviews (Screen) | Customer reviews and merchant reply. | Construction source: [seller_profile_screen.dart:397](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [SellerReviewsScreen:17](../../apps/seller/lib/screens/reviews/reviews_screen.dart) |
| SEL-034 | rfq | Seller Quote Detail (Screen) | Merchant quote-request detail. | Construction source: [notifications_screen.dart:113](../../apps/seller/lib/screens/notifications/notifications_screen.dart) | [SellerRfqDetailScreen:17](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart) |
| SEL-035 | rfq | Seller Quote Inbox (Screen) | Merchant quote inbox. | Construction source: [dashboard_screen.dart:262](../../apps/seller/lib/screens/home/dashboard_screen.dart) | [SellerRfqInboxScreen:15](../../apps/seller/lib/screens/rfq/seller_rfq_inbox_screen.dart) |
| SEL-036 | search | Seller Search (Screen) | Merchant cross-record search. | Construction source: [dashboard_screen.dart:360](../../apps/seller/lib/screens/home/dashboard_screen.dart) | [SellerSearchScreen:18](../../apps/seller/lib/screens/search/search_screen.dart) |
| SEL-037 | storefront | Storefront Editor (Screen) | Public storefront editing. | Construction source: [seller_profile_screen.dart:348](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | [StorefrontEditorScreen:23](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) |
| SEL-038 | storefront | Storefront Preview (Screen) | Synthetic preview of the current storefront draft. | Construction source: [storefront_editor_screen.dart:172](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) | [StorefrontPreviewScreen:319](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) |

#### Nested journeys and screen modes

| Parent | View or mode | Relationship | Source |
| --- | --- | --- | --- |
| ApplicationScreen | Business information | Five separate step widgets mounted by one application host. | [application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| ApplicationScreen | Store location | Five separate step widgets mounted by one application host. | [application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| ApplicationScreen | Documents | Five separate step widgets mounted by one application host. | [application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| ApplicationScreen | Payout information | Five separate step widgets mounted by one application host. | [application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| ApplicationScreen | Review and submit | Five separate step widgets mounted by one application host. | [application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| AddProductScreen | Create product | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AddProductScreen | Edit product | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AddProductScreen | Pack options subpage | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AddProductScreen | Pricing and tax subpage | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AddProductScreen | Delivery coverage subpage | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AddProductScreen | Wholesale subpage | Create/edit share the main widget; four private _EditorSubscreen route instances. | [add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| AccountRestrictedScreen | Rejected application | RestrictionReason variants of one screen. | [account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart) |
| AccountRestrictedScreen | Suspended account | RestrictionReason variants of one screen. | [account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart) |
| PayoutAccountScreen | Add payout destination | changing constructor flag controls mode. | [wallet.dart](../../apps/seller/lib/screens/payments/wallet.dart) |
| PayoutAccountScreen | Change payout destination | changing constructor flag controls mode. | [wallet.dart](../../apps/seller/lib/screens/payments/wallet.dart) |

#### Named dialogs and sheets

| No | Presentation | Source class | Definition |
| --- | --- | --- | --- |
| 1 | Store Status Sheet | _StoreStatusSheet | [store_status.dart:47](../../apps/seller/lib/screens/account/store_status.dart) |
| 2 | Order Reason Sheet | _OrderReasonSheet | [order_reason_sheet.dart:51](../../apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart) |
| 3 | Stock Sheet | _StockSheet | [seller_products_screen.dart:391](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| 4 | Variant Sheet | _VariantSheet | [product_variants_section.dart:87](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart) |
| 5 | Business Details Sheet | BusinessDetailsSheet | [business_details_sheet.dart:82](../../apps/seller/lib/screens/profile/business_details_sheet.dart) |
| 6 | Reply Sheet | _ReplySheet | [reviews_screen.dart:242](../../apps/seller/lib/screens/reviews/reviews_screen.dart) |
| 7 | Quote Counter Sheet | QuoteCounterSheet | [quote_counter_sheet.dart:32](../../apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart) |
| 8 | Quote Decline Sheet | QuoteDeclineSheet | [quote_decline_sheet.dart:19](../../apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart) |

#### Modal presentation call sites

Raw Flutter presentation APIs and known Agrimore helpers are listed individually. A method label is a lexical enclosing-method candidate, not a reviewed user-facing title. Helper definitions are excluded, while calls inside shared/local helper implementations can appear. Not all popup menus, OS permission prompts or third-party plugin UIs are modelled by this list.

| No | Presentation API | Context candidate | Named widget candidates | Source |
| --- | --- | --- | --- | --- |
| 1 | showDialog | final | Inline or helper content | [seller_feedback.dart:82](../../apps/seller/lib/design_system/components/seller_feedback.dart) |
| 2 | sellerConfirm | sellerConfirmDiscard | Inline or helper content | [seller_feedback.dart:167](../../apps/seller/lib/design_system/components/seller_feedback.dart) |
| 3 | sellerConfirmDiscard | build | Inline or helper content | [seller_feedback.dart:192](../../apps/seller/lib/design_system/components/seller_feedback.dart) |
| 4 | showModalBottomSheet | build | Inline or helper content | [seller_feedback.dart:210](../../apps/seller/lib/design_system/components/seller_feedback.dart) |
| 5 | showModalBottomSheet | fromSeller | _StoreStatusSheet | [store_status.dart:39](../../apps/seller/lib/screens/account/store_status.dart) |
| 6 | showSellerSheet | setState | Inline or helper content | [email_sign_in_screen.dart:54](../../apps/seller/lib/screens/auth/email_sign_in_screen.dart) |
| 7 | showSellerSheet | _explain | Inline or helper content | [insights_screen.dart:79](../../apps/seller/lib/screens/insights/insights_screen.dart) |
| 8 | sellerConfirm | tertiary | Inline or helper content | [step_footer.dart:51](../../apps/seller/lib/screens/onboarding/widgets/step_footer.dart) |
| 9 | showModalBottomSheet | orderReasonLabel | _OrderReasonSheet | [order_reason_sheet.dart:43](../../apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart) |
| 10 | sellerConfirm | _withdraw | Inline or helper content | [wallet.dart:294](../../apps/seller/lib/screens/payments/wallet.dart) |
| 11 | sellerConfirm | _cancel | Inline or helper content | [wallet.dart:308](../../apps/seller/lib/screens/payments/wallet.dart) |
| 12 | sellerConfirm | _delete | Inline or helper content | [followers_screen.dart:136](../../apps/seller/lib/screens/posts/followers_screen.dart) |
| 13 | showModalBottomSheet | catch | _StockSheet | [seller_products_screen.dart:112](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| 14 | sellerConfirm | _delete | Inline or helper content | [seller_products_screen.dart:129](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| 15 | showSellerSheet | _sortMenu | Inline or helper content | [seller_products_screen.dart:160](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| 16 | showModalBottomSheet | _edit | _VariantSheet | [product_variants_section.dart:20](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart) |
| 17 | sellerConfirm | _confirmDisconnect | Inline or helper content | [seller_ai_integration_screen.dart:360](../../apps/seller/lib/screens/profile/seller_ai_integration_screen.dart) |
| 18 | showSellerSheet | _infoSheet | Inline or helper content | [seller_profile_screen.dart:211](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) |
| 19 | sellerConfirm | _signOut | Inline or helper content | [seller_profile_screen.dart:223](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) |
| 20 | showModalBottomSheet | _reply | _ReplySheet | [reviews_screen.dart:52](../../apps/seller/lib/screens/reviews/reviews_screen.dart) |
| 21 | sellerConfirm | _accept | Inline or helper content | [seller_rfq_detail_screen.dart:66](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart) |
| 22 | showModalBottomSheet | showQuoteCounterSheet | QuoteCounterSheet | [quote_counter_sheet.dart:24](../../apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart) |
| 23 | showModalBottomSheet | showQuoteDeclineSheet | QuoteDeclineSheet | [quote_decline_sheet.dart:11](../../apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart) |

### Delivery

**Identity:** Black and white; burgundy and burnt orange.

| ID | Area | Screen or shell | Purpose | Entry source | Definition |
| --- | --- | --- | --- | --- | --- |
| DEL-001 | app | Delivery Shell (Application shell) | Five-tab rider shell: Home, Deliveries, Earnings, Inbox, Profile. | Construction source: [app.dart:127](../../apps/delivery/lib/app/app.dart) | [DeliveryShell:28](../../apps/delivery/lib/app/delivery_shell.dart) |
| DEL-002 | safety | Incident Status (Screen) | Rider incident status. | Construction source: [emergency_sheet.dart:184](../../apps/delivery/lib/safety/emergency_sheet.dart) | [IncidentStatusScreen:56](../../apps/delivery/lib/safety/incident_status_screen.dart) |
| DEL-003 | safety | My Incidents (Screen) | Rider incident list. | Construction source: [rider_profile_screen.dart:706](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | [MyIncidentsScreen:105](../../apps/delivery/lib/safety/incident_status_screen.dart) |
| DEL-004 | auth | Login (Screen) | Rider sign-in presentation. | Construction source: [app.dart:134](../../apps/delivery/lib/app/app.dart) | [LoginScreen:17](../../apps/delivery/lib/screens/auth/login_screen.dart) |
| DEL-005 | auth | Pending rejected suspended or deactivated account (Screen) | Presentation for pending rejected suspended or deactivated account. | Construction source: [app.dart:130](../../apps/delivery/lib/app/app.dart) | [DeliveryPendingApprovalScreen:54](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| DEL-006 | auth | Rider Registration (Screen) | Five-stage rider account and application form. | Construction source: [app.dart:132](../../apps/delivery/lib/app/app.dart) | [RiderRegistrationScreen:74](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| DEL-007 | history | Delivery history (Screen) | Presentation for delivery history. | Deliveries tab; Construction source: [delivery_shell.dart:102](../../apps/delivery/lib/app/delivery_shell.dart) | [RiderHistoryScreen:46](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| DEL-008 | home | Dashboard (Screen) | Rider home, duty/map/current-work presentation. | Home tab; Construction source: [delivery_shell.dart:95](../../apps/delivery/lib/app/delivery_shell.dart) | [DashboardScreen:43](../../apps/delivery/lib/screens/home/dashboard_screen.dart) |
| DEL-009 | inbox | Inbox (Screen) | Rider notification inbox and destination handling. | Inbox tab; Construction source: [delivery_shell.dart:104](../../apps/delivery/lib/app/delivery_shell.dart) | [InboxScreen:117](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) |
| DEL-010 | money | Bank Change Request (Screen) | Rider payout-account change request status. | Construction source: [inbox_screen.dart:237](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | [BankChangeRequestScreen:16](../../apps/delivery/lib/screens/money/bank_change_request_screen.dart) |
| DEL-011 | money | Earnings and payouts (Screen) | Presentation for earnings and payouts. | Earnings tab; Construction source: [delivery_shell.dart:103](../../apps/delivery/lib/app/delivery_shell.dart) | [MoneyScreen:23](../../apps/delivery/lib/screens/money/money_screen.dart) |
| DEL-012 | money | Statement (Screen) | Statement detail for the supplied statement context. | Construction source: [rider_history_screen.dart:791](../../apps/delivery/lib/screens/history/rider_history_screen.dart) | [StatementScreen:31](../../apps/delivery/lib/screens/money/statement_screen.dart) |
| DEL-013 | offers | Incoming Offer (Screen) | Incoming dispatch offer and response presentation. | Construction source: [offer_coordinator.dart:82](../../apps/delivery/lib/offers/offer_coordinator.dart) | [IncomingOfferScreen:27](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart) |
| DEL-014 | orders | Active Order (Screen) | Active delivery task, route, verification/proof, payment context and recovery. | Construction source: [rider_history_screen.dart:112](../../apps/delivery/lib/screens/history/rider_history_screen.dart) | [ActiveOrderScreen:194](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| DEL-015 | profile | Document Submission (Screen) | Rider document submission and review states. | Construction source: [inbox_screen.dart:291](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | [DocumentSubmissionScreen:31](../../apps/delivery/lib/screens/profile/document_submission_screen.dart) |
| DEL-016 | profile | Identity Change (Screen) | Rider identity-change presentation. | Construction source: [inbox_screen.dart:252](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | [IdentityChangeScreen:44](../../apps/delivery/lib/screens/profile/identity_change_screen.dart) |
| DEL-017 | profile | Rider Profile (Screen) | Rider account, documents and support actions. | Profile tab; Construction source: [delivery_shell.dart:109](../../apps/delivery/lib/app/delivery_shell.dart) | [RiderProfileScreen:68](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| DEL-018 | settings | Device Readiness (Screen) | Location, notification and device-readiness checks. | Construction source: [rider_profile_screen.dart:658](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | [DeviceReadinessScreen:20](../../apps/delivery/lib/screens/settings/device_readiness_screen.dart) |
| DEL-019 | support | Help Support (Screen) | App-domain help and support presentation. | Construction source: [rider_profile_screen.dart:674](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | [HelpSupportScreen:29](../../apps/delivery/lib/screens/support/help_support_screen.dart) |
| DEL-020 | support | My Support Requests (Screen) | Rider support-request list. | Construction source: [rider_profile_screen.dart:691](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | [MySupportRequestsScreen:16](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart) |
| DEL-021 | support | Submit Support Request (Screen) | Submit a rider support request. | Construction source: [help_sheet.dart:41](../../apps/delivery/lib/screens/support/help_sheet.dart) | [SubmitSupportRequestScreen:18](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart) |
| DEL-022 | support | Support Request Status (Screen) | Support-request status and outcome presentation. | Construction source: [inbox_screen.dart:226](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | [SupportRequestStatusScreen:27](../../apps/delivery/lib/screens/support/support_request_status_screen.dart) |

#### Nested journeys and screen modes

| Parent | View or mode | Relationship | Source |
| --- | --- | --- | --- |
| RiderRegistrationScreen | Account | Five form steps; an existing account may skip its account step. | [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| RiderRegistrationScreen | About rider | Five form steps; an existing account may skip its account step. | [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| RiderRegistrationScreen | Vehicle | Five form steps; an existing account may skip its account step. | [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| RiderRegistrationScreen | Documents | Five form steps; an existing account may skip its account step. | [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| RiderRegistrationScreen | Payout | Five form steps; an existing account may skip its account step. | [rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| DeliveryPendingApprovalScreen | Pending review | One account-status widget; allowed recovery depends on status. | [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| DeliveryPendingApprovalScreen | Rejected | One account-status widget; allowed recovery depends on status. | [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| DeliveryPendingApprovalScreen | Suspended | One account-status widget; allowed recovery depends on status. | [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| DeliveryPendingApprovalScreen | Deactivated | One account-status widget; allowed recovery depends on status. | [pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| DocumentSubmissionScreen | Submission form and review states | Conditional states of one document presentation. | [document_submission_screen.dart](../../apps/delivery/lib/screens/profile/document_submission_screen.dart) |

#### Named dialogs and sheets

| No | Presentation | Source class | Definition |
| --- | --- | --- | --- |
| 1 | Navigation Failed Sheet | NavigationFailedSheet | [navigation_launch.dart:92](../../apps/delivery/lib/navigation/navigation_launch.dart) |
| 2 | Emergency Sheet | EmergencySheet | [emergency_sheet.dart:64](../../apps/delivery/lib/safety/emergency_sheet.dart) |
| 3 | History Filter Sheet | HistoryFilterSheet | [history_filter_sheet.dart:43](../../apps/delivery/lib/screens/history/history_filter_sheet.dart) |
| 4 | Verify Sheet | _VerifySheet | [active_order_screen.dart:1130](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 5 | Help Sheet | _HelpSheet | [active_order_screen.dart:1289](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 6 | Problem Report Sheet | ProblemReportSheet | [delivery_problem_panel.dart:197](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) |
| 7 | Contact Edit Sheet | ContactEditSheet | [rider_profile_screen.dart:851](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 8 | Document Preview Dialog | _DocumentPreviewDialog | [rider_profile_screen.dart:1169](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 9 | Help Sheet | HelpSheet | [help_sheet.dart:34](../../apps/delivery/lib/screens/support/help_sheet.dart) |

#### Modal presentation call sites

Raw Flutter presentation APIs and known Agrimore helpers are listed individually. A method label is a lexical enclosing-method candidate, not a reviewed user-facing title. Helper definitions are excluded, while calls inside shared/local helper implementations can appear. Not all popup menus, OS permission prompts or third-party plugin UIs are modelled by this list.

| No | Presentation API | Context candidate | Named widget candidates | Source |
| --- | --- | --- | --- | --- |
| 1 | showModalBottomSheet | build | Inline or helper content | [delivery_feedback.dart:196](../../apps/delivery/lib/design_system/components/delivery_feedback.dart) |
| 2 | showDialog | RoundedRectangleBorder | AlertDialog | [delivery_feedback.dart:274](../../apps/delivery/lib/design_system/components/delivery_feedback.dart) |
| 3 | showDialog | RoundedRectangleBorder | AlertDialog | [delivery_feedback.dart:339](../../apps/delivery/lib/design_system/components/delivery_feedback.dart) |
| 4 | showDeliveryDisclosureDialog | ensureLocationDisclosure | Inline or helper content | [location_disclosure.dart:35](../../apps/delivery/lib/location/location_disclosure.dart) |
| 5 | showDeliveryDisclosureDialog | ensureBackgroundLocation | Inline or helper content | [location_disclosure.dart:98](../../apps/delivery/lib/location/location_disclosure.dart) |
| 6 | showDeliveryConfirmDialog | catch | Inline or helper content | [location_disclosure.dart:157](../../apps/delivery/lib/location/location_disclosure.dart) |
| 7 | showModalBottomSheet | _showNavigationFailedSheet | NavigationFailedSheet | [navigation_launch.dart:81](../../apps/delivery/lib/navigation/navigation_launch.dart) |
| 8 | showModalBottomSheet | dialUri | EmergencySheet | [emergency_sheet.dart:47](../../apps/delivery/lib/safety/emergency_sheet.dart) |
| 9 | showModalBottomSheet | _forgotPassword | Inline or helper content | [login_screen.dart:50](../../apps/delivery/lib/screens/auth/login_screen.dart) |
| 10 | showDeliveryConfirmDialog | _delete | Inline or helper content | [pending_approval_screen.dart:116](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) |
| 11 | showDeliveryConfirmDialog | if | Inline or helper content | [rider_registration_screen.dart:226](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| 12 | showDeliveryConfirmDialog | _confirmStartOver | Inline or helper content | [rider_registration_screen.dart:333](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) |
| 13 | showModalBottomSheet | showHistoryFilterSheet | HistoryFilterSheet | [history_filter_sheet.dart:35](../../apps/delivery/lib/screens/history/history_filter_sheet.dart) |
| 14 | showModalBottomSheet | _openDetail | Inline or helper content | [rider_history_screen.dart:97](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| 15 | showDeliveryConfirmDialog | if | Inline or helper content | [dashboard_screen.dart:591](../../apps/delivery/lib/screens/home/dashboard_screen.dart) |
| 16 | showModalBottomSheet | _correct | Inline or helper content | [bank_change_request_screen.dart:41](../../apps/delivery/lib/screens/money/bank_change_request_screen.dart) |
| 17 | showModalBottomSheet | _openChangeForm | Inline or helper content | [money_screen.dart:159](../../apps/delivery/lib/screens/money/money_screen.dart) |
| 18 | showDeliveryConfirmDialog | _confirmFarTap | Inline or helper content | [active_order_screen.dart:862](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 19 | showDeliveryConfirmDialog | _confirmSellerNotReady | Inline or helper content | [active_order_screen.dart:874](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 20 | showModalBottomSheet | _showHelp | _HelpSheet, ProblemReportSheet | [active_order_screen.dart:909](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 21 | showModalBottomSheet | _HelpSheet | ProblemReportSheet | [active_order_screen.dart:917](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 22 | showModalBottomSheet | _showVerificationSheet | _VerifySheet | [active_order_screen.dart:936](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 23 | showModalBottomSheet | _showDelivered | Inline or helper content | [active_order_screen.dart:1033](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| 24 | showModalBottomSheet | _report | ProblemReportSheet | [delivery_problem_panel.dart:85](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) |
| 25 | showModalBottomSheet | _editContact | ContactEditSheet | [rider_profile_screen.dart:205](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 26 | showDeliveryConfirmDialog | _signOut | Inline or helper content | [rider_profile_screen.dart:225](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 27 | showDeliveryConfirmDialog | if | Inline or helper content | [rider_profile_screen.dart:256](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 28 | showDeliveryConfirmDialog | if | Inline or helper content | [rider_profile_screen.dart:274](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 29 | showDeliveryConfirmDialog | if | Inline or helper content | [rider_profile_screen.dart:292](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 30 | showDialog | if | _DocumentPreviewDialog | [rider_profile_screen.dart:1041](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| 31 | showModalBottomSheet | showHelpSheet | HelpSheet | [help_sheet.dart:25](../../apps/delivery/lib/screens/support/help_sheet.dart) |

### Sales Associate

**Identity:** Premium royal blue; indigo and pearl/slate.

| ID | Area | Screen or shell | Purpose | Entry source | Definition |
| --- | --- | --- | --- | --- | --- |
| SSA-001 | shell | Sales Associate shell (Application shell) | Four-tab associate shell: Home, Orders, Wallet, Profile. | Construction source: [app.dart:61](../../apps/employee/lib/app/app.dart) | [EmployeeShellScreen:42](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) |
| SSA-002 | auth | Associate OTP (Screen) | Associate mobile-number verification. | Construction source: [login_screen.dart:389](../../apps/employee/lib/screens/auth/login_screen.dart) | [AssociateOtpScreen:23](../../apps/employee/lib/screens/auth/associate_otp_screen.dart) |
| SSA-003 | auth | Forgot Password (Screen) | Associate password-reset request. | Construction source: [login_screen.dart:471](../../apps/employee/lib/screens/auth/login_screen.dart) | [ForgotPasswordScreen:9](../../apps/employee/lib/screens/auth/forgot_password_screen.dart) |
| SSA-004 | auth | Login (Screen) | Associate sign-in entry and authentication states. | Construction source: [app.dart:83](../../apps/employee/lib/app/app.dart) | [LoginScreen:32](../../apps/employee/lib/screens/auth/login_screen.dart) |
| SSA-005 | auth | Pending associate approval (Screen) | Presentation for pending associate approval. | Construction source: [app.dart:77](../../apps/employee/lib/app/app.dart) | [EmployeePendingApprovalScreen:8](../../apps/employee/lib/screens/auth/pending_approval_screen.dart) |
| SSA-006 | auth | Suspended (Screen) | Associate suspension state. | Construction source: [app.dart:70](../../apps/employee/lib/app/app.dart) | [SuspendedScreen:11](../../apps/employee/lib/screens/auth/suspended_screen.dart) |
| SSA-007 | home | Dashboard (Screen) | Associate sales and attribution dashboard. | Home tab; Construction source: [employee_shell_screen.dart:59](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | [DashboardScreen:20](../../apps/employee/lib/screens/home/dashboard_screen.dart) |
| SSA-008 | notifications | Notifications (Screen) | Presentation for notifications. | Construction source: [dashboard_screen.dart:413](../../apps/employee/lib/screens/home/dashboard_screen.dart) | [NotificationsScreen:11](../../apps/employee/lib/screens/notifications/notifications_screen.dart) |
| SSA-009 | orders | Order Detail (Screen) | Attributed-order detail. | Construction source: [dashboard_screen.dart:282](../../apps/employee/lib/screens/home/dashboard_screen.dart) | [OrderDetailScreen:10](../../apps/employee/lib/screens/orders/order_detail_screen.dart) |
| SSA-010 | orders | Attributed orders (Screen) | Presentation for attributed orders. | Orders tab; Construction source: [employee_shell_screen.dart:60](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | [OrdersScreen:15](../../apps/employee/lib/screens/orders/orders_screen.dart) |
| SSA-011 | profile | Onboarding Status (Screen) | Associate onboarding and activation information. | Construction source: [dashboard_screen.dart:778](../../apps/employee/lib/screens/home/dashboard_screen.dart) | [OnboardingStatusScreen:10](../../apps/employee/lib/screens/profile/onboarding_status_screen.dart) |
| SSA-012 | profile | Profile (Screen) | Presentation for profile. | Profile tab; Construction source: [employee_shell_screen.dart:62](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | [ProfileScreen:22](../../apps/employee/lib/screens/profile/profile_screen.dart) |
| SSA-013 | support | Help Support (Screen) | App-domain help and support presentation. | Construction source: [pending_approval_screen.dart:117](../../apps/employee/lib/screens/auth/pending_approval_screen.dart) | [HelpSupportScreen:9](../../apps/employee/lib/screens/support/help_support_screen.dart) |
| SSA-014 | wallet | Payout Account (Screen) | Payout destination form or account presentation. | Construction source: [profile_screen.dart:374](../../apps/employee/lib/screens/profile/profile_screen.dart) | [PayoutAccountScreen:40](../../apps/employee/lib/screens/wallet/payout_account_screen.dart) |
| SSA-015 | wallet | Payout Details (Screen) | Individual associate payout result/detail. | Construction source: [payout_history_screen.dart:273](../../apps/employee/lib/screens/wallet/payout_history_screen.dart) | [PayoutDetailsScreen:11](../../apps/employee/lib/screens/wallet/payout_details_screen.dart) |
| SSA-016 | wallet | Payout History (Screen) | Associate payout history. | Construction source: [wallet_screen.dart:230](../../apps/employee/lib/screens/wallet/wallet_screen.dart) | [PayoutHistoryScreen:14](../../apps/employee/lib/screens/wallet/payout_history_screen.dart) |
| SSA-017 | wallet | Payout Request (Screen) | Associate payout amount and account prerequisites. | Construction source: [wallet_screen.dart:215](../../apps/employee/lib/screens/wallet/wallet_screen.dart) | [PayoutRequestScreen:14](../../apps/employee/lib/screens/wallet/payout_request_screen.dart) |
| SSA-018 | wallet | Payout Review (Screen) | Review and submit an associate payout request. | Construction source: [payout_request_screen.dart:300](../../apps/employee/lib/screens/wallet/payout_request_screen.dart) | [PayoutReviewScreen:13](../../apps/employee/lib/screens/wallet/payout_review_screen.dart) |
| SSA-019 | wallet | Commission wallet (Screen) | Presentation for commission wallet. | Wallet tab; Construction source: [employee_shell_screen.dart:61](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | [WalletScreen:19](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |

#### Nested journeys and screen modes

| Parent | View or mode | Relationship | Source |
| --- | --- | --- | --- |
| Auth gate | Signed out | Gate returns the already-listed screen/shell; not additional screens. | [app.dart](../../apps/employee/lib/app/app.dart) |
| Auth gate | Pending approval | Gate returns the already-listed screen/shell; not additional screens. | [app.dart](../../apps/employee/lib/app/app.dart) |
| Auth gate | Suspended | Gate returns the already-listed screen/shell; not additional screens. | [app.dart](../../apps/employee/lib/app/app.dart) |
| Auth gate | Approved workspace | Gate returns the already-listed screen/shell; not additional screens. | [app.dart](../../apps/employee/lib/app/app.dart) |
| Payout journey | Account setup | Five separate screen widgets already counted in the main screen table. | [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Payout journey | Amount request | Five separate screen widgets already counted in the main screen table. | [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Payout journey | Review | Five separate screen widgets already counted in the main screen table. | [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Payout journey | Payout detail | Five separate screen widgets already counted in the main screen table. | [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Payout journey | Payout history | Five separate screen widgets already counted in the main screen table. | [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Developer catalogue | Brand and Tokens | Standalone developer tooling; not production tabs. | [catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| Developer catalogue | Typography | Standalone developer tooling; not production tabs. | [catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| Developer catalogue | Icons | Standalone developer tooling; not production tabs. | [catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| Developer catalogue | Components | Standalone developer tooling; not production tabs. | [catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| Developer catalogue | Content and Privacy | Standalone developer tooling; not production tabs. | [catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) |

#### Named dialogs and sheets

No dedicated *Dialog/*Sheet widget-class declaration was located in the app source. This does not mean there are no dialogs: shared-helper and inline call sites are indexed below.

#### Modal presentation call sites

Raw Flutter presentation APIs and known Agrimore helpers are listed individually. A method label is a lexical enclosing-method candidate, not a reviewed user-facing title. Helper definitions are excluded, while calls inside shared/local helper implementations can appear. Not all popup menus, OS permission prompts or third-party plugin UIs are modelled by this list.

| No | Presentation API | Context candidate | Named widget candidates | Source |
| --- | --- | --- | --- | --- |
| 1 | DialogHelper.showConfirmation | SaLoadingButton | Inline or helper content | [profile_screen.dart:569](../../apps/employee/lib/screens/profile/profile_screen.dart) |

### Admin

**Identity:** Professional blue; cyan and steel/slate.

| ID | Area | Screen or shell | Purpose | Entry source | Definition |
| --- | --- | --- | --- | --- | --- |
| ADM-001 | admin | Admin Shell (Application shell) | Sidebar/header host for administrative child routes. | Construction source: [app_router.dart:331](../../apps/admin/lib/app/app_router.dart) | [AdminShell:13](../../apps/admin/lib/screens/admin/admin_shell.dart) |
| ADM-002 | admin | Admin Dashboard (Screen) | Administrative operational summary. | Route source: /dashboard | [AdminDashboard:19](../../apps/admin/lib/screens/admin/admin_dashboard.dart) |
| ADM-003 | admin / analytics | Analytics (Screen) | Administrative analytics. | Route source: /analytics | [AnalyticsScreen:6](../../apps/admin/lib/screens/admin/analytics/analytics_screen.dart) |
| ADM-004 | admin / banners | Banner Management (Screen) | Home/banner administration. | Route source: /banners | [BannerManagementScreen:13](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) |
| ADM-005 | admin / benefit_program | Compliance Control (Screen) | Benefit-program compliance controls and audit presentation. | Route source: /benefit-program/compliance | [ComplianceControlScreen:44](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) |
| ADM-006 | admin / benefit_program | Feature Flags (Screen) | Benefit-program feature controls. | Route source: /benefit-program/feature-flags | [FeatureFlagsScreen:89](../../apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart) |
| ADM-007 | admin / bestsellers | Bestseller Management (Screen) | Bestseller slot management. | Route source: /bestsellers | [BestsellerManagementScreen:9](../../apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart) |
| ADM-008 | admin / category_sections | Category Section Management (Screen) | Category-section list. | Route source: /sections | [CategorySectionManagementScreen:13](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| ADM-009 | admin / category_sections | Edit Category Section (Screen) | Create/edit category-section composition. | Route source: /sections/new, /sections/:id/edit | [EditCategorySectionScreen:11](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) |
| ADM-010 | admin / coupon | Coupon Management (Screen) | Coupon administration. | Route source: /coupons | [CouponManagementScreen:11](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) |
| ADM-011 | admin / delivery | Delivery Partner Management (Screen) | Delivery-partner list and account administration. | Route source: /delivery-partners | [DeliveryPartnerManagementScreen:38](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) |
| ADM-012 | admin / delivery | Delivery Problems (Screen) | Delivery-problem queue. | Route source: /delivery-problems | [DeliveryProblemsScreen:17](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) |
| ADM-013 | admin / delivery | Dispatch Queue (Screen) | Dispatch assignment queue. | Route source: /delivery-dispatch | [DispatchQueueScreen:20](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) |
| ADM-014 | admin / delivery | Dispatch Detail (Screen) | Single dispatch/order review. | Construction source: [dispatch_queue_screen.dart:240](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) | [DispatchDetailScreen:320](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) |
| ADM-015 | admin / delivery | Order Assignment (Screen) | Manual delivery assignment and reassignment. | Construction source: [dispatch_queue_screen.dart:538](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) | [OrderAssignmentScreen:20](../../apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart) |
| ADM-016 | admin / delivery | Rider Cash Ledger (Screen) | Individual rider cash ledger. | Construction source: [rider_detail_screen.dart:618](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) | [RiderCashLedgerScreen:14](../../apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart) |
| ADM-017 | admin / delivery | Rider Detail (Screen) | Delivery-partner profile and operational detail. | Route source: /delivery-partners/:id | [RiderDetailScreen:36](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| ADM-018 | admin / delivery | Rider Incidents (Screen) | Administrative rider-incident review. | Route source: /rider-incidents | [RiderIncidentsScreen:16](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) |
| ADM-019 | admin / delivery | Rider Payouts (Screen) | Administrative rider-payout review. | Route source: /rider-payouts | [RiderPayoutsScreen:22](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| ADM-020 | admin / delivery | Rider Support (Screen) | Administrative rider-support review. | Route source: /rider-support | [RiderSupportScreen:30](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) |
| ADM-021 | admin / employees | Add Sales Associate (Screen) | Presentation for add sales associate. | Route source: /add-employee | [AddEmployeeScreen:5](../../apps/admin/lib/screens/admin/employees/add_employee_screen.dart) |
| ADM-022 | admin / employees | Associate Detail (Screen) | Associate profile and account review. | Route source: /employees/:id | [AssociateDetailScreen:36](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| ADM-023 | admin / employees | Commission Exceptions (Screen) | Commission exceptions and review. | Route source: /commission-exceptions | [CommissionExceptionsScreen:20](../../apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart) |
| ADM-024 | admin / employees | Sales Associate management (Screen) | Presentation for sales associate management. | Route source: /employees | [EmployeeManagementScreen:12](../../apps/admin/lib/screens/admin/employees/employee_management_screen.dart) |
| ADM-025 | admin / employees | Associate payout account review (Screen) | Presentation for associate payout account review. | Route source: /employee-payout-account-review | [EmployeePayoutAccountReviewScreen:86](../../apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart) |
| ADM-026 | admin / employees | Associate payout detail (Screen) | Presentation for associate payout detail. | Route source: /employee-payouts/:id | [EmployeePayoutDetailScreen:25](../../apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart) |
| ADM-027 | admin / employees | Associate payout requests (Screen) | Presentation for associate payout requests. | Route source: /employee-payouts | [EmployeePayoutsScreen:26](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) |
| ADM-028 | admin / finance | Finance Reconciliation (Screen) | Financial reconciliation findings. | Route source: /finance/reconciliation | [FinanceReconciliationScreen:60](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart) |
| ADM-029 | admin / finance | Financial Record Detail (Screen) | Source financial record and associated finding context. | Route source: /finance/records/:type/:id | [FinancialRecordDetailScreen:19](../../apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart) |
| ADM-030 | admin / home_sections | Home Product Section Management (Screen) | Home-page product-section administration. | Construction source: [admin_settings_screen.dart:216](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [HomeProductSectionManagementScreen:13](../../apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart) |
| ADM-031 | admin / notifications | Send Notification (Screen) | Administrative notification composer. | Route source: /notifications | [SendNotificationScreen:12](../../apps/admin/lib/screens/admin/notifications/send_notification_screen.dart) |
| ADM-032 | admin / orders | Admin Order Details (Screen) | Administrative order detail and operational actions. | Construction source: [rider_detail_screen.dart:511](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) | [AdminOrderDetailsScreen:128](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart) |
| ADM-033 | admin / orders | Order Management (Screen) | Administrative order list, search, filters and selection. | Route source: /orders | [OrderManagementScreen:61](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart) |
| ADM-034 | admin / products | Category Management (Screen) | Product category management. | Construction source: [product_management_screen.dart:282](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) | [CategoryManagementScreen:17](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) |
| ADM-035 | admin / products | Product Form (Screen) | Create or edit product administration form. | Route source: /products/new, /products/:id/edit | [ProductFormScreen:19](../../apps/admin/lib/screens/admin/products/product_form_screen.dart) |
| ADM-036 | admin / products | Product Management (Screen) | Administrative product catalogue. | Route source: /products | [ProductManagementScreen:13](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) |
| ADM-037 | admin / products | Seller Product Approval (Screen) | Merchant-product approval queue. | Construction source: [admin_dashboard.dart:745](../../apps/admin/lib/screens/admin/admin_dashboard.dart) | [SellerProductApprovalScreen:7](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart) |
| ADM-038 | admin / reviews | Review Management (Screen) | Customer review administration. | Route source: /reviews | [ReviewManagementScreen:6](../../apps/admin/lib/screens/admin/reviews/review_management_screen.dart) |
| ADM-039 | admin / rewards | Rewards Management (Screen) | Rewards administration. | Route source: /rewards | [RewardsManagementScreen:6](../../apps/admin/lib/screens/admin/rewards/rewards_management_screen.dart) |
| ADM-040 | admin / section_banners | Section Banner Management (Screen) | Section-banner administration. | Route source: /section-banners | [SectionBannerManagementScreen:10](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) |
| ADM-041 | admin / security | Payment Security Logs (Screen) | Payment-security event logs. | Construction source: [admin_settings_screen.dart:330](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [PaymentSecurityLogsScreen:12](../../apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart) |
| ADM-042 | admin / security | Verified Payment Lookup (Screen) | Verified-payment record lookup. | Construction source: [admin_settings_screen.dart:344](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [VerifiedPaymentLookupScreen:14](../../apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart) |
| ADM-043 | admin / sellers | Add Seller (Screen) | Create a merchant account. | Route source: /add-seller | [AddSellerScreen:5](../../apps/admin/lib/screens/admin/sellers/add_seller_screen.dart) |
| ADM-044 | admin / sellers | Edit Seller (Screen) | Edit merchant profile and images. | Construction source: [seller_detail_screen.dart:102](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) | [EditSellerScreen:11](../../apps/admin/lib/screens/admin/sellers/edit_seller_screen.dart) |
| ADM-045 | admin / sellers | Manage Sellers (Screen) | Merchant account list. | Route source: /manage-sellers | [ManageSellersScreen:10](../../apps/admin/lib/screens/admin/sellers/manage_sellers_screen.dart) |
| ADM-046 | admin / sellers | Seller Detail (Screen) | Merchant account detail. | Route source: /sellers/:id | [SellerDetailScreen:29](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| ADM-047 | admin / sellers | Seller Payouts (Screen) | Merchant payout administration. | Route source: /seller-payouts | [SellerPayoutsScreen:15](../../apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart) |
| ADM-048 | admin / sellers | Seller Requests Management (Screen) | Merchant application/request queue. | Route source: /seller-requests | [SellerRequestsManagementScreen:9](../../apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart) |
| ADM-049 | admin / settings | Admin Settings (Screen) | Administrative configuration and linked tools. | Route source: /settings | [AdminSettingsScreen:66](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| ADM-050 | admin / settings | Delivery Time Slots Management (Screen) | Delivery-slot administration. | Route source: /delivery-time-slots | [DeliveryTimeSlotsManagementScreen:8](../../apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart) |
| ADM-051 | admin / settings | Home Grocery Strip Settings (Screen) | Grocery/kitchen home strip configuration. | Construction source: [admin_settings_screen.dart:230](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [HomeGroceryStripSettingsScreen:11](../../apps/admin/lib/screens/admin/settings/home_grocery_strip_settings_screen.dart) |
| ADM-052 | admin / settings | Home Section Order Settings (Screen) | Mobile/web home section ordering. | Construction source: [admin_settings_screen.dart:244](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [HomeSectionOrderSettingsScreen:20](../../apps/admin/lib/screens/admin/settings/home_section_order_settings_screen.dart) |
| ADM-053 | admin / settings | Location Settings (Screen) | Location and hyperlocal configuration. | Construction source: [admin_settings_screen.dart:202](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [LocationSettingsScreen:5](../../apps/admin/lib/screens/admin/settings/location_settings_screen.dart) |
| ADM-054 | admin / settings | Wallet Config (Screen) | Wallet feature and bonus configuration. | Construction source: [admin_settings_screen.dart:294](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | [WalletConfigScreen:8](../../apps/admin/lib/screens/admin/settings/wallet_config_screen.dart) |
| ADM-055 | admin / sponsored_banners | Sponsored Banner Management (Screen) | Sponsored-banner administration. | Route source: /sponsored | [SponsoredBannerManagementScreen:12](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) |
| ADM-056 | admin / subscriptions | Subscription Management (Screen) | Subscription administration. | Route source: /subscriptions | [SubscriptionManagementScreen:6](../../apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart) |
| ADM-057 | admin / support | Support Case Detail (Screen) | Case notes, activity, linked records and evidence. | Route source: /support/:id | [SupportCaseDetailScreen:35](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| ADM-058 | admin / support | Support Queue (Screen) | Support-case queue and case creation. | Route source: /support | [SupportQueueScreen:23](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) |
| ADM-059 | admin / users | Customer Detail (Screen) | Customer profile and account detail. | Route source: /users/:id | [CustomerDetailScreen:25](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| ADM-060 | admin / users | Edit User (Screen) | Customer/user editing form. | Construction source: [customer_detail_screen.dart:67](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) | [EditUserScreen:16](../../apps/admin/lib/screens/admin/users/edit_user_screen.dart) |
| ADM-061 | admin / users | User Management (Screen) | Administrative customer/user list. | Route source: /users | [UserManagementScreen:13](../../apps/admin/lib/screens/admin/users/user_management_screen.dart) |
| ADM-062 | admin / vendors | Vendors List (Screen) | Vendor administration. | Route source: /vendors | [VendorsListScreen:14](../../apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart) |
| ADM-063 | admin / wallet | Wallet Tracking (Screen) | Wallet top-up tracking. | Route source: /wallet-topups | [WalletTrackingScreen:6](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) |
| ADM-064 | auth | Auth (Screen) | Administrator authentication. | Route source: /auth | [AuthScreen:19](../../apps/admin/lib/screens/auth/auth_screen.dart) |

#### Nested journeys and screen modes

| Parent | View or mode | Relationship | Source |
| --- | --- | --- | --- |
| ProductFormScreen | Create product | Two route paths share one screen widget. | [app_router.dart](../../apps/admin/lib/app/app_router.dart) |
| ProductFormScreen | Edit product | Two route paths share one screen widget. | [app_router.dart](../../apps/admin/lib/app/app_router.dart) |
| EditCategorySectionScreen | Create category section | Both route builders currently supply section:null; existing-record editing requires context inspection. | [app_router.dart](../../apps/admin/lib/app/app_router.dart) |
| EditCategorySectionScreen | Edit category section | Both route builders currently supply section:null; existing-record editing requires context inspection. | [app_router.dart](../../apps/admin/lib/app/app_router.dart) |
| SupportCaseDetailScreen | Notes | Four embedded tabs in one case screen. | [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| SupportCaseDetailScreen | Activity | Four embedded tabs in one case screen. | [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| SupportCaseDetailScreen | Linked Records | Four embedded tabs in one case screen. | [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| SupportCaseDetailScreen | Evidence | Four embedded tabs in one case screen. | [support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |

#### Named dialogs and sheets

| No | Presentation | Source class | Definition |
| --- | --- | --- | --- |
| 1 | Add Edit Banner Dialog | AddEditBannerDialog | [add_edit_banner_dialog.dart:14](../../apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart) |
| 2 | Edit Bestseller Slot Dialog | EditBestsellerSlotDialog | [edit_bestseller_slot_dialog.dart:23](../../apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart) |
| 3 | Add Edit Coupon Dialog | AddEditCouponDialog | [add_edit_coupon_dialog.dart:11](../../apps/admin/lib/screens/admin/coupon/add_edit_coupon_dialog.dart) |
| 4 | Add Delivery Partner Dialog | AddDeliveryPartnerDialog | [add_delivery_partner_dialog.dart:9](../../apps/admin/lib/screens/admin/delivery/add_delivery_partner_dialog.dart) |
| 5 | Rider Review Sheet | RiderReviewSheet | [rider_review_sheet.dart:60](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) |
| 6 | Raise Financial Case Dialog | _RaiseFinancialCaseDialog | [financial_record_detail_screen.dart:401](../../apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart) |
| 7 | Add Edit Home Product Section Dialog | AddEditHomeProductSectionDialog | [add_edit_home_product_section_dialog.dart:10](../../apps/admin/lib/screens/admin/home_sections/add_edit_home_product_section_dialog.dart) |
| 8 | Category Form Dialog | _CategoryFormDialog | [category_management_screen.dart:1050](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) |
| 9 | Add Edit Section Banner Dialog | AddEditSectionBannerDialog | [add_edit_section_banner_dialog.dart:11](../../apps/admin/lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart) |
| 10 | Owned Password Dialog | _OwnedPasswordDialog | [admin_settings_screen.dart:1131](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 11 | Add Edit Sponsored Banner Dialog | AddEditSponsoredBannerDialog | [add_edit_sponsored_banner_dialog.dart:13](../../apps/admin/lib/screens/admin/sponsored_banners/add_edit_sponsored_banner_dialog.dart) |
| 12 | Pick Admin Dialog | _PickAdminDialog | [support_case_detail_screen.dart:563](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 13 | Change Status Dialog | _ChangeStatusDialog | [support_case_detail_screen.dart:648](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 14 | Add Link Dialog | _AddLinkDialog | [support_case_detail_screen.dart:835](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 15 | Create Case Dialog | _CreateCaseDialog | [support_queue_screen.dart:204](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) |
| 16 | Raise Order Case Dialog | _RaiseOrderCaseDialog | [actor_support_cases_section.dart:206](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| 17 | Raise Case Dialog | _RaiseCaseDialog | [actor_support_cases_section.dart:325](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| 18 | Create From Source Dialog | _CreateFromSourceDialog | [actor_support_cases_section.dart:473](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |

#### Modal presentation call sites

Raw Flutter presentation APIs and known Agrimore helpers are listed individually. A method label is a lexical enclosing-method candidate, not a reviewed user-facing title. Helper definitions are excluded, while calls inside shared/local helper implementations can appear. Not all popup menus, OS permission prompts or third-party plugin UIs are modelled by this list.

| No | Presentation API | Context candidate | Named widget candidates | Source |
| --- | --- | --- | --- | --- |
| 1 | showDialog | if | AlertDialog | [admin_shell.dart:876](../../apps/admin/lib/screens/admin/admin_shell.dart) |
| 2 | showDialog | _bulkDelete | AlertDialog | [banner_management_screen.dart:62](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) |
| 3 | showDialog | _navigateToAddBanner | AddEditBannerDialog | [banner_management_screen.dart:138](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) |
| 4 | showDialog | _navigateToEditBanner | AddEditBannerDialog | [banner_management_screen.dart:142](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) |
| 5 | showDialog | GestureDetector | AlertDialog | [banner_management_screen.dart:396](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) |
| 6 | showDialog | _showStatusEditDialog | AlertDialog | [compliance_control_screen.dart:380](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) |
| 7 | showDialog | _showTextEditDialog | AlertDialog | [compliance_control_screen.dart:439](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) |
| 8 | showDialog | _showDateEditDialog | AlertDialog | [compliance_control_screen.dart:494](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) |
| 9 | showDialog | _confirmAndSetFlag | AlertDialog | [feature_flags_screen.dart:266](../../apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart) |
| 10 | showDialog | _openEditDialog | EditBestsellerSlotDialog | [bestseller_management_screen.dart:160](../../apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart) |
| 11 | showDialog | _deleteSlot | AlertDialog | [edit_bestseller_slot_dialog.dart:435](../../apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart) |
| 12 | showDialog | _deleteSection | AlertDialog | [category_section_management_screen.dart:360](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| 13 | showDialog | _deleteSection | AlertDialog | [edit_category_section_screen.dart:781](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) |
| 14 | showDialog | _bulkDeleteCoupons | AlertDialog | [coupon_management_screen.dart:56](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) |
| 15 | showDialog | _openAddDialog | AddEditCouponDialog | [coupon_management_screen.dart:174](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) |
| 16 | showDialog | _openEditDialog | AddEditCouponDialog | [coupon_management_screen.dart:178](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) |
| 17 | showDialog | _showDeleteConfirmation | AlertDialog | [coupon_management_screen.dart:330](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) |
| 18 | showDialog | _showAddPartnerDialog | AddDeliveryPartnerDialog | [delivery_partner_management_screen.dart:362](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) |
| 19 | showDialog | _deletePartner | AlertDialog | [delivery_partner_management_screen.dart:369](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) |
| 20 | showDialog | _resolve | AlertDialog | [delivery_problems_screen.dart:133](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) |
| 21 | DialogHelper.showConfirmation | if | Inline or helper content | [order_assignment_screen.dart:468](../../apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart) |
| 22 | showDialog | if | AlertDialog | [rider_detail_screen.dart:278](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| 23 | showDialog | if | AlertDialog | [rider_detail_screen.dart:676](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| 24 | showDialog | _resolve | AlertDialog | [rider_incidents_screen.dart:146](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) |
| 25 | showDialog | _markPaid | AlertDialog | [rider_payouts_screen.dart:190](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 26 | showDialog | _recordDeposit | AlertDialog | [rider_payouts_screen.dart:395](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 27 | showDialog | if | AlertDialog | [rider_payouts_screen.dart:549](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 28 | showDialog | if | AlertDialog | [rider_payouts_screen.dart:697](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 29 | showDialog | if | Inline or helper content | [rider_payouts_screen.dart:871](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 30 | showDialog | if | AlertDialog | [rider_payouts_screen.dart:892](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| 31 | DialogHelper.showInput | if | Inline or helper content | [rider_review_sheet.dart:83](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) |
| 32 | DialogHelper.showConfirmation | if | Inline or helper content | [rider_review_sheet.dart:97](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) |
| 33 | showDialog | _close | AlertDialog | [rider_support_screen.dart:178](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) |
| 34 | showDialog | if | AlertDialog | [associate_detail_screen.dart:593](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| 35 | showDialog | _editCommissionRate | AlertDialog | [employee_management_screen.dart:71](../../apps/admin/lib/screens/admin/employees/employee_management_screen.dart) |
| 36 | showDialog | _askReason | AlertDialog | [employee_payout_account_review_screen.dart:65](../../apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart) |
| 37 | showDialog | _showMarkPaidDialog | AlertDialog | [employee_payout_detail_screen.dart:86](../../apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart) |
| 38 | showDialog | _showRejectDialog | AlertDialog | [employee_payout_detail_screen.dart:169](../../apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart) |
| 39 | showDialog | _markPaid | AlertDialog | [employee_payouts_screen.dart:43](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) |
| 40 | showDialog | _raiseCase | _RaiseFinancialCaseDialog | [financial_record_detail_screen.dart:167](../../apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart) |
| 41 | showDialog | addPostFrameCallback | AddEditHomeProductSectionDialog | [home_product_section_management_screen.dart:37](../../apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart) |
| 42 | showDialog | _confirmDelete | AlertDialog | [home_product_section_management_screen.dart:44](../../apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart) |
| 43 | showDialog | showSuccessDialog | AlertDialog | [send_notification_screen.dart:419](../../apps/admin/lib/screens/admin/notifications/send_notification_screen.dart) |
| 44 | showDialog | _bulkUpdateStatus | AlertDialog | [order_management_screen.dart:122](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart) |
| 45 | showDialog | Inline callback | AlertDialog | [order_reason_dialog.dart:22](../../apps/admin/lib/screens/admin/orders/widgets/order_reason_dialog.dart) |
| 46 | showDialog | _buildEmptyState | _CategoryFormDialog | [category_management_screen.dart:924](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) |
| 47 | showDialog | _confirmDelete | AlertDialog | [category_management_screen.dart:956](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) |
| 48 | showDialog | _showDeleteDialog | AlertDialog | [product_form_screen.dart:579](../../apps/admin/lib/screens/admin/products/product_form_screen.dart) |
| 49 | showDialog | _bulkDelete | AlertDialog | [product_management_screen.dart:72](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) |
| 50 | showDialog | _deleteProduct | AlertDialog | [product_management_screen.dart:780](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) |
| 51 | showModalBottomSheet | _openVariantImages | DraggableScrollableSheet | [variant_form.dart:170](../../apps/admin/lib/screens/admin/products/widgets/variant_form.dart) |
| 52 | showModalBottomSheet | _showFilterSheet | Inline or helper content | [review_management_screen.dart:58](../../apps/admin/lib/screens/admin/reviews/review_management_screen.dart) |
| 53 | showDialog | _showAddDialog | AddEditSectionBannerDialog | [section_banner_management_screen.dart:38](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) |
| 54 | showDialog | _showEditDialog | AddEditSectionBannerDialog | [section_banner_management_screen.dart:45](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) |
| 55 | showDialog | _confirmDelete | AlertDialog | [section_banner_management_screen.dart:207](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) |
| 56 | showDialog | _askReason | AlertDialog | [seller_detail_screen.dart:618](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| 57 | showDialog | _markPaid | AlertDialog | [seller_payouts_screen.dart:60](../../apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart) |
| 58 | showDialog | _askReason | AlertDialog | [seller_wallet_admin.dart:167](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) |
| 59 | showDialog | if | AlertDialog | [seller_wallet_admin.dart:259](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) |
| 60 | showDialog | _showMaintenanceModeDialog | AlertDialog | [admin_settings_screen.dart:723](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 61 | showDialog | _showChangePasswordDialog | _OwnedPasswordDialog | [admin_settings_screen.dart:778](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 62 | showDialog | _showClearCacheDialog | AlertDialog | [admin_settings_screen.dart:785](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 63 | showDialog | if | AlertDialog | [admin_settings_screen.dart:826](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 64 | showDialog | _showBackupDialog | AlertDialog | [admin_settings_screen.dart:869](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 65 | showDialog | _showCategoryManagementDialog | AlertDialog | [admin_settings_screen.dart:906](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 66 | showDialog | _showShippingSettingsDialog | AlertDialog | [admin_settings_screen.dart:972](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 67 | showDialog | _showPaymentSettingsDialog | AlertDialog | [admin_settings_screen.dart:1011](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 68 | showDialog | _showTwoFactorDialog | AlertDialog | [admin_settings_screen.dart:1050](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 69 | showDialog | _showLegalContentDialog | AlertDialog | [admin_settings_screen.dart:1082](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 70 | showDialog | _showSupportDialog | AlertDialog | [admin_settings_screen.dart:1094](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) |
| 71 | showDialog | _editSlot | AlertDialog | [delivery_time_slots_management_screen.dart:59](../../apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart) |
| 72 | showDialog | _showAddTopupBonusDialog | AlertDialog | [wallet_config_screen.dart:608](../../apps/admin/lib/screens/admin/settings/wallet_config_screen.dart) |
| 73 | showDialog | _showEditTopupBonusDialog | AlertDialog | [wallet_config_screen.dart:667](../../apps/admin/lib/screens/admin/settings/wallet_config_screen.dart) |
| 74 | showDialog | _bulkDelete | AlertDialog | [sponsored_banner_management_screen.dart:63](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) |
| 75 | showDialog | _navigateToAddBanner | AddEditSponsoredBannerDialog | [sponsored_banner_management_screen.dart:135](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) |
| 76 | showDialog | _navigateToEditBanner | AddEditSponsoredBannerDialog | [sponsored_banner_management_screen.dart:141](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) |
| 77 | showDialog | _deleteSingleBanner | AlertDialog | [sponsored_banner_management_screen.dart:149](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) |
| 78 | showDialog | _showCreatePlanDialog | AlertDialog | [subscription_management_screen.dart:23](../../apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart) |
| 79 | showDialog | _assign | _PickAdminDialog | [support_case_detail_screen.dart:102](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 80 | showDialog | _changeStatus | _ChangeStatusDialog | [support_case_detail_screen.dart:115](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 81 | showDialog | _addLink | _AddLinkDialog | [support_case_detail_screen.dart:161](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 82 | showDialog | _removeLink | AlertDialog | [support_case_detail_screen.dart:174](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 83 | showDialog | _removeLink | AlertDialog | [support_case_detail_screen.dart:202](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 84 | showDialog | if | AlertDialog | [support_case_detail_screen.dart:1185](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| 85 | showDialog | _createCase | _CreateCaseDialog | [support_queue_screen.dart:62](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) |
| 86 | showDialog | _confirmRoleChange | AlertDialog | [edit_user_screen.dart:68](../../apps/admin/lib/screens/admin/users/edit_user_screen.dart) |
| 87 | showDialog | _bulkDelete | AlertDialog | [user_management_screen.dart:73](../../apps/admin/lib/screens/admin/users/user_management_screen.dart) |
| 88 | showDialog | _showAddVendorDialog | AlertDialog | [vendors_list_screen.dart:92](../../apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart) |
| 89 | showDialog | _showUpdateStatusDialog | AlertDialog | [vendors_list_screen.dart:128](../../apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart) |
| 90 | showDialog | _raiseCase | _RaiseCaseDialog | [actor_support_cases_section.dart:53](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| 91 | showDialog | _raiseCase | _RaiseOrderCaseDialog | [actor_support_cases_section.dart:161](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| 92 | showDialog | build | Inline or helper content | [actor_support_cases_section.dart:440](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |

## Application entry and root state hosts

| App | Gate or conditional full-page host | Category | Source |
| --- | --- | --- | --- |
| Marketplace | AuthGuard | Auth gate | [auth_guard.dart:9](../../apps/marketplace/lib/screens/auth/auth_guard.dart) |
| Marketplace | AuthWrapper | Auth gate | [auth_wrapper.dart:39](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart) |
| Marketplace | AuthGate | Auth gate | [auth_gate.dart:11](../../apps/marketplace/lib/widgets/auth_gate.dart) |
| Seller | SellerAuthGate | Auth gate | [app.dart:52](../../apps/seller/lib/app/app.dart) |
| Delivery | RiderSessionGate | Auth gate | [app.dart:70](../../apps/delivery/lib/app/app.dart) |
| Sales Associate | _AuthGate | Auth gate | [app.dart:52](../../apps/employee/lib/app/app.dart) |
| Marketplace | _MinimalLoadingScreen | Private full-page state or host | [auth_guard.dart:45](../../apps/marketplace/lib/screens/auth/auth_guard.dart) |
| Marketplace | _SplashLoader | Private full-page state or host | [auth_wrapper.dart:90](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart) |
| Seller | _LoadingAccount | Private full-page state or host | [app.dart:81](../../apps/seller/lib/app/app.dart) |
| Seller | _EditorSubscreen | Private full-page state or host | [add_product_screen.dart:1324](../../apps/seller/lib/screens/home/add_product_screen.dart) |
| Seller | _Stepper | Private full-page state or host | [application_screen.dart:34](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| Delivery | _LoadingAccount | Private full-page state or host | [app.dart:138](../../apps/delivery/lib/app/app.dart) |
| Delivery | _AccountUnavailable | Private full-page state or host | [app.dart:166](../../apps/delivery/lib/app/app.dart) |
| Admin | _EmulatorWiringFailedApp | Private full-page state or host | [main.dart:218](../../apps/admin/lib/main.dart) |

| App | Additional surface | Category | Entry | Source |
| --- | --- | --- | --- | --- |
| Admin | Shared Admin splash | Shared screen dependency | /splash builder in Admin router | [premium_splash_screen.dart](../../packages/agrimore_ui/lib/widgets/premium_splash_screen.dart) |
| Admin | Router page-not-found fallback | Inline fallback | GoRouter errorBuilder | [app_router.dart](../../apps/admin/lib/app/app_router.dart) |

Private _EditorSubscreen and _Stepper are reused hosts, not two extra public navigation destinations; their individual product-editor and application steps are already described. Marketplace AuthGuard uses different web/mobile branches and can show LandingScreen on web. Seller uses typed SellerAccess, Delivery uses rider/session/account states, Associate uses its auth gate, and Admin uses GoRouter redirects. These presentation boundaries must be preserved when later changing navigation or styling.

## Named routes aliases and source mismatches

Marketplace uses onGenerateRoute and switches/parameter handlers. Admin uses GoRouter builders and redirects. Seller, Delivery and Sales Associate principally construct screens through their state gates, tab shells and Navigator/MaterialPageRoute calls; they do not need a named URL for every screen. No route-registration absence is treated as proof that a directly pushed screen is missing.

| App | Route or alias | Source targets | Source relationship | Definition |
| --- | --- | --- | --- | --- |
| Marketplace | / | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:334](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /main | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:339](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /home | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:342](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /shop | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:345](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /shop/search | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:365](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /cart | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:372](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wishlist | WishlistScreen | Switch route source; argument/auth branches may change target. | [routes.dart:375](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /business-feed | BusinessFeedScreen | Switch route source; argument/auth branches may change target. | [routes.dart:378](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:381](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /onboarding | OnboardingScreen | Switch route source; argument/auth branches may change target. | [routes.dart:386](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /landing | LandingScreen | Switch route source; argument/auth branches may change target. | [routes.dart:390](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /login | LoginScreen | Switch route source; argument/auth branches may change target. | [routes.dart:394](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /signup | SignupScreen | Switch route source; argument/auth branches may change target. | [routes.dart:396](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /complete-profile | CompleteProfileScreen, LoginScreen | Switch route source; argument/auth branches may change target. | [routes.dart:407](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /forgot-password | LoginScreen | Switch route source; argument/auth branches may change target. | [routes.dart:414](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /mobile-number | MobileNumberScreen | Switch route source; argument/auth branches may change target. | [routes.dart:418](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /onboarding-address | OnboardingAddressScreen | Switch route source; argument/auth branches may change target. | [routes.dart:420](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile/add-address | OnboardingAddressScreen | Switch route source; argument/auth branches may change target. | [routes.dart:427](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile/edit-address | OnboardingAddressScreen | Switch route source; argument/auth branches may change target. | [routes.dart:432](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /terms | TermsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:443](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /privacy-policy | PrivacyPolicyScreen | Switch route source; argument/auth branches may change target. | [routes.dart:445](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /search | SearchScreen | Switch route source; argument/auth branches may change target. | [routes.dart:449](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /search/results | SearchResultsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:451](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /product-details | ProductDetailsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:461](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /category/:id | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:468](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /categories | MainScreen | Switch route source; argument/auth branches may change target. | [routes.dart:482](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /recently-viewed | ShopScreen | Switch route source; argument/auth branches may change target. | [routes.dart:485](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /deals | ShopScreen | Switch route source; argument/auth branches may change target. | [routes.dart:488](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /chat-history | ChatHistoryScreen | Switch route source; argument/auth branches may change target. | [routes.dart:492](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /checkout | CheckoutScreen | Switch route source; argument/auth branches may change target. | [routes.dart:496](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /order-success | OrderSuccessScreen | Switch route source; argument/auth branches may change target. | [routes.dart:498](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /orders | OrdersScreen | Switch route source; argument/auth branches may change target. | [routes.dart:506](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /my-orders | OrdersScreen | Switch route source; argument/auth branches may change target. | [routes.dart:507](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /order-details | OrderDetailsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:511](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /order-tracking | OrderTrackingScreen | Switch route source; argument/auth branches may change target. | [routes.dart:517](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile/edit | EditProfileScreen | Switch route source; argument/auth branches may change target. | [routes.dart:525](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile/change-password | ChangePasswordScreen | Switch route source; argument/auth branches may change target. | [routes.dart:528](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /profile/addresses | SavedAddressesScreen | Switch route source; argument/auth branches may change target. | [routes.dart:531](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /settings | SettingsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:534](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /checkout/add-address | OnboardingAddressScreen | Switch route source; argument/auth branches may change target. | [routes.dart:539](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /checkout/payment | PaymentMethodScreen | Switch route source; argument/auth branches may change target. | [routes.dart:544](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /cart/coupons | CouponSelectionScreen | Switch route source; argument/auth branches may change target. | [routes.dart:567](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /notifications | NotificationsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:571](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /support | AIChatScreen | Switch route source; argument/auth branches may change target. | [routes.dart:575](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /offers | OffersScreen | Switch route source; argument/auth branches may change target. | [routes.dart:579](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /flash-sale | FlashSaleScreen | Switch route source; argument/auth branches may change target. | [routes.dart:581](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /rewards | RewardsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:586](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /rate-order | RateOrderScreen | Switch route source; argument/auth branches may change target. | [routes.dart:590](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /my-rfqs | MyRfqsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:601](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /rfq-detail | RfqDetailScreen | Switch route source; argument/auth branches may change target. | [routes.dart:603](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /my-subscriptions | MySubscriptionsScreen | Switch route source; argument/auth branches may change target. | [routes.dart:610](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /subscription-setup | SubscriptionSetupScreen | Switch route source; argument/auth branches may change target. | [routes.dart:613](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /language | LanguageScreen | Switch route source; argument/auth branches may change target. | [routes.dart:630](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /seller/apply | SellerHandoffScreen | Switch route source; argument/auth branches may change target. | [routes.dart:635](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /seller/panel | SellerHandoffScreen | Switch route source; argument/auth branches may change target. | [routes.dart:636](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /seller/dashboard | SellerHandoffScreen | Switch route source; argument/auth branches may change target. | [routes.dart:637](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /employee/apply | EmployeeApplyScreen | Switch route source; argument/auth branches may change target. | [routes.dart:642](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /employee/onboarding | AssociateOnboardingScreen | Switch route source; argument/auth branches may change target. | [routes.dart:651](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wallet | WalletScreen | Switch route source; argument/auth branches may change target. | [routes.dart:655](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wallet/add-money | AddMoneyScreen | Switch route source; argument/auth branches may change target. | [routes.dart:657](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wallet/history | TransactionHistoryScreen | Switch route source; argument/auth branches may change target. | [routes.dart:660](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wallet/referral | ReferralScreen | Switch route source; argument/auth branches may change target. | [routes.dart:663](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /wallet/product-credit | ProductCreditScreen | Switch route source; argument/auth branches may change target. | [routes.dart:666](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /product/:id | ProductDetailsScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:286](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /business/:id | BusinessProfileScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:302](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /category/:id | ShopScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:312](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /order/:id | OrderDetailsScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:326](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /search?q=… | SearchResultsScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:456](../../apps/marketplace/lib/app/routes.dart) |
| Marketplace | /employee/onboarding?handoff=… | AssociateOnboardingScreen | Manually checked dynamic/query handler, not an additional screen. | [routes.dart:652](../../apps/marketplace/lib/app/routes.dart) |
| Admin | /splash | PremiumSplashScreen | Builder source; auth redirect may guard access. | [app_router.dart:234](../../apps/admin/lib/app/app_router.dart) |
| Admin | /auth | AuthScreen | Builder source; auth redirect may guard access. | [app_router.dart:265](../../apps/admin/lib/app/app_router.dart) |
| Admin | /login | Redirect only | Builder source; auth redirect may guard access. | [app_router.dart:270](../../apps/admin/lib/app/app_router.dart) |
| Admin | / | Redirect only | Builder source; auth redirect may guard access. | [app_router.dart:276](../../apps/admin/lib/app/app_router.dart) |
| Admin | /products/new | ProductFormScreen | Builder source; auth redirect may guard access. | [app_router.dart:293](../../apps/admin/lib/app/app_router.dart) |
| Admin | /products/:id/edit | ProductFormScreen | Builder source; auth redirect may guard access. | [app_router.dart:299](../../apps/admin/lib/app/app_router.dart) |
| Admin | /sections/new | EditCategorySectionScreen | Builder source; auth redirect may guard access. | [app_router.dart:310](../../apps/admin/lib/app/app_router.dart) |
| Admin | /sections/:id/edit | EditCategorySectionScreen | Builder source; auth redirect may guard access. | [app_router.dart:316](../../apps/admin/lib/app/app_router.dart) |
| Admin | /dashboard | AdminDashboard | Builder source; auth redirect may guard access. | [app_router.dart:334](../../apps/admin/lib/app/app_router.dart) |
| Admin | /products | ProductManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:342](../../apps/admin/lib/app/app_router.dart) |
| Admin | /orders | OrderManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:350](../../apps/admin/lib/app/app_router.dart) |
| Admin | /users | UserManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:358](../../apps/admin/lib/app/app_router.dart) |
| Admin | /users/:id | CustomerDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:367](../../apps/admin/lib/app/app_router.dart) |
| Admin | /subscriptions | SubscriptionManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:377](../../apps/admin/lib/app/app_router.dart) |
| Admin | /rewards | RewardsManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:385](../../apps/admin/lib/app/app_router.dart) |
| Admin | /reviews | ReviewManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:393](../../apps/admin/lib/app/app_router.dart) |
| Admin | /wallet-topups | WalletTrackingScreen | Builder source; auth redirect may guard access. | [app_router.dart:400](../../apps/admin/lib/app/app_router.dart) |
| Admin | /vendors | VendorsListScreen | Builder source; auth redirect may guard access. | [app_router.dart:408](../../apps/admin/lib/app/app_router.dart) |
| Admin | /delivery-partners | DeliveryPartnerManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:416](../../apps/admin/lib/app/app_router.dart) |
| Admin | /delivery-partners/:id | RiderDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:423](../../apps/admin/lib/app/app_router.dart) |
| Admin | /delivery-dispatch | DispatchQueueScreen | Builder source; auth redirect may guard access. | [app_router.dart:433](../../apps/admin/lib/app/app_router.dart) |
| Admin | /rider-payouts | RiderPayoutsScreen | Builder source; auth redirect may guard access. | [app_router.dart:441](../../apps/admin/lib/app/app_router.dart) |
| Admin | /rider-incidents | RiderIncidentsScreen | Builder source; auth redirect may guard access. | [app_router.dart:449](../../apps/admin/lib/app/app_router.dart) |
| Admin | /delivery-problems | DeliveryProblemsScreen | Builder source; auth redirect may guard access. | [app_router.dart:457](../../apps/admin/lib/app/app_router.dart) |
| Admin | /rider-support | RiderSupportScreen | Builder source; auth redirect may guard access. | [app_router.dart:465](../../apps/admin/lib/app/app_router.dart) |
| Admin | /coupons | CouponManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:473](../../apps/admin/lib/app/app_router.dart) |
| Admin | /banners | BannerManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:481](../../apps/admin/lib/app/app_router.dart) |
| Admin | /sponsored | SponsoredBannerManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:489](../../apps/admin/lib/app/app_router.dart) |
| Admin | /section-banners | SectionBannerManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:497](../../apps/admin/lib/app/app_router.dart) |
| Admin | /bestsellers | BestsellerManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:505](../../apps/admin/lib/app/app_router.dart) |
| Admin | /sections | CategorySectionManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:513](../../apps/admin/lib/app/app_router.dart) |
| Admin | /notifications | SendNotificationScreen | Builder source; auth redirect may guard access. | [app_router.dart:521](../../apps/admin/lib/app/app_router.dart) |
| Admin | /analytics | AnalyticsScreen | Builder source; auth redirect may guard access. | [app_router.dart:529](../../apps/admin/lib/app/app_router.dart) |
| Admin | /settings | AdminSettingsScreen | Builder source; auth redirect may guard access. | [app_router.dart:537](../../apps/admin/lib/app/app_router.dart) |
| Admin | /delivery-time-slots | DeliveryTimeSlotsManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:544](../../apps/admin/lib/app/app_router.dart) |
| Admin | /seller-requests | SellerRequestsManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:551](../../apps/admin/lib/app/app_router.dart) |
| Admin | /add-seller | AddSellerScreen | Builder source; auth redirect may guard access. | [app_router.dart:558](../../apps/admin/lib/app/app_router.dart) |
| Admin | /manage-sellers | ManageSellersScreen | Builder source; auth redirect may guard access. | [app_router.dart:565](../../apps/admin/lib/app/app_router.dart) |
| Admin | /sellers/:id | SellerDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:572](../../apps/admin/lib/app/app_router.dart) |
| Admin | /seller-payouts | SellerPayoutsScreen | Builder source; auth redirect may guard access. | [app_router.dart:581](../../apps/admin/lib/app/app_router.dart) |
| Admin | /employees | EmployeeManagementScreen | Builder source; auth redirect may guard access. | [app_router.dart:588](../../apps/admin/lib/app/app_router.dart) |
| Admin | /employees/:id | AssociateDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:595](../../apps/admin/lib/app/app_router.dart) |
| Admin | /add-employee | AddEmployeeScreen | Builder source; auth redirect may guard access. | [app_router.dart:604](../../apps/admin/lib/app/app_router.dart) |
| Admin | /employee-payouts | EmployeePayoutsScreen | Builder source; auth redirect may guard access. | [app_router.dart:611](../../apps/admin/lib/app/app_router.dart) |
| Admin | /employee-payout-account-review | EmployeePayoutAccountReviewScreen | Builder source; auth redirect may guard access. | [app_router.dart:618](../../apps/admin/lib/app/app_router.dart) |
| Admin | /commission-exceptions | CommissionExceptionsScreen | Builder source; auth redirect may guard access. | [app_router.dart:625](../../apps/admin/lib/app/app_router.dart) |
| Admin | /finance/reconciliation | FinanceReconciliationScreen | Builder source; auth redirect may guard access. | [app_router.dart:632](../../apps/admin/lib/app/app_router.dart) |
| Admin | /finance/records/:type/:id | FinancialRecordDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:639](../../apps/admin/lib/app/app_router.dart) |
| Admin | /employee-payouts/:id | EmployeePayoutDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:658](../../apps/admin/lib/app/app_router.dart) |
| Admin | /benefit-program/compliance | ComplianceControlScreen | Builder source; auth redirect may guard access. | [app_router.dart:674](../../apps/admin/lib/app/app_router.dart) |
| Admin | /benefit-program/feature-flags | FeatureFlagsScreen | Builder source; auth redirect may guard access. | [app_router.dart:681](../../apps/admin/lib/app/app_router.dart) |
| Admin | /support | SupportQueueScreen | Builder source; auth redirect may guard access. | [app_router.dart:688](../../apps/admin/lib/app/app_router.dart) |
| Admin | /support/:id | SupportCaseDetailScreen | Builder source; auth redirect may guard access. | [app_router.dart:695](../../apps/admin/lib/app/app_router.dart) |

Source-confirmed distinctions:

- Marketplace /, /main and /home mount MainScreen through AuthGuard; the retained SplashScreen file is not the current root destination.
- Marketplace /forgot-password returns LoginScreen. Current LoginScreen contains phone-entry/OTP states; there is no separate Marketplace ForgotPasswordScreen definition in this source inventory.
- Marketplace /support mounts AIChatScreen. The /ai-chat constant has no explicit onGenerateRoute case; direct AIChatScreen construction is separately indexed. HelpScreen is a different existing view.
- Marketplace routed SearchScreen is under user/home/search. The separate responsive SearchScreen under user/search has no app-lib constructor caller found; its mobile/web children should not be assumed reachable merely because they exist.
- Marketplace /checkout/add-address uses OnboardingAddressScreen, while a separate AddAddressScreen still exists and has direct construction references.
- Marketplace /orders and /my-orders share OrdersScreen; /seller/apply, /seller/panel and /seller/dashboard share SellerHandoffScreen rather than hosting the standalone Seller app.
- Marketplace live tracking is a directly constructed LiveTrackingScreen; the obsolete /order/track route/TrackOrderScreen is not added to the list.
- Admin /login and / are redirect entries; they are not extra authentication/dashboard screen classes.
- Admin /products/new and /products/:id/edit share ProductFormScreen. /sections/new and /sections/:id/edit share EditCategorySectionScreen, with both examined builders supplying section:null.
- Admin OrderDetail and sectionEdit constants differ from the located direct screen calls / registered section edit path. Their declarations do not establish a registered detail/edit URL.

Constants with no explicit matching source handler/path in this router scan:

| App | Constant | Declared path |
| --- | --- | --- |
| Marketplace | aiChat | /ai-chat |
| Admin | orderDetail | /orders/:id |
| Admin | sectionEdit | /sections/:id |
| Admin | sellerPanel | /seller/panel |
| Admin | sellerApply | /seller/apply |

These are static mapping findings; global redirects, argument-dependent fallback, access state and other callers can alter runtime behavior. No routing fix is included.

## Developer catalogue

Sales Associate has a separate main_catalogue.dart entry and five documentation tabs. The following 17 widget declarations include its app/root, five tabs and specimen helpers; they are not 17 production screens.

| Declaration | Source |
| --- | --- |
| SaCatalogueApp | [catalogue_app.dart:11](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _CatalogueHomeScreen | [catalogue_app.dart:25](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _TokensTab | [catalogue_app.dart:87](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _TypographyTab | [catalogue_app.dart:261](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _IconsTab | [catalogue_app.dart:374](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _ComponentsTab | [catalogue_app.dart:497](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _ContentTab | [catalogue_app.dart:681](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _SectionHeader | [catalogue_app.dart:760](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _ColorSwatch | [catalogue_app.dart:780](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _MiniColorSwatch | [catalogue_app.dart:839](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _SemanticPairCard | [catalogue_app.dart:890](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _SpacingRow | [catalogue_app.dart:939](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _RadiusCard | [catalogue_app.dart:971](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _TypeSpecimenCard | [catalogue_app.dart:1020](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _IconSpecimen | [catalogue_app.dart:1070](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _ContentConventionRow | [catalogue_app.dart:1099](../../apps/employee/lib/catalogue/catalogue_app.dart) |
| _PrivacyFieldRow | [catalogue_app.dart:1155](../../apps/employee/lib/catalogue/catalogue_app.dart) |

## Embedded view appendix

These 352 public/private widget declarations are composition parts under screen, safety or catalogue trees, such as record cards, sections, maps, form steps and tab bodies. They are recorded for completeness and are not counted as standalone screens. Other reusable primitives under app design_system or shared packages are outside this screen inventory and are covered by C28. Class naming and source alone do not certify which internal widget states actually render.

| App | Embedded declaration | Area | Source |
| --- | --- | --- | --- |
| Marketplace | AuthGuard | auth | [auth_guard.dart:9](../../apps/marketplace/lib/screens/auth/auth_guard.dart) |
| Marketplace | AuthWrapper | auth | [auth_wrapper.dart:39](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart) |
| Marketplace | _GoogleLogo | auth | [login_screen.dart:1171](../../apps/marketplace/lib/screens/auth/login_screen.dart) |
| Marketplace | _PostCard | business | [business_feed_screen.dart:84](../../apps/marketplace/lib/screens/business/business_feed_screen.dart) |
| Marketplace | _ChatAppBar | chat | [ai_chat_screen.dart:412](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _LoadingState | chat | [ai_chat_screen.dart:437](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _GuestModeBanner | chat | [ai_chat_screen.dart:457](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _SessionStatsBar | chat | [ai_chat_screen.dart:494](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _StatChip | chat | [ai_chat_screen.dart:534](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _MessageList | chat | [ai_chat_screen.dart:565](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _ReplyingToBar | chat | [ai_chat_screen.dart:666](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | _ChatInputArea | chat | [ai_chat_screen.dart:709](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) |
| Marketplace | ChatAppBar | chat / widgets | [chat_app_bar.dart:3](../../apps/marketplace/lib/screens/chat/widgets/chat_app_bar.dart) |
| Marketplace | ChatMessageWidget | chat / widgets | [chat_message_widget.dart:7](../../apps/marketplace/lib/screens/chat/widgets/chat_message_widget.dart) |
| Marketplace | MessageBubble | chat / widgets | [message_bubble.dart:12](../../apps/marketplace/lib/screens/chat/widgets/message_bubble.dart) |
| Marketplace | MessageListView | chat / widgets | [message_list_view.dart:9](../../apps/marketplace/lib/screens/chat/widgets/message_list_view.dart) |
| Marketplace | OrderCardRenderer | chat / widgets | [order_card_renderer.dart:5](../../apps/marketplace/lib/screens/chat/widgets/order_card_renderer.dart) |
| Marketplace | ProductCardHorizontal | chat / widgets | [product_card_horizontal.dart:7](../../apps/marketplace/lib/screens/chat/widgets/product_card_horizontal.dart) |
| Marketplace | ProductCardWidget | chat / widgets | [product_card_widget.dart:7](../../apps/marketplace/lib/screens/chat/widgets/product_card_widget.dart) |
| Marketplace | QuickReplyChip | chat / widgets | [quick_reply_chip.dart:5](../../apps/marketplace/lib/screens/chat/widgets/quick_reply_chip.dart) |
| Marketplace | TypingIndicator | chat / widgets | [typing_indicator.dart:5](../../apps/marketplace/lib/screens/chat/widgets/typing_indicator.dart) |
| Marketplace | _EmployeeStateGate | employee / onboarding | [associate_onboarding_screen.dart:332](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) |
| Marketplace | OnboardingConfirmationStep | employee / onboarding / widgets | [onboarding_confirmation_step.dart:36](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_confirmation_step.dart) |
| Marketplace | OnboardingDetailsStep | employee / onboarding / widgets | [onboarding_details_step.dart:12](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_details_step.dart) |
| Marketplace | OnboardingHeaderSection | employee / onboarding / widgets | [onboarding_info_sections.dart:35](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingWhyFeeSection | employee / onboarding / widgets | [onboarding_info_sections.dart:96](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingBenefitGroupsSection | employee / onboarding / widgets | [onboarding_info_sections.dart:123](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingEarningsExplainerSection | employee / onboarding / widgets | [onboarding_info_sections.dart:175](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | _FlowChip | employee / onboarding / widgets | [onboarding_info_sections.dart:244](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingJourneyStepsSection | employee / onboarding / widgets | [onboarding_info_sections.dart:262](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingSummaryCardSection | employee / onboarding / widgets | [onboarding_info_sections.dart:325](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingDisclosuresSection | employee / onboarding / widgets | [onboarding_info_sections.dart:381](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingSupportContactSection | employee / onboarding / widgets | [onboarding_info_sections.dart:435](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | _Card | employee / onboarding / widgets | [onboarding_info_sections.dart:490](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) |
| Marketplace | OnboardingPaymentStep | employee / onboarding / widgets | [onboarding_payment_step.dart:43](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart) |
| Marketplace | CartItemCard | user / cart / widgets | [cart_item_card.dart:11](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart) |
| Marketplace | CartSummary | user / cart / widgets | [cart_summary.dart:11](../../apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart) |
| Marketplace | EmptyCart | user / cart / widgets | [empty_cart.dart:6](../../apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart) |
| Marketplace | QuantitySelector | user / cart / widgets | [quantity_selector.dart:6](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart) |
| Marketplace | _EnhancedCategorySidebar | user / categories | [categories_screen.dart:844](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | _EnhancedSidebarItem | user / categories | [categories_screen.dart:893](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | _PremiumCategoryHeader | user / categories | [categories_screen.dart:1105](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | _PremiumSubcategoryGrid | user / categories | [categories_screen.dart:1263](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | _SubcategoryImageCard | user / categories | [categories_screen.dart:1331](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | _AdvancedProductCard | user / categories | [categories_screen.dart:1480](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) |
| Marketplace | CategoryHeroBanner | user / categories / widgets | [category_content_sections.dart:13](../../apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart) |
| Marketplace | CategoryFilterChips | user / categories / widgets | [category_content_sections.dart:199](../../apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart) |
| Marketplace | PopularPicksSection | user / categories / widgets | [category_content_sections.dart:277](../../apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart) |
| Marketplace | _LocationSelector | user / checkout | [add_address_screen.dart:2456](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) |
| Marketplace | AssociateCodeField | user / checkout / widgets | [associate_code_field.dart:41](../../apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart) |
| Marketplace | _FeedbackChip | user / checkout / widgets | [associate_code_field.dart:420](../../apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart) |
| Marketplace | CheckoutSteps | user / checkout / widgets | [checkout_steps.dart:7](../../apps/marketplace/lib/screens/user/checkout/widgets/checkout_steps.dart) |
| Marketplace | SavedCheckoutCard | user / checkout / widgets | [saved_checkout_card.dart:9](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart) |
| Marketplace | RecentSearches | user / home / search / widgets | [recent_searches.dart:8](../../apps/marketplace/lib/screens/user/home/search/widgets/recent_searches.dart) |
| Marketplace | SearchBarWidget | user / home / search / widgets | [search_bar_widget.dart:6](../../apps/marketplace/lib/screens/user/home/search/widgets/search_bar_widget.dart) |
| Marketplace | SearchFilters | user / home / search / widgets | [search_filters.dart:8](../../apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart) |
| Marketplace | SearchProductCard | user / home / search / widgets | [search_product_card.dart:7](../../apps/marketplace/lib/screens/user/home/search/widgets/search_product_card.dart) |
| Marketplace | SearchSuggestions | user / home / search / widgets | [search_suggestions.dart:6](../../apps/marketplace/lib/screens/user/home/search/widgets/search_suggestions.dart) |
| Marketplace | TrendingSearches | user / home / search / widgets | [trending_searches.dart:7](../../apps/marketplace/lib/screens/user/home/search/widgets/trending_searches.dart) |
| Marketplace | AllProductsGrid | user / home / widgets | [all_products_grid.dart:11](../../apps/marketplace/lib/screens/user/home/widgets/all_products_grid.dart) |
| Marketplace | BannerSlider | user / home / widgets | [banner_slider.dart:11](../../apps/marketplace/lib/screens/user/home/widgets/banner_slider.dart) |
| Marketplace | DealsForYou | user / home / widgets | [bestsellers.dart:17](../../apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart) |
| Marketplace | _BestsellerCard | user / home / widgets | [bestsellers.dart:228](../../apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart) |
| Marketplace | _ImageTile | user / home / widgets | [bestsellers.dart:408](../../apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart) |
| Marketplace | CategoriesGrid | user / home / widgets | [categories_grid.dart:12](../../apps/marketplace/lib/screens/user/home/widgets/categories_grid.dart) |
| Marketplace | DynamicCategorySections | user / home / widgets | [dynamic_category_sections.dart:52](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) |
| Marketplace | _AdminCategorySection | user / home / widgets | [dynamic_category_sections.dart:180](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) |
| Marketplace | _FallbackCategorySection | user / home / widgets | [dynamic_category_sections.dart:276](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) |
| Marketplace | _EnhancedCategoryTile | user / home / widgets | [dynamic_category_sections.dart:362](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) |
| Marketplace | FeaturedProducts | user / home / widgets | [featured_products.dart:15](../../apps/marketplace/lib/screens/user/home/widgets/featured_products.dart) |
| Marketplace | _CategoryTile | user / home / widgets | [featured_products.dart:106](../../apps/marketplace/lib/screens/user/home/widgets/featured_products.dart) |
| Marketplace | GroceryKitchenHomeStrip | user / home / widgets | [grocery_kitchen_home_strip.dart:20](../../apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart) |
| Marketplace | _Tile | user / home / widgets | [grocery_kitchen_home_strip.dart:133](../../apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart) |
| Marketplace | HomeAppBar | user / home / widgets | [home_app_bar.dart:33](../../apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart) |
| Marketplace | HomeSearchBar | user / home / widgets | [home_search_bar.dart:7](../../apps/marketplace/lib/screens/user/home/widgets/home_search_bar.dart) |
| Marketplace | ProductCardCompact | user / home / widgets | [product_card_compact.dart:14](../../apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart) |
| Marketplace | ProductSectionWidget | user / home / widgets | [product_section_widget.dart:11](../../apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart) |
| Marketplace | RecentlyViewedWidget | user / home / widgets | [recently_viewed_widget.dart:11](../../apps/marketplace/lib/screens/user/home/widgets/recently_viewed_widget.dart) |
| Marketplace | SectionBannerCarousel | user / home / widgets | [section_banner_carousel.dart:13](../../apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart) |
| Marketplace | _BannerItem | user / home / widgets | [section_banner_carousel.dart:157](../../apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart) |
| Marketplace | SponsoredBannerStrip | user / home / widgets | [sponsored_banner_strip.dart:17](../../apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart) |
| Marketplace | _SponsoredBannerItem | user / home / widgets | [sponsored_banner_strip.dart:135](../../apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart) |
| Marketplace | TrendingProducts | user / home / widgets | [trending_products.dart:15](../../apps/marketplace/lib/screens/user/home/widgets/trending_products.dart) |
| Marketplace | _CategoryTile | user / home / widgets | [trending_products.dart:105](../../apps/marketplace/lib/screens/user/home/widgets/trending_products.dart) |
| Marketplace | _ProductSelectionModal | user / orders | [order_details_screen.dart:2064](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) |
| Marketplace | _ProductSelectionItem | user / orders | [order_details_screen.dart:2391](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) |
| Marketplace | _OrderCard | user / orders | [orders_screen.dart:712](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart) |
| Marketplace | _StatusBadge | user / orders | [orders_screen.dart:1203](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart) |
| Marketplace | DeliveredView | user / orders / widgets | [delivered_view.dart:11](../../apps/marketplace/lib/screens/user/orders/widgets/delivered_view.dart) |
| Marketplace | EmptyOrders | user / orders / widgets | [empty_orders.dart:5](../../apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart) |
| Marketplace | LiveEtaText | user / orders / widgets | [live_eta_text.dart:10](../../apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart) |
| Marketplace | OrderCard | user / orders / widgets | [order_card.dart:8](../../apps/marketplace/lib/screens/user/orders/widgets/order_card.dart) |
| Marketplace | OrderItemCard | user / orders / widgets | [order_item_card.dart:5](../../apps/marketplace/lib/screens/user/orders/widgets/order_item_card.dart) |
| Marketplace | OrderStatusBadge | user / orders / widgets | [order_status_badge.dart:3](../../apps/marketplace/lib/screens/user/orders/widgets/order_status_badge.dart) |
| Marketplace | OrderTimeline | user / orders / widgets | [order_timeline.dart:6](../../apps/marketplace/lib/screens/user/orders/widgets/order_timeline.dart) |
| Marketplace | TrackingMap | user / orders / widgets | [tracking_map.dart:4](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_map.dart) |
| Marketplace | TrackingCard | user / orders / widgets | [tracking_sections.dart:24](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | TrackingStepper | user / orders / widgets | [tracking_sections.dart:46](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | DeliveryCodeCard | user / orders / widgets | [tracking_sections.dart:172](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | RiderCard | user / orders / widgets | [tracking_sections.dart:218](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | _RoundAction | user / orders / widgets | [tracking_sections.dart:292](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | RiderPendingCard | user / orders / widgets | [tracking_sections.dart:318](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | OrderSummaryCard | user / orders / widgets | [tracking_sections.dart:345](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | HelpCard | user / orders / widgets | [tracking_sections.dart:452](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) |
| Marketplace | _DisclosureSection | user / profile | [delete_account_screen.dart:288](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart) |
| Marketplace | _MessageBanner | user / profile | [delete_account_screen.dart:361](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart) |
| Marketplace | VerificationStepHeader | user / profile / widgets | [verification_flow_widgets.dart:13](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | LockedValueCard | user / profile / widgets | [verification_flow_widgets.dart:68](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | InfoCallout | user / profile / widgets | [verification_flow_widgets.dart:137](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | OtpBoxesDisplay | user / profile / widgets | [verification_flow_widgets.dart:201](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | NumericKeypad | user / profile / widgets | [verification_flow_widgets.dart:245](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | VerificationSuccessView | user / profile / widgets | [verification_flow_widgets.dart:318](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | VerificationPrimaryButton | user / profile / widgets | [verification_flow_widgets.dart:475](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) |
| Marketplace | _RfqCard | user / rfq | [my_rfqs_screen.dart:64](../../apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart) |
| Marketplace | _HistoryTile | user / rfq | [rfq_detail_screen.dart:270](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| Marketplace | _ActionBar | user / rfq | [rfq_detail_screen.dart:316](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) |
| Marketplace | DeliveryInfoWidget | user / shop / widgets | [delivery_info_widget.dart:8](../../apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart) |
| Marketplace | FilterDrawer | user / shop / widgets | [filter_drawer.dart:11](../../apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart) |
| Marketplace | ProductCard | user / shop / widgets | [product_card.dart:11](../../apps/marketplace/lib/screens/user/shop/widgets/product_card.dart) |
| Marketplace | ProductGrid | user / shop / widgets | [product_grid.dart:5](../../apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart) |
| Marketplace | ProductImageHero | user / shop / widgets | [product_image_hero.dart:18](../../apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart) |
| Marketplace | ProductInfoSection | user / shop / widgets | [product_info_section.dart:9](../../apps/marketplace/lib/screens/user/shop/widgets/product_info_section.dart) |
| Marketplace | ProductList | user / shop / widgets | [product_list.dart:5](../../apps/marketplace/lib/screens/user/shop/widgets/product_list.dart) |
| Marketplace | ProductShareWidget | user / shop / widgets | [product_share_widget.dart:14](../../apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart) |
| Marketplace | ReviewCard | user / shop / widgets | [review_card.dart:11](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) |
| Marketplace | ReviewFeed | user / shop / widgets | [review_feed.dart:7](../../apps/marketplace/lib/screens/user/shop/widgets/review_feed.dart) |
| Marketplace | ReviewsSection | user / shop / widgets | [reviews_section.dart:11](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart) |
| Marketplace | ReviewsSectionInline | user / shop / widgets | [reviews_section_inline.dart:12](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart) |
| Marketplace | ShopAppBar | user / shop / widgets | [shop_app_bar.dart:17](../../apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart) |
| Marketplace | SpecificationList | user / shop / widgets | [specification_list.dart:7](../../apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart) |
| Marketplace | VariantSelector | user / shop / widgets | [variant_selector.dart:11](../../apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart) |
| Marketplace | ProductCreditCard | user / wallet / widgets | [product_credit_card.dart:11](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart) |
| Marketplace | _StatusRow | user / wallet / widgets | [product_credit_card.dart:174](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart) |
| Marketplace | ProductCreditLedgerTile | user / wallet / widgets | [product_credit_ledger_tile.dart:25](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_ledger_tile.dart) |
| Marketplace | TransactionTile | user / wallet / widgets | [transaction_tile.dart:5](../../apps/marketplace/lib/screens/user/wallet/widgets/transaction_tile.dart) |
| Marketplace | WalletBalanceCard | user / wallet / widgets | [wallet_balance_card.dart:4](../../apps/marketplace/lib/screens/user/wallet/widgets/wallet_balance_card.dart) |
| Marketplace | EmptyWishlist | user / wishlist / widgets | [empty_wishlist.dart:6](../../apps/marketplace/lib/screens/user/wishlist/widgets/empty_wishlist.dart) |
| Marketplace | WishlistItemCard | user / wishlist / widgets | [wishlist_item_card.dart:11](../../apps/marketplace/lib/screens/user/wishlist/widgets/wishlist_item_card.dart) |
| Seller | SellerSupportCard | account / widgets | [support_card.dart:11](../../apps/seller/lib/screens/account/widgets/support_card.dart) |
| Seller | _Bubble | ai | [seller_ai_chat_screen.dart:168](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) |
| Seller | _TypingBubble | ai | [seller_ai_chat_screen.dart:224](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) |
| Seller | _LegalLine | auth | [seller_sign_in_screen.dart:384](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) |
| Seller | _FormColumn | auth | [seller_sign_in_screen.dart:429](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) |
| Seller | AuthBrandPanel | auth / widgets | [auth_brand_panel.dart:8](../../apps/seller/lib/screens/auth/widgets/auth_brand_panel.dart) |
| Seller | AuthErrorBanner | auth / widgets | [auth_error_banner.dart:11](../../apps/seller/lib/screens/auth/widgets/auth_error_banner.dart) |
| Seller | AuthInlineError | auth / widgets | [auth_error_banner.dart:35](../../apps/seller/lib/screens/auth/widgets/auth_error_banner.dart) |
| Seller | ActionQueueCard | home / widgets | [home_widgets.dart:21](../../apps/seller/lib/screens/home/widgets/home_widgets.dart) |
| Seller | NotificationBell | notifications | [notifications_screen.dart:19](../../apps/seller/lib/screens/notifications/notifications_screen.dart) |
| Seller | StepBody | onboarding | [application_screen.dart:73](../../apps/seller/lib/screens/onboarding/application_screen.dart) |
| Seller | BusinessStep | onboarding / steps | [business_step.dart:13](../../apps/seller/lib/screens/onboarding/steps/business_step.dart) |
| Seller | DocumentsStep | onboarding / steps | [documents_step.dart:15](../../apps/seller/lib/screens/onboarding/steps/documents_step.dart) |
| Seller | _DocumentTile | onboarding / steps | [documents_step.dart:88](../../apps/seller/lib/screens/onboarding/steps/documents_step.dart) |
| Seller | LocationStep | onboarding / steps | [location_step.dart:14](../../apps/seller/lib/screens/onboarding/steps/location_step.dart) |
| Seller | PayoutStep | onboarding / steps | [payout_step.dart:15](../../apps/seller/lib/screens/onboarding/steps/payout_step.dart) |
| Seller | ReviewStep | onboarding / steps | [review_step.dart:16](../../apps/seller/lib/screens/onboarding/steps/review_step.dart) |
| Seller | StepFooter | onboarding / widgets | [step_footer.dart:8](../../apps/seller/lib/screens/onboarding/widgets/step_footer.dart) |
| Seller | ApplicationSignOut | onboarding / widgets | [step_footer.dart:40](../../apps/seller/lib/screens/onboarding/widgets/step_footer.dart) |
| Seller | _InvoiceBody | orders | [invoice_screen.dart:40](../../apps/seller/lib/screens/orders/invoice_screen.dart) |
| Seller | OrderStagePill | orders | [seller_orders_screen.dart:49](../../apps/seller/lib/screens/orders/seller_orders_screen.dart) |
| Seller | OrderCard | orders | [seller_orders_screen.dart:201](../../apps/seller/lib/screens/orders/seller_orders_screen.dart) |
| Seller | OrderInvoiceCard | orders / widgets | [order_invoice_card.dart:19](../../apps/seller/lib/screens/orders/widgets/order_invoice_card.dart) |
| Seller | SettlementRow | payments | [payments_screen.dart:169](../../apps/seller/lib/screens/payments/payments_screen.dart) |
| Seller | PaymentsBody | payments | [payments_screen.dart:195](../../apps/seller/lib/screens/payments/payments_screen.dart) |
| Seller | WalletSection | payments | [wallet.dart:208](../../apps/seller/lib/screens/payments/wallet.dart) |
| Seller | _BalanceCard | payments | [wallet.dart:366](../../apps/seller/lib/screens/payments/wallet.dart) |
| Seller | _OpenWithdrawalCard | payments | [wallet.dart:421](../../apps/seller/lib/screens/payments/wallet.dart) |
| Seller | _AccountCard | payments | [wallet.dart:455](../../apps/seller/lib/screens/payments/wallet.dart) |
| Seller | _WithdrawalRow | payments | [wallet.dart:513](../../apps/seller/lib/screens/payments/wallet.dart) |
| Seller | _ProductCard | products | [seller_products_screen.dart:277](../../apps/seller/lib/screens/products/seller_products_screen.dart) |
| Seller | ProductFilterBar | products / widgets | [product_list_controls.dart:18](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart) |
| Seller | ProductBulkBar | products / widgets | [product_list_controls.dart:39](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart) |
| Seller | ProductTaxSection | products / widgets | [product_tax_section.dart:17](../../apps/seller/lib/screens/products/widgets/product_tax_section.dart) |
| Seller | ProductVariantsSection | products / widgets | [product_variants_section.dart:14](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart) |
| Seller | SellerStars | reviews | [reviews_screen.dart:158](../../apps/seller/lib/screens/reviews/reviews_screen.dart) |
| Seller | _ReviewCard | reviews | [reviews_screen.dart:179](../../apps/seller/lib/screens/reviews/reviews_screen.dart) |
| Seller | _QuoteBody | rfq | [seller_rfq_detail_screen.dart:40](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart) |
| Seller | QuoteStatusPill | rfq / widgets | [quote_copy.dart:49](../../apps/seller/lib/screens/rfq/widgets/quote_copy.dart) |
| Seller | QuoteExpiryText | rfq / widgets | [quote_copy.dart:72](../../apps/seller/lib/screens/rfq/widgets/quote_copy.dart) |
| Seller | QuoteTile | rfq / widgets | [quote_tile.dart:10](../../apps/seller/lib/screens/rfq/widgets/quote_tile.dart) |
| Seller | StorefrontPreview | storefront | [storefront_editor_screen.dart:340](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) |
| Delivery | _HistoryRow | history | [rider_history_screen.dart:216](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _Hint | history | [rider_history_screen.dart:248](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _Footer | history | [rider_history_screen.dart:269](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _Empty | history | [rider_history_screen.dart:315](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _Filters | history | [rider_history_screen.dart:328](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _SearchResult | history | [rider_history_screen.dart:453](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | HistoryDetail | history | [rider_history_screen.dart:494](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _SectionHeading | history | [rider_history_screen.dart:721](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _StatementLink | history | [rider_history_screen.dart:738](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | _Line | history | [rider_history_screen.dart:833](../../apps/delivery/lib/screens/history/rider_history_screen.dart) |
| Delivery | ActiveWorkLoading | home | [active_work_states.dart:13](../../apps/delivery/lib/screens/home/active_work_states.dart) |
| Delivery | ActiveWorkError | home | [active_work_states.dart:33](../../apps/delivery/lib/screens/home/active_work_states.dart) |
| Delivery | MultipleActiveOrders | home | [active_work_states.dart:56](../../apps/delivery/lib/screens/home/active_work_states.dart) |
| Delivery | ActiveOrderSummaryCard | home | [active_work_states.dart:103](../../apps/delivery/lib/screens/home/active_work_states.dart) |
| Delivery | StaleDataBanner | home | [active_work_states.dart:177](../../apps/delivery/lib/screens/home/active_work_states.dart) |
| Delivery | _StatCard | home | [dashboard_screen.dart:624](../../apps/delivery/lib/screens/home/dashboard_screen.dart) |
| Delivery | _ActionCard | home | [dashboard_screen.dart:663](../../apps/delivery/lib/screens/home/dashboard_screen.dart) |
| Delivery | HomeAppBar | home | [home_app_bar.dart:19](../../apps/delivery/lib/screens/home/home_app_bar.dart) |
| Delivery | _AvailabilityToggle | home | [home_app_bar.dart:90](../../apps/delivery/lib/screens/home/home_app_bar.dart) |
| Delivery | _CircleIconButton | home | [home_app_bar.dart:165](../../apps/delivery/lib/screens/home/home_app_bar.dart) |
| Delivery | HomeMap | home | [home_map.dart:56](../../apps/delivery/lib/screens/home/home_map.dart) |
| Delivery | _StateBanner | home | [home_map.dart:260](../../apps/delivery/lib/screens/home/home_map.dart) |
| Delivery | _RecenterButton | home | [home_map.dart:312](../../apps/delivery/lib/screens/home/home_map.dart) |
| Delivery | HomeOperationsPanel | home | [home_operations_panel.dart:39](../../apps/delivery/lib/screens/home/home_operations_panel.dart) |
| Delivery | PendingProofBanner | home | [pending_proof_banner.dart:27](../../apps/delivery/lib/screens/home/pending_proof_banner.dart) |
| Delivery | _Centered | inbox | [inbox_screen.dart:612](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) |
| Delivery | InboxButton | inbox | [inbox_screen.dart:642](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) |
| Delivery | _Summary | money | [money_screen.dart:175](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _CashCard | money | [money_screen.dart:234](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | EarningTile | money | [money_screen.dart:306](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _PayoutTile | money | [money_screen.dart:355](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _PayoutDetails | money | [money_screen.dart:435](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _Heading | money | [money_screen.dart:530](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _Muted | money | [money_screen.dart:560](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _ErrorLine | money | [money_screen.dart:576](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | BankChangeForm | money | [money_screen.dart:595](../../apps/delivery/lib/screens/money/money_screen.dart) |
| Delivery | _AmountRow | money | [statement_screen.dart:349](../../apps/delivery/lib/screens/money/statement_screen.dart) |
| Delivery | _StageBlock | money | [statement_screen.dart:380](../../apps/delivery/lib/screens/money/statement_screen.dart) |
| Delivery | _Row | offers | [incoming_offer_screen.dart:266](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart) |
| Delivery | _Section | orders | [active_order_screen.dart:1245](../../apps/delivery/lib/screens/orders/active_order_screen.dart) |
| Delivery | DeliveryProblemPanel | orders | [delivery_problem_panel.dart:32](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) |
| Delivery | _ProblemState | orders | [delivery_problem_panel.dart:126](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) |
| Delivery | RiderRouteCard | orders / widgets | [rider_route_card.dart:51](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart) |
| Delivery | StaleLocationBanner | orders / widgets | [rider_route_card.dart:792](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart) |
| Delivery | RequestStatusCard | profile | [identity_change_screen.dart:265](../../apps/delivery/lib/screens/profile/identity_change_screen.dart) |
| Delivery | _Form | profile | [identity_change_screen.dart:305](../../apps/delivery/lib/screens/profile/identity_change_screen.dart) |
| Delivery | _DocumentPreviewTile | profile | [rider_profile_screen.dart:989](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) |
| Delivery | _Row | support | [help_sheet.dart:154](../../apps/delivery/lib/screens/support/help_sheet.dart) |
| Delivery | _Topic | support | [help_support_screen.dart:137](../../apps/delivery/lib/screens/support/help_support_screen.dart) |
| Delivery | _TicketRow | support | [my_support_requests_screen.dart:87](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart) |
| Delivery | _MessageState | support | [my_support_requests_screen.dart:135](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart) |
| Delivery | _Timeline | support | [support_request_status_screen.dart:67](../../apps/delivery/lib/screens/support/support_request_status_screen.dart) |
| Delivery | _Step | support | [support_request_status_screen.dart:122](../../apps/delivery/lib/screens/support/support_request_status_screen.dart) |
| Sales Associate | _NotificationBellButton | home | [dashboard_screen.dart:368](../../apps/employee/lib/screens/home/dashboard_screen.dart) |
| Sales Associate | _MetricCard | home | [dashboard_screen.dart:423](../../apps/employee/lib/screens/home/dashboard_screen.dart) |
| Sales Associate | _AssociateCodeCard | home | [dashboard_screen.dart:493](../../apps/employee/lib/screens/home/dashboard_screen.dart) |
| Sales Associate | _OnboardingFeeStatusCard | home | [dashboard_screen.dart:749](../../apps/employee/lib/screens/home/dashboard_screen.dart) |
| Sales Associate | _ActionTile | wallet | [wallet_screen.dart:458](../../apps/employee/lib/screens/wallet/wallet_screen.dart) |
| Admin | BannerCard | admin / banners | [banner_card.dart:7](../../apps/admin/lib/screens/admin/banners/banner_card.dart) |
| Admin | _SlotCard | admin / bestsellers | [bestseller_management_screen.dart:168](../../apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart) |
| Admin | _StatCard | admin / category_sections | [category_section_management_screen.dart:406](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| Admin | _PremiumSectionCard | admin / category_sections | [category_section_management_screen.dart:464](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| Admin | _ActionButton | admin / category_sections | [category_section_management_screen.dart:688](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| Admin | _ScheduleStatusChip | admin / category_sections | [category_section_management_screen.dart:736](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) |
| Admin | _PremiumCard | admin / category_sections | [edit_category_section_screen.dart:816](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) |
| Admin | _ImageSlot | admin / category_sections | [edit_category_section_screen.dart:883](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) |
| Admin | CouponCard | admin / coupon | [coupon_card.dart:8](../../apps/admin/lib/screens/admin/coupon/coupon_card.dart) |
| Admin | DeliveryFlagsCard | admin / delivery | [delivery_flags.dart:84](../../apps/admin/lib/screens/admin/delivery/delivery_flags.dart) |
| Admin | _PartnerCard | admin / delivery | [delivery_partner_management_screen.dart:399](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) |
| Admin | _ProblemList | admin / delivery | [delivery_problems_screen.dart:43](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) |
| Admin | _ProblemCard | admin / delivery | [delivery_problems_screen.dart:93](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) |
| Admin | _Message | admin / delivery | [dispatch_queue_screen.dart:167](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) |
| Admin | _DispatchCard | admin / delivery | [dispatch_queue_screen.dart:216](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) |
| Admin | _Tag | admin / delivery | [dispatch_queue_screen.dart:300](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) |
| Admin | _LedgerCard | admin / delivery | [rider_cash_ledger_screen.dart:77](../../apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart) |
| Admin | _HeaderCard | admin / delivery | [rider_detail_screen.dart:170](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _StatusChip | admin / delivery | [rider_detail_screen.dart:235](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _IdentityTab | admin / delivery | [rider_detail_screen.dart:257](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _AssignmentsTab | admin / delivery | [rider_detail_screen.dart:475](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _EarningsTab | admin / delivery | [rider_detail_screen.dart:525](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _EarningTile | admin / delivery | [rider_detail_screen.dart:559](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _CodCashTab | admin / delivery | [rider_detail_screen.dart:580](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _MetricCard | admin / delivery | [rider_detail_screen.dart:628](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _BankPayoutTab | admin / delivery | [rider_detail_screen.dart:656](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _SupportTab | admin / delivery | [rider_detail_screen.dart:803](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) |
| Admin | _IncidentList | admin / delivery | [rider_incidents_screen.dart:44](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) |
| Admin | _IncidentCard | admin / delivery | [rider_incidents_screen.dart:99](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) |
| Admin | _RiderLine | admin / delivery | [rider_payouts_screen.dart:97](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _StatementsTab | admin / delivery | [rider_payouts_screen.dart:173](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _CashTab | admin / delivery | [rider_payouts_screen.dart:388](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _BankChangesTab | admin / delivery | [rider_payouts_screen.dart:541](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _IdentityChangesTab | admin / delivery | [rider_payouts_screen.dart:689](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _StagedDocumentPreview | admin / delivery | [rider_payouts_screen.dart:839](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _DocumentReviewsTab | admin / delivery | [rider_payouts_screen.dart:885](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | _RatesTab | admin / delivery | [rider_payouts_screen.dart:1010](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) |
| Admin | RiderStatusBadge | admin / delivery | [rider_review_sheet.dart:36](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) |
| Admin | _KycTile | admin / delivery | [rider_review_sheet.dart:384](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) |
| Admin | _TicketList | admin / delivery | [rider_support_screen.dart:78](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) |
| Admin | _TicketCard | admin / delivery | [rider_support_screen.dart:132](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) |
| Admin | _HeaderCard | admin / employees | [associate_detail_screen.dart:169](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _StatusChip | admin / employees | [associate_detail_screen.dart:223](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _ProfileTab | admin / employees | [associate_detail_screen.dart:245](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _InfoTile | admin / employees | [associate_detail_screen.dart:343](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _AttributionTab | admin / employees | [associate_detail_screen.dart:380](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _CommissionTab | admin / employees | [associate_detail_screen.dart:430](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _WalletTab | admin / employees | [associate_detail_screen.dart:475](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _MetricCard | admin / employees | [associate_detail_screen.dart:545](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _BankPayoutTab | admin / employees | [associate_detail_screen.dart:573](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _SupportTab | admin / employees | [associate_detail_screen.dart:717](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) |
| Admin | _RequestCard | admin / employees | [employee_payout_account_review_screen.dart:144](../../apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart) |
| Admin | _EmployeeSummaryRow | admin / employees | [employee_payouts_screen.dart:425](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) |
| Admin | _MessageState | admin / employees | [employee_payouts_screen.dart:517](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) |
| Admin | _DeliveryProofTile | admin / orders | [admin_order_details_screen.dart:3015](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart) |
| Admin | AdminOrderCard | admin / orders / widgets | [admin_order_card.dart:7](../../apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart) |
| Admin | OrderStatusUpdater | admin / orders / widgets | [order_status_updater.dart:16](../../apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart) |
| Admin | AdminProductCard | admin / products / widgets | [admin_product_card.dart:7](../../apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart) |
| Admin | DeliveryInfoForm | admin / products / widgets | [delivery_info_form.dart:6](../../apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart) |
| Admin | ImageUploader | admin / products / widgets | [image_uploader.dart:12](../../apps/admin/lib/screens/admin/products/widgets/image_uploader.dart) |
| Admin | ProductForm | admin / products / widgets | [product_form.dart:10](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart) |
| Admin | SpecificationForm | admin / products / widgets | [specification_form.dart:6](../../apps/admin/lib/screens/admin/products/widgets/specification_form.dart) |
| Admin | StockManager | admin / products / widgets | [stock_manager.dart:6](../../apps/admin/lib/screens/admin/products/widgets/stock_manager.dart) |
| Admin | VariantForm | admin / products / widgets | [variant_form.dart:9](../../apps/admin/lib/screens/admin/products/widgets/variant_form.dart) |
| Admin | _SectionBannerCard | admin / section_banners | [section_banner_management_screen.dart:238](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) |
| Admin | _LogCard | admin / security | [payment_security_logs_screen.dart:75](../../apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart) |
| Admin | _ResultCard | admin / security | [verified_payment_lookup_screen.dart:112](../../apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart) |
| Admin | _HeaderCard | admin / sellers | [seller_detail_screen.dart:171](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _StatusChip | admin / sellers | [seller_detail_screen.dart:232](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _OverviewTab | admin / sellers | [seller_detail_screen.dart:254](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _SectionHeader | admin / sellers | [seller_detail_screen.dart:320](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _InfoTile | admin / sellers | [seller_detail_screen.dart:334](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _CatalogTab | admin / sellers | [seller_detail_screen.dart:372](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _OrdersTab | admin / sellers | [seller_detail_screen.dart:414](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _FinanceTab | admin / sellers | [seller_detail_screen.dart:452](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _MetricCard | admin / sellers | [seller_detail_screen.dart:553](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _BankPayoutTab | admin / sellers | [seller_detail_screen.dart:581](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _SupportTab | admin / sellers | [seller_detail_screen.dart:732](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) |
| Admin | _ApplicationDetails | admin / sellers | [seller_requests_management_screen.dart:250](../../apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart) |
| Admin | _SellerHeader | admin / sellers | [seller_wallet_admin.dart:194](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) |
| Admin | SellerWithdrawalsTab | admin / sellers | [seller_wallet_admin.dart:239](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) |
| Admin | SellerPayoutChangesTab | admin / sellers | [seller_wallet_admin.dart:395](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) |
| Admin | SponsoredBannerCard | admin / sponsored_banners | [sponsored_banner_card.dart:6](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_card.dart) |
| Admin | _CaseHeader | admin / support | [support_case_detail_screen.dart:327](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _NotesTab | admin / support | [support_case_detail_screen.dart:441](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _ActivityTab | admin / support | [support_case_detail_screen.dart:495](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _Timestamp | admin / support | [support_case_detail_screen.dart:550](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _LinkedRecordsTab | admin / support | [support_case_detail_screen.dart:717](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _LinkedRecordTile | admin / support | [support_case_detail_screen.dart:766](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _EvidenceTab | admin / support | [support_case_detail_screen.dart:931](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _EvidenceTile | admin / support | [support_case_detail_screen.dart:1124](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) |
| Admin | _CaseRow | admin / support | [support_queue_screen.dart:128](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) |
| Admin | _StatusDot | admin / support | [support_queue_screen.dart:179](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) |
| Admin | _HeaderCard | admin / users | [customer_detail_screen.dart:187](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _StatusChip | admin / users | [customer_detail_screen.dart:285](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _OverviewTab | admin / users | [customer_detail_screen.dart:308](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _OrdersTab | admin / users | [customer_detail_screen.dart:365](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _WalletTab | admin / users | [customer_detail_screen.dart:406](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _MetricCard | admin / users | [customer_detail_screen.dart:561](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _PaymentsTab | admin / users | [customer_detail_screen.dart:592](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _AddressesTab | admin / users | [customer_detail_screen.dart:645](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _SupportTab | admin / users | [customer_detail_screen.dart:701](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _SectionHeader | admin / users | [customer_detail_screen.dart:719](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | _InfoTile | admin / users | [customer_detail_screen.dart:733](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) |
| Admin | RoleBadge | admin / users / widgets | [role_badge.dart:4](../../apps/admin/lib/screens/admin/users/widgets/role_badge.dart) |
| Admin | UserCard | admin / users / widgets | [user_card.dart:8](../../apps/admin/lib/screens/admin/users/widgets/user_card.dart) |
| Admin | _SummaryCard | admin / wallet | [wallet_tracking_screen.dart:306](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) |
| Admin | _StatusPill | admin / wallet | [wallet_tracking_screen.dart:374](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) |
| Admin | _MessageState | admin / wallet | [wallet_tracking_screen.dart:399](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) |
| Admin | ActorSupportCasesSection | admin / widgets | [actor_support_cases_section.dart:22](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| Admin | _CaseTile | admin / widgets | [actor_support_cases_section.dart:100](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| Admin | OrderLinkedSupportCasesSection | admin / widgets | [actor_support_cases_section.dart:136](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) |
| Admin | SectionMessage | admin / widgets | [paginated_query_list.dart:13](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart) |
| Admin | PaginatedQueryList | admin / widgets | [paginated_query_list.dart:52](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart) |

## Every inspected app source file

The snapshot includes screen sources, roots, providers, services and supporting app logic. Source hashes and imports are retained in JSON; this index exposes paths and line counts only.

| App | Source file | Lines |
| --- | --- | --- |
| Marketplace | [apps/marketplace/lib/app/app.dart](../../apps/marketplace/lib/app/app.dart) | 113 |
| Marketplace | [apps/marketplace/lib/app/routes.dart](../../apps/marketplace/lib/app/routes.dart) | 890 |
| Marketplace | [apps/marketplace/lib/main.dart](../../apps/marketplace/lib/main.dart) | 390 |
| Marketplace | [apps/marketplace/lib/providers/address_provider.dart](../../apps/marketplace/lib/providers/address_provider.dart) | 264 |
| Marketplace | [apps/marketplace/lib/providers/ai_connection_provider.dart](../../apps/marketplace/lib/providers/ai_connection_provider.dart) | 122 |
| Marketplace | [apps/marketplace/lib/providers/auth_provider.dart](../../apps/marketplace/lib/providers/auth_provider.dart) | 1134 |
| Marketplace | [apps/marketplace/lib/providers/banner_provider.dart](../../apps/marketplace/lib/providers/banner_provider.dart) | 370 |
| Marketplace | [apps/marketplace/lib/providers/bestseller_provider.dart](../../apps/marketplace/lib/providers/bestseller_provider.dart) | 134 |
| Marketplace | [apps/marketplace/lib/providers/business_feed_provider.dart](../../apps/marketplace/lib/providers/business_feed_provider.dart) | 99 |
| Marketplace | [apps/marketplace/lib/providers/business_follow_provider.dart](../../apps/marketplace/lib/providers/business_follow_provider.dart) | 81 |
| Marketplace | [apps/marketplace/lib/providers/cart_provider.dart](../../apps/marketplace/lib/providers/cart_provider.dart) | 759 |
| Marketplace | [apps/marketplace/lib/providers/category_provider.dart](../../apps/marketplace/lib/providers/category_provider.dart) | 282 |
| Marketplace | [apps/marketplace/lib/providers/category_section_provider.dart](../../apps/marketplace/lib/providers/category_section_provider.dart) | 160 |
| Marketplace | [apps/marketplace/lib/providers/coupon_provider.dart](../../apps/marketplace/lib/providers/coupon_provider.dart) | 278 |
| Marketplace | [apps/marketplace/lib/providers/home_grocery_strip_config_provider.dart](../../apps/marketplace/lib/providers/home_grocery_strip_config_provider.dart) | 95 |
| Marketplace | [apps/marketplace/lib/providers/home_product_section_config_provider.dart](../../apps/marketplace/lib/providers/home_product_section_config_provider.dart) | 60 |
| Marketplace | [apps/marketplace/lib/providers/home_section_order_provider.dart](../../apps/marketplace/lib/providers/home_section_order_provider.dart) | 127 |
| Marketplace | [apps/marketplace/lib/providers/location_settings_provider.dart](../../apps/marketplace/lib/providers/location_settings_provider.dart) | 141 |
| Marketplace | [apps/marketplace/lib/providers/market_mode_provider.dart](../../apps/marketplace/lib/providers/market_mode_provider.dart) | 81 |
| Marketplace | [apps/marketplace/lib/providers/order_provider.dart](../../apps/marketplace/lib/providers/order_provider.dart) | 424 |
| Marketplace | [apps/marketplace/lib/providers/product_credit_provider.dart](../../apps/marketplace/lib/providers/product_credit_provider.dart) | 234 |
| Marketplace | [apps/marketplace/lib/providers/product_provider.dart](../../apps/marketplace/lib/providers/product_provider.dart) | 878 |
| Marketplace | [apps/marketplace/lib/providers/review_provider.dart](../../apps/marketplace/lib/providers/review_provider.dart) | 310 |
| Marketplace | [apps/marketplace/lib/providers/rfq_provider.dart](../../apps/marketplace/lib/providers/rfq_provider.dart) | 260 |
| Marketplace | [apps/marketplace/lib/providers/search_provider.dart](../../apps/marketplace/lib/providers/search_provider.dart) | 100 |
| Marketplace | [apps/marketplace/lib/providers/section_banner_provider.dart](../../apps/marketplace/lib/providers/section_banner_provider.dart) | 188 |
| Marketplace | [apps/marketplace/lib/providers/seller_provider.dart](../../apps/marketplace/lib/providers/seller_provider.dart) | 190 |
| Marketplace | [apps/marketplace/lib/providers/settings_provider.dart](../../apps/marketplace/lib/providers/settings_provider.dart) | 162 |
| Marketplace | [apps/marketplace/lib/providers/shop_entry_provider.dart](../../apps/marketplace/lib/providers/shop_entry_provider.dart) | 27 |
| Marketplace | [apps/marketplace/lib/providers/sponsored_banner_provider.dart](../../apps/marketplace/lib/providers/sponsored_banner_provider.dart) | 76 |
| Marketplace | [apps/marketplace/lib/providers/theme_provider.dart](../../apps/marketplace/lib/providers/theme_provider.dart) | 48 |
| Marketplace | [apps/marketplace/lib/providers/wallet_provider.dart](../../apps/marketplace/lib/providers/wallet_provider.dart) | 454 |
| Marketplace | [apps/marketplace/lib/providers/wishlist_provider.dart](../../apps/marketplace/lib/providers/wishlist_provider.dart) | 218 |
| Marketplace | [apps/marketplace/lib/screens/auth/auth_guard.dart](../../apps/marketplace/lib/screens/auth/auth_guard.dart) | 65 |
| Marketplace | [apps/marketplace/lib/screens/auth/auth_wrapper.dart](../../apps/marketplace/lib/screens/auth/auth_wrapper.dart) | 100 |
| Marketplace | [apps/marketplace/lib/screens/auth/complete_profile_screen.dart](../../apps/marketplace/lib/screens/auth/complete_profile_screen.dart) | 870 |
| Marketplace | [apps/marketplace/lib/screens/auth/enable_notifications_screen.dart](../../apps/marketplace/lib/screens/auth/enable_notifications_screen.dart) | 172 |
| Marketplace | [apps/marketplace/lib/screens/auth/login_screen.dart](../../apps/marketplace/lib/screens/auth/login_screen.dart) | 1251 |
| Marketplace | [apps/marketplace/lib/screens/auth/mobile_number_screen.dart](../../apps/marketplace/lib/screens/auth/mobile_number_screen.dart) | 543 |
| Marketplace | [apps/marketplace/lib/screens/auth/onboarding_address_screen.dart](../../apps/marketplace/lib/screens/auth/onboarding_address_screen.dart) | 1010 |
| Marketplace | [apps/marketplace/lib/screens/auth/post_auth_router.dart](../../apps/marketplace/lib/screens/auth/post_auth_router.dart) | 55 |
| Marketplace | [apps/marketplace/lib/screens/auth/signup_screen.dart](../../apps/marketplace/lib/screens/auth/signup_screen.dart) | 904 |
| Marketplace | [apps/marketplace/lib/screens/business/business_feed_screen.dart](../../apps/marketplace/lib/screens/business/business_feed_screen.dart) | 171 |
| Marketplace | [apps/marketplace/lib/screens/business/business_profile_screen.dart](../../apps/marketplace/lib/screens/business/business_profile_screen.dart) | 745 |
| Marketplace | [apps/marketplace/lib/screens/business/storefront_visibility.dart](../../apps/marketplace/lib/screens/business/storefront_visibility.dart) | 33 |
| Marketplace | [apps/marketplace/lib/screens/chat/ai_chat_screen.dart](../../apps/marketplace/lib/screens/chat/ai_chat_screen.dart) | 860 |
| Marketplace | [apps/marketplace/lib/screens/chat/chat_history_screen.dart](../../apps/marketplace/lib/screens/chat/chat_history_screen.dart) | 205 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/chat_app_bar.dart](../../apps/marketplace/lib/screens/chat/widgets/chat_app_bar.dart) | 128 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/chat_message_widget.dart](../../apps/marketplace/lib/screens/chat/widgets/chat_message_widget.dart) | 473 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/message_bubble.dart](../../apps/marketplace/lib/screens/chat/widgets/message_bubble.dart) | 431 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/message_list_view.dart](../../apps/marketplace/lib/screens/chat/widgets/message_list_view.dart) | 97 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/order_card_renderer.dart](../../apps/marketplace/lib/screens/chat/widgets/order_card_renderer.dart) | 117 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/product_card_horizontal.dart](../../apps/marketplace/lib/screens/chat/widgets/product_card_horizontal.dart) | 68 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/product_card_widget.dart](../../apps/marketplace/lib/screens/chat/widgets/product_card_widget.dart) | 53 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/quick_reply_chip.dart](../../apps/marketplace/lib/screens/chat/widgets/quick_reply_chip.dart) | 65 |
| Marketplace | [apps/marketplace/lib/screens/chat/widgets/typing_indicator.dart](../../apps/marketplace/lib/screens/chat/widgets/typing_indicator.dart) | 82 |
| Marketplace | [apps/marketplace/lib/screens/employee/employee_apply_screen.dart](../../apps/marketplace/lib/screens/employee/employee_apply_screen.dart) | 436 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart](../../apps/marketplace/lib/screens/employee/onboarding/associate_onboarding_screen.dart) | 442 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_confirmation_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_confirmation_step.dart) | 227 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_details_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_details_step.dart) | 189 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_fee_text.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_fee_text.dart) | 28 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_info_sections.dart) | 524 |
| Marketplace | [apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart](../../apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart) | 496 |
| Marketplace | [apps/marketplace/lib/screens/landing/landing_screen.dart](../../apps/marketplace/lib/screens/landing/landing_screen.dart) | 1109 |
| Marketplace | [apps/marketplace/lib/screens/legal/privacy_policy_screen.dart](../../apps/marketplace/lib/screens/legal/privacy_policy_screen.dart) | 260 |
| Marketplace | [apps/marketplace/lib/screens/legal/terms_screen.dart](../../apps/marketplace/lib/screens/legal/terms_screen.dart) | 235 |
| Marketplace | [apps/marketplace/lib/screens/not_found_screen.dart](../../apps/marketplace/lib/screens/not_found_screen.dart) | 569 |
| Marketplace | [apps/marketplace/lib/screens/onboarding/onboarding_screen.dart](../../apps/marketplace/lib/screens/onboarding/onboarding_screen.dart) | 231 |
| Marketplace | [apps/marketplace/lib/screens/seller/seller_handoff_screen.dart](../../apps/marketplace/lib/screens/seller/seller_handoff_screen.dart) | 84 |
| Marketplace | [apps/marketplace/lib/screens/splash/splash_screen.dart](../../apps/marketplace/lib/screens/splash/splash_screen.dart) | 15 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/blinkit_coupon_screen.dart](../../apps/marketplace/lib/screens/user/cart/blinkit_coupon_screen.dart) | 585 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/cart_screen.dart) | 30 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/coupon_selection_screen.dart](../../apps/marketplace/lib/screens/user/cart/coupon_selection_screen.dart) | 856 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/mobile_cart_screen.dart) | 3762 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/web_cart_screen.dart](../../apps/marketplace/lib/screens/user/cart/web_cart_screen.dart) | 613 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_item_card.dart) | 550 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart](../../apps/marketplace/lib/screens/user/cart/widgets/cart_summary.dart) | 375 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart](../../apps/marketplace/lib/screens/user/cart/widgets/empty_cart.dart) | 414 |
| Marketplace | [apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart](../../apps/marketplace/lib/screens/user/cart/widgets/quantity_selector.dart) | 296 |
| Marketplace | [apps/marketplace/lib/screens/user/categories/categories_screen.dart](../../apps/marketplace/lib/screens/user/categories/categories_screen.dart) | 1818 |
| Marketplace | [apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart](../../apps/marketplace/lib/screens/user/categories/widgets/category_content_sections.dart) | 321 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/add_address_screen.dart](../../apps/marketplace/lib/screens/user/checkout/add_address_screen.dart) | 2696 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/checkout_screen.dart](../../apps/marketplace/lib/screens/user/checkout/checkout_screen.dart) | 814 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/order_success_screen.dart](../../apps/marketplace/lib/screens/user/checkout/order_success_screen.dart) | 933 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/payment_method_screen.dart](../../apps/marketplace/lib/screens/user/checkout/payment_method_screen.dart) | 2002 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/associate_code_field.dart) | 448 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/widgets/checkout_steps.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/checkout_steps.dart) | 161 |
| Marketplace | [apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart](../../apps/marketplace/lib/screens/user/checkout/widgets/saved_checkout_card.dart) | 80 |
| Marketplace | [apps/marketplace/lib/screens/user/flash_sale/flash_sale_screen.dart](../../apps/marketplace/lib/screens/user/flash_sale/flash_sale_screen.dart) | 266 |
| Marketplace | [apps/marketplace/lib/screens/user/help/help_screen.dart](../../apps/marketplace/lib/screens/user/help/help_screen.dart) | 340 |
| Marketplace | [apps/marketplace/lib/screens/user/home/home_screen.dart](../../apps/marketplace/lib/screens/user/home/home_screen.dart) | 18 |
| Marketplace | [apps/marketplace/lib/screens/user/home/mobile_home_screen.dart](../../apps/marketplace/lib/screens/user/home/mobile_home_screen.dart) | 1009 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/search_results_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_results_screen.dart) | 435 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/search_screen.dart](../../apps/marketplace/lib/screens/user/home/search/search_screen.dart) | 1026 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/recent_searches.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/recent_searches.dart) | 210 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/search_bar_widget.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_bar_widget.dart) | 111 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart) | 360 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/search_product_card.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_product_card.dart) | 28 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/search_suggestions.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_suggestions.dart) | 117 |
| Marketplace | [apps/marketplace/lib/screens/user/home/search/widgets/trending_searches.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/trending_searches.dart) | 218 |
| Marketplace | [apps/marketplace/lib/screens/user/home/web_home_screen.dart](../../apps/marketplace/lib/screens/user/home/web_home_screen.dart) | 1325 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/home/widgets/address_bottom_sheet.dart) | 622 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/all_products_grid.dart](../../apps/marketplace/lib/screens/user/home/widgets/all_products_grid.dart) | 257 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/banner_slider.dart](../../apps/marketplace/lib/screens/user/home/widgets/banner_slider.dart) | 299 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart](../../apps/marketplace/lib/screens/user/home/widgets/bestsellers.dart) | 437 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/categories_grid.dart](../../apps/marketplace/lib/screens/user/home/widgets/categories_grid.dart) | 363 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart](../../apps/marketplace/lib/screens/user/home/widgets/dynamic_category_sections.dart) | 468 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/featured_products.dart](../../apps/marketplace/lib/screens/user/home/widgets/featured_products.dart) | 192 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart](../../apps/marketplace/lib/screens/user/home/widgets/grocery_kitchen_home_strip.dart) | 209 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart](../../apps/marketplace/lib/screens/user/home/widgets/home_app_bar.dart) | 721 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/home_search_bar.dart](../../apps/marketplace/lib/screens/user/home/widgets/home_search_bar.dart) | 84 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_card_compact.dart) | 507 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart](../../apps/marketplace/lib/screens/user/home/widgets/product_section_widget.dart) | 221 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/recently_viewed_widget.dart](../../apps/marketplace/lib/screens/user/home/widgets/recently_viewed_widget.dart) | 301 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart](../../apps/marketplace/lib/screens/user/home/widgets/section_banner_carousel.dart) | 280 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart](../../apps/marketplace/lib/screens/user/home/widgets/sponsored_banner_strip.dart) | 233 |
| Marketplace | [apps/marketplace/lib/screens/user/home/widgets/trending_products.dart](../../apps/marketplace/lib/screens/user/home/widgets/trending_products.dart) | 191 |
| Marketplace | [apps/marketplace/lib/screens/user/main_screen.dart](../../apps/marketplace/lib/screens/user/main_screen.dart) | 800 |
| Marketplace | [apps/marketplace/lib/screens/user/notifications/notifications_screen.dart](../../apps/marketplace/lib/screens/user/notifications/notifications_screen.dart) | 253 |
| Marketplace | [apps/marketplace/lib/screens/user/offers/offers_screen.dart](../../apps/marketplace/lib/screens/user/offers/offers_screen.dart) | 284 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart](../../apps/marketplace/lib/screens/user/orders/live_tracking_screen.dart) | 817 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/order_details_screen.dart](../../apps/marketplace/lib/screens/user/orders/order_details_screen.dart) | 2538 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/order_tracking_screen.dart](../../apps/marketplace/lib/screens/user/orders/order_tracking_screen.dart) | 695 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/orders_screen.dart](../../apps/marketplace/lib/screens/user/orders/orders_screen.dart) | 1296 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/rate_order_screen.dart](../../apps/marketplace/lib/screens/user/orders/rate_order_screen.dart) | 325 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/delivered_view.dart](../../apps/marketplace/lib/screens/user/orders/widgets/delivered_view.dart) | 160 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart](../../apps/marketplace/lib/screens/user/orders/widgets/empty_orders.dart) | 127 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart](../../apps/marketplace/lib/screens/user/orders/widgets/live_eta_text.dart) | 201 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/order_card.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_card.dart) | 148 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/order_item_card.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_item_card.dart) | 114 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/order_status_badge.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_status_badge.dart) | 157 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/order_timeline.dart](../../apps/marketplace/lib/screens/user/orders/widgets/order_timeline.dart) | 149 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/tracking_map.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_map.dart) | 149 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/tracking_marker_icons.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_marker_icons.dart) | 56 |
| Marketplace | [apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart](../../apps/marketplace/lib/screens/user/orders/widgets/tracking_sections.dart) | 480 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/change_email_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_email_screen.dart) | 564 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/change_password_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_password_screen.dart) | 721 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/change_phone_screen.dart](../../apps/marketplace/lib/screens/user/profile/change_phone_screen.dart) | 573 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/delete_account_screen.dart](../../apps/marketplace/lib/screens/user/profile/delete_account_screen.dart) | 398 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/edit_profile_screen.dart) | 1440 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/profile_screen.dart](../../apps/marketplace/lib/screens/user/profile/profile_screen.dart) | 1479 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart](../../apps/marketplace/lib/screens/user/profile/saved_addresses_screen.dart) | 835 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/settings_screen.dart](../../apps/marketplace/lib/screens/user/profile/settings_screen.dart) | 786 |
| Marketplace | [apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart](../../apps/marketplace/lib/screens/user/profile/widgets/verification_flow_widgets.dart) | 534 |
| Marketplace | [apps/marketplace/lib/screens/user/rewards/rewards_screen.dart](../../apps/marketplace/lib/screens/user/rewards/rewards_screen.dart) | 371 |
| Marketplace | [apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart](../../apps/marketplace/lib/screens/user/rfq/my_rfqs_screen.dart) | 162 |
| Marketplace | [apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart](../../apps/marketplace/lib/screens/user/rfq/rfq_detail_screen.dart) | 412 |
| Marketplace | [apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart](../../apps/marketplace/lib/screens/user/rfq/widgets/request_quote_sheet.dart) | 156 |
| Marketplace | [apps/marketplace/lib/screens/user/search/mobile_search_screen.dart](../../apps/marketplace/lib/screens/user/search/mobile_search_screen.dart) | 760 |
| Marketplace | [apps/marketplace/lib/screens/user/search/search_screen.dart](../../apps/marketplace/lib/screens/user/search/search_screen.dart) | 18 |
| Marketplace | [apps/marketplace/lib/screens/user/search/web_search_screen.dart](../../apps/marketplace/lib/screens/user/search/web_search_screen.dart) | 13 |
| Marketplace | [apps/marketplace/lib/screens/user/settings/language_screen.dart](../../apps/marketplace/lib/screens/user/settings/language_screen.dart) | 137 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/mobile_shop_screen.dart) | 1468 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/product_details_screen.dart](../../apps/marketplace/lib/screens/user/shop/product_details_screen.dart) | 1799 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/shop_screen.dart) | 54 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/web_shop_screen.dart](../../apps/marketplace/lib/screens/user/shop/web_shop_screen.dart) | 292 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart](../../apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart) | 723 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart](../../apps/marketplace/lib/screens/user/shop/widgets/delivery_info_widget.dart) | 268 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart](../../apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart) | 679 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_card.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_card.dart) | 34 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_grid.dart) | 39 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_image_hero.dart) | 241 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_info_section.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_info_section.dart) | 193 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_list.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_list.dart) | 24 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart](../../apps/marketplace/lib/screens/user/shop/widgets/product_share_widget.dart) | 599 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/review_card.dart](../../apps/marketplace/lib/screens/user/shop/widgets/review_card.dart) | 445 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/review_feed.dart](../../apps/marketplace/lib/screens/user/shop/widgets/review_feed.dart) | 109 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section.dart) | 303 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart](../../apps/marketplace/lib/screens/user/shop/widgets/reviews_section_inline.dart) | 404 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart](../../apps/marketplace/lib/screens/user/shop/widgets/shop_app_bar.dart) | 638 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart) | 221 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart](../../apps/marketplace/lib/screens/user/shop/widgets/specification_list.dart) | 72 |
| Marketplace | [apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart](../../apps/marketplace/lib/screens/user/shop/widgets/variant_selector.dart) | 159 |
| Marketplace | [apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart](../../apps/marketplace/lib/screens/user/subscriptions/my_subscriptions_screen.dart) | 261 |
| Marketplace | [apps/marketplace/lib/screens/user/subscriptions/subscription_setup_screen.dart](../../apps/marketplace/lib/screens/user/subscriptions/subscription_setup_screen.dart) | 289 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/add_money_screen.dart](../../apps/marketplace/lib/screens/user/wallet/add_money_screen.dart) | 677 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/product_credit_screen.dart](../../apps/marketplace/lib/screens/user/wallet/product_credit_screen.dart) | 218 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/referral_screen.dart](../../apps/marketplace/lib/screens/user/wallet/referral_screen.dart) | 655 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/transaction_history_screen.dart](../../apps/marketplace/lib/screens/user/wallet/transaction_history_screen.dart) | 216 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/wallet_screen.dart](../../apps/marketplace/lib/screens/user/wallet/wallet_screen.dart) | 431 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_card.dart) | 212 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/widgets/product_credit_ledger_tile.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/product_credit_ledger_tile.dart) | 238 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/widgets/transaction_tile.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/transaction_tile.dart) | 104 |
| Marketplace | [apps/marketplace/lib/screens/user/wallet/widgets/wallet_balance_card.dart](../../apps/marketplace/lib/screens/user/wallet/widgets/wallet_balance_card.dart) | 160 |
| Marketplace | [apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/mobile_wishlist_screen.dart) | 565 |
| Marketplace | [apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/web_wishlist_screen.dart) | 314 |
| Marketplace | [apps/marketplace/lib/screens/user/wishlist/widgets/empty_wishlist.dart](../../apps/marketplace/lib/screens/user/wishlist/widgets/empty_wishlist.dart) | 287 |
| Marketplace | [apps/marketplace/lib/screens/user/wishlist/widgets/wishlist_item_card.dart](../../apps/marketplace/lib/screens/user/wishlist/widgets/wishlist_item_card.dart) | 299 |
| Marketplace | [apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart](../../apps/marketplace/lib/screens/user/wishlist/wishlist_screen.dart) | 18 |
| Marketplace | [apps/marketplace/lib/services/associate_application_service.dart](../../apps/marketplace/lib/services/associate_application_service.dart) | 85 |
| Marketplace | [apps/marketplace/lib/services/checkout_recovery_service.dart](../../apps/marketplace/lib/services/checkout_recovery_service.dart) | 497 |
| Marketplace | [apps/marketplace/lib/services/checkout_request_store.dart](../../apps/marketplace/lib/services/checkout_request_store.dart) | 8 |
| Marketplace | [apps/marketplace/lib/services/checkout_request_store_file.dart](../../apps/marketplace/lib/services/checkout_request_store_file.dart) | 72 |
| Marketplace | [apps/marketplace/lib/services/checkout_request_store_stub.dart](../../apps/marketplace/lib/services/checkout_request_store_stub.dart) | 8 |
| Marketplace | [apps/marketplace/lib/services/delivery_tracking_service.dart](../../apps/marketplace/lib/services/delivery_tracking_service.dart) | 250 |
| Marketplace | [apps/marketplace/lib/services/mobile_checkout_confirmation.dart](../../apps/marketplace/lib/services/mobile_checkout_confirmation.dart) | 49 |
| Marketplace | [apps/marketplace/lib/services/mobile_checkout_flow.dart](../../apps/marketplace/lib/services/mobile_checkout_flow.dart) | 333 |
| Marketplace | [apps/marketplace/lib/services/native_payment_flight.dart](../../apps/marketplace/lib/services/native_payment_flight.dart) | 16 |
| Marketplace | [apps/marketplace/lib/services/order_rating_service.dart](../../apps/marketplace/lib/services/order_rating_service.dart) | 94 |
| Marketplace | [apps/marketplace/lib/services/payment_checkout_order.dart](../../apps/marketplace/lib/services/payment_checkout_order.dart) | 45 |
| Marketplace | [apps/marketplace/lib/services/razorpay_flutter_stub.dart](../../apps/marketplace/lib/services/razorpay_flutter_stub.dart) | 31 |
| Marketplace | [apps/marketplace/lib/services/razorpay_service.dart](../../apps/marketplace/lib/services/razorpay_service.dart) | 715 |
| Marketplace | [apps/marketplace/lib/services/razorpay_stub.dart](../../apps/marketplace/lib/services/razorpay_stub.dart) | 53 |
| Marketplace | [apps/marketplace/lib/services/razorpay_web.dart](../../apps/marketplace/lib/services/razorpay_web.dart) | 315 |
| Marketplace | [apps/marketplace/lib/services/wallet_topup_flow.dart](../../apps/marketplace/lib/services/wallet_topup_flow.dart) | 246 |
| Marketplace | [apps/marketplace/lib/services/wallet_topup_recovery_service.dart](../../apps/marketplace/lib/services/wallet_topup_recovery_service.dart) | 404 |
| Marketplace | [apps/marketplace/lib/utils/web_url_helper.dart](../../apps/marketplace/lib/utils/web_url_helper.dart) | 6 |
| Marketplace | [apps/marketplace/lib/utils/web_url_helper_stub.dart](../../apps/marketplace/lib/utils/web_url_helper_stub.dart) | 19 |
| Marketplace | [apps/marketplace/lib/utils/web_url_helper_web.dart](../../apps/marketplace/lib/utils/web_url_helper_web.dart) | 29 |
| Marketplace | [apps/marketplace/lib/widgets/auth_gate.dart](../../apps/marketplace/lib/widgets/auth_gate.dart) | 300 |
| Marketplace | [apps/marketplace/lib/widgets/cart_fly_animation.dart](../../apps/marketplace/lib/widgets/cart_fly_animation.dart) | 186 |
| Marketplace | [apps/marketplace/lib/widgets/category/category_card.dart](../../apps/marketplace/lib/widgets/category/category_card.dart) | 50 |
| Marketplace | [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart) | 2132 |
| Seller | [apps/seller/lib/app/app.dart](../../apps/seller/lib/app/app.dart) | 101 |
| Seller | [apps/seller/lib/app/emulator.dart](../../apps/seller/lib/app/emulator.dart) | 34 |
| Seller | [apps/seller/lib/design_system/components/seller_badge.dart](../../apps/seller/lib/design_system/components/seller_badge.dart) | 103 |
| Seller | [apps/seller/lib/design_system/components/seller_banner.dart](../../apps/seller/lib/design_system/components/seller_banner.dart) | 118 |
| Seller | [apps/seller/lib/design_system/components/seller_brand.dart](../../apps/seller/lib/design_system/components/seller_brand.dart) | 370 |
| Seller | [apps/seller/lib/design_system/components/seller_button.dart](../../apps/seller/lib/design_system/components/seller_button.dart) | 427 |
| Seller | [apps/seller/lib/design_system/components/seller_card.dart](../../apps/seller/lib/design_system/components/seller_card.dart) | 143 |
| Seller | [apps/seller/lib/design_system/components/seller_charts.dart](../../apps/seller/lib/design_system/components/seller_charts.dart) | 1112 |
| Seller | [apps/seller/lib/design_system/components/seller_chips.dart](../../apps/seller/lib/design_system/components/seller_chips.dart) | 268 |
| Seller | [apps/seller/lib/design_system/components/seller_feedback.dart](../../apps/seller/lib/design_system/components/seller_feedback.dart) | 291 |
| Seller | [apps/seller/lib/design_system/components/seller_fields.dart](../../apps/seller/lib/design_system/components/seller_fields.dart) | 1089 |
| Seller | [apps/seller/lib/design_system/components/seller_layout.dart](../../apps/seller/lib/design_system/components/seller_layout.dart) | 338 |
| Seller | [apps/seller/lib/design_system/components/seller_list.dart](../../apps/seller/lib/design_system/components/seller_list.dart) | 291 |
| Seller | [apps/seller/lib/design_system/components/seller_media.dart](../../apps/seller/lib/design_system/components/seller_media.dart) | 215 |
| Seller | [apps/seller/lib/design_system/components/seller_metrics.dart](../../apps/seller/lib/design_system/components/seller_metrics.dart) | 257 |
| Seller | [apps/seller/lib/design_system/components/seller_nav.dart](../../apps/seller/lib/design_system/components/seller_nav.dart) | 330 |
| Seller | [apps/seller/lib/design_system/components/seller_otp.dart](../../apps/seller/lib/design_system/components/seller_otp.dart) | 173 |
| Seller | [apps/seller/lib/design_system/components/seller_search.dart](../../apps/seller/lib/design_system/components/seller_search.dart) | 62 |
| Seller | [apps/seller/lib/design_system/components/seller_states.dart](../../apps/seller/lib/design_system/components/seller_states.dart) | 285 |
| Seller | [apps/seller/lib/design_system/components/seller_timeline.dart](../../apps/seller/lib/design_system/components/seller_timeline.dart) | 303 |
| Seller | [apps/seller/lib/design_system/design_system.dart](../../apps/seller/lib/design_system/design_system.dart) | 32 |
| Seller | [apps/seller/lib/design_system/format/seller_format.dart](../../apps/seller/lib/design_system/format/seller_format.dart) | 128 |
| Seller | [apps/seller/lib/design_system/icons/seller_account_icon.dart](../../apps/seller/lib/design_system/icons/seller_account_icon.dart) | 63 |
| Seller | [apps/seller/lib/design_system/icons/seller_icons.dart](../../apps/seller/lib/design_system/icons/seller_icons.dart) | 143 |
| Seller | [apps/seller/lib/design_system/theme/seller_focus.dart](../../apps/seller/lib/design_system/theme/seller_focus.dart) | 87 |
| Seller | [apps/seller/lib/design_system/theme/seller_theme.dart](../../apps/seller/lib/design_system/theme/seller_theme.dart) | 462 |
| Seller | [apps/seller/lib/design_system/tokens/seller_colors.dart](../../apps/seller/lib/design_system/tokens/seller_colors.dart) | 317 |
| Seller | [apps/seller/lib/design_system/tokens/seller_motion.dart](../../apps/seller/lib/design_system/tokens/seller_motion.dart) | 29 |
| Seller | [apps/seller/lib/design_system/tokens/seller_tokens.dart](../../apps/seller/lib/design_system/tokens/seller_tokens.dart) | 153 |
| Seller | [apps/seller/lib/design_system/tokens/seller_typography.dart](../../apps/seller/lib/design_system/tokens/seller_typography.dart) | 69 |
| Seller | [apps/seller/lib/main.dart](../../apps/seller/lib/main.dart) | 63 |
| Seller | [apps/seller/lib/providers/rfq_provider.dart](../../apps/seller/lib/providers/rfq_provider.dart) | 128 |
| Seller | [apps/seller/lib/providers/seller_ai_chat_provider.dart](../../apps/seller/lib/providers/seller_ai_chat_provider.dart) | 375 |
| Seller | [apps/seller/lib/providers/seller_ai_connection_provider.dart](../../apps/seller/lib/providers/seller_ai_connection_provider.dart) | 157 |
| Seller | [apps/seller/lib/providers/seller_application_provider.dart](../../apps/seller/lib/providers/seller_application_provider.dart) | 248 |
| Seller | [apps/seller/lib/providers/seller_auth_provider.dart](../../apps/seller/lib/providers/seller_auth_provider.dart) | 661 |
| Seller | [apps/seller/lib/providers/seller_order_provider.dart](../../apps/seller/lib/providers/seller_order_provider.dart) | 239 |
| Seller | [apps/seller/lib/providers/seller_post_provider.dart](../../apps/seller/lib/providers/seller_post_provider.dart) | 74 |
| Seller | [apps/seller/lib/providers/seller_product_provider.dart](../../apps/seller/lib/providers/seller_product_provider.dart) | 405 |
| Seller | [apps/seller/lib/providers/seller_settings_provider.dart](../../apps/seller/lib/providers/seller_settings_provider.dart) | 45 |
| Seller | [apps/seller/lib/screens/account/help_screen.dart](../../apps/seller/lib/screens/account/help_screen.dart) | 66 |
| Seller | [apps/seller/lib/screens/account/notification_prefs.dart](../../apps/seller/lib/screens/account/notification_prefs.dart) | 52 |
| Seller | [apps/seller/lib/screens/account/notification_settings_screen.dart](../../apps/seller/lib/screens/account/notification_settings_screen.dart) | 169 |
| Seller | [apps/seller/lib/screens/account/policies_screen.dart](../../apps/seller/lib/screens/account/policies_screen.dart) | 62 |
| Seller | [apps/seller/lib/screens/account/settings_screen.dart](../../apps/seller/lib/screens/account/settings_screen.dart) | 83 |
| Seller | [apps/seller/lib/screens/account/store_schedule.dart](../../apps/seller/lib/screens/account/store_schedule.dart) | 244 |
| Seller | [apps/seller/lib/screens/account/store_status.dart](../../apps/seller/lib/screens/account/store_status.dart) | 106 |
| Seller | [apps/seller/lib/screens/account/widgets/support_card.dart](../../apps/seller/lib/screens/account/widgets/support_card.dart) | 58 |
| Seller | [apps/seller/lib/screens/ai/seller_ai_chat_screen.dart](../../apps/seller/lib/screens/ai/seller_ai_chat_screen.dart) | 239 |
| Seller | [apps/seller/lib/screens/auth/account_restricted_screen.dart](../../apps/seller/lib/screens/auth/account_restricted_screen.dart) | 60 |
| Seller | [apps/seller/lib/screens/auth/application_status_screen.dart](../../apps/seller/lib/screens/auth/application_status_screen.dart) | 74 |
| Seller | [apps/seller/lib/screens/auth/email_sign_in_screen.dart](../../apps/seller/lib/screens/auth/email_sign_in_screen.dart) | 164 |
| Seller | [apps/seller/lib/screens/auth/seller_sign_in_screen.dart](../../apps/seller/lib/screens/auth/seller_sign_in_screen.dart) | 447 |
| Seller | [apps/seller/lib/screens/auth/widgets/auth_brand_panel.dart](../../apps/seller/lib/screens/auth/widgets/auth_brand_panel.dart) | 58 |
| Seller | [apps/seller/lib/screens/auth/widgets/auth_error_banner.dart](../../apps/seller/lib/screens/auth/widgets/auth_error_banner.dart) | 55 |
| Seller | [apps/seller/lib/screens/home/add_product_screen.dart](../../apps/seller/lib/screens/home/add_product_screen.dart) | 1349 |
| Seller | [apps/seller/lib/screens/home/dashboard_screen.dart](../../apps/seller/lib/screens/home/dashboard_screen.dart) | 455 |
| Seller | [apps/seller/lib/screens/home/home_stats.dart](../../apps/seller/lib/screens/home/home_stats.dart) | 127 |
| Seller | [apps/seller/lib/screens/home/widgets/home_widgets.dart](../../apps/seller/lib/screens/home/widgets/home_widgets.dart) | 58 |
| Seller | [apps/seller/lib/screens/insights/health_screen.dart](../../apps/seller/lib/screens/insights/health_screen.dart) | 109 |
| Seller | [apps/seller/lib/screens/insights/insights_rules.dart](../../apps/seller/lib/screens/insights/insights_rules.dart) | 149 |
| Seller | [apps/seller/lib/screens/insights/insights_screen.dart](../../apps/seller/lib/screens/insights/insights_screen.dart) | 283 |
| Seller | [apps/seller/lib/screens/notifications/inbox_rules.dart](../../apps/seller/lib/screens/notifications/inbox_rules.dart) | 89 |
| Seller | [apps/seller/lib/screens/notifications/notifications_screen.dart](../../apps/seller/lib/screens/notifications/notifications_screen.dart) | 243 |
| Seller | [apps/seller/lib/screens/onboarding/application_rules.dart](../../apps/seller/lib/screens/onboarding/application_rules.dart) | 88 |
| Seller | [apps/seller/lib/screens/onboarding/application_screen.dart](../../apps/seller/lib/screens/onboarding/application_screen.dart) | 124 |
| Seller | [apps/seller/lib/screens/onboarding/apply_intro_screen.dart](../../apps/seller/lib/screens/onboarding/apply_intro_screen.dart) | 93 |
| Seller | [apps/seller/lib/screens/onboarding/steps/business_step.dart](../../apps/seller/lib/screens/onboarding/steps/business_step.dart) | 114 |
| Seller | [apps/seller/lib/screens/onboarding/steps/documents_step.dart](../../apps/seller/lib/screens/onboarding/steps/documents_step.dart) | 156 |
| Seller | [apps/seller/lib/screens/onboarding/steps/location_step.dart](../../apps/seller/lib/screens/onboarding/steps/location_step.dart) | 180 |
| Seller | [apps/seller/lib/screens/onboarding/steps/payout_step.dart](../../apps/seller/lib/screens/onboarding/steps/payout_step.dart) | 149 |
| Seller | [apps/seller/lib/screens/onboarding/steps/review_step.dart](../../apps/seller/lib/screens/onboarding/steps/review_step.dart) | 122 |
| Seller | [apps/seller/lib/screens/onboarding/widgets/application_copy.dart](../../apps/seller/lib/screens/onboarding/widgets/application_copy.dart) | 43 |
| Seller | [apps/seller/lib/screens/onboarding/widgets/step_footer.dart](../../apps/seller/lib/screens/onboarding/widgets/step_footer.dart) | 65 |
| Seller | [apps/seller/lib/screens/orders/invoice_screen.dart](../../apps/seller/lib/screens/orders/invoice_screen.dart) | 166 |
| Seller | [apps/seller/lib/screens/orders/order_stage.dart](../../apps/seller/lib/screens/orders/order_stage.dart) | 92 |
| Seller | [apps/seller/lib/screens/orders/seller_order_detail_screen.dart](../../apps/seller/lib/screens/orders/seller_order_detail_screen.dart) | 273 |
| Seller | [apps/seller/lib/screens/orders/seller_orders_screen.dart](../../apps/seller/lib/screens/orders/seller_orders_screen.dart) | 248 |
| Seller | [apps/seller/lib/screens/orders/widgets/order_invoice_card.dart](../../apps/seller/lib/screens/orders/widgets/order_invoice_card.dart) | 155 |
| Seller | [apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart](../../apps/seller/lib/screens/orders/widgets/order_reason_sheet.dart) | 145 |
| Seller | [apps/seller/lib/screens/payments/payments_screen.dart](../../apps/seller/lib/screens/payments/payments_screen.dart) | 441 |
| Seller | [apps/seller/lib/screens/payments/statements.dart](../../apps/seller/lib/screens/payments/statements.dart) | 120 |
| Seller | [apps/seller/lib/screens/payments/wallet.dart](../../apps/seller/lib/screens/payments/wallet.dart) | 714 |
| Seller | [apps/seller/lib/screens/posts/create_post_screen.dart](../../apps/seller/lib/screens/posts/create_post_screen.dart) | 167 |
| Seller | [apps/seller/lib/screens/posts/followers_screen.dart](../../apps/seller/lib/screens/posts/followers_screen.dart) | 256 |
| Seller | [apps/seller/lib/screens/products/product_stats.dart](../../apps/seller/lib/screens/products/product_stats.dart) | 37 |
| Seller | [apps/seller/lib/screens/products/seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart) | 485 |
| Seller | [apps/seller/lib/screens/products/stock_count_validation.dart](../../apps/seller/lib/screens/products/stock_count_validation.dart) | 9 |
| Seller | [apps/seller/lib/screens/products/widgets/product_list_controls.dart](../../apps/seller/lib/screens/products/widgets/product_list_controls.dart) | 68 |
| Seller | [apps/seller/lib/screens/products/widgets/product_tax_section.dart](../../apps/seller/lib/screens/products/widgets/product_tax_section.dart) | 67 |
| Seller | [apps/seller/lib/screens/products/widgets/product_variants_section.dart](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart) | 194 |
| Seller | [apps/seller/lib/screens/profile/business_details_sheet.dart](../../apps/seller/lib/screens/profile/business_details_sheet.dart) | 244 |
| Seller | [apps/seller/lib/screens/profile/delivery_fee_sheet.dart](../../apps/seller/lib/screens/profile/delivery_fee_sheet.dart) | 350 |
| Seller | [apps/seller/lib/screens/profile/delivery_fee_validation.dart](../../apps/seller/lib/screens/profile/delivery_fee_validation.dart) | 71 |
| Seller | [apps/seller/lib/screens/profile/seller_ai_integration_screen.dart](../../apps/seller/lib/screens/profile/seller_ai_integration_screen.dart) | 401 |
| Seller | [apps/seller/lib/screens/profile/seller_profile_screen.dart](../../apps/seller/lib/screens/profile/seller_profile_screen.dart) | 420 |
| Seller | [apps/seller/lib/screens/reviews/review_rules.dart](../../apps/seller/lib/screens/reviews/review_rules.dart) | 97 |
| Seller | [apps/seller/lib/screens/reviews/reviews_screen.dart](../../apps/seller/lib/screens/reviews/reviews_screen.dart) | 300 |
| Seller | [apps/seller/lib/screens/rfq/quote_rules.dart](../../apps/seller/lib/screens/rfq/quote_rules.dart) | 62 |
| Seller | [apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_detail_screen.dart) | 279 |
| Seller | [apps/seller/lib/screens/rfq/seller_rfq_inbox_screen.dart](../../apps/seller/lib/screens/rfq/seller_rfq_inbox_screen.dart) | 92 |
| Seller | [apps/seller/lib/screens/rfq/widgets/quote_copy.dart](../../apps/seller/lib/screens/rfq/widgets/quote_copy.dart) | 99 |
| Seller | [apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart](../../apps/seller/lib/screens/rfq/widgets/quote_counter_sheet.dart) | 163 |
| Seller | [apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart](../../apps/seller/lib/screens/rfq/widgets/quote_decline_sheet.dart) | 73 |
| Seller | [apps/seller/lib/screens/rfq/widgets/quote_tile.dart](../../apps/seller/lib/screens/rfq/widgets/quote_tile.dart) | 61 |
| Seller | [apps/seller/lib/screens/search/search_rules.dart](../../apps/seller/lib/screens/search/search_rules.dart) | 54 |
| Seller | [apps/seller/lib/screens/search/search_screen.dart](../../apps/seller/lib/screens/search/search_screen.dart) | 132 |
| Seller | [apps/seller/lib/screens/shell/seller_shell.dart](../../apps/seller/lib/screens/shell/seller_shell.dart) | 124 |
| Seller | [apps/seller/lib/screens/storefront/storefront_editor_screen.dart](../../apps/seller/lib/screens/storefront/storefront_editor_screen.dart) | 382 |
| Seller | [apps/seller/lib/screens/storefront/storefront_rules.dart](../../apps/seller/lib/screens/storefront/storefront_rules.dart) | 85 |
| Seller | [apps/seller/lib/services/distance_service.dart](../../apps/seller/lib/services/distance_service.dart) | 193 |
| Seller | [apps/seller/lib/services/geocoding_service.dart](../../apps/seller/lib/services/geocoding_service.dart) | 154 |
| Seller | [apps/seller/lib/services/razorpay_stub.dart](../../apps/seller/lib/services/razorpay_stub.dart) | 43 |
| Seller | [apps/seller/lib/services/razorpay_web.dart](../../apps/seller/lib/services/razorpay_web.dart) | 241 |
| Delivery | [apps/delivery/lib/account/rider_account.dart](../../apps/delivery/lib/account/rider_account.dart) | 118 |
| Delivery | [apps/delivery/lib/account/support_card.dart](../../apps/delivery/lib/account/support_card.dart) | 82 |
| Delivery | [apps/delivery/lib/app/app.dart](../../apps/delivery/lib/app/app.dart) | 241 |
| Delivery | [apps/delivery/lib/app/delivery_shell.dart](../../apps/delivery/lib/app/delivery_shell.dart) | 192 |
| Delivery | [apps/delivery/lib/app/delivery_tab.dart](../../apps/delivery/lib/app/delivery_tab.dart) | 8 |
| Delivery | [apps/delivery/lib/app/device_localizations.dart](../../apps/delivery/lib/app/device_localizations.dart) | 15 |
| Delivery | [apps/delivery/lib/auth/auth_copy.dart](../../apps/delivery/lib/auth/auth_copy.dart) | 17 |
| Delivery | [apps/delivery/lib/auth/rider_account_source.dart](../../apps/delivery/lib/auth/rider_account_source.dart) | 190 |
| Delivery | [apps/delivery/lib/data/order_timeline.dart](../../apps/delivery/lib/data/order_timeline.dart) | 63 |
| Delivery | [apps/delivery/lib/data/rider_history.dart](../../apps/delivery/lib/data/rider_history.dart) | 512 |
| Delivery | [apps/delivery/lib/data/rider_work.dart](../../apps/delivery/lib/data/rider_work.dart) | 115 |
| Delivery | [apps/delivery/lib/delivery/delivery_problems.dart](../../apps/delivery/lib/delivery/delivery_problems.dart) | 138 |
| Delivery | [apps/delivery/lib/delivery/proof_photo_recovery.dart](../../apps/delivery/lib/delivery/proof_photo_recovery.dart) | 129 |
| Delivery | [apps/delivery/lib/delivery/rider_steps.dart](../../apps/delivery/lib/delivery/rider_steps.dart) | 203 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_badge.dart](../../apps/delivery/lib/design_system/components/delivery_badge.dart) | 271 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_banner.dart](../../apps/delivery/lib/design_system/components/delivery_banner.dart) | 124 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_brand.dart](../../apps/delivery/lib/design_system/components/delivery_brand.dart) | 670 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_button.dart](../../apps/delivery/lib/design_system/components/delivery_button.dart) | 436 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_card.dart](../../apps/delivery/lib/design_system/components/delivery_card.dart) | 169 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_chips.dart](../../apps/delivery/lib/design_system/components/delivery_chips.dart) | 231 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_feedback.dart](../../apps/delivery/lib/design_system/components/delivery_feedback.dart) | 420 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_fields.dart](../../apps/delivery/lib/design_system/components/delivery_fields.dart) | 230 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_layout.dart](../../apps/delivery/lib/design_system/components/delivery_layout.dart) | 189 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_list.dart](../../apps/delivery/lib/design_system/components/delivery_list.dart) | 251 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_media.dart](../../apps/delivery/lib/design_system/components/delivery_media.dart) | 144 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_metrics.dart](../../apps/delivery/lib/design_system/components/delivery_metrics.dart) | 196 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_nav.dart](../../apps/delivery/lib/design_system/components/delivery_nav.dart) | 234 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_otp.dart](../../apps/delivery/lib/design_system/components/delivery_otp.dart) | 208 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_search.dart](../../apps/delivery/lib/design_system/components/delivery_search.dart) | 66 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart) | 226 |
| Delivery | [apps/delivery/lib/design_system/components/delivery_timeline.dart](../../apps/delivery/lib/design_system/components/delivery_timeline.dart) | 505 |
| Delivery | [apps/delivery/lib/design_system/design_system.dart](../../apps/delivery/lib/design_system/design_system.dart) | 33 |
| Delivery | [apps/delivery/lib/design_system/format/delivery_format.dart](../../apps/delivery/lib/design_system/format/delivery_format.dart) | 109 |
| Delivery | [apps/delivery/lib/design_system/icons/delivery_icons.dart](../../apps/delivery/lib/design_system/icons/delivery_icons.dart) | 144 |
| Delivery | [apps/delivery/lib/design_system/theme/delivery_focus.dart](../../apps/delivery/lib/design_system/theme/delivery_focus.dart) | 87 |
| Delivery | [apps/delivery/lib/design_system/theme/delivery_theme.dart](../../apps/delivery/lib/design_system/theme/delivery_theme.dart) | 373 |
| Delivery | [apps/delivery/lib/design_system/tokens/delivery_colors.dart](../../apps/delivery/lib/design_system/tokens/delivery_colors.dart) | 362 |
| Delivery | [apps/delivery/lib/design_system/tokens/delivery_motion.dart](../../apps/delivery/lib/design_system/tokens/delivery_motion.dart) | 63 |
| Delivery | [apps/delivery/lib/design_system/tokens/delivery_tokens.dart](../../apps/delivery/lib/design_system/tokens/delivery_tokens.dart) | 187 |
| Delivery | [apps/delivery/lib/design_system/tokens/delivery_typography.dart](../../apps/delivery/lib/design_system/tokens/delivery_typography.dart) | 94 |
| Delivery | [apps/delivery/lib/identity/rider_document_review.dart](../../apps/delivery/lib/identity/rider_document_review.dart) | 193 |
| Delivery | [apps/delivery/lib/identity/rider_identity.dart](../../apps/delivery/lib/identity/rider_identity.dart) | 186 |
| Delivery | [apps/delivery/lib/inbox/rider_inbox.dart](../../apps/delivery/lib/inbox/rider_inbox.dart) | 199 |
| Delivery | [apps/delivery/lib/location/location_disclosure.dart](../../apps/delivery/lib/location/location_disclosure.dart) | 196 |
| Delivery | [apps/delivery/lib/location/location_policy.dart](../../apps/delivery/lib/location/location_policy.dart) | 143 |
| Delivery | [apps/delivery/lib/location/rider_platform.dart](../../apps/delivery/lib/location/rider_platform.dart) | 57 |
| Delivery | [apps/delivery/lib/main.dart](../../apps/delivery/lib/main.dart) | 169 |
| Delivery | [apps/delivery/lib/money/money_text.dart](../../apps/delivery/lib/money/money_text.dart) | 57 |
| Delivery | [apps/delivery/lib/money/rider_money.dart](../../apps/delivery/lib/money/rider_money.dart) | 482 |
| Delivery | [apps/delivery/lib/navigation/navigation_launch.dart](../../apps/delivery/lib/navigation/navigation_launch.dart) | 146 |
| Delivery | [apps/delivery/lib/navigation/rider_navigation.dart](../../apps/delivery/lib/navigation/rider_navigation.dart) | 111 |
| Delivery | [apps/delivery/lib/offers/delivery_offer.dart](../../apps/delivery/lib/offers/delivery_offer.dart) | 160 |
| Delivery | [apps/delivery/lib/offers/device_readiness.dart](../../apps/delivery/lib/offers/device_readiness.dart) | 101 |
| Delivery | [apps/delivery/lib/offers/offer_alerts.dart](../../apps/delivery/lib/offers/offer_alerts.dart) | 188 |
| Delivery | [apps/delivery/lib/offers/offer_coordinator.dart](../../apps/delivery/lib/offers/offer_coordinator.dart) | 96 |
| Delivery | [apps/delivery/lib/offers/offer_launch.dart](../../apps/delivery/lib/offers/offer_launch.dart) | 23 |
| Delivery | [apps/delivery/lib/offers/offer_platform.dart](../../apps/delivery/lib/offers/offer_platform.dart) | 60 |
| Delivery | [apps/delivery/lib/providers/auth_provider.dart](../../apps/delivery/lib/providers/auth_provider.dart) | 439 |
| Delivery | [apps/delivery/lib/providers/location_provider.dart](../../apps/delivery/lib/providers/location_provider.dart) | 402 |
| Delivery | [apps/delivery/lib/providers/offer_provider.dart](../../apps/delivery/lib/providers/offer_provider.dart) | 184 |
| Delivery | [apps/delivery/lib/providers/order_provider.dart](../../apps/delivery/lib/providers/order_provider.dart) | 256 |
| Delivery | [apps/delivery/lib/registration/registration_draft.dart](../../apps/delivery/lib/registration/registration_draft.dart) | 175 |
| Delivery | [apps/delivery/lib/registration/rider_application.dart](../../apps/delivery/lib/registration/rider_application.dart) | 255 |
| Delivery | [apps/delivery/lib/safety/emergency_sheet.dart](../../apps/delivery/lib/safety/emergency_sheet.dart) | 377 |
| Delivery | [apps/delivery/lib/safety/incident_report.dart](../../apps/delivery/lib/safety/incident_report.dart) | 150 |
| Delivery | [apps/delivery/lib/safety/incident_status_screen.dart](../../apps/delivery/lib/safety/incident_status_screen.dart) | 173 |
| Delivery | [apps/delivery/lib/screens/auth/login_screen.dart](../../apps/delivery/lib/screens/auth/login_screen.dart) | 285 |
| Delivery | [apps/delivery/lib/screens/auth/pending_approval_screen.dart](../../apps/delivery/lib/screens/auth/pending_approval_screen.dart) | 261 |
| Delivery | [apps/delivery/lib/screens/auth/rider_registration_screen.dart](../../apps/delivery/lib/screens/auth/rider_registration_screen.dart) | 1018 |
| Delivery | [apps/delivery/lib/screens/history/history_filter_sheet.dart](../../apps/delivery/lib/screens/history/history_filter_sheet.dart) | 263 |
| Delivery | [apps/delivery/lib/screens/history/rider_history_screen.dart](../../apps/delivery/lib/screens/history/rider_history_screen.dart) | 860 |
| Delivery | [apps/delivery/lib/screens/home/active_work_states.dart](../../apps/delivery/lib/screens/home/active_work_states.dart) | 195 |
| Delivery | [apps/delivery/lib/screens/home/dashboard_screen.dart](../../apps/delivery/lib/screens/home/dashboard_screen.dart) | 722 |
| Delivery | [apps/delivery/lib/screens/home/home_app_bar.dart](../../apps/delivery/lib/screens/home/home_app_bar.dart) | 211 |
| Delivery | [apps/delivery/lib/screens/home/home_map.dart](../../apps/delivery/lib/screens/home/home_map.dart) | 345 |
| Delivery | [apps/delivery/lib/screens/home/home_operations_panel.dart](../../apps/delivery/lib/screens/home/home_operations_panel.dart) | 179 |
| Delivery | [apps/delivery/lib/screens/home/pending_proof_banner.dart](../../apps/delivery/lib/screens/home/pending_proof_banner.dart) | 136 |
| Delivery | [apps/delivery/lib/screens/inbox/inbox_screen.dart](../../apps/delivery/lib/screens/inbox/inbox_screen.dart) | 701 |
| Delivery | [apps/delivery/lib/screens/money/bank_change_request_screen.dart](../../apps/delivery/lib/screens/money/bank_change_request_screen.dart) | 105 |
| Delivery | [apps/delivery/lib/screens/money/money_screen.dart](../../apps/delivery/lib/screens/money/money_screen.dart) | 725 |
| Delivery | [apps/delivery/lib/screens/money/statement_screen.dart](../../apps/delivery/lib/screens/money/statement_screen.dart) | 446 |
| Delivery | [apps/delivery/lib/screens/offers/incoming_offer_screen.dart](../../apps/delivery/lib/screens/offers/incoming_offer_screen.dart) | 315 |
| Delivery | [apps/delivery/lib/screens/orders/active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart) | 1360 |
| Delivery | [apps/delivery/lib/screens/orders/delivery_problem_panel.dart](../../apps/delivery/lib/screens/orders/delivery_problem_panel.dart) | 326 |
| Delivery | [apps/delivery/lib/screens/orders/widgets/rider_route_card.dart](../../apps/delivery/lib/screens/orders/widgets/rider_route_card.dart) | 872 |
| Delivery | [apps/delivery/lib/screens/orders/widgets/route_recovery.dart](../../apps/delivery/lib/screens/orders/widgets/route_recovery.dart) | 37 |
| Delivery | [apps/delivery/lib/screens/profile/document_submission_screen.dart](../../apps/delivery/lib/screens/profile/document_submission_screen.dart) | 167 |
| Delivery | [apps/delivery/lib/screens/profile/identity_change_screen.dart](../../apps/delivery/lib/screens/profile/identity_change_screen.dart) | 428 |
| Delivery | [apps/delivery/lib/screens/profile/rider_profile_screen.dart](../../apps/delivery/lib/screens/profile/rider_profile_screen.dart) | 1222 |
| Delivery | [apps/delivery/lib/screens/settings/device_readiness_screen.dart](../../apps/delivery/lib/screens/settings/device_readiness_screen.dart) | 178 |
| Delivery | [apps/delivery/lib/screens/support/help_sheet.dart](../../apps/delivery/lib/screens/support/help_sheet.dart) | 225 |
| Delivery | [apps/delivery/lib/screens/support/help_support_screen.dart](../../apps/delivery/lib/screens/support/help_support_screen.dart) | 183 |
| Delivery | [apps/delivery/lib/screens/support/my_support_requests_screen.dart](../../apps/delivery/lib/screens/support/my_support_requests_screen.dart) | 174 |
| Delivery | [apps/delivery/lib/screens/support/submit_support_request_screen.dart](../../apps/delivery/lib/screens/support/submit_support_request_screen.dart) | 195 |
| Delivery | [apps/delivery/lib/screens/support/support_request_status_screen.dart](../../apps/delivery/lib/screens/support/support_request_status_screen.dart) | 184 |
| Delivery | [apps/delivery/lib/services/geocoding_service.dart](../../apps/delivery/lib/services/geocoding_service.dart) | 154 |
| Delivery | [apps/delivery/lib/support/rider_support.dart](../../apps/delivery/lib/support/rider_support.dart) | 226 |
| Sales Associate | [apps/employee/lib/app/app.dart](../../apps/employee/lib/app/app.dart) | 88 |
| Sales Associate | [apps/employee/lib/catalogue/catalogue_app.dart](../../apps/employee/lib/catalogue/catalogue_app.dart) | 1203 |
| Sales Associate | [apps/employee/lib/catalogue/main_catalogue.dart](../../apps/employee/lib/catalogue/main_catalogue.dart) | 17 |
| Sales Associate | [apps/employee/lib/main.dart](../../apps/employee/lib/main.dart) | 108 |
| Sales Associate | [apps/employee/lib/providers/auth_provider.dart](../../apps/employee/lib/providers/auth_provider.dart) | 602 |
| Sales Associate | [apps/employee/lib/providers/theme_provider.dart](../../apps/employee/lib/providers/theme_provider.dart) | 57 |
| Sales Associate | [apps/employee/lib/screens/auth/associate_otp_screen.dart](../../apps/employee/lib/screens/auth/associate_otp_screen.dart) | 413 |
| Sales Associate | [apps/employee/lib/screens/auth/forgot_password_screen.dart](../../apps/employee/lib/screens/auth/forgot_password_screen.dart) | 208 |
| Sales Associate | [apps/employee/lib/screens/auth/login_screen.dart](../../apps/employee/lib/screens/auth/login_screen.dart) | 513 |
| Sales Associate | [apps/employee/lib/screens/auth/pending_approval_screen.dart](../../apps/employee/lib/screens/auth/pending_approval_screen.dart) | 196 |
| Sales Associate | [apps/employee/lib/screens/auth/suspended_screen.dart](../../apps/employee/lib/screens/auth/suspended_screen.dart) | 159 |
| Sales Associate | [apps/employee/lib/screens/home/dashboard_screen.dart](../../apps/employee/lib/screens/home/dashboard_screen.dart) | 909 |
| Sales Associate | [apps/employee/lib/screens/notifications/notifications_screen.dart](../../apps/employee/lib/screens/notifications/notifications_screen.dart) | 282 |
| Sales Associate | [apps/employee/lib/screens/orders/order_detail_screen.dart](../../apps/employee/lib/screens/orders/order_detail_screen.dart) | 440 |
| Sales Associate | [apps/employee/lib/screens/orders/orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart) | 495 |
| Sales Associate | [apps/employee/lib/screens/profile/onboarding_status_screen.dart](../../apps/employee/lib/screens/profile/onboarding_status_screen.dart) | 353 |
| Sales Associate | [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart) | 588 |
| Sales Associate | [apps/employee/lib/screens/shell/employee_shell_screen.dart](../../apps/employee/lib/screens/shell/employee_shell_screen.dart) | 132 |
| Sales Associate | [apps/employee/lib/screens/support/help_support_screen.dart](../../apps/employee/lib/screens/support/help_support_screen.dart) | 301 |
| Sales Associate | [apps/employee/lib/screens/wallet/payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart) | 687 |
| Sales Associate | [apps/employee/lib/screens/wallet/payout_details_screen.dart](../../apps/employee/lib/screens/wallet/payout_details_screen.dart) | 418 |
| Sales Associate | [apps/employee/lib/screens/wallet/payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart) | 375 |
| Sales Associate | [apps/employee/lib/screens/wallet/payout_request_screen.dart](../../apps/employee/lib/screens/wallet/payout_request_screen.dart) | 530 |
| Sales Associate | [apps/employee/lib/screens/wallet/payout_review_screen.dart](../../apps/employee/lib/screens/wallet/payout_review_screen.dart) | 356 |
| Sales Associate | [apps/employee/lib/screens/wallet/wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart) | 519 |
| Sales Associate | [apps/employee/lib/utils/sa_formatters.dart](../../apps/employee/lib/utils/sa_formatters.dart) | 47 |
| Admin | [apps/admin/lib/app/app.dart](../../apps/admin/lib/app/app.dart) | 66 |
| Admin | [apps/admin/lib/app/app_router.dart](../../apps/admin/lib/app/app_router.dart) | 757 |
| Admin | [apps/admin/lib/app/themes/admin_colors.dart](../../apps/admin/lib/app/themes/admin_colors.dart) | 192 |
| Admin | [apps/admin/lib/app/themes/admin_theme.dart](../../apps/admin/lib/app/themes/admin_theme.dart) | 304 |
| Admin | [apps/admin/lib/main.dart](../../apps/admin/lib/main.dart) | 322 |
| Admin | [apps/admin/lib/providers/admin_provider.dart](../../apps/admin/lib/providers/admin_provider.dart) | 455 |
| Admin | [apps/admin/lib/providers/auth_provider.dart](../../apps/admin/lib/providers/auth_provider.dart) | 854 |
| Admin | [apps/admin/lib/providers/banner_provider.dart](../../apps/admin/lib/providers/banner_provider.dart) | 253 |
| Admin | [apps/admin/lib/providers/benefit_compliance_provider.dart](../../apps/admin/lib/providers/benefit_compliance_provider.dart) | 237 |
| Admin | [apps/admin/lib/providers/bestseller_provider.dart](../../apps/admin/lib/providers/bestseller_provider.dart) | 169 |
| Admin | [apps/admin/lib/providers/category_provider.dart](../../apps/admin/lib/providers/category_provider.dart) | 132 |
| Admin | [apps/admin/lib/providers/category_section_provider.dart](../../apps/admin/lib/providers/category_section_provider.dart) | 197 |
| Admin | [apps/admin/lib/providers/coupon_provider.dart](../../apps/admin/lib/providers/coupon_provider.dart) | 271 |
| Admin | [apps/admin/lib/providers/home_product_section_provider.dart](../../apps/admin/lib/providers/home_product_section_provider.dart) | 119 |
| Admin | [apps/admin/lib/providers/order_provider.dart](../../apps/admin/lib/providers/order_provider.dart) | 1055 |
| Admin | [apps/admin/lib/providers/product_provider.dart](../../apps/admin/lib/providers/product_provider.dart) | 323 |
| Admin | [apps/admin/lib/providers/section_banner_provider.dart](../../apps/admin/lib/providers/section_banner_provider.dart) | 165 |
| Admin | [apps/admin/lib/providers/seller_provider.dart](../../apps/admin/lib/providers/seller_provider.dart) | 240 |
| Admin | [apps/admin/lib/providers/settings_provider.dart](../../apps/admin/lib/providers/settings_provider.dart) | 151 |
| Admin | [apps/admin/lib/providers/sponsored_banner_provider.dart](../../apps/admin/lib/providers/sponsored_banner_provider.dart) | 163 |
| Admin | [apps/admin/lib/providers/theme_provider.dart](../../apps/admin/lib/providers/theme_provider.dart) | 36 |
| Admin | [apps/admin/lib/providers/user_provider.dart](../../apps/admin/lib/providers/user_provider.dart) | 187 |
| Admin | [apps/admin/lib/providers/vendor_provider.dart](../../apps/admin/lib/providers/vendor_provider.dart) | 104 |
| Admin | [apps/admin/lib/providers/wallet_config_provider.dart](../../apps/admin/lib/providers/wallet_config_provider.dart) | 193 |
| Admin | [apps/admin/lib/screens/admin/admin_dashboard.dart](../../apps/admin/lib/screens/admin/admin_dashboard.dart) | 958 |
| Admin | [apps/admin/lib/screens/admin/admin_shell.dart](../../apps/admin/lib/screens/admin/admin_shell.dart) | 921 |
| Admin | [apps/admin/lib/screens/admin/analytics/analytics_screen.dart](../../apps/admin/lib/screens/admin/analytics/analytics_screen.dart) | 101 |
| Admin | [apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart](../../apps/admin/lib/screens/admin/banners/add_edit_banner_dialog.dart) | 589 |
| Admin | [apps/admin/lib/screens/admin/banners/banner_card.dart](../../apps/admin/lib/screens/admin/banners/banner_card.dart) | 219 |
| Admin | [apps/admin/lib/screens/admin/banners/banner_management_screen.dart](../../apps/admin/lib/screens/admin/banners/banner_management_screen.dart) | 462 |
| Admin | [apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart](../../apps/admin/lib/screens/admin/benefit_program/compliance_control_screen.dart) | 580 |
| Admin | [apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart](../../apps/admin/lib/screens/admin/benefit_program/feature_flags_screen.dart) | 325 |
| Admin | [apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart](../../apps/admin/lib/screens/admin/bestsellers/bestseller_management_screen.dart) | 329 |
| Admin | [apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart](../../apps/admin/lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart) | 466 |
| Admin | [apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart](../../apps/admin/lib/screens/admin/category_sections/category_section_management_screen.dart) | 778 |
| Admin | [apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart](../../apps/admin/lib/screens/admin/category_sections/edit_category_section_screen.dart) | 1003 |
| Admin | [apps/admin/lib/screens/admin/coupon/add_edit_coupon_dialog.dart](../../apps/admin/lib/screens/admin/coupon/add_edit_coupon_dialog.dart) | 556 |
| Admin | [apps/admin/lib/screens/admin/coupon/coupon_card.dart](../../apps/admin/lib/screens/admin/coupon/coupon_card.dart) | 238 |
| Admin | [apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart](../../apps/admin/lib/screens/admin/coupon/coupon_management_screen.dart) | 375 |
| Admin | [apps/admin/lib/screens/admin/delivery/add_delivery_partner_dialog.dart](../../apps/admin/lib/screens/admin/delivery/add_delivery_partner_dialog.dart) | 299 |
| Admin | [apps/admin/lib/screens/admin/delivery/delivery_flags.dart](../../apps/admin/lib/screens/admin/delivery/delivery_flags.dart) | 174 |
| Admin | [apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart](../../apps/admin/lib/screens/admin/delivery/delivery_partner_management_screen.dart) | 554 |
| Admin | [apps/admin/lib/screens/admin/delivery/delivery_problems_admin.dart](../../apps/admin/lib/screens/admin/delivery/delivery_problems_admin.dart) | 58 |
| Admin | [apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart](../../apps/admin/lib/screens/admin/delivery/delivery_problems_screen.dart) | 253 |
| Admin | [apps/admin/lib/screens/admin/delivery/dispatch_queue.dart](../../apps/admin/lib/screens/admin/delivery/dispatch_queue.dart) | 520 |
| Admin | [apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart](../../apps/admin/lib/screens/admin/delivery/dispatch_queue_screen.dart) | 623 |
| Admin | [apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart](../../apps/admin/lib/screens/admin/delivery/order_assignment_screen.dart) | 515 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_cash_ledger_screen.dart) | 147 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_detail_screen.dart) | 878 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_incidents_admin.dart](../../apps/admin/lib/screens/admin/delivery/rider_incidents_admin.dart) | 105 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_incidents_screen.dart) | 323 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_money_admin.dart](../../apps/admin/lib/screens/admin/delivery/rider_money_admin.dart) | 133 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_payouts_screen.dart) | 1128 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_review.dart](../../apps/admin/lib/screens/admin/delivery/rider_review.dart) | 139 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart](../../apps/admin/lib/screens/admin/delivery/rider_review_sheet.dart) | 414 |
| Admin | [apps/admin/lib/screens/admin/delivery/rider_support_screen.dart](../../apps/admin/lib/screens/admin/delivery/rider_support_screen.dart) | 334 |
| Admin | [apps/admin/lib/screens/admin/employees/add_employee_screen.dart](../../apps/admin/lib/screens/admin/employees/add_employee_screen.dart) | 188 |
| Admin | [apps/admin/lib/screens/admin/employees/associate_detail_screen.dart](../../apps/admin/lib/screens/admin/employees/associate_detail_screen.dart) | 732 |
| Admin | [apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart](../../apps/admin/lib/screens/admin/employees/commission_exceptions_screen.dart) | 232 |
| Admin | [apps/admin/lib/screens/admin/employees/employee_management_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_management_screen.dart) | 262 |
| Admin | [apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payout_account_review_screen.dart) | 193 |
| Admin | [apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payout_detail_screen.dart) | 1008 |
| Admin | [apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart) | 561 |
| Admin | [apps/admin/lib/screens/admin/finance/finance_reconciliation_models.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_models.dart) | 183 |
| Admin | [apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart](../../apps/admin/lib/screens/admin/finance/finance_reconciliation_screen.dart) | 341 |
| Admin | [apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart](../../apps/admin/lib/screens/admin/finance/financial_record_detail_screen.dart) | 512 |
| Admin | [apps/admin/lib/screens/admin/home_sections/add_edit_home_product_section_dialog.dart](../../apps/admin/lib/screens/admin/home_sections/add_edit_home_product_section_dialog.dart) | 176 |
| Admin | [apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart](../../apps/admin/lib/screens/admin/home_sections/home_product_section_management_screen.dart) | 176 |
| Admin | [apps/admin/lib/screens/admin/notifications/send_notification_screen.dart](../../apps/admin/lib/screens/admin/notifications/send_notification_screen.dart) | 1485 |
| Admin | [apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart](../../apps/admin/lib/screens/admin/orders/admin_order_details_screen.dart) | 3109 |
| Admin | [apps/admin/lib/screens/admin/orders/order_management_screen.dart](../../apps/admin/lib/screens/admin/orders/order_management_screen.dart) | 795 |
| Admin | [apps/admin/lib/screens/admin/orders/web_download_impl.dart](../../apps/admin/lib/screens/admin/orders/web_download_impl.dart) | 14 |
| Admin | [apps/admin/lib/screens/admin/orders/web_download_stub.dart](../../apps/admin/lib/screens/admin/orders/web_download_stub.dart) | 8 |
| Admin | [apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart](../../apps/admin/lib/screens/admin/orders/widgets/admin_order_card.dart) | 340 |
| Admin | [apps/admin/lib/screens/admin/orders/widgets/order_reason_dialog.dart](../../apps/admin/lib/screens/admin/orders/widgets/order_reason_dialog.dart) | 69 |
| Admin | [apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart](../../apps/admin/lib/screens/admin/orders/widgets/order_status_updater.dart) | 446 |
| Admin | [apps/admin/lib/screens/admin/products/category_management_screen.dart](../../apps/admin/lib/screens/admin/products/category_management_screen.dart) | 1636 |
| Admin | [apps/admin/lib/screens/admin/products/product_form_screen.dart](../../apps/admin/lib/screens/admin/products/product_form_screen.dart) | 703 |
| Admin | [apps/admin/lib/screens/admin/products/product_management_screen.dart](../../apps/admin/lib/screens/admin/products/product_management_screen.dart) | 829 |
| Admin | [apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart](../../apps/admin/lib/screens/admin/products/seller_product_approval_screen.dart) | 162 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart](../../apps/admin/lib/screens/admin/products/widgets/admin_product_card.dart) | 295 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart](../../apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart) | 601 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/image_uploader.dart](../../apps/admin/lib/screens/admin/products/widgets/image_uploader.dart) | 797 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/product_form.dart](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart) | 481 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/specification_form.dart](../../apps/admin/lib/screens/admin/products/widgets/specification_form.dart) | 472 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/stock_manager.dart](../../apps/admin/lib/screens/admin/products/widgets/stock_manager.dart) | 357 |
| Admin | [apps/admin/lib/screens/admin/products/widgets/variant_form.dart](../../apps/admin/lib/screens/admin/products/widgets/variant_form.dart) | 842 |
| Admin | [apps/admin/lib/screens/admin/reviews/review_management_screen.dart](../../apps/admin/lib/screens/admin/reviews/review_management_screen.dart) | 235 |
| Admin | [apps/admin/lib/screens/admin/rewards/rewards_management_screen.dart](../../apps/admin/lib/screens/admin/rewards/rewards_management_screen.dart) | 310 |
| Admin | [apps/admin/lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart](../../apps/admin/lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart) | 416 |
| Admin | [apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart](../../apps/admin/lib/screens/admin/section_banners/section_banner_management_screen.dart) | 400 |
| Admin | [apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart](../../apps/admin/lib/screens/admin/security/payment_security_logs_screen.dart) | 126 |
| Admin | [apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart](../../apps/admin/lib/screens/admin/security/verified_payment_lookup_screen.dart) | 174 |
| Admin | [apps/admin/lib/screens/admin/sellers/add_seller_screen.dart](../../apps/admin/lib/screens/admin/sellers/add_seller_screen.dart) | 194 |
| Admin | [apps/admin/lib/screens/admin/sellers/edit_seller_screen.dart](../../apps/admin/lib/screens/admin/sellers/edit_seller_screen.dart) | 229 |
| Admin | [apps/admin/lib/screens/admin/sellers/manage_sellers_screen.dart](../../apps/admin/lib/screens/admin/sellers/manage_sellers_screen.dart) | 93 |
| Admin | [apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart) | 774 |
| Admin | [apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_payouts_screen.dart) | 252 |
| Admin | [apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart) | 302 |
| Admin | [apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart](../../apps/admin/lib/screens/admin/sellers/seller_wallet_admin.dart) | 456 |
| Admin | [apps/admin/lib/screens/admin/settings/admin_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/admin_settings_screen.dart) | 1254 |
| Admin | [apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart](../../apps/admin/lib/screens/admin/settings/delivery_time_slots_management_screen.dart) | 195 |
| Admin | [apps/admin/lib/screens/admin/settings/home_grocery_strip_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/home_grocery_strip_settings_screen.dart) | 287 |
| Admin | [apps/admin/lib/screens/admin/settings/home_section_order_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/home_section_order_settings_screen.dart) | 278 |
| Admin | [apps/admin/lib/screens/admin/settings/location_settings_screen.dart](../../apps/admin/lib/screens/admin/settings/location_settings_screen.dart) | 417 |
| Admin | [apps/admin/lib/screens/admin/settings/wallet_config_screen.dart](../../apps/admin/lib/screens/admin/settings/wallet_config_screen.dart) | 722 |
| Admin | [apps/admin/lib/screens/admin/sponsored_banners/add_edit_sponsored_banner_dialog.dart](../../apps/admin/lib/screens/admin/sponsored_banners/add_edit_sponsored_banner_dialog.dart) | 462 |
| Admin | [apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_card.dart](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_card.dart) | 242 |
| Admin | [apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart](../../apps/admin/lib/screens/admin/sponsored_banners/sponsored_banner_management_screen.dart) | 454 |
| Admin | [apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart](../../apps/admin/lib/screens/admin/subscriptions/subscription_management_screen.dart) | 326 |
| Admin | [apps/admin/lib/screens/admin/support/support_case_constants.dart](../../apps/admin/lib/screens/admin/support/support_case_constants.dart) | 228 |
| Admin | [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart) | 1244 |
| Admin | [apps/admin/lib/screens/admin/support/support_queue_screen.dart](../../apps/admin/lib/screens/admin/support/support_queue_screen.dart) | 328 |
| Admin | [apps/admin/lib/screens/admin/users/customer_detail_screen.dart](../../apps/admin/lib/screens/admin/users/customer_detail_screen.dart) | 774 |
| Admin | [apps/admin/lib/screens/admin/users/edit_user_screen.dart](../../apps/admin/lib/screens/admin/users/edit_user_screen.dart) | 418 |
| Admin | [apps/admin/lib/screens/admin/users/user_management_screen.dart](../../apps/admin/lib/screens/admin/users/user_management_screen.dart) | 404 |
| Admin | [apps/admin/lib/screens/admin/users/widgets/role_badge.dart](../../apps/admin/lib/screens/admin/users/widgets/role_badge.dart) | 60 |
| Admin | [apps/admin/lib/screens/admin/users/widgets/user_card.dart](../../apps/admin/lib/screens/admin/users/widgets/user_card.dart) | 386 |
| Admin | [apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart](../../apps/admin/lib/screens/admin/vendors/vendors_list_screen.dart) | 164 |
| Admin | [apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart](../../apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart) | 442 |
| Admin | [apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart](../../apps/admin/lib/screens/admin/widgets/actor_support_cases_section.dart) | 546 |
| Admin | [apps/admin/lib/screens/admin/widgets/paginated_query_list.dart](../../apps/admin/lib/screens/admin/widgets/paginated_query_list.dart) | 197 |
| Admin | [apps/admin/lib/screens/auth/auth_screen.dart](../../apps/admin/lib/screens/auth/auth_screen.dart) | 1056 |

## Redesign checklist use

Use the screen ID as the review unit, then expand its modes, tabs, overlays and states. Preserve the five locked identities and map relevant C01–C28 foundations to each composition. Review actual light/dark rendering, loading/empty/error/access states, navigation/back behavior, large text, keyboard/touch/screen-reader behavior, localization and domain formatting. Access state, session ownership, financial/order/delivery authority and supported recovery must survive any future presentation migration. This document lists the current source system and does not authorize new business behavior.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Only three inventory documents are created. Earlier boards, their prompts/manifests and app/backend source remain untouched by this task. No branch/index/commit/push/deploy or message to another chat. Deploy consequence: NONE.

## Inventory integrity check

First report-validation snapshot: PASS. All 216 screen/shell IDs and source definitions are unique and located. All screen-named app source files have a classification. CSV has 643 definition/view rows; 1721 local source/document links resolve. Ten mobile/web implementation variants are included in the Marketplace definition count; MobileNumberScreen is an onboarding screen, not a responsive platform variant. Exactly three new repository documents were created, and all 1107 earlier design files remained byte-for-byte unchanged.

The 573 eligible app source-file hashes matched the collection at this validation snapshot. Collection HEAD 725e70f7aa9cb2966c2a5f590c6cb76117c6bc70; validation HEAD 536a17fca8dce9ec5ebef092267bccad625ebf3e. Git advanced concurrently, and this task made no runtime or Git mutation. Runtime reachability, rendered UI, backend behavior and adoption remain unverified.
