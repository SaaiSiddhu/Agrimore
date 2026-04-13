// ============================================================
//  AGRIMORE - SEND EMAIL OTP CLOUD FUNCTION
// ============================================================

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================
// BEAUTIFUL HTML EMAIL TEMPLATE
// ============================================
function generateOTPEmailTemplate(otp: string, email: string): string {
  // Agrimore Theme Colors
  const colors = {
    primary: "#00E676",
    secondary: "#4CAF50",
    background: "#0A120A",
    cardBg: "#0F2818",
    textLight: "#FFFFFF",
    textDim: "#A5D6A7",
    accent: "#81C784"
  };

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Verification Code - Agrimore</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .otp-code { font-size: 32px !important; letter-spacing: 8px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: ${colors.background}; color: ${colors.textLight};">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <!-- Main Container -->
        <table class="container" role="presentation" width="480" cellspacing="0" cellpadding="0" border="0" style="background: linear-gradient(145deg, #1A2E1A 0%, #0A120A 100%); border-radius: 24px; border: 1px solid rgba(0, 230, 118, 0.1); box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4); overflow: hidden;">
          
          <!-- Header (Logo) -->
          <tr>
            <td align="center" style="padding: 40px 40px 20px 40px;">
              <div style="display: inline-block; width: 64px; height: 64px; border-radius: 16px; background: linear-gradient(135deg, ${colors.primary} 0%, ${colors.secondary} 100%); line-height: 64px; text-align: center; box-shadow: 0 8px 16px rgba(0, 230, 118, 0.2);">
                <span style="font-size: 32px; font-weight: 800; color: #003300;">A</span>
              </div>
              <h1 style="margin: 16px 0 0 0; font-size: 24px; font-weight: 700; background: linear-gradient(90deg, #FFFFFF 0%, #A5D6A7 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; letter-spacing: 1px;">AGRIMORE</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 0 40px;">
              <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 1.6; color: rgba(255, 255, 255, 0.9); text-align: center;">
                Hello, use the verification code below to securely access your Agrimore account.
              </p>

              <!-- OTP Box -->
              <div style="background: rgba(0, 230, 118, 0.08); border: 1px dashed rgba(0, 230, 118, 0.3); border-radius: 16px; padding: 32px 20px; text-align: center; margin-bottom: 24px;">
                <span style="display: block; font-size: 12px; font-weight: 600; text-transform: uppercase; color: ${colors.primary}; letter-spacing: 1.5px; margin-bottom: 8px;">Verification Code</span>
                <span class="otp-code" style="display: block; font-size: 40px; font-weight: 800; color: #FFFFFF; font-family: monospace; letter-spacing: 12px;">${otp}</span>
              </div>

              <p style="margin: 0; font-size: 14px; text-align: center; color: ${colors.textDim};">
                ⏱️ This code will expire in 5 minutes.
              </p>
            </td>
          </tr>

          <!-- Security Tip -->
          <tr>
            <td style="padding: 30px 40px;">
              <div style="background: rgba(255, 255, 255, 0.03); border-left: 3px solid ${colors.secondary}; padding: 12px 16px; border-radius: 0 8px 8px 0;">
                <p style="margin: 0; font-size: 13px; color: rgba(255, 255, 255, 0.7); line-height: 1.5;">
                  <strong>Security Notice:</strong> Agrimore will never ask for this code via call or SMS. Do not share it with anyone.
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 30px 40px; background-color: rgba(0, 0, 0, 0.2); border-top: 1px solid rgba(255, 255, 255, 0.05); text-align: center;">
              <p style="margin: 0 0 8px 0; font-size: 12px; color: ${colors.textDim};">
                Sent to <span style="color: ${colors.primary};">${email}</span>
              </p>
              <p style="margin: 0; font-size: 11px; color: rgba(255, 255, 255, 0.4);">
                &copy; ${new Date().getFullYear()} Agrimore Marketplace. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

// ============================================
// GENERATE 6-DIGIT OTP
// ============================================
function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ============================================
// SEND EMAIL OTP FUNCTION
// ============================================
export const sendEmailOTP = functions.https.onRequest(async (req, res) => {
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
    const { email } = req.body;

    // Validate email
    if (!email || typeof email !== "string") {
      res.status(400).json({ success: false, error: "Email is required" });
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json({ success: false, error: "Invalid email format" });
      return;
    }

    // Generate OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    // Store OTP in Firestore
    await db.collection("otp_codes").doc(email).set({
      otp: otp,
      email: email,
      expiresAt: expiresAt,
      createdAt: Date.now(),
      verified: false,
      attempts: 0,
    });

    // Get SMTP config from environment
    const smtpHost = process.env.SMTP_HOST || functions.config().smtp?.host;
    const smtpPort = parseInt(process.env.SMTP_PORT || functions.config().smtp?.port || "587");
    const smtpUser = process.env.SMTP_USER || functions.config().smtp?.user;
    const smtpPass = process.env.SMTP_PASS || functions.config().smtp?.pass;
    const fromName = process.env.SMTP_FROM_NAME || functions.config().smtp?.from_name || "Agrimore";
    const fromEmail = process.env.SMTP_FROM_EMAIL || functions.config().smtp?.from_email || smtpUser;

    if (!smtpHost || !smtpUser || !smtpPass) {
      console.error("SMTP configuration missing");
      res.status(500).json({ success: false, error: "Server configuration error" });
      return;
    }

    // Create transporter
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });

    // Send email
    const emailHtml = generateOTPEmailTemplate(otp, email);

    await transporter.sendMail({
      from: `"${fromName}" <${fromEmail}>`,
      to: email,
      subject: `${otp} is your Agrimore verification code`,
      html: emailHtml,
    });

    console.log(`✅ OTP sent to ${email}`);

    // Check if user exists
    const userSnapshot = await db.collection("users").where("email", "==", email).limit(1).get();
    const userExists = !userSnapshot.empty;

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      userExists: userExists,
    });

  } catch (error: any) {
    console.error("❌ Error sending OTP:", error);
    res.status(500).json({
      success: false,
      error: error.message || "Failed to send OTP",
    });
  }
});
