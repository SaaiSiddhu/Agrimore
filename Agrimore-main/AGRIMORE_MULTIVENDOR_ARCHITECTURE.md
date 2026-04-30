# 🌾 Agrimore Platform — Master Multi-Vendor Architecture & Features Document

> **Version:** 2.0.0 (Multi-Vendor Edition) | **Platform:** Android, iOS, Web | **Framework:** Flutter + Firebase  
> **Project ID:** `agrimore-66a4e` | **Business Model:** Multi-Vendor Hyperlocal E-Commerce

---

## 📑 Table of Contents
1. [Architectural Reality Check: Multi-Vendor Shift](#1-architectural-reality-check-multi-vendor-shift)
2. [Full Application Feature Breakdown](#2-full-application-feature-breakdown)
3. [The New Seller App Features](#3-the-new-seller-app-features)
4. [End-to-End Workflows (Multi-Vendor)](#4-end-to-end-workflows-multi-vendor)
5. [Database Architecture Changes (Firestore)](#5-database-architecture-changes-firestore)
6. [API Structure & Firebase Services](#6-api-structure--firebase-services)
7. [App Screens & Navigation Flow](#7-app-screens--navigation-flow)
8. [Critical Business Logic: Order Routing](#8-critical-business-logic-order-routing)
9. [Security Considerations (Firestore Rules)](#9-security-considerations-firestore-rules)
10. [Performance & Scalability Design](#10-performance--scalability-design)

---

## 1. Architectural Reality Check: Multi-Vendor Shift

Agrimore is transitioning from a **Single Vendor Mindset** (centralized inventory) to a true **Multi-Vendor Marketplace**. This represents a massive architectural shift affecting:
*   **Database**: Data ownership (Products and Orders must belong to specific Sellers).
*   **Order Logic**: Carts with mixed seller items must be split into distinct orders.
*   **Payments**: Earnings must be tracked per seller for payouts (Razorpay Route/Manual).
*   **Admin Control**: Admin transitions from managing inventory to moderating sellers and payouts.

### System Flow
**Customer App** ➡️ **Firebase** ➡️ **Admin Panel** & **Seller App**

---

## 2. Full Application Feature Breakdown

Agrimore is structured as a **Monorepo** managed using `melos`, scaling into 3 independent apps:

### 🏗️ Shared Packages (`packages/`)
- **`agrimore_core`**: Shared Models (`ProductModel`, `OrderModel`, `SellerModel`), Constants, Enums.
- **`agrimore_services`**: Shared infrastructure (`AuthService`, `DatabaseService`, `PaymentService`, `FCM`).
- **`agrimore_ui`**: Shared design system for visual consistency across Customer, Seller, and Admin apps.

### 📱 Apps (`apps/`)
1. **Marketplace App (`apps/marketplace`)** — *Customer-Facing*
   - Location-based filtering, Cart (Multi-Seller capable), AI Assistant, Live Order Tracking.
2. **Admin Panel (`apps/admin`)** — *Backend Management*
   - Seller KYC approvals, Global Category Management, Payouts tracking, Platform metrics.
3. **Seller App (`apps/seller`)** — *NEW: Dedicated Vendor Management*
   - Independent vendor controls (Inventory, Orders, KYC, Payouts).
4. **Delivery Partner App (`apps/delivery`)** — *Logistics*
   - Live routing, order assignment.

---

## 3. The New Seller App Features

The standalone Seller App contains 10 core feature pillars:

1. **🔐 Seller Authentication**
   - Login via Phone OTP or Email.
   - Initial onboarding requires GST / Business Verification & KYC Upload (PAN / Aadhaar).
   - *Admin approval required before dashboard access is granted.*
2. **🏪 Seller Dashboard**
   - Real-time Firestore stream showing: Today's Orders, Revenue, Pending Orders, Low Stock Alerts.
3. **📦 Product Management**
   - Add/Edit/Delete products (Name, Price, Firebase Storage Images, Stock, Category mapping).
   - Future support for Bulk Upload (CSV).
4. **🛒 Order Management (Critical)**
   - View customer details and manage the strict flow: `New Order → Accept → Pack → Ready → Pickup → Delivered`.
   - Ability to Accept / Reject incoming orders.
5. **📊 Inventory Management**
   - Auto stock deductions upon order placement. Low stock warning notifications.
6. **💰 Earnings & Payouts**
   - Track Total Earnings, Pending Payouts, and Completed Payouts.
   - Payout processing via Razorpay Route API or Manual Admin Settlement.
7. **🚚 Delivery Integration**
   - *Model A (Current)*: Centralized (Admin/Platform assigns delivery partner).
   - *Model B (Future)*: Seller-assigned self-delivery.
8. **⭐ Reviews & Ratings**
   - View customer feedback on products and respond.
9. **🔔 Notifications**
   - Alerts for new orders, payment updates, and admin broadcasts.
10. **⚙️ Seller Settings**
    - Business profile management, Bank details, Store timings, and customized Delivery radius.

### UI Screens (Seller App)
`Login` | `KYC Upload` | `Dashboard` | `Product List` | `Add/Edit Product` | `Orders List` | `Order Detail` | `Earnings` | `Profile`

---

## 4. End-to-End Workflows (Multi-Vendor)

### 🛒 Customer Shopping Flow
1. Browse products filtered by local area.
2. Add products from multiple sellers to the Cart.
3. Checkout. *Behind the scenes, the system splits the cart into multiple seller-specific orders.*

### 🏪 Seller Fulfillment Flow
1. Receives FCM Push Notification: *"New Order Arrived"*.
2. Reviews order details -> Taps **Accept**.
3. Packs items -> Taps **Ready for Pickup**.
4. Hands over to assigned Delivery Partner.

### 👨‍💻 Admin Moderation Flow
1. Reviews pending Seller KYC documents.
2. Approves Seller (changes status to `approved`), enabling them to add products.
3. Monitors global order flow and manages scheduled payouts to Sellers.

---

## 5. Database Architecture Changes (Firestore)

To support Multi-Vendor, the schema strictly enforces ownership.

### 🔥 New Collections & Updates
*   **`sellers/`** (New Collection)
    *   `sellerId` (Document ID == User UID)
    *   `name`, `phone`, `status` (pending/approved), `kycDocs`, `bankDetails`, `storeTimings`
*   **`products/`** (Updated)
    *   Added mandatory field: `sellerId`. (Ownership mapping).
*   **`orders/`** (Updated)
    *   Added mandatory field: `sellerId`.
    *   Added `assignedTo` (Delivery Partner ID).

---

## 6. API Structure & Firebase Services

- **Firebase Auth**: Identifies roles via Firestore `users` collection sync.
- **Cloud Storage**: Segregated folders (e.g., `kyc_docs/{sellerId}/`, `product_images/{sellerId}/`).
- **Cloud Functions**: 
  - Required for **Cart-to-Order Splitting**.
  - Required for generating Payout requests via Razorpay Route.
  - Dispatching role-specific FCM Notifications (e.g., notifying a specific seller of a new order).

---

## 7. Critical Business Logic: Order Routing

This is the most critical logic shift in the transition:

**🧩 The Cart Splitter Algorithm**
When a customer attempts to checkout a cart containing mixed items:
1. Backend/Client groups all `CartItems` by their respective `sellerId`.
2. For each unique `sellerId`, a **distinct Order Document** is generated.
   * *Example:* Cart has Item A (Seller 1) & Item B (Seller 2) = Customer pays once, but DB creates 2 distinct `orders` records.
3. Subtotals, shipping, and discounts must be proportionally calculated per grouped order.

---

## 8. Security Considerations (Firestore Rules)

With multi-vendor, data isolation is critical to prevent leaks or unauthorized modifications.

### `firestore.rules` Logic:
- **Sellers:**
  - `allow read, write: if request.auth.uid == resource.data.sellerId;`
  - Sellers can **only** read and update their own products and their own orders.
  - Sellers **cannot** access other sellers' financial data, orders, or unapproved products.
- **Customers:**
  - Can read any `active` product.
  - Can only read their own orders (`userId == request.auth.uid`).
- **Admin:**
  - Has global read/write access.

---

## 9. Performance & Scalability Design

- **Independent Apps:** Moving Seller logic to a dedicated app (`apps/seller`) drastically reduces the bundle size of the customer marketplace app.
- **Query Indexing:** Composite indexes required on `products` collection: `[sellerId: ASC, createdAt: DESC]` to power the Seller Dashboard efficiently.
- **Real-time Streams:** Seller Dashboard uses low-latency snapshot listeners for "Today's Orders" to ensure immediate fulfillment response without manual refreshing.

---

> **© 2026 Agrimore** — Advanced Multi-Vendor E-Commerce Platform
