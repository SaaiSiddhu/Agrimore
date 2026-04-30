import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlobalErrorHandler {
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      } else {
        // Send to error reporting service (e.g., Firebase Crashlytics)
        logError(details.exceptionAsString(), details.stack);
      }
    };

    // Handle asynchronous unhandled errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('Async Error caught by GlobalErrorHandler: $error');
      } else {
        logError(error.toString(), stack);
      }
      return true;
    };
  }

  static void logError(String message, [StackTrace? stackTrace]) {
    // In a real production app, integrate FirebaseCrashlytics.instance.recordError here
    debugPrint('🚨 [ERROR LOGGED]: $message');
    if (stackTrace != null) {
      debugPrint('Stacktrace: $stackTrace');
    }
  }

  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
