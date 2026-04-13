import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 🔹 Handles native UPI payments and optional backend verification
class UpiPaymentService {
  /// Launches native UPI intent for supported apps
  Future<void> initiateUpiPayment({
    required double amount,
    required String userName,
    required String upiId,
    required String packageName,
  }) async {
    final amountStr = amount.toStringAsFixed(2);
    final txnId = DateTime.now().millisecondsSinceEpoch.toString();
    final note = Uri.encodeComponent("Agrimore Payment");

    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(userName)}&tn=$note&am=$amountStr&cu=INR&tid=$txnId',
    );

    debugPrint("🪙 Starting UPI Payment → ₹$amountStr via $packageName");
    debugPrint("🔗 URI: $upiUri");

    try {
      if (Platform.isAndroid) {
        if (packageName.isNotEmpty) {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: upiUri.toString(),
            package: packageName,
          );
          await intent.launch();
        } else {
          await launchUrl(upiUri, mode: LaunchMode.externalApplication);
        }
      } else {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      }

      debugPrint("✅ UPI App Launched Successfully");

      // Optional backend verification
      await Future.delayed(const Duration(seconds: 8));
      await verifyUpiTransaction(txnId, amount);
    } catch (e) {
      debugPrint("❌ UPI Payment Launch Error: $e");
    }
  }

  /// Optional — verify UPI payment using your Firebase Function or backend
  Future<void> verifyUpiTransaction(String txnId, double amount) async {
    const verifyEndpoint =
        'https://us-central1-your-firebase-project.cloudfunctions.net/verifyUpiPayment';

    try {
      final response = await http.post(
        Uri.parse(verifyEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'txnId': txnId, 'amount': amount}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint("✅ Payment Verified Successfully");
      } else {
        debugPrint("⚠️ Verification Failed: ${data['message']}");
      }
    } catch (e) {
      debugPrint("🚨 Verification Error: $e");
    }
  }
}
