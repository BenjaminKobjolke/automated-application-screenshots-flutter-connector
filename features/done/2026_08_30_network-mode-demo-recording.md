# [DONE] Feature: Flutter connector — network-mode demo recording (phone records, PC exports)

- **Goal**: Record screenshots, GIFs and videos of Flutter apps with the existing PC tool `automated-application-screenshots`. Flutter apps (first target `block-screen-app`, Android-only) have no Win32 HWND and cannot be launched by the tool, so: app runs on phone/emulator, tool on PC, both on LAN. Phone records video natively (one demo = one mp4) and captures stills in-app, uploads them to the PC; PC exports gif/mp4/png into the same output layout the tool uses today so `compose` keeps working. Demo steps use one step model, playable from demos registered in the app or from steps sent by the PC config.

- **Where**:
  - Core tool `D:\GIT\BenjaminKobjolke\automated-application-screenshots`: `screenshot_tool/config.py`, `screenshot_tool/demo_server.py`, new `screenshot_tool/network_demo_cli.py`, `screenshot_tool/demo_cli.py` (dispatch + shared helpers), `docs/AUTOMATION_INTERFACE.md`, `docs/CONFIG.md`, `config/example-full.json`, `tests/unit/`, `tests/integration/`.
  - This repo (pure Dart package `automated_screenshot_connector`, mirrors the python-connector = library, no executable): `lib/src/{app_logger,steps,registry,protocol,client,still_capture,screen_recorder,step_executor,demo_host}.dart`, `lib/automated_screenshot_connector.dart`, `test/`, `README.md`, `docs/WRITING_DEMOS.md`, `.fvmrc` (3.47.1), `install.bat`, `update.bat`, `tools/run_tests.bat`, `analysis_options.yaml`.
  - First consumer `D:\GIT\BenjaminKobjolke\block-screen-app`: `pubspec.yaml`, `lib/main.dart`, new `lib/demos/demo_registry.dart`, `lib/screens/home_screen.dart` (ValueKeys on AppBar actions, lines ~131/140), `tools/create_media/blockscreen.json`, `tools/create_media/record_demos.bat`, `tools/run_demo_device.bat`.

- **Reuse**:
  - Core: `DemoServer` / `parse_event_line` / `DemoEvent` (`screenshot_tool/demo_server.py`), timeout constants + `_export`/`_run_verify`/`_clear_stale_stills` (`screenshot_tool/demo_cli.py`), `compose/gif.py: clip_to_gif` (mp4 → gif), `compose/ffmpeg.py` (bundled ffmpeg), `config.DemoSpec` (`formats`, `app_settings`, `languages`, `crop`, `verify`, `group`, `caption`), texts loading from `<texts_dir>/<lang>.json`, `AppLogger`.
  - Python connector as design template: `automated_screenshot_connector/{steps,registry,client,args}.py` (step model, `flatten`, `localize_script`, `estimated_duration`, constants `START_DELAY_MS=500`, `SCREENSHOT_SETTLE_MS=400`, `END_HOLD_MS=1000`), `docs/WRITING_DEMOS.md`.
  - Coding rules: `/coding-rules:apply` (COMMON + AI + FLUTTER), `flutter_setup_files/{install.bat,update.bat,tools/run_tests.bat,LIBRARIES.md}` at `D:\GIT\BenjaminKobjolke\claude-coding-rules\plugins\coding-rules\rules\`.
  - block-screen-app: `_navigatorKey` on `MaterialApp` (pop to home in `onPrepare`), `SettingsService`, `tools/config.bat` pattern.
  - Plugin: `flutter_screen_recording ^2.0.25` (MediaProjection/MediaRecorder on Android, ReplayKit on iOS; user-confirmed).

- **Plan sketch**:
  1. Wire protocol (TCP, newline JSON, bidirectional, PC listens `0.0.0.0:<port>`, app connects via `--dart-define=AUTOMATION_HOST=ip:port`, one connection per run):
     - PC → app: `{"command":"start","demo":1,"video":true,"pixel_ratio":1.0,"settings":{...},"language":"de","texts":{...},"steps":[...optional]}`
     - app → PC: `{"event":"demo_started","demo":1}`, `{"event":"screenshot","name":"home","png":"<base64>"}`, `{"event":"demo_ended","demo":1}`, `{"event":"video","demo":1,"size":N}` + N raw mp4 bytes, `{"event":"error","message":"..."}`.
     - `video` derived from demo `formats`: `["png"]` = stills only (no recording, no consent dialog); `gif`/`mp4` = record. GIF is made on the PC from the mp4 (`clip_to_gif`).
     - Steps JSON: `tap(key)`, `type_text(text, char_delay_ms)`, `pause(seconds)`, `screenshot(name)`, `custom(name)`; `{placeholder}` in `type_text` localized from `texts`, screenshot names never.
  2. Core repo: `NetworkSettings(port)` + top-level `"network"` key; `demos` need `launch` OR `network`; `DemoSpec` += `pixel_ratio`, `steps`, `wants_video`; `_VALID_FORMATS` += `png`; `process_name`/`title_substring` only required for launch/dropdown mode. `DemoServer(host, port)`, `send()`, `read_exact()`; `KNOWN_EVENTS` += `video`, `error`; `DemoEvent` += `png`, `size`, `message`. New `NetworkDemoCLI`: accept once, per demo send `start`, event loop with existing timeouts, write stills, receive mp4, `clip_to_gif` if gif wanted, `_run_verify`. Docs + unit/integration tests (fake app over real socket). Follow that repo's CLAUDE.md chain (`/plan:dry` → `/convention:check` → implement → `/dry:check` → `/verify:after-change`).
  3. Dart package: run `/coding-rules:apply`, copy flutter setup files, `.fvmrc` 3.47.1. Modules: `AppLogger` (dart:developer), sealed `DemoStep` + `DemoScript` + `localizeScript` + `estimatedDuration`, `DemoRegistry` (+ `customActions`), `StartCommand`/event encoders, `DemoClient` (Socket, line stream, `sendLine`/`sendBytes`, never throws into app), `StillCapture` (RepaintBoundary.toImage → PNG), `ScreenRecorder` wrapper over the plugin (small interface so tests mock it), `StepExecutor` (tap by `ValueKey` via element walk + `GestureBinding.handlePointerEvent`; type into focused `EditableText`; custom callbacks), `AutomationDemoHost` widget (RepaintBoundary around MaterialApp, reads `AUTOMATION_HOST`, on start: `onPrepare(settings, language)` → immersive UI + record if video → START_DELAY → demo_started → steps → END_HOLD → demo_ended → stop + upload → restore UI; no host = passthrough). Tests: steps, protocol, client (real ServerSocket + binary upload), step_executor + demo_host widget tests. README + `docs/WRITING_DEMOS.md` (Android manifest/foreground-service bits, per-demo consent tap, `onPrepare` clean state, keys on tapped widgets).
  4. block-screen-app: path dep, wrap `MaterialApp` in `AutomationDemoHost`, `onPrepare` applies settings + pops to home, demo 1 `overview` (video: home → settings → back → history with stills), demo 2 `settings` (`formats: ["png"]`), ValueKeys on AppBar actions, `blockscreen.json` + `record_demos.bat` + `run_demo_device.bat`.
  5. Verify: core `tools\run_tests.bat` + `run_integration_tests.bat`, ruff, mypy; connector `tools\run_tests.bat`, `fvm flutter analyze`; end to end on emulator: `record_demos.bat` → `run_demo_device.bat` → accept prompt → `output/demos/overview/{demo.mp4,demo.gif,home.png,settings.png,history.png}`, `output/demos/settings/settings.png` with no prompt.

- **Open questions**:
  - Android 14+ shows the MediaProjection consent dialog before every video demo (one tap per demo). Acceptable for v1; single-consent multi-demo needs custom native code (one projection, swap MediaRecorder files).
  - block-screen-app already runs `flutter_foreground_task`; the recording plugin also needs a foreground service — verify coexistence on the emulator before wiring demos.
  - Device recording resolution is native (e.g. 1080x2400); rely on existing `compose` size fitting, or add a `scale` option later if files are too big.
  - `AppLogger` in the Dart lib uses `dart:developer log` to stay dependency-light; switch to the `logger` package if the user prefers.
  - Out of scope: Windows-desktop Flutter via HWND, iOS testing, `PressKey` step (use `custom`), audio.

- **Answers** (defaults taken; user not available during autonomous run — revisit on request):
  - Consent dialog per video demo: accepted for v1.
  - Foreground-service coexistence: `flutter_screen_recording` 2.0.25 pins `flutter_foreground_task ^9.1.0`; block-screen-app uses `^11.0.1`. Same Dart API names on both sides, so block-screen-app adds `dependency_overrides: flutter_foreground_task: ^11.0.1`. The plugin's `stopRecordScreen` calls `FlutterForegroundTask.stopService()` (stops the app's own polling service) — acceptable, demos never need polling to run. Emulator run left as manual verification.
  - Native recording resolution: rely on `compose` fitting; no `scale` option yet.
  - Logging: `dart:developer log` behind `AppLogger` (dependency-light); `logger` package on request.

## Implementation

### Files changed

**Core tool** (`D:\GIT\BenjaminKobjolke\automated-application-screenshots`)
- `screenshot_tool/config.py` — `NetworkSettings`, `Settings.network`, `DemoSpec.pixel_ratio` / `steps` / `wants_video`, `_parse_network`, `_parse_demo_section` (launch XOR network), `png` format, `process_name`/`title_substring` only required for launch/language mode.
- `screenshot_tool/demo_server.py` — `DemoServer(host, port)`, `send()`, `read_exact()`; `DemoEvent.png/size/message`; `KNOWN_EVENTS` += `video`, `error`; base64 still decoding in `parse_event_line`.
- `screenshot_tool/demo_common.py` (new) — shared timeouts, `_run_label`, `output_dir_for`, `texts_file_for`, `load_texts`, `_clear_stale_stills`, `_run_verify`, `run_all`.
- `screenshot_tool/network_demo_cli.py` (new) — `NetworkDemoCLI(server).run(demos)`: accept once, per run send `start`, `_event_loop`, `_receive_video`, `clip_to_gif`, verify.
- `screenshot_tool/demo_cli.py` — helpers moved to `demo_common`, `DemoCLI.run` dispatches to `NetworkDemoCLI` when `settings.network` is set, uses `texts_file_for`.
- `config/example-network.json` (new), `docs/AUTOMATION_INTERFACE.md` (section 7 network mode), `docs/CONFIG.md` (`network`, `png`, `pixel_ratio`, `steps`), `README.md`.
- Tests: `tests/unit/test_protocol.py` (+3), `tests/unit/test_network_config.py` (new), `tests/unit/test_example_config.py` (+1), `tests/integration/test_network_demo.py` (new, fake app over a real socket).

**This repo** (Dart package `automated_screenshot_connector`)
- Setup: `pubspec.yaml`, `.fvmrc` (3.47.1), `analysis_options.yaml`, `.gitignore`, `.gitattributes`, `install.bat`, `update.bat`, `tools/run_tests.bat`, `/coding-rules:apply` (COMMON + AI + FLUTTER, codex delegation).
- `lib/src/app_logger.dart` (`AppLogger`), `steps.dart` (sealed `DemoStep` + 5 steps, `DemoScript`, `localizeSteps`, `estimatedDuration`, timing constants), `registry.dart` (`DemoRegistry`, `customActions`, `UnknownDemoError`), `protocol.dart` (`StartCommand.fromJson`, `DemoEvents`), `client.dart` (`DemoClient.connect/commands/sendLine/sendBytes`), `still_capture.dart` (`StillCapture`), `screen_recorder.dart` (`ScreenRecorder` interface, `PluginScreenRecorder`), `step_executor.dart` (`StepExecutor.run/tap/typeText`), `demo_host.dart` (`AutomationDemoHost`), `lib/automated_screenshot_connector.dart` (exports).
- Tests: `test/steps_test.dart`, `protocol_test.dart`, `client_test.dart` (real `ServerSocket`), `demo_host_test.dart` (widget test driving a full run incl. video upload through a real socket, fake recorder).
- `README.md`, `docs/WRITING_DEMOS.md`.
- Coding rules: `flutter_setup_files/LIBRARIES.md` gained `flutter_screen_recording`.

**block-screen-app**
- `pubspec.yaml` — path dep + `dependency_overrides: flutter_foreground_task: ^11.0.1`.
- `lib/main.dart` — `MaterialApp` wrapped in `AutomationDemoHost`.
- `lib/demos/demo_registry.dart` (new) — `buildDemoRegistry` (demo 1 `overview`, demo 2 `settings`, custom `back`), `prepareDemo` (applies `api_base_url`/`code`, pops to home, reloads `SettingsCubit`).
- `lib/screens/home_screen.dart` — `ValueKey('history_button')`, `ValueKey('settings_button')`.
- `tools/create_media/blockscreen.json`, `tools/create_media/record_demos.bat`, `tools/run_demo_device.bat`, `tools/config.bat.example` (`AUTOMATION_HOST`).

### What was done
Network mode as sketched: tool listens (`"network": {"port"}`), app connects, tool sends `start` per run (video flag from `formats`, settings, language, texts, optional steps), app records natively + sends stills inline, uploads mp4 after `demo_ended`, PC derives the GIF with `clip_to_gif`. One step model in Dart, JSON-compatible with config-sent steps. Verified: core 162 unit+integration tests, ruff, mypy; connector 14 tests + analyze; block-screen-app 64 tests + analyze.

### Notes
- `flutter_screen_recording` pins `flutter_foreground_task ^9`; consumers on `^11` need the `dependency_overrides` (same Dart API). Its `stopRecordScreen` also calls `FlutterForegroundTask.stopService()` — a video demo stops the app's polling service; acceptable for demos.
- `DemoServer` keeps `127.0.0.1` as default (launch mode stays local); network mode passes `0.0.0.0` explicitly.
- Not done here: the end-to-end emulator run (`record_demos.bat` + `run_demo_device.bat`, consent tap, real mp4) — manual verification pending; `SystemChrome` immersive toggling and plugin behaviour on Android 14 unverified on device.
- `fps` in network mode only drives the derived GIF.
