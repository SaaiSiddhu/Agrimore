// lib/utils/web_url_helper_stub.dart
// Stub implementation for non-web platforms

void updateWebUrl(String path) {
  // No-op on non-web platforms
}

void pushWebUrl(String path) {
  // No-op on non-web platforms
}

void setupPopStateListener(void Function(String path) onPopState) {
  // No-op on non-web platforms
}

String getCurrentWebPath() {
  return '/';
}
