/// Optional deep link / web URL for the Admin Flutter/Web app.
///
/// After an admin signs in on the **marketplace** app, we can open this URL
/// (e.g. `https://admin.yourdomain.com` or a custom scheme).
///
/// `flutter run --dart-define=AGRIMORE_ADMIN_PANEL_URL=https://admin.example.com`
class AppRoutingConfig {
  static const String adminPanelUrl = String.fromEnvironment(
    'AGRIMORE_ADMIN_PANEL_URL',
    defaultValue: '',
  );

  static bool get hasAdminPanelUrl => adminPanelUrl.trim().isNotEmpty;
}
