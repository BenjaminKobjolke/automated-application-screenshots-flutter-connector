# Live named screens

Live mode keeps a debug app connected to the screenshot tool. The tool can list
registered screens, open one by name, capture it, and reset app state. It is
intended for the screenshot tool's `--live` driver and iterate checks; see its
live-mode guide for starting the driver.

## Register screens

Keep navigation in the app, where its `NavigatorState` and routes are known.
Screen names should be unique, lowercase `snake_case` identifiers. A screen's
`open` callback should finish after its data is ready to display. The connector
then waits for the current frame and transient animations to settle before it
replies to `navigate`.

```dart
final navigatorKey = GlobalKey<NavigatorState>();

LiveScreenRegistry buildScreens(GlobalKey<NavigatorState> navigatorKey) =>
    LiveScreenRegistry()
  ..add([
    LiveScreen(
      name: 'home',
      description: 'Home screen',
      needsLogin: false,
      open: () async => navigatorKey.currentState!.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      ),
    ),
    LiveScreen(
      name: 'account_settings',
      description: 'Account settings',
      needsLogin: true,
      open: () async => navigatorKey.currentState!.pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => const AccountSettingsScreen()),
      ),
    ),
  ]);

AutomationDemoHost(
  registry: buildDemoRegistry(navigatorKey),
  screens: demoModeEnabled ? buildScreens(navigatorKey) : null,
  onPrepare: prepareDemoState,
  onRestore: restoreUserState,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: !demoModeEnabled,
    home: const HomeScreen(),
  ),
)
```

The connector is inert without `AUTOMATION_HOST`. Only create and pass the live
registry in demo mode, and keep `debugShowCheckedModeBanner` off in captured
frames. The connector rejects live commands in release builds. Never ship test
credentials in app code: pass short-lived test tokens through the command's
`settings`, then apply them in `onPrepare`.

## Connection contract

Commands and replies are one JSON object per line over the existing TCP
connection. Commands are handled in order, with one reply per command:

| Command | Reply |
| --- | --- |
| `{"command":"list_screens"}` | `{"event":"screens","screens":[{"name":"account_settings","description":"Account settings","needs_login":true}]}` |
| `{"command":"navigate","screen":"account_settings","settings":{"test_token":"..."},"language":"de"}` | `{"event":"navigated","screen":"account_settings"}` |
| `{"command":"screenshot","name":"account_settings","pixel_ratio":1.0}` | `{"event":"screenshot","name":"account_settings","png":"<base64 PNG>"}` |
| `{"command":"reset","settings":{},"language":null}` | `{"event":"reset_done"}` |

Failures return the existing `{"event":"error","message":"..."}` event;
the connection remains usable. Screenshot captures the current view and does
not navigate. `pixel_ratio` defaults to `1.0`. `navigate` runs `onPrepare`
before opening the named screen, so the same command restores a screen after a
reload or restart. `reset` runs `onPrepare` without opening another screen.

## Test login and restore

Use `onPrepare` to switch to a deterministic test account, apply settings and
return navigation to the app's home route. Mark protected screens with
`needsLogin: true` so the driver can report that requirement. Save a snapshot of
the user's own account and backend settings in persistent storage before
changing them: a hot restart loses in-memory state, so `onRestore` must be able
to restore the snapshot after the connection closes. Clear the snapshot only
after restoration succeeds. Keep a test token in driver config or injected
settings, never in committed app source or example assets.

## Windows desktop

Run the app with `flutter run -d windows` and
`--dart-define=AUTOMATION_HOST=127.0.0.1:<port>` while the screenshot tool
listens on that port. The app connects to loopback, so this setup needs no
firewall rule. Captures use Flutter's in-app `RepaintBoundary` and work on
Windows as well as Android. Live mode is stills-only; video demos use the
existing Android recording plugin. A live session stays open after the tool
disconnects; the driver stops it when finished.

For Android, use the emulator host address supplied by the screenshot tool.
After hot reload the current route stays visible. After hot restart the driver
reconnects and sends `navigate` again for the current screen.

## Per-app setup checklist

- Add the connector package and a `GlobalKey<NavigatorState>`.
- Register stable screen names with descriptions and login requirements.
- Make `onPrepare` deterministic and `onRestore` restore persisted user state.
- Keep the registry and live-only UI out of production mode; do not commit test
  credentials.
- Try list, navigate, screenshot and reset on Windows and on the target Android
  emulator, then point the app's setup todo to this guide.
