/// Optional build-time list of admin emails that receive `role: admin` on first sign-in
/// if their Firestore user doc exists but `role` is not yet `admin`.
///
/// Pass at build time, e.g.:
/// `flutter run --dart-define=AGRIMORE_BOOTSTRAP_ADMIN_EMAILS=owner@yourdomain.com`
///
/// Leave empty in production if you assign `role: admin` only via Firestore / admin tools.
class AdminAccessConfig {
  static const String _bootstrapEmails = String.fromEnvironment(
    'AGRIMORE_BOOTSTRAP_ADMIN_EMAILS',
    defaultValue: '',
  );

  static const List<String> _defaultAdminEmails = [
    'srieswaran22@gmail.com',
    'srieswaran@agrimore.com',
    'agrimorein@gmail.com',
    'admin@agrimore.in',
  ];

  static List<String> get bootstrapAdminEmailsLower => _bootstrapEmails
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  static bool shouldBootstrapAdminRole(String emailLower) {
    final lower = emailLower.trim().toLowerCase();
    if (_defaultAdminEmails.contains(lower)) return true;
    final list = bootstrapAdminEmailsLower;
    if (list.isEmpty) return false;
    return list.contains(lower);
  }
}
