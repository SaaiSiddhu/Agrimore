import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Phase 16B-2, Workstream 2a — the ONE place `employees/{uid}` is created
/// by a self-applying user.
///
/// Extracted verbatim from `employee_apply_screen.dart`'s `_handleSubmit`
/// (Phase 1) so that screen and the new associate-onboarding flow
/// (`screens/employee/onboarding/`) share a single write instead of
/// maintaining two copies that could silently drift apart. The document
/// shape below is exactly what `createAssociateOnboardingPayment`
/// (`functions/src/employee/createAssociateOnboardingPayment.ts`) requires
/// to exist before it will create a payment order, and exactly what
/// `firestore.rules`' `employees/{employeeId}` self-create rule permits:
/// `status == 'pending'`, `commissionRate == 0` (or absent), and none of the
/// seven onboarding fields (S3) — this function writes none of them.
Future<void> submitAssociateApplication({
  required String uid,
  required String name,
  required String email,
  required String phone,
}) async {
  final employeeCode = EmployeeModel.generateEmployeeCode(uid, name);

  await FirebaseFirestore.instance.collection('employees').doc(uid).set({
    'userId': uid,
    'name': name,
    'email': email,
    'phone': phone,
    'employeeCode': employeeCode,
    'status': 'pending',
    'commissionRate': 0,
    'createdBy': 'self',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'employeeStatus': 'pending',
  }, SetOptions(merge: true));
}

/// Verification response for an associate code
class AssociateVerification {
  final bool valid;
  final String? reason;

  const AssociateVerification({required this.valid, this.reason});
}

/// Backs the optional B2C "Associate Code" field's Apply button
/// (AssociateCodeField, used by mobile_cart_screen.dart's quick checkout and
/// payment_method_screen.dart's full checkout). Calls the
/// `verifyAssociateCode` callable rather than querying `employees` directly —
/// firestore.rules only lets a user read their own employee doc (or an
/// admin read any), so a client-side query for someone else's code cannot
/// work at all, by design. Returns whether the code is valid along with
/// reason metadata (e.g. 'self', 'pending', 'not_active', 'not_found').
Future<AssociateVerification> verifyAssociateCodeDetails(String code) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'verifyAssociateCode',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 6)),
    );
    final result = await callable.call({'code': code}).timeout(
      const Duration(seconds: 7),
    );
    final data = result.data;
    if (data is Map) {
      final valid = data['valid'] == true;
      final reason = data['reason']?.toString();
      return AssociateVerification(valid: valid, reason: reason);
    }
    return const AssociateVerification(valid: false);
  } catch (e) {
    return const AssociateVerification(valid: false, reason: 'error');
  }
}

Future<bool> verifyAssociateCode(String code) async {
  final details = await verifyAssociateCodeDetails(code);
  return details.valid;
}
