import 'steps.dart';

/// An app-defined action a [CustomStep] runs (pop a route, reset a form...).
typedef CustomAction = Future<void> Function();

/// No demo with the requested id; the message lists the ones there are.
class UnknownDemoError implements Exception {
  /// Creates the error with a ready-to-report [message].
  UnknownDemoError(this.message);

  /// Human-readable reason, including the available ids.
  final String message;

  @override
  String toString() => message;
}

/// The demos an app can play, looked up by the id the tool asks for, plus the
/// named callbacks its [CustomStep]s may call.
class DemoRegistry {
  final Map<int, DemoScript> _scripts = {};

  /// Callbacks a `custom` step refers to by name.
  final Map<String, CustomAction> customActions = {};

  /// Registers finished [scripts]; a duplicate id throws [ArgumentError].
  void add(Iterable<DemoScript> scripts) {
    for (final script in scripts) {
      if (_scripts.containsKey(script.id)) {
        throw ArgumentError('Demo id ${script.id} is already registered');
      }
      _scripts[script.id] = script;
    }
  }

  /// The script for [demoId]; throws [UnknownDemoError] if none.
  DemoScript get(int demoId) {
    final script = _scripts[demoId];
    if (script == null) {
      throw UnknownDemoError(
          'No demo with id $demoId (available: ${ids.join(', ')})');
    }
    return script;
  }

  /// Every registered id, sorted.
  List<int> get ids => _scripts.keys.toList()..sort();

  /// Whether [demoId] is registered.
  bool contains(int demoId) => _scripts.containsKey(demoId);
}
