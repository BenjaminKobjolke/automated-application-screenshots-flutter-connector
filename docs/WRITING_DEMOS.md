# Writing demo scripts

A demo is a `DemoScript` built from the step types below, registered in your
app in a `DemoRegistry`. The recording tool selects one by id in its `start`
command — or sends the steps itself (`"steps"` in the tool config demo), in
which case the registry is bypassed and only `customActions` are used.

```dart
DemoRegistry buildDemoRegistry(GlobalKey<NavigatorState> navigatorKey) {
  return DemoRegistry()
    ..add(const [
      DemoScript(id: 1, name: 'overview', steps: [   // demos/overview/
        PauseStep(1),                                // let the first frame settle
        ScreenshotStep('home'),                      // demos/overview/home.png
        TapStep('settings_button'),                  // ValueKey('settings_button')
        PauseStep(1.5),                              // reading time
        ScreenshotStep('settings'),
        CustomStep('back'),                          // app-defined action
      ]),
    ])
    ..customActions['back'] = () async => navigatorKey.currentState?.pop();
}
```

## Step types

| Step | JSON (`"steps"` in the tool config) | What it does |
|---|---|---|
| `TapStep(key)` | `{"type":"tap","key":"..."}` | Synthesized pointer down/up on the centre of the widget with `ValueKey(key)`. Runs the app's real gesture handling. |
| `TypeTextStep(text, charDelayMs: 60)` | `{"type":"type_text","text":"...","char_delay_ms":60}` | Appends `text` char by char to the **focused** text field. |
| `PauseStep(seconds)` | `{"type":"pause","seconds":1.5}` | Does nothing — reading time for viewers. |
| `ScreenshotStep(name)` | `{"type":"screenshot","name":"..."}` | Waits 400 ms, captures the app (`RepaintBoundary`, no system UI) at the config's `pixel_ratio`, sends `<name>.png`. |
| `CustomStep(name)` | `{"type":"custom","name":"..."}` | Awaits `registry.customActions[name]` — navigation, resets, anything the steps cannot express. |

A missing key, an unfocused text field or an unknown action fails the demo
with an `error` event instead of silently skipping a step.

## Things every app has to get right

1. **`onPrepare` resets to a clean, deterministic state.** It receives the
   tool config's `app_settings` and the run's language. Apply the settings,
   pop to the home screen, close dialogs. A re-recording must match the first
   take.
   **Pair it with `onRestore`**, which fires once the tool disconnects: the
   demo account and demo backend URL land in the app's real preferences, and
   whatever reads them — a settings screen, a polling background task — keeps
   using them after the recording unless something puts the user's own values
   back. Snapshot on the first `onPrepare`, not on every one, or a two-demo run
   restores demo state.
2. **Keys on everything a demo taps.** `key: const ValueKey('settings_button')`
   on the `IconButton`, not on its icon. Keys are the contract between the
   config/registry and the UI.
3. **No dialogs stealing taps.** Permission prompts, onboarding, update
   notices — gate them on demo mode or dismiss them in `onPrepare`.
4. **Video demos need the consent tap.** Android shows the screen-recording
   dialog before each video demo; someone taps *Start now* on the device. Not
   in the video (recording starts after), but it delays `demo_started`. Stills
   only? Use `"formats": ["png"]` — no recording, no prompt.
5. **Background services keep running.** The recorder plugin's stop calls
   `FlutterForegroundTask.stopService()`; if your app runs its own foreground
   task, a video demo stops it. Fine for demos that do not depend on it.

## Guidelines

- **Pace for viewers, not machines.** 0.8–1.5 s pauses after each screen
  change. The host adds a 500 ms start delay and a 1 s end hold.
- **Screenshot names** must be filesystem-friendly and unique within a demo.
- **Localize typed text with placeholders**: `TypeTextStep('{greeting}')` is
  filled from the tool's `texts_dir/<lang>.json`; screenshot names are never
  localized.
- **Check the length**: `estimatedDuration(steps)` returns the seconds a
  script takes without running it. The tool aborts at 300 s and after 60 s
  without an event.
- **Appearance and data belong in the config**, not in scripts: `app_settings`
  reaches `onPrepare`, so a demo backend URL or a demo account code is a
  config edit, not a code change.

## Playing without the tool

There is no manual mode: without `AUTOMATION_HOST` the host is inert. To
iterate on pacing, run the tool on the PC with a stills-only demo — it costs
one `--demo <id>` run and no consent tap.
