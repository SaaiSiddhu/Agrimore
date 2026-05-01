import * as functions from "firebase-functions/v1";
import * as nodemailer from "nodemailer";

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

export const sendPasswordResetEmail = functions.https.onCall(async (data) => {
  const { email, resetLink } = data;

  if (!email || !resetLink) {
    throw new functions.https.HttpsError("invalid-argument", "Email and resetLink required");
  }

  const mailOptions = {
    from: "noreply@agrimore.com",
    to: email,
    subject: "🔐 Agrimore - Reset Your Password",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4CAF50;">Agrimore Password Reset</h2>
        <p>Hi,</p>
        <p>We received a request to reset your password. Click the link below to create a new password:</p>
        
        <a href="${resetLink}" style="
          display: inline-block;
          background-color: #4CAF50;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 5px;
          margin: 20px 0;
        ">Reset Password</a>
        
        <p>Or copy and paste this link: ${resetLink}</p>
        <p style="color: #999; font-size: 12px;">This link expires in 1 hour.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: "Email sent successfully" };
  } catch (error) {
    console.error("Email error:", error);
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});
