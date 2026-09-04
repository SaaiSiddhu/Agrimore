import 'package:equatable/equatable.dart';

// Base failure class
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  
  const Failure(this.message, {this.code});
  
  @override
  List<Object?> get props => [message, code];
}

// Network failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network failure'])
      : super(message, code: 'NETWORK_FAILURE');
}

class NoInternetFailure extends Failure {
  const NoInternetFailure([String message = 'No internet connection'])
      : super(message, code: 'NO_INTERNET');
}

// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code})
      : super(message, code: code ?? 'AUTH_FAILURE');
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([String message = 'Invalid credentials'])
      : super(message, code: 'INVALID_CREDENTIALS');
}

// Database failures
class DatabaseFailure extends Failure {
  const DatabaseFailure(String message, {String? code})
      : super(message, code: code ?? 'DATABASE_FAILURE');
}

// Storage failures
class StorageFailure extends Failure {
  const StorageFailure(String message, {String? code})
      : super(message, code: code ?? 'STORAGE_FAILURE');
}

// Payment failures
class PaymentFailure extends Failure {
  const PaymentFailure(String message, {String? code})
      : super(message, code: code ?? 'PAYMENT_FAILURE');
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message)
      : super(message, code: 'VALIDATION_FAILURE');
}

// Cache failures
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache failure'])
      : super(message, code: 'CACHE_FAILURE');
}

// Server failures
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server failure'])
      : super(message, code: 'SERVER_FAILURE');
}

// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Unknown error occurred'])
      : super(message, code: 'UNKNOWN_FAILURE');
}
