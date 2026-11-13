/// Names used by the JSON-lines command and event protocol.
abstract final class ProtocolNames {
  /// The command that starts a demo.
  static const String start = 'start';

  /// The command that lists registered screens.
  static const String listScreens = 'list_screens';

  /// The command that opens a registered screen.
  static const String navigate = 'navigate';

  /// The command that changes the app's theme.
  static const String setTheme = 'set_theme';

  /// The command that captures the current screen.
  static const String screenshot = 'screenshot';

  /// The command that performs a touch gesture on the current screen.
  static const String gesture = 'gesture';

  /// The command that reads visible text from the current screen.
  static const String readText = 'read_text';

  /// The command that taps a visible label.
  static const String tapText = 'tap_text';

  /// The command that taps a widget by its value key.
  static const String tapKey = 'tap_key';

  /// The command that types into a focused field.
  static const String typeText = 'type_text';

  /// The command that presses a key inside the app.
  static const String pressKey = 'press_key';

  /// The command that restores the app's initial state.
  static const String reset = 'reset';

  /// The event reporting registered screens.
  static const String screens = 'screens';

  /// The event confirming a screen navigation.
  static const String navigated = 'navigated';

  /// The event confirming that the app's theme was changed.
  static const String themeSet = 'theme_set';

  /// The event confirming that a gesture has finished.
  static const String gestured = 'gestured';

  /// The event reporting visible text entries.
  static const String visibleText = 'visible_text';

  /// The event confirming a visible-text tap.
  static const String textTapped = 'text_tapped';

  /// The event confirming a value-key tap.
  static const String keyTapped = 'key_tapped';

  /// The event confirming text entry.
  static const String textTyped = 'text_typed';

  /// The event confirming a key press.
  static const String keyPressed = 'key_pressed';

  /// The event confirming a reset.
  static const String resetDone = 'reset_done';

  /// The event announcing that demo playback started.
  static const String demoStarted = 'demo_started';

  /// The event announcing that demo playback finished.
  static const String demoEnded = 'demo_ended';

  /// The event announcing an mp4 payload.
  static const String video = 'video';

  /// The event reporting a command failure.
  static const String error = 'error';
}
