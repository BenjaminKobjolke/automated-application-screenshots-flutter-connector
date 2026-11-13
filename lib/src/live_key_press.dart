import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'live_input.dart';

/// Dispatches supported keys through Flutter's in-app keyboard handling.
final class KeyPresser {
  /// Creates a key dispatcher.
  const KeyPresser();

  static final Stopwatch _eventClock = Stopwatch()..start();

  /// Sends a key to the current app focus, using route navigation if escape is
  /// not handled by the focused widget or the app's shortcuts.
  Future<void> press(LiveKey key) async {
    if (key == LiveKey.enter) {
      final editable = _focusedEditableText;
      if (editable != null) {
        _submitOrInsertNewline(editable);
        return;
      }
    }

    final handled = key == LiveKey.shiftTab
        ? _pressShiftTab()
        : _pressKey(_keyFor(key));
    if (key == LiveKey.escape && !handled) {
      await WidgetsBinding.instance.handlePopRoute();
    }
  }

  EditableTextState? get _focusedEditableText => FocusManager
      .instance
      .primaryFocus
      ?.context
      ?.findAncestorStateOfType<EditableTextState>();

  void _submitOrInsertNewline(EditableTextState state) {
    final widget = state.widget;
    final action =
        widget.textInputAction ??
        (widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline);
    if (action == TextInputAction.newline && widget.maxLines != 1) {
      final value = state.textEditingValue;
      state.userUpdateTextEditingValue(
        value.replaced(value.selection, '\n'),
        SelectionChangedCause.keyboard,
      );
      return;
    }
    state.performAction(action);
  }

  bool _pressShiftTab() {
    final shift = _keyFor(LiveKey.shiftTab);
    final tab = _keyFor(LiveKey.tab);
    _send(shift, isDown: true);
    final handled = _pressKey(tab);
    _send(shift, isDown: false);
    return handled;
  }

  bool _pressKey(_Key key) {
    final downHandled = _send(key, isDown: true);
    final upHandled = _send(key, isDown: false);
    return downHandled || upHandled;
  }

  bool _send(_Key key, {required bool isDown}) {
    // The key-event manager also routes events through Focus and Shortcuts;
    // HardwareKeyboard.handleKeyEvent alone only updates global handlers.
    // ignore: deprecated_member_use
    return ServicesBinding.instance.keyEventManager.handleKeyData(
      ui.KeyData(
        timeStamp: _eventClock.elapsed,
        type: isDown ? ui.KeyEventType.down : ui.KeyEventType.up,
        physical: key.physical.usbHidUsage,
        logical: key.logical.keyId,
        character: null,
        synthesized: true,
      ),
    );
  }

  _Key _keyFor(LiveKey key) => switch (key) {
    LiveKey.enter => const _Key(
      PhysicalKeyboardKey.enter,
      LogicalKeyboardKey.enter,
    ),
    LiveKey.tab => const _Key(PhysicalKeyboardKey.tab, LogicalKeyboardKey.tab),
    LiveKey.shiftTab => const _Key(
      PhysicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftLeft,
    ),
    LiveKey.escape => const _Key(
      PhysicalKeyboardKey.escape,
      LogicalKeyboardKey.escape,
    ),
    LiveKey.backspace => const _Key(
      PhysicalKeyboardKey.backspace,
      LogicalKeyboardKey.backspace,
    ),
    LiveKey.arrowUp => const _Key(
      PhysicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
    ),
    LiveKey.arrowDown => const _Key(
      PhysicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
    ),
    LiveKey.arrowLeft => const _Key(
      PhysicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
    ),
    LiveKey.arrowRight => const _Key(
      PhysicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
    ),
  };
}

final class _Key {
  const _Key(this.physical, this.logical);

  final PhysicalKeyboardKey physical;
  final LogicalKeyboardKey logical;
}
