/// Legacy build-time email hints retained for operator configuration displays.
/// These hints do not grant or revoke roles during authentication. Provision
/// privileged roles through server/admin tools; shared profile reads preserve
/// the role recorded for the current SDK owner.
///
/// Public helper signatures and hint values remain compatible with existing
/// consumers. A hint match is not proof of server authorization.
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
