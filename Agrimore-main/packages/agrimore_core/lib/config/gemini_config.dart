// lib/config/gemini_config.dart
class GeminiConfig {
  // Phase 21: this key was revoked by the owner in Google Cloud on
  // 2026-08-30 (finding 19-B — it had been committed to git and compiled
  // into every shipped build since c024b3e). The class is retained because
  // ai_chat_service.dart:164 still reads GeminiConfig.apiKey; leaving this
  // value empty is deliberate — it makes that file's own
  // `apiKey.trim().isEmpty` guard fire immediately, so AI chat degrades to
  // its existing offline message instead of attempting a doomed call
  // against a revoked key. The feature is kept dormant by owner decision
  // pending a product call, not accidentally broken. If AI chat is ever
  // restored, the key must come from a Cloud Function proxy (mirroring how
  // functions/src/customer/payment.ts keeps the Razorpay key secret off
  // the client) and be bound as a Secret Manager secret via defineSecret,
  // the same way the five secrets in functions/.secret.local.example are —
  // never as a client constant, because anything in this file ships
  // inside the APK.
  static const String apiKey = '';
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static const String modelName = 'gemini-2.5-flash';
}
