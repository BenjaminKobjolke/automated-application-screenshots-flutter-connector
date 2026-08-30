# automated_screenshot_connector (Flutter)

App-side Flutter connector for the
[automated-application-screenshots](../automated-application-screenshots) demo
recording tool, **network mode**: the app runs on a phone or emulator, the tool
on a PC in the same LAN. The app connects to the tool, plays scripted demos,
**records the video on the device** (one mp4 per demo, native screen
recording) and captures pixel-exact stills in-app; the tool receives both and
exports `demo.gif` / `demo.mp4` / `<still>.png` into its usual output layout.
Wire protocol: the tool's `docs/AUTOMATION_INTERFACE.md`, section 7.

Pure Dart package, no executable — the Flutter twin of the
[python connector](../automated-application-screenshots-python-connector).

## What's inside

| Module (`lib/src/`) | Purpose |
|---|---|
| `steps.dart` | Step model (`TapStep`, `TypeTextStep`, `PauseStep`, `ScreenshotStep`, `CustomStep`), `DemoScript`, JSON codec, `localizeSteps`, `estimatedDuration` |
| `registry.dart` | `DemoRegistry` — id → script, `customActions` for `custom` steps, `UnknownDemoError` |
| `protocol.dart` | `StartCommand` (tool → app) and `DemoEvents` encoders (app → tool) |
| `client.dart` | `DemoClient` — TCP link, `start` command stream, event lines + raw mp4 upload; never throws into the app |
| `still_capture.dart` | `StillCapture` — `RepaintBoundary.toImage` → PNG bytes |
| `screen_recorder.dart` | `ScreenRecorder` interface + `PluginScreenRecorder` (`flutter_screen_recording`) |
| `step_executor.dart` | `StepExecutor` — taps by `ValueKey` via synthesized pointer events, types into the focused field, runs custom actions |
| `demo_host.dart` | `AutomationDemoHost` — the widget that wires it all; inert without `AUTOMATION_HOST` |

## Install

```yaml
dependencies:
  automated_screenshot_connector:
    path: ../automated-application-screenshots-flutter-connector
```

`flutter_screen_recording` (pulled in by the connector) pins
`flutter_foreground_task ^9`. An app already on `^11` adds:

```yaml
dependency_overrides:
  flutter_foreground_task: ^11.0.1
```

(the Dart API the plugin uses is unchanged; verified in `block-screen-app`).
Android: minSdk 23, the plugin's manifest brings its own foreground service
and `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission. Android 14+ shows the
system consent dialog before **every** video demo — one tap on the device per
demo, not part of the recording. Stills-only demos (`"formats": ["png"]`)
never prompt.

## Wire it up

```dart
final navigatorKey = GlobalKey<NavigatorState>();

AutomationDemoHost(
  registry: buildDemoRegistry(navigatorKey),   // your DemoScripts + custom actions
  onPrepare: (settings, language) async {      // clean, deterministic state
    await applySettings(settings);             // tool config app_settings
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  },
  child: MaterialApp(navigatorKey: navigatorKey, home: const HomeScreen()),
)
```

- Widgets a demo taps carry `key: const ValueKey('settings_button')`.
- Run the app with `--dart-define=AUTOMATION_HOST=<pc ip>:<port>` (emulator:
  `10.0.2.2`). Without it the host renders the child and does nothing.
- On the PC: `uv run screenshot-tool --config your.json --demo all` with
  `"network": {"port": 8765}` in the config — it waits for the app to connect.

Demo content stays in your app; see [docs/WRITING_DEMOS.md](docs/WRITING_DEMOS.md).
`block-screen-app` (`lib/demos/demo_registry.dart`,
`tools/create_media/`) is the working reference.

## Development

```
install.bat           # fvm install + pub get + tests
tools\run_tests.bat   # fvm flutter test
fvm flutter analyze
```

## Dependencies

- Runtime: Flutter SDK, `flutter_screen_recording ^2.0.25`.
- Dev: `flutter_test`, `flutter_lints`.
