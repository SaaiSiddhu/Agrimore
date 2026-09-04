import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { log } from "./helpers";

export const cleanupInvalidTokens = functions.pubsub
  .schedule("every day 02:00")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    try {
      log.info("🧹 Starting invalid token cleanup");
      const usersSnapshot = await admin.firestore().collection("users").get();
      let totalRemoved = 0;

      for (const userDoc of usersSnapshot.docs) {
        const data = userDoc.data();
        const tokens = (data.fcmTokens as string[]) || [];
        if (!tokens.length) continue;

        const validTokens: string[] = [];
        for (const token of tokens) {
          try {
            const testMessage: admin.messaging.Message = {
              token,
              notification: { title: "Token Test", body: "This is a test message" },
              data: { test: "true" },
              webpush: { fcmOptions: { link: "/" } },
            };
            await admin.messaging().send(testMessage);
            validTokens.push(token);
          } catch (error: any) {
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              totalRemoved++;
              log.warn(`Removed invalid token: ${token.substring(0, 20)}...`);
            } else {
              validTokens.push(token);
            }
          }
        }

        if (validTokens.length !== tokens.length) {
          await admin.firestore().collection("users").doc(userDoc.id).update({
            fcmTokens: validTokens,
          });
        }
      }

      log.success(`✅ Cleanup complete — removed ${totalRemoved} invalid token(s)`);
      return { success: true, tokensRemoved: totalRemoved };
    } catch (error: any) {
      log.error(`Cleanup error: ${error.message}`);
      return { success: false, error: error.message };
    }
  });
