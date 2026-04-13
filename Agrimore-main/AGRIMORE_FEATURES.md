# 🌾 Agrimore — Complete Features Documentation

> **Version:** 1.0.0 | **Platform:** Android, iOS, Web | **Framework:** Flutter + Firebase  
> **Project ID:** `agrimore-66a4e` | **Last Updated:** March 27, 2026

---

## 📱 Marketplace App (Customer-Facing)

### 🚀 Onboarding & Authentication
- **Splash Screen** — Branded loading with animated logo
- **Onboarding Flow** — Multi-step walkthrough introducing app features
- **Landing Page** — Rich, responsive landing page for web visitors
- **Authentication Methods:**
  - Google Sign-In (OAuth 2.0)
  - Phone Number OTP Login
  - Email & Password
- **Auth Gate** — Smart routing based on authentication state

---

### 🏠 Home Screen
- **Dual Layout** — Separate mobile and web-optimized layouts
- **Promotional Banners** — Auto-rotating carousel with admin-managed banners
- **Category Grid** — Quick-access category navigation
- **Bestseller Products** — Featured product showcase
- **Section Banners** — Category-specific promotional banners
- **Sponsored Banners** — Advertiser-managed promotions
- **Search Bar** — Quick product search from home

---

### 🛍️ Shop & Product Browsing
- **Product Catalog** — Browse all products with filters
- **Category-wise Browsing** — Products organized by agricultural categories
- **Product Details Screen:**
  - High-res product images
  - Price, description, specifications
  - Stock availability indicator
  - Add to Cart / Buy Now
  - Add to Wishlist
  - Product reviews & ratings
  - Share product via deep links
- **Search:**
  - Real-time product search
  - Search suggestions & history
- **Responsive Design** — Separate mobile and web shop layouts

---

### 🛒 Cart & Checkout
- **Cart Management:**
  - Add/remove items
  - Quantity adjustment
  - Price summary with discounts
- **Checkout Flow:**
  - Address selection / add new address
  - Google Maps address picker with autocomplete
  - Multiple payment methods
  - Order summary review
- **Coupon/Discount System:**
  - Apply coupon codes at checkout
  - Auto-calculated discounts
- **Order Success Screen** — Animated confirmation with confetti

---

### 💳 Payment Integration (Razorpay)
- **UPI Payments** — Direct UPI with preferred app selection
- **Card Payments** — Credit/Debit card processing
- **All Payment Methods** — Netbanking, wallet, and more
- **Wallet Balance** — Pay using in-app wallet balance
- **Cash on Delivery** — COD option
- **Live Mode** — Production-ready Razorpay integration (`rzp_live`)

---

### 📦 Order Management
- **My Orders** — Full order history with status filters
- **Order Details** — Comprehensive order view with:
  - Item breakdown
  - Payment info
  - Delivery address
  - Timeline events
- **Order Tracking:**
  - Real-time order status updates
  - Live GPS tracking on Google Maps
  - Order timeline with status progression
- **Order History** — Past orders archive

---

### 💰 Wallet System
- **Digital Wallet:**
  - View wallet balance
  - Add money via Razorpay
  - Transaction history with filters
- **Referral Program:**
  - Unique referral code per user
  - Share referral links
  - Earn wallet credits on successful referrals
  - Track referral status

---

### ❤️ Wishlist
- Save/remove favorite products
- Quick add-to-cart from wishlist
- Persistent across sessions

---

### 🤖 AI Chat Assistant
- **Gemini AI Powered** — Integrated Google Generative AI
- **Agricultural Advisor** — Ask farming, product, and agriculture questions
- **Chat History** — Persistent conversation history
- **Voice Input** — Audio recording with playback support
- **Markdown Responses** — Rich formatted AI responses

---

### 👤 Profile & Settings
- **Profile Management:**
  - View/Edit profile (name, email, phone, photo)
  - Profile image upload
- **Saved Addresses:**
  - Multiple delivery addresses
  - Google Maps location picker
  - Set default address
- **Change Password**
- **App Settings:**
  - Notification preferences
  - Theme/display settings
- **Help & Support** — In-app help center
- **Legal:**
  - Terms & Conditions
  - Privacy Policy
  - Return/Refund Policy

---

### 🔔 Push Notifications
- **Firebase Cloud Messaging (FCM)**
- Order status updates
- Promotional notifications
- Background message handling via Service Worker

---

### 🔗 Deep Linking
- **Product Links** — Share product URLs
- **Order Links** — Direct links to order details
- **Category Links** — Deep link to categories
- **Firebase Dynamic Links** — Cross-platform link handling
- **Android App Links** — Verified deep link domains

---

## 🖥️ Admin Panel (Business Management)

### 📊 Dashboard
- **Overview Metrics:**
  - Total orders, revenue, customers
  - Today's stats vs. historical
- **Quick Actions** — Shortcuts to key management areas
- **Recent Activity Feed**

---

### 📈 Analytics
- Sales analytics with charts
- Revenue tracking
- Customer growth metrics
- Product performance data

---

### 📦 Product Management
- **CRUD Operations:**
  - Add new products with images
  - Edit product details, pricing, stock
  - Delete products
- **Category Management:**
  - Create/edit/delete categories
  - Category-based product organization
- **Stock Management** — Inventory tracking

---

### 🛒 Order Management (Admin)
- **Order Queue** — View all incoming orders
- **Order Status Management:**
  - Pending → Confirmed → Shipped → Delivered
  - Cancel/reject orders
- **Order Details** — Full customer and item information
- **Order Timeline** — Track status changes

---

### 👥 User Management
- View all registered users
- User details and order history
- Customer management capabilities

---

### 🎫 Coupon Management
- **Create Coupons:**
  - Percentage or fixed discount
  - Minimum order value
  - Expiry dates
  - Usage limits
- **Edit/Delete coupons**
- **Track coupon usage**

---

### 🖼️ Banner Management
- **Promotional Banners** — Home screen carousels
- **Section Banners** — Category-specific promotions
- **Sponsored Banners** — Third-party advertisements
- **Bestseller Slots** — Featured product placements
- Image upload and scheduling

---

### 🚚 Delivery Management
- **Delivery Partners:**
  - Add/manage delivery partners
  - Assign orders to partners
- **Delivery Settings:**
  - Delivery radius
  - Delivery charges configuration
  - Free delivery thresholds

---

### 📢 Marketing & Notifications
- **Push Notification Campaigns:**
  - Send to all users
  - Targeted notifications
- **Promotional content management**

---

### ⚙️ Settings (Admin)
- **General Settings** — Business name, logo, contact info
- **Payment Settings:**
  - Razorpay key configuration
  - Payment modes (UPI, Card, COD, Wallet)
  - Payment gateway toggle
- **Delivery Settings:**
  - Delivery zones
  - Shipping charges
- **Wallet Configuration:**
  - Enable/disable wallet
  - Referral rewards setup
  - Wallet limits

---

## 🔧 Technical Architecture

### Shared Packages (Monorepo)
| Package | Purpose |
|---------|---------|
| `agrimore_core` | Models, constants, configs, utilities |
| `agrimore_services` | Firebase, payment, auth, AI, notifications |
| `agrimore_ui` | Shared UI components and themes |

### Tech Stack
| Component | Technology |
|-----------|------------|
| Frontend | Flutter (Dart) |
| Backend | Firebase (Firestore, Auth, Storage, FCM) |
| Database | Cloud Firestore + Realtime Database |
| Payment | Razorpay (Live) |
| AI | Google Generative AI (Gemini) |
| Maps | Google Maps SDK |
| State | Provider |
| Hosting | Firebase Hosting |
| Analytics | Firebase Analytics |

### Data Models (28 total)
`Address` · `Banner` · `BestsellerSlot` · `CartItem` · `Cart` · `Category` · `CategorySectionSlot` · `ChatMessage` · `Coupon` · `DeliveryPartner` · `Notification` · `OrderItem` · `Order` · `OrderStatus` · `OrderTimeline` · `PaymentSettings` · `Product` · `Referral` · `Review` · `SectionBanner` · `SponsoredBanner` · `UpiApp` · `User` · `WalletConfig` · `Wallet` · `WalletTransaction` · `Wishlist` · `IndiaLocations`

### Key Integrations
- 🔐 **Firebase Auth** — Multi-method authentication
- 🗄️ **Cloud Firestore** — Real-time NoSQL database
- 📁 **Firebase Storage** — Image/file storage
- 🔔 **Firebase Cloud Messaging** — Push notifications
- 💳 **Razorpay** — Payment processing (Live mode)
- 🗺️ **Google Maps** — Location, delivery tracking
- 🤖 **Google Gemini AI** — Chat assistant
- 🔗 **Firebase Dynamic Links** — Deep linking
- 🎤 **Audio Recording** — Voice input in AI chat

---

## 📱 Platform Support

| Platform | Status | App |
|----------|--------|-----|
| Android | ✅ Production | Marketplace + Admin |
| iOS | ✅ Supported | Marketplace + Admin |
| Web | ✅ Deployed | Marketplace + Admin |
| Windows | ✅ Supported | Marketplace + Admin |
| macOS | ✅ Supported | Marketplace + Admin |

---

> **© 2026 Agrimore** — Agricultural E-Commerce Platform
