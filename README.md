# automated_screenshot_connector (Flutter)

App-side Flutter connector for the
[automated-application-screenshots](../automated-application-screenshots) demo
recording tool, **network mode**: the app runs on a phone or emulator, the tool
on a PC in the same LAN. The app connects to the tool, plays scripted demos,
**records the video on the device** (one mp4 per demo, native screen
recording) and captures pixel-exact stills in-app; the tool receives both and
exports `demo.gif` / `demo.mp4` / `<still>.png` into its usual output layout.
Wire protocol: the tool's `docs/AUTOMATION_INTERFACE.md`, section 7.

The Flutter twin of the
[python connector](../automated-application-screenshots-python-connector).
The library itself is pure Dart; it also ships one host-side script,
`ensure_device` (see below).

## What's inside

| Module (`lib/src/`) | Purpose |
|---|---|
| `steps.dart` | Step model (`TapStep`, `TypeTextStep`, `PauseStep`, `ScreenshotStep`, `CustomStep`), `DemoScript`, JSON codec, `localizeSteps`, `estimatedDuration` |
| `registry.dart` | `DemoRegistry` — id → script, `customActions` for `custom` steps, `UnknownDemoError` |
| `protocol.dart` | `StartCommand` (tool → app) and `DemoEvents` encoders (app → tool) |
| `client.dart` | `DemoClient` — TCP link, `start` command stream, event lines + raw mp4 upload; never throws into the app. `connectWithRetry` + `ConnectRetry` keep waiting for the tool, so app and tool start in either order |
| `still_capture.dart` | `StillCapture` — `RepaintBoundary.toImage` → PNG bytes |
| `screen_recorder.dart` | `ScreenRecorder` interface + `PluginScreenRecorder` (`flutter_screen_recording`) |
| `step_executor.dart` | `StepExecutor` — taps by `ValueKey` via synthesized pointer events, types into the focused field, runs custom actions |
| `demo_host.dart` | `AutomationDemoHost` — the widget that wires it all; `onPrepare` per demo, `onRestore` then `exitWhenDone` when the tool hangs up; inert without `AUTOMATION_HOST` |

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
and `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission. Android 14+ requires
screen-recording consent before each video demo. `ensure_device` pre-grants it
on development devices; see [Skipping the recording consent prompt](#skipping-the-recording-consent-prompt).
Stills-only demos (`"formats": ["png"]`) never prompt.

## Wire it up

```dart
final navigatorKey = GlobalKey<NavigatorState>();

AutomationDemoHost(
  registry: buildDemoRegistry(navigatorKey),   // your DemoScripts + custom actions
  onPrepare: (settings, language) async {      // clean, deterministic state
    await applySettings(settings);             // tool config app_settings
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  },
  onRestore: () async => restoreSettings(),    // after the tool disconnects
  child: MaterialApp(navigatorKey: navigatorKey, home: const HomeScreen()),
)
```

- `onPrepare` writes to the app's real stores, so give it an `onRestore` that
  puts the user's own state back. It runs once, after the tool disconnects and
  the last demo has finished — not after each demo.
- **The app closes itself when the run is over**, right after `onRestore`, so
  the device says plainly that the recording finished instead of sitting on a
  home screen that looks identical to one still being recorded. Pass
  `exitWhenDone: false` to keep it open.
- Widgets a demo taps carry `key: const ValueKey('settings_button')`.
- Run the app with `--dart-define=AUTOMATION_HOST=<pc ip>:<port>` (emulator:
  `10.0.2.2`). Without it the host renders the child and does nothing.
- On the PC: `uv run screenshot-tool --config your.json --demo all` with
  `"network": {"port": 8765}` in the config.
- **Start order does not matter.** The app retries for 3 minutes
  (`ConnectRetry`); the tool waits `network.accept_timeout` (default 30 s, raise
  it when the run also boots an emulator and builds the app). Whichever side
  comes up first waits for the other, as long as one of those two windows covers
  the gap. Watch for
  `waiting for demo tool at ...` then `connected to demo tool at ...` in the
  `flutter run` console; both are logged under `automated_screenshot_connector`
  via `dart:developer`, so they show there but are easy to miss in raw
  `adb logcat`.
- The PC must actually accept the inbound connection: on Windows the tool's
  listener needs TCP `<port>` allowed through the firewall, and a network
  classified *Public* blocks it silently — neither side logs a dropped SYN.

Demo content stays in your app; see [docs/WRITING_DEMOS.md](docs/WRITING_DEMOS.md).
`block-screen-app` (`lib/demos/demo_registry.dart`,
`tools/create_media/`) is the working reference.

## Starting a device (`ensure_device`)

Recording needs a booted Android device. Rather than each app reinventing that,
the connector ships it as a script, so any app that already depends on the
package can call it in one line — pub resolves the package's location, so no app
needs to know where this repo is checked out:

```
fvm dart run automated_screenshot_connector:ensure_device
```

It reuses whatever `adb` already lists and only launches an emulator when
nothing usable is attached, then waits for `sys.boot_completed` (up to 180 s).
It also pre-grants screen capture on every ready device. If the app is not
installed yet, a device-side watcher grants it after `flutter run` installs the
app (up to 20 minutes). Exit code 0 means a device is ready.

| variable | effect |
|---|---|
| `DEMO_EMULATOR` | AVD to launch. Empty: the first id `flutter emulators` lists. |
| `DEMO_PACKAGE` | Package to pre-grant screen capture for. Empty: use `applicationId` from `android/app/build.gradle(.kts)` in the working directory. |

Selecting *which* attached device the app then runs on is the calling app's job
(`flutter run -d <serial>`), not this script's — it only guarantees one exists.

### Creating the AVD

`ensure_device` boots an emulator but does not create one. Make it once, in
Android Studio — **View → Tool Windows → Device Manager**, then **+ → Create
Virtual Device**:

1. Pick a device definition (Pixel 9 or similar) and a recent system image.
2. Open **Additional settings** (older versions: **Show Advanced Settings**) and
   raise **Internal Storage**. This is the setting that matters, and the default
   is too small — see below.
3. Name it for the job, e.g. `Pixel_9_Demos`, so recordings never fight with the
   emulator you develop on. Put that name in `DEMO_EMULATOR`; the id
   `flutter emulators` lists is the name with spaces replaced by underscores.

**Give it enough space.** A debug build of a Flutter app with plugins is large —
around 160 MB for `block-screen-app` — and a streamed install needs several
times that free while it runs. A default AVD ships ~6 GB of internal storage, of
which the system image and Google apps take most: a fresh one left ~5.1 GB free,
but one that had been developed on for a while was down to ~600 MB, and installs
failed there. **16 GB is a comfortable setting** and costs nothing up front —
the disk image is sparse and only grows as it fills.

Set it at creation. Changing Internal Storage on an existing AVD generally means
wiping its data, so it is easier to make a second AVD than to resize one.

Check what a running emulator actually has left:

```
adb shell df /data
```

If the free column is a few hundred MB, installs fail with
`INSTALL_FAILED_INSUFFICIENT_STORAGE: Failed to override installation location`
— which surfaces as the app never connecting, because `flutter run` dies before
the app ever starts. `adb shell pm trim-caches 8G` may buy a little room; a
roomier AVD is the real fix.

### Skipping the recording consent prompt

`ensure_device` pre-grants screen capture on every ready development device each
time it runs. If the app is not installed yet, it leaves a device-side watcher
that grants consent as soon as `flutter run` installs the app, for up to 20
minutes. Re-running `ensure_device` while a watcher is waiting may start another
one; duplicate watchers are harmless.

The manual command remains a fallback for apps that do not call `ensure_device`:

```
adb shell appops set <your.package.id> PROJECT_MEDIA allow
```

Check it with `adb shell appops get <your.package.id> PROJECT_MEDIA`: after a
recording the entry reads `allow; time=…`, where `time` is when capture last
actually used it. To undo the grant, run
`adb shell appops set <your.package.id> PROJECT_MEDIA default`.

- A tap is only needed if the app is installed another way more than 20 minutes
  after `ensure_device` ran, or if `flutter run` uninstalls the app because of a
  signature mismatch. The grant is removed with the app; the next
  `ensure_device` run grants it again.
- Verified on an Android 17 (API 37) emulator. This is a debugging aid for
  machines you control — it does not change what a released app does, and real
  users always see the dialog.
- Without it, the tool waits at `Waiting for the app (accept the recording
  prompt on the phone)...` and the run fails on the event timeout if nobody taps.

## Development

```
install.bat           # fvm install + pub get + tests
tools\run_tests.bat   # fvm flutter test
fvm flutter analyze
```

## Dependencies

- Runtime: Flutter SDK, `flutter_screen_recording ^2.0.25`.
- Dev: `flutter_test`, `flutter_lints`.
