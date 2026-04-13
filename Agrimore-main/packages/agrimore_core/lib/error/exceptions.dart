// Base Exception
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

// Auth Exceptions
class AuthException extends AppException {
  AuthException(String message, {String? code}) : super(message, code: code);
}

class UserNotFoundException extends AuthException {
  UserNotFoundException(String message) : super(message, code: 'USER_NOT_FOUND');
}

class UnauthorizedException extends AuthException {
  UnauthorizedException([String message = 'Unauthorized']) : super(message, code: 'UNAUTHORIZED');
}

class WeakPasswordException extends AuthException {
  WeakPasswordException(String message) : super(message, code: 'WEAK_PASSWORD');
}

class EmailAlreadyExistsException extends AuthException {
  EmailAlreadyExistsException(String message) : super(message, code: 'EMAIL_EXISTS');
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException(String message) : super(message, code: 'INVALID_CREDENTIALS');
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message, code: 'VALIDATION_ERROR');
}

// Network Exceptions
class NetworkException extends AppException {
  NetworkException(String message) : super(message, code: 'NETWORK_ERROR');
}

// Database Exceptions
class DatabaseException extends AppException {
  DatabaseException(String message) : super(message, code: 'DATABASE_ERROR');
}

class DataNotFoundException extends DatabaseException {
  DataNotFoundException(String message) : super(message);
}

// Server Exceptions
class ServerException extends AppException {
  ServerException(String message, {String? code}) : super(message, code: code);
}

class BadRequestException extends ServerException {
  BadRequestException(String message) : super(message, code: 'BAD_REQUEST');
}

class ForbiddenException extends ServerException {
  ForbiddenException(String message) : super(message, code: 'FORBIDDEN');
}

class NotFoundException extends ServerException {
  NotFoundException(String message) : super(message, code: 'NOT_FOUND');
}

class InternalServerException extends ServerException {
  InternalServerException(String message) : super(message, code: 'INTERNAL_SERVER_ERROR');
}

// Cache Exception
class CacheException extends AppException {
  CacheException(String message) : super(message, code: 'CACHE_ERROR');
}

// Storage Exception
class StorageException extends AppException {
  StorageException(String message) : super(message, code: 'STORAGE_ERROR');
}

// Payment Exceptions
class PaymentException extends AppException {
  PaymentException(String message, {String? code}) : super(message, code: code);
}

class PaymentCancelledException extends PaymentException {
  PaymentCancelledException() : super('Payment was cancelled by user', code: 'PAYMENT_CANCELLED');
}
