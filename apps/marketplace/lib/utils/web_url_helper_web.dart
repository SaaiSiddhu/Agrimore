// lib/utils/web_url_helper_web.dart
// Web-specific implementation using dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Replace URL without adding to history (for tab switches within MainScreen)
void updateWebUrl(String path) {
  html.window.history.replaceState({'path': path}, '', path);
}

/// Push URL to history (for actual navigation to new screens)
void pushWebUrl(String path) {
  html.window.history.pushState({'path': path}, '', path);
}

/// Setup browser back button listener
/// Call this once from main() or your root widget
void setupPopStateListener(void Function(String path) onPopState) {
  html.window.onPopState.listen((event) {
    final path = html.window.location.pathname ?? '/';
    onPopState(path);
  });
}

/// Get current browser path
String getCurrentWebPath() {
  return html.window.location.pathname ?? '/';
}
