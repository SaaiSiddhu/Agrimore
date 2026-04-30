// ============================================================
//  AGRIMORE - VERIFY EMAIL OTP CLOUD FUNCTION
// ============================================================

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

// ============================================
// VERIFY EMAIL OTP FUNCTION
// ============================================
export const verifyEmailOTP = functions.https.onRequest(async (req, res) => {
    // CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }

    if (req.method !== "POST") {
        res.status(405).json({ success: false, error: "Method not allowed" });
        return;
    }

    try {
        const { email, otp, name, phone } = req.body;

        // Validate inputs
        if (!email || typeof email !== "string") {
            res.status(400).json({ success: false, error: "Email is required" });
            return;
        }

        if (!otp || typeof otp !== "string") {
            res.status(400).json({ success: false, error: "OTP is required" });
            return;
        }

        // Get OTP document
        const otpDoc = await db.collection("otp_codes").doc(email).get();

        if (!otpDoc.exists) {
            res.status(400).json({ success: false, error: "No OTP found. Please request a new code." });
            return;
        }

        const otpData = otpDoc.data()!;

        // Check if already verified
        if (otpData.verified) {
            res.status(400).json({ success: false, error: "OTP already used. Please request a new code." });
            return;
        }

        // Check attempts (max 5)
        if (otpData.attempts >= 5) {
            await db.collection("otp_codes").doc(email).delete();
            res.status(400).json({ success: false, error: "Too many attempts. Please request a new code." });
            return;
        }

        // Increment attempts
        await db.collection("otp_codes").doc(email).update({
            attempts: admin.firestore.FieldValue.increment(1),
        });

        // Check if expired
        if (Date.now() > otpData.expiresAt) {
            await db.collection("otp_codes").doc(email).delete();
            res.status(400).json({ success: false, error: "OTP expired. Please request a new code." });
            return;
        }

        // Verify OTP
        if (otpData.otp !== otp) {
            res.status(400).json({ success: false, error: "Invalid OTP. Please try again." });
            return;
        }

        // OTP is valid - mark as verified
        await db.collection("otp_codes").doc(email).update({
            verified: true,
            verifiedAt: Date.now(),
        });

        // Check if user exists
        let userId: string;
        let isNewUser = false;

        try {
            const userRecord = await auth.getUserByEmail(email);
            userId = userRecord.uid;
            console.log(`✅ Existing user found: ${userId}`);
        } catch (error: any) {
            if (error.code === "auth/user-not-found") {
                // Create new user
                const newUser = await auth.createUser({
                    email: email,
                    emailVerified: true,
                    displayName: name || email.split("@")[0],
                });
                userId = newUser.uid;
                isNewUser = true;
                console.log(`✅ New user created: ${userId}`);

                // Create user document in Firestore
                await db.collection("users").doc(userId).set({
                    email: email,
                    name: name || email.split("@")[0],
                    phone: phone || "",
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    isAdmin: false,
                    isSeller: false,
                    emailVerified: true,
                    loyaltyPoints: 0,
                    tier: "Bronze",
                });
            } else {
                throw error;
            }
        }

        // If existing user with new name/phone, update
        if (!isNewUser && (name || phone)) {
            const updateData: any = {
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                emailVerified: true,
            };
            if (name) updateData.name = name;
            if (phone) updateData.phone = phone;

            await db.collection("users").doc(userId).update(updateData);
        }

        // Generate custom token for Firebase Auth
        const customToken = await auth.createCustomToken(userId);

        // Clean up OTP
        await db.collection("otp_codes").doc(email).delete();

        console.log(`✅ User ${email} authenticated successfully`);

        res.status(200).json({
            success: true,
            message: "OTP verified successfully",
            token: customToken,
            userId: userId,
            isNewUser: isNewUser,
        });

    } catch (error: any) {
        console.error("❌ Error verifying OTP:", error);
        res.status(500).json({
            success: false,
            error: error.message || "Failed to verify OTP",
        });
    }
});
