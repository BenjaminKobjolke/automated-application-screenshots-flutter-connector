import 'protocol_names.dart';

/// A validated request to read or interact with visible app input.
sealed class LiveInput {
  /// Creates a live input request.
  const LiveInput();

  /// Parses one input command from the tool's JSON object.
  factory LiveInput.fromJson(Map<String, dynamic> json) {
    return switch (json[_InputJsonKeys.command]) {
      ProtocolNames.readText => const ReadTextInput(),
      ProtocolNames.tapText => TapTextInput.fromJson(json),
      ProtocolNames.tapKey => TapKeyInput.fromJson(json),
      ProtocolNames.typeText => TypeTextInput.fromJson(json),
      ProtocolNames.pressKey => PressKeyInput.fromJson(json),
      _ => throw FormatException(
        'unknown or missing input command: ${json[_InputJsonKeys.command]}',
      ),
    };
  }
}

/// Reads text currently visible in the app.
final class ReadTextInput extends LiveInput {
  /// Creates a read-text request.
  const ReadTextInput();
}

/// Taps a control whose visible text matches [text].
final class TapTextInput extends LiveInput {
  /// Creates a text-tap request.
  const TapTextInput({
    required this.text,
    this.match = TextMatch.exact,
    this.index,
  });

  /// Parses and validates a `tap_text` request.
  factory TapTextInput.fromJson(Map<String, dynamic> json) {
    final text = _requiredString(json, _InputJsonKeys.text);
    final rawIndex = json[_InputJsonKeys.index];
    if (rawIndex != null && (rawIndex is! int || rawIndex < 0)) {
      throw FormatException('index must be a non-negative integer');
    }
    return TapTextInput(
      text: text,
      match: TextMatch.parse(json[_InputJsonKeys.match]),
      index: rawIndex as int?,
    );
  }

  /// Text to match against visible entries.
  final String text;

  /// Whether matching requires equality or permits a substring.
  final TextMatch match;

  /// Zero-based match to select, or null when the match must be unique.
  final int? index;
}

/// Taps a widget identified by its `ValueKey<String>` value.
final class TapKeyInput extends LiveInput {
  /// Creates a value-key tap request.
  const TapKeyInput({required this.key});

  /// Parses and validates a `tap_key` request.
  factory TapKeyInput.fromJson(Map<String, dynamic> json) =>
      TapKeyInput(key: _requiredString(json, _InputJsonKeys.key));

  /// Value key of the widget to tap.
  final String key;
}

/// Types [text] into the focused field or an optional named field.
final class TypeTextInput extends LiveInput {
  /// Creates a text-entry request.
  const TypeTextInput({required this.text, this.field});

  /// Parses and validates a `type_text` request.
  factory TypeTextInput.fromJson(Map<String, dynamic> json) {
    final rawField = json[_InputJsonKeys.field];
    if (rawField != null && (rawField is! String || rawField.isEmpty)) {
      throw FormatException('field must be a non-empty string');
    }
    return TypeTextInput(
      text: _requiredString(json, _InputJsonKeys.text),
      field: rawField as String?,
    );
  }

  /// Text to type.
  final String text;

  /// Optional field label or hint to focus before typing.
  final String? field;
}

/// Presses a supported keyboard key inside the app.
final class PressKeyInput extends LiveInput {
  /// Creates a key-press request.
  const PressKeyInput({required this.key});

  /// Parses and validates a `press_key` request.
  factory PressKeyInput.fromJson(Map<String, dynamic> json) =>
      PressKeyInput(key: LiveKey.parse(json[_InputJsonKeys.key]));

  /// Key to press.
  final LiveKey key;
}

/// Text matching behavior for a visible-text command.
enum TextMatch {
  /// The entry text must equal the requested text.
  exact,

  /// The entry text may contain the requested text.
  contains;

  /// Parses the protocol spelling, defaulting a missing value to [exact].
  static TextMatch parse(Object? value) => switch (value) {
    null || 'exact' => exact,
    'contains' => contains,
    _ => throw FormatException('match must be "exact" or "contains"'),
  };
}

/// Supported keys for `press_key` commands.
enum LiveKey {
  /// The Enter key.
  enter,

  /// The Tab key.
  tab,

  /// Shift plus Tab.
  shiftTab,

  /// The Escape key.
  escape,

  /// The Backspace key.
  backspace,

  /// The Up arrow key.
  arrowUp,

  /// The Down arrow key.
  arrowDown,

  /// The Left arrow key.
  arrowLeft,

  /// The Right arrow key.
  arrowRight;

  /// Protocol spelling for this key.
  String get wireName => switch (this) {
    enter => _InputJsonValues.enter,
    tab => _InputJsonValues.tab,
    shiftTab => _InputJsonValues.shiftTab,
    escape => _InputJsonValues.escape,
    backspace => _InputJsonValues.backspace,
    arrowUp => _InputJsonValues.arrowUp,
    arrowDown => _InputJsonValues.arrowDown,
    arrowLeft => _InputJsonValues.arrowLeft,
    arrowRight => _InputJsonValues.arrowRight,
  };

  /// Parses a supported protocol spelling.
  static LiveKey parse(Object? value) => switch (value) {
    _InputJsonValues.enter => enter,
    _InputJsonValues.tab => tab,
    _InputJsonValues.shiftTab => shiftTab,
    _InputJsonValues.escape => escape,
    _InputJsonValues.backspace => backspace,
    _InputJsonValues.arrowUp => arrowUp,
    _InputJsonValues.arrowDown => arrowDown,
    _InputJsonValues.arrowLeft => arrowLeft,
    _InputJsonValues.arrowRight => arrowRight,
    _ => throw FormatException('unknown or missing press key: $value'),
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

abstract final class _InputJsonKeys {
  static const command = 'command';
  static const text = 'text';
  static const key = 'key';
  static const match = 'match';
  static const index = 'index';
  static const field = 'field';
}

abstract final class _InputJsonValues {
  static const enter = 'enter';
  static const tab = 'tab';
  static const shiftTab = 'shift_tab';
  static const escape = 'escape';
  static const backspace = 'backspace';
  static const arrowUp = 'arrow_up';
  static const arrowDown = 'arrow_down';
  static const arrowLeft = 'arrow_left';
  static const arrowRight = 'arrow_right';
}
