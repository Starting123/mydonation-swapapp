import 'dart:developer' as developer;

/// A simple logging service for the donation swap app
class LoggingService {
  static const String _name = 'DonationSwap';

  /// Log an info message
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 800, // INFO level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 900, // WARNING level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 1000, // ERROR level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a debug message
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 700, // DEBUG level
      error: error,
      stackTrace: stackTrace,
    );
  }
}