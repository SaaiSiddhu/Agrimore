# 🌾 Agrimore Platform — Master Architecture & Product Documentation

> **Version:** 3.0.0 (Hyperlocal Warehouse Edition) | **Platform:** Android, iOS, Web | **Framework:** Flutter + Firebase  
> **Project ID:** `agrimore-66a4e` | **Business Model:** Location-Based Centralized Inventory (Blinkit Model)

---

## 📑 Table of Contents
1. [Architectural Reality Check: Hyperlocal Centralized Inventory](#1-architectural-reality-check-hyperlocal-centralized-inventory)
2. [Full Application Feature Breakdown](#2-full-application-feature-breakdown)
3. [End-to-End Workflows (Blinkit Model)](#3-end-to-end-workflows-blinkit-model)
4. [Database Architecture (Firestore - Strict Inventory Split)](#4-database-architecture-firestore---strict-inventory-split)
5. [API Structure & Firebase Services](#5-api-structure--firebase-services)
6. [Critical Business Logic: Location & Inventory Mapping](#6-critical-business-logic-location--inventory-mapping)
7. [App Screens & Navigation Flow](#7-app-screens--navigation-flow)
8. [Performance & Scalability Design](#8-performance--scalability-design)

---

## 1. Architectural Reality Check: Hyperlocal Centralized Inventory

Agrimore operates on a **Controlled Inventory System** rather than a chaotic multi-vendor marketplace. This is similar to the Blinkit/Zepto model. 

The core philosophy is:
👉 **Every area (e.g., Vathalakundu, Theni) operates from a central warehouse/hub.**
👉 **Users only see the specific inventory and stock available in their nearest assigned warehouse.**

**Why this approach?**
✅ Easy to manage centrally.
✅ Faster launch timeline.
✅ Fewer bugs compared to multi-vendor order routing.
❌ Seller App and multi-vendor complexities are skipped. Warehouse Admin is sufficient.

---

## 2. Full Application Feature Breakdown

Agrimore is structured as a **Monorepo** managed using `melos`, containing shared packages and individual platform apps.

### 🏗️ Shared Packages (`packages/`)
- **`agrimore_core`**: Shared Models (`ProductModel`, `InventoryModel`, `WarehouseModel`), Constants.
- **`agrimore_services`**: Shared infrastructure (`AuthService`, `DatabaseService`, `PaymentService`, `LocationService`).
- **`agrimore_ui`**: Shared design system for visual consistency.

### 📱 Apps (`apps/`)
1. **Marketplace App (`apps/marketplace`)** — *Customer-Facing*
   - Location auto-detection, Nearest Warehouse matching, Hub-specific inventory browsing, AI Assistant, Live Order Tracking.
2. **Admin Panel (`apps/admin`)** — *Backend Management*
   - Global Product Catalog management, Warehouse creation, Area-specific stock management, Fleet management.
3. **Delivery Partner App (`apps/delivery`)** — *Logistics*
   - Live routing, order assignment tied strictly to the delivery partner's assigned warehouse.

---

## 3. End-to-End Workflows (Blinkit Model)

### 🛒 Customer Shopping Flow
1. **Location Detection**: User opens app → App gets GPS/Manual Address → Finds nearest `Warehouse`.
2. **Inventory Sync**: App queries the `inventory` collection for that specific `warehouseId`.
3. **Browse & Cart**: User sees only products that are mapped to that warehouse and have `stock > 0`. 
4. **Checkout**: Standard checkout via Razorpay/COD.

### 🏪 Warehouse Admin Flow
1. **Catalog Setup**: Admin adds a global product (e.g., "Tomato") to the `products` collection.
2. **Stock Mapping**: Admin assigns 100 kg stock to "Theni Hub" and 50 kg to "Vathalakundu Hub" in the `inventory` collection.
3. **Fulfillment**: Warehouse receives order → Packs items → Hands over to hub-specific Delivery Partner.

### 🚚 Delivery Partner Flow
1. Partner signs in and is mapped to a specific `warehouseId`.
2. Partner receives orders exclusively originating from their assigned warehouse.
3. Executes delivery and enters customer PIN for verification.

---

## 4. Database Architecture (Firestore - Strict Inventory Split)

To support the Hyperlocal model efficiently, **Product Metadata** is separated from **Stock Data**.

### 🔥 Core Schema Architecture

**1. `warehouses/`** *(Hub definitions)*
*   `warehouseId`
*   `name` (e.g., "Theni Hub")
*   `location`: { `lat`: 10.xxxx, `lng`: 77.xxxx }
*   `serviceRadius`: 20 (km)
*   `isActive`: boolean

**2. `products/`** *(Global Catalog - NO STOCK OR LOCATION HERE)*
*   `productId`
*   `name`
*   `description`
*   `images`
*   `price` (Global base price, or overridden in inventory)

**3. `inventory/`** *(The Mapping Engine)*
*   `inventoryId`
*   `productId`
*   `warehouseId`
*   `stock`: integer
*   *(Optional)* `localPriceOverride`: double

**4. `orders/`** 
*   `orderId`
*   `userId`
*   `warehouseId` (Order is tied to the hub that fulfilled it)
*   `items`
*   `assignedTo` (Delivery Partner ID)

---

## 5. API Structure & Firebase Services

- **Database Service**: Advanced querying mapping `inventory` docs to `products` docs for the UI.
- **Location Service (Google Maps SDK)**: Determines the user's geocoordinates and calculates the Haversine distance to all active `warehouses` to find the one within the `serviceRadius`.
- **Cloud Functions**: Auto-deducts stock from the specific `inventory` document upon successful payment.

---

## 6. Critical Business Logic: Location & Inventory Mapping

This is the brain of the app:

**🧩 The Fetch Logic:**
1. User Location: `(Lat: 10.01, Lng: 77.47)`
2. Nearest Warehouse: `warehouseId: "hub_theni"`
3. Firestore Query: `inventory.where("warehouseId", isEqualTo: "hub_theni").where("stock", isGreaterThan: 0)`
4. Client merges the returned `productId`s with the global `products` collection to display UI cards.

**⚠️ Edge Cases Handled:**
- **User moves location (e.g., travels to a new city)**: App re-fetches nearest warehouse. Cart is validated; if old items aren't in the new warehouse, they are flagged as "Unavailable".
- **Product Out of Stock**: Handled gracefully at the `inventory` level. Shows "Out of stock in your area".
- **Multiple Warehouses**: System always locks the user to the single *Nearest* warehouse for fulfillment.

---

## 7. App Screens & Navigation Flow

### Customer App Key Routes
- `/location-picker` (Crucial first step before Home)
- `/home` (Hub-specific banners and products)
- `/product/:id` (Validates against local `inventory` stock)
- `/cart` (Real-time stock validation during checkout)

### Admin App Key Routes
- `/warehouses` (Manage Hubs and service radii)
- `/catalog` (Global products)
- `/inventory` (Assigning stock levels to specific hubs)

---

## 8. Performance & Scalability Design

- **Index Optimization**: The `inventory` collection is heavily indexed: `[warehouseId: ASC, stock: DESC]` to instantly query available items for an entire city.
- **Data De-duplication**: By separating `products` and `inventory`, we prevent duplicating product images and descriptions across thousands of local inventory records.
- **Future Proofing (Advanced Fallback)**: If an item is out of stock in Hub A, the architecture allows checking adjacent Hub B and offering "Delivery in 2 days" instead of standard instant delivery.

---

> **© 2026 Agrimore** — Hyperlocal Centralized Inventory E-Commerce
