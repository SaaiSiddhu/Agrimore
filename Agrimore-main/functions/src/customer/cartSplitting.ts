import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

export const splitCartIntoOrders = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to place an order."
    );
  }

  const userId = context.auth.uid;
  const { cartItems, shippingAddress, paymentMethod, paymentDetails } = data;

  if (!cartItems || !Array.isArray(cartItems) || cartItems.length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Cart items cannot be empty."
    );
  }

  const db = admin.firestore();
  
  try {
    // 1. Group items by sellerId
    const itemsBySeller: Record<string, any[]> = {};
    for (const item of cartItems) {
      if (!item.sellerId) {
        throw new functions.https.HttpsError("invalid-argument", "Item missing sellerId");
      }
      if (!itemsBySeller[item.sellerId]) {
        itemsBySeller[item.sellerId] = [];
      }
      itemsBySeller[item.sellerId].push(item);
    }

    const orderIds: string[] = [];
    const batch = db.batch();
    
    // 2. Create distinct order for each seller
    for (const sellerId in itemsBySeller) {
      const items = itemsBySeller[sellerId];
      
      // Calculate subtotal for this specific seller's order
      let sellerSubtotal = 0;
      for (const item of items) {
        sellerSubtotal += (item.price * item.quantity);
      }
      
      const orderRef = db.collection("orders").doc();
      orderIds.push(orderRef.id);
      
      batch.set(orderRef, {
        id: orderRef.id,
        userId: userId,
        sellerId: sellerId,
        items: items,
        subtotal: sellerSubtotal,
        totalAmount: sellerSubtotal, // + any shipping fees if logic requires
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        paymentDetails: paymentDetails || null,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Add initial timeline event
      const timelineRef = orderRef.collection("timeline").doc();
      batch.set(timelineRef, {
        id: timelineRef.id,
        status: "pending",
        description: "Order placed successfully",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 3. Clear the user's cart (Assuming user's cart is in carts/userId/items)
    const cartItemsRef = db.collection("carts").doc(userId).collection("items");
    const cartSnapshot = await cartItemsRef.get();
    cartSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // Commit all order creations and cart deletions
    await batch.commit();

    return {
      success: true,
      message: "Orders successfully created and split by seller",
      orderIds: orderIds,
    };
    
  } catch (error) {
    console.error("Error splitting cart into orders:", error);
    throw new functions.https.HttpsError("internal", "Failed to process orders");
  }
});
