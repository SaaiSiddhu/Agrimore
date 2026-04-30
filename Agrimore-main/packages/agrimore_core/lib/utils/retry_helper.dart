import 'dart:async';
import 'package:flutter/foundation.dart';

class RetryHelper {
  /// Executes a function with automatic retries on failure.
  /// 
  /// [task] The async function to execute
  /// [maxRetries] Maximum number of retry attempts (default: 3)
  /// [delay] Delay between retries (default: 2 seconds)
  static Future<T> withRetry<T>({
    required Future<T> Function() task,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    String taskName = 'Task',
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await task();
      } catch (e) {
        attempts++;
        if (kDebugMode) {
          debugPrint('⚠️ [$taskName] Failed attempt $attempts of $maxRetries. Error: $e');
        }
        if (attempts >= maxRetries) {
          debugPrint('❌ [$taskName] All $maxRetries attempts failed.');
          rethrow;
        }
        await Future.delayed(delay);
      }
    }
    throw Exception('Retry loop failed unexpectedly');
  }
}
