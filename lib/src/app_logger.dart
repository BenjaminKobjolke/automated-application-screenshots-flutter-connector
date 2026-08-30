import 'dart:developer' as developer;

/// The connector's single logging entry point.
///
/// Wraps `dart:developer` so the library adds no logging dependency to the
/// app; [enabled] is the one off switch. Never used from outside the library
/// except to silence it.
class AppLogger {
  AppLogger._();

  /// Turn all connector logging off (e.g. in tests).
  static bool enabled = true;

  static const String _name = 'automated_screenshot_connector';

  /// Informational message.
  static void i(String message) {
    if (enabled) developer.log(message, name: _name);
  }

  /// Error message with optional [error] and [stackTrace].
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (enabled) {
      developer.log(message,
          name: _name, level: 1000, error: error, stackTrace: stackTrace);
    }
  }
}
