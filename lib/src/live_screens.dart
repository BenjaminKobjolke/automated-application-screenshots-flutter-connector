import 'package:flutter/widgets.dart';

/// Screen definitions an app exposes to a live screenshot session.
typedef ScreenOpen = Future<void> Function();

/// A screen the screenshot tool can open by name.
class LiveScreen {
  /// Creates a named screen with its app-owned open callback.
  const LiveScreen({
    required this.name,
    required this.description,
    required this.needsLogin,
    required this.open,
    this.sections = const {},
  });

  /// Stable screen name used by the tool.
  final String name;

  /// Human-readable summary of the screen.
  final String description;

  /// Whether opening the screen requires a logged-in test account.
  final bool needsLogin;

  /// Opens this screen using the app's own navigation mechanism.
  ///
  /// Do not return a `Navigator.push*` future: it completes only when the
  /// pushed route is popped, so the `navigate` command would never reply.
  final ScreenOpen open;

  /// Widgets the screenshot tool can request to scroll into view by key.
  final Map<String, GlobalKey> sections;

  /// Returns the registered key for [name] or throws [UnknownSectionError].
  GlobalKey section(String name) {
    final key = sections[name];
    if (key == null) {
      throw UnknownSectionError(
        'unknown section "$name" for screen "${this.name}" '
        '(available: ${sections.isEmpty ? 'none' : sections.keys.join(', ')})',
      );
    }
    return key;
  }

  /// Encodes the screen metadata with the live protocol's field names.
  Map<String, Object> toJson() => {
    'name': name,
    'description': description,
    'needs_login': needsLogin,
    if (sections.isNotEmpty) 'sections': sections.keys.toList(),
  };
}

/// No section with the requested name is registered on a screen.
class UnknownSectionError implements Exception {
  /// Creates the error with a ready-to-report [message].
  const UnknownSectionError(this.message);

  /// Human-readable reason, including the available section keys.
  final String message;

  @override
  String toString() => message;
}

/// No screen with the requested name is registered.
class UnknownScreenError implements Exception {
  /// Creates the error with a ready-to-report [message].
  const UnknownScreenError(this.message);

  /// Human-readable reason, including the available screen names.
  final String message;

  @override
  String toString() => message;
}

/// Named screens an app makes available to live screenshot commands.
class LiveScreenRegistry {
  final Map<String, LiveScreen> _screens = {};

  /// Registers [screens]; a duplicate name throws [ArgumentError].
  void add(Iterable<LiveScreen> screens) {
    for (final screen in screens) {
      if (_screens.containsKey(screen.name)) {
        throw ArgumentError(
          'Screen name "${screen.name}" is already registered',
        );
      }
      _screens[screen.name] = screen;
    }
  }

  /// The screen named [name]; throws [UnknownScreenError] if none exists.
  LiveScreen get(String name) {
    final screen = _screens[name];
    if (screen == null) {
      throw UnknownScreenError(
        'No screen named "$name" (available: ${names.join(', ')})',
      );
    }
    return screen;
  }

  /// Every registered screen, in registration order.
  List<LiveScreen> get all => List.unmodifiable(_screens.values);

  /// Every registered name, in registration order.
  List<String> get names => List.unmodifiable(_screens.keys);
}
