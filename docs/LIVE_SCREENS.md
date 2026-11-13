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
replies to `navigate`. Never return a `Navigator.push*` Future from `open` (for
example, don't use `async =>` with a push): it completes only when the route is
popped, so `navigate` would never reply.

```dart
final navigatorKey = GlobalKey<NavigatorState>();
final bottomKey = GlobalKey();

LiveScreenRegistry buildScreens(GlobalKey<NavigatorState> navigatorKey) =>
    LiveScreenRegistry()
  ..add([
    LiveScreen(
      name: 'home',
      description: 'Home screen',
      needsLogin: false,
      open: () async {
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      },
    ),
    LiveScreen(
      name: 'account_settings',
      description: 'Account settings',
      needsLogin: true,
      open: () async {
        navigatorKey.currentState!.pushReplacement<void, void>(
          MaterialPageRoute<void>(builder: (_) => const AccountSettingsScreen()),
        );
      },
    ),
    LiveScreen(
      name: 'long_form',
      description: 'Long form',
      needsLogin: false,
      sections: {'additional_information': bottomKey},
      open: () async => openLongForm(),
    ),
    LiveScreen(
      name: 'todo_detail',
      description: 'Todo detail',
      needsLogin: true,
      open: () async => openNewestTodo(),
      record: LiveScreenRecord(
        meaning: 'todo id',
        open: (id) async => openTodo(id),
      ),
    ),
  ]);

AutomationDemoHost(
  registry: buildDemoRegistry(navigatorKey),
  screens: demoModeEnabled ? buildScreens(navigatorKey) : null,
  onPrepare: prepareDemoState,
  onSetTheme: (brightness) async => themeMode.value =
      brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
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
| `{"command":"list_screens"}` for a record-aware screen | `{"event":"screens","screens":[{"name":"todo_detail","description":"Todo detail","needs_login":true,"record_id":"todo id"}]}` |
| `{"command":"navigate","screen":"account_settings","settings":{"test_token":"..."},"language":"de"}` | `{"event":"navigated","screen":"account_settings"}` |
| `{"command":"navigate","screen":"todo_detail","record_id":11551}` | `{"event":"navigated","screen":"todo_detail"}` |
| `{"command":"set_theme","theme":"dark"}` | `{"event":"theme_set","theme":"dark"}` |
| `{"command":"navigate","screen":"long_form","theme":"dark","section":"additional_information"}` | `{"event":"navigated","screen":"long_form"}` |
| `{"command":"screenshot","name":"account_settings","pixel_ratio":1.0,"full":true}` | `{"event":"screenshot","name":"account_settings","png":"<base64 PNG>"}` |
| `{"command":"gesture","kind":"tap","at":[0.5,0.5]}` | `{"event":"gestured","kind":"tap"}` |
| `{"command":"gesture","kind":"drag","from":[0.5,0.7],"to":[0.5,0.3],"duration_ms":400}` | `{"event":"gestured","kind":"drag"}` |
| `{"command":"gesture","kind":"pinch","center":[0.5,0.5],"scale":2,"screen":"image_viewer","section":"image"}` | `{"event":"gestured","kind":"pinch"}` |
| `{"command":"reset","settings":{},"language":null}` | `{"event":"reset_done"}` |

Failures return the existing `{"event":"error","message":"..."}` event;
the connection remains usable. Screenshot captures the current view and does
not navigate. `pixel_ratio` defaults to `1.0`. `navigate` runs `onPrepare`
before opening the named screen, so the same command restores a screen after a
reload or restart. `reset` runs `onPrepare` without opening another screen.

`set_theme` accepts a `theme` (`dark` or `light`), calls the app-owned
`AutomationDemoHost.onSetTheme` hook and replies with `theme_set` after the
updated frame settles. Without a hook, it returns
`theme switching is not supported: the app registered no onSetTheme hook`.
The optional `theme` field on `navigate` remains supported for older tools; the
connector calls its hook after `onPrepare` and before opening the screen. Apps
should apply the theme in memory and restore it in `onRestore` when needed.

## Gestures

The debug-only `gesture` command touches the screen currently shown and does not
navigate. `tap` uses `at: [x, y]`; `drag` uses `from: [x, y]` and `to: [x, y]`;
`pinch` uses `center: [x, y]` and a positive `scale` (above `1` zooms in,
below `1` zooms out). Each point is a pair of fractions from `0` to `1` within
the full app view. To target a registered section instead, send both its
`screen` name and `section` key; those fractions are then relative to that
widget's bounds.

`duration_ms` is optional: taps hold for `100` ms, while drags and pinches move
over `300` ms by default. Invalid gesture kinds, point shapes or ranges, and
non-positive durations or pinch scales return the usual `error` event. A
missing screen or section also returns `error`. The connector replies with
`gestured` after Flutter's gesture handling and the resulting frame settle. Send
a `screenshot` command afterwards to capture the changed view.

## Reading and acting on text

These debug-only commands let a connected tool inspect the current app view and
interact with its visible controls. They run inside Flutter; they do not send
input to the operating system.

| Command | Reply |
| --- | --- |
| `{"command":"read_text"}` | `{"event":"visible_text","entries":[{"text":"Sign in","kind":"button","enabled":true,"bounds":[0.1,0.8,0.9,0.86]},{"text":"me@x.de","kind":"text_field","enabled":true,"bounds":[0.1,0.3,0.9,0.38],"label":"Email","hint":"you@example.com","value":"me@x.de"}]}` |
| `{"command":"tap_text","text":"Sign in"}` | `{"event":"text_tapped","text":"Sign in"}` |
| `{"command":"tap_text","text":"Save","match":"contains","index":1}` | `{"event":"text_tapped","text":"Save"}` |
| `{"command":"tap_key","key":"login_button"}` | `{"event":"key_tapped","key":"login_button"}` |
| `{"command":"type_text","text":"me@x.de","field":"Email"}` | `{"event":"text_typed","text":"me@x.de"}` |
| `{"command":"press_key","key":"shift_tab"}` | `{"event":"key_pressed","key":"shift_tab"}` |

`read_text` returns entries in reading order, top to bottom and left to right.
Each `bounds` value is `[left, top, right, bottom]` as fractions of the app
view. `kind` is `text`, `button` (including links and other tappable controls),
or `text_field`. Every entry includes `enabled`. Text-field entries may also
include non-empty `label`, `hint` and `value`; their `text` is the current value
or, when empty, the field label. Text hidden behind a modal route or scrolled
outside the view is omitted.

The reader uses Flutter semantics. Custom widgets must expose semantics for
their text to appear; text drawn without semantics cannot be read. A plain text
entry can also be tapped at its centre when no tappable match exists for the
requested text.

`tap_text` uses an exact match by default. Set `match` to `contains` for a
substring match. Matching checks entry text and, for text fields, their label
and hint. Use the optional zero-based `index` to choose among multiple matches.
Without it, no match and ambiguous matches return an `error` with visible
candidates; an ambiguous error asks for an index. Only buttons and text fields
are preferred as targets when a tappable match exists.

`tap_key` taps a widget with the matching `ValueKey<String>`. `type_text` types
into the focused field; its optional `field` selects and focuses a text field by
an exact label or hint match first. A missing or ambiguous field selection
returns an `error` listing the available fields.

`press_key` accepts `enter`, `tab`, `shift_tab`, `escape`, `backspace`,
`arrow_up`, `arrow_down`, `arrow_left` and `arrow_right`. Enter performs the
focused text field's submit action, or inserts a newline in a multiline field.
Escape dismisses the current route when the app does not handle it. Each
successful command gets the event shown above; failures use the existing
`{"event":"error","message":"..."}` reply and leave the connection usable.

Try `read_text` and `tap_text` during the Windows live setup check.

## Record ids

`navigate.record_id` must be a JSON integer. A record id sent to a screen without
a `LiveScreenRecord` returns an error before `onPrepare` runs. When no id is
sent, a record-aware screen uses its ordinary `open` callback, so the app can
choose a fallback such as opening the newest matching record. A screen that
requires an id can report that from its ordinary `open` callback.

Register section keys on `LiveScreen.sections`, mapping stable section names to
`GlobalKey`s attached to the corresponding widgets. `list_screens` includes a
screen's `sections` array only when it has registered sections. A requested
unknown key returns an error listing the available keys. The target widget must
already be built when navigation finishes; avoid targets far below the fold in
lazy builders. The connector uses `Scrollable.ensureVisible` to bring the
section to the top of its scrollable.

Set `full: true` on `screenshot` to render the current route's main vertical
scrollable as one tall image. The connector expands the app layout temporarily,
captures it, then restores the viewport size. Non-scrollable screens return a
normal still. Full images are capped at 16384 physical pixels tall; layouts
that size themselves directly from `MediaQuery` may not expand.

Malformed commands return `{"event":"error","message":"malformed tool command: ..."}`
and leave the connection available for the next command.

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
- Register a `LiveScreenRecord` on screens that open one record by id.
- Add an `onSetTheme` hook if live captures should switch the app theme.
- Register section `GlobalKey`s for widgets that can be scrolled into view.
- Use `full: true` for one-image captures of long vertical screens.
- Make `onPrepare` deterministic and `onRestore` restore persisted user state.
- Keep the registry and live-only UI out of production mode; do not commit test
  credentials.
- Try list, navigate, screenshot and reset on Windows and on the target Android
  emulator, then point the app's setup todo to this guide.
