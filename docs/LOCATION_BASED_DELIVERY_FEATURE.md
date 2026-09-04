# 📍 Location-Based Product Visibility & Delivery Range Feature

Based on your audio instructions, here is the complete feature specification and implementation plan for the new Location-Based Product Visibility system.

---

## 1. Visibility for Existing Products
*Handling products that are already listed in the database.*
- **Global Visibility:** All existing products currently in the platform will be made visible to **everyone across Tamil Nadu** by default, regardless of the user's specific local location.
- We will set a default flag (e.g., `visibility: "all_over_tamilnadu"`) for all current products so they are not hidden from any users.

---

## 2. New Product Addition (Location Selector)
*For all new products added going forward.*

When adding a new product from either the **Admin Panel** or the **Seller Panel**, a new **Location & Range Selection Module** will be introduced. 

### Visibility Options:
Sellers and Admins must choose one of the following visibility scopes for the product:
1. **All over Tamil Nadu:** The product can be delivered and is visible anywhere in the state.
2. **Specific District:** The product is only visible to customers whose delivery address is within a selected district.
3. **Surrounding Area (Custom Range):** The product is only visible within a specific radius (e.g., 5km, 15km) from a chosen origin point.

### UI / UX Implementation:
- **Google Maps Integration:** A map view will be embedded in the "Add Product" screen.
- **Pin Drop & Range Slider:** Users can drop a pin on their exact location and use a slider to define the delivery radius (e.g., drawing a circle on the map).
- **Admin & Seller Panels:** Both panels will have this identical feature allowing vendors to restrict their product visibility to "particular areas only" if they cannot deliver state-wide.

---

## 3. Technical Implementation Plan (My Creative Approach)

### A. Database Model Updates (`ProductModel`)
We need to update the Firestore schema for products to include:
- `visibilityScope`: String (`'tamilnadu'`, `'district'`, `'radius'`)
- `targetDistrict`: String (e.g., `'Madurai'`, `'Coimbatore'`)
- `originLocation`: GeoPoint (Latitude, Longitude of the seller/store)
- `deliveryRadiusKm`: Number (Radius in kilometers)

### B. UI Updates (Admin & Seller Apps)
- Update `apps/admin/lib/screens/products/product_form_screen.dart` to include the Map and Range Slider.
- Update `apps/seller/lib/screens/add_product_screen.dart` to include the same widgets.
- Add a new shared UI component: `LocationRangePickerWidget` inside `agrimore_ui` or core packages.

### C. Customer App Filtering Logic
- Update the fetching logic in `database_service.dart` (Marketplace App). 
- When a customer opens the app, we check their active address/location.
- The query will filter out products where the customer's location falls outside the product's `deliveryRadiusKm` or `targetDistrict`, while always showing products marked as `'tamilnadu'`.

---
*I have documented this based on your voice note. Let me know if you want me to start implementing the code changes (like updating the ProductModel and Admin/Seller UI) right away!*
