import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_logger.dart';
import 'client.dart';
import 'protocol.dart';
import 'registry.dart';
import 'screen_recorder.dart';
import 'step_executor.dart';
import 'steps.dart';
import 'still_capture.dart';

/// Resets the app to a clean, deterministic state before a demo plays.
///
/// [settings] is the tool config's `app_settings`, [language] the run's UI
/// language (null when the demo has none).
typedef PrepareCallback = Future<void> Function(
    Map<String, String> settings, String? language);

/// Undoes what a [PrepareCallback] changed, once the tool has disconnected.
///
/// [PrepareCallback] runs per demo and normally writes to the app's real
/// stores, so without this the device is left in the demo's state — a demo
/// backend URL the app then keeps polling long after the recording ended.
typedef RestoreCallback = Future<void> Function();

/// `--dart-define` key naming the tool's `ip:port`.
const String automationHostDefine = 'AUTOMATION_HOST';

/// True when the app was built with [automationHostDefine], i.e. to be recorded.
///
/// Lets the app strip anything that would end up in the captured frames but is
/// not part of the product — most obviously
/// `MaterialApp.debugShowCheckedModeBanner`, since demos run a debug build and
/// the connector's `RepaintBoundary` sits above `MaterialApp`, so the banner
/// lands in every still.
const bool demoModeEnabled = bool.hasEnvironment(automationHostDefine);

/// Wraps the app and plays demos on the recording tool's command.
///
/// With no [host] (the default reads `--dart-define=AUTOMATION_HOST=ip:port`)
/// it renders [child] and nothing else, so production builds pay nothing.
class AutomationDemoHost extends StatefulWidget {
  /// Creates the host around [child] (normally the `MaterialApp`).
  const AutomationDemoHost({
    super.key,
    required this.child,
    required this.registry,
    this.onPrepare,
    this.onRestore,
    this.host = const String.fromEnvironment(automationHostDefine),
    this.recorder = const PluginScreenRecorder(),
    this.retry = const ConnectRetry(),
    this.exitWhenDone = true,
  });

  /// The app.
  final Widget child;

  /// Demos playable by id, plus custom actions.
  final DemoRegistry registry;

  /// Called with the run's settings and language before each demo.
  final PrepareCallback? onPrepare;

  /// Called once after the tool disconnects, to undo [onPrepare].
  final RestoreCallback? onRestore;

  /// `ip:port` of the tool; empty = demo mode off.
  final String host;

  /// Screen recorder used for video demos.
  final ScreenRecorder recorder;

  /// How long to keep waiting for the tool; see [DemoClient.connectWithRetry].
  final ConnectRetry retry;

  /// Whether to close the app once the run is over and [onRestore] has run.
  ///
  /// The app vanishing from the screen is the only signal on the device that
  /// the recording finished — a demo build left sitting on its home screen
  /// looks exactly like one still recording. Only ever reached in a build
  /// carrying [automationHostDefine].
  final bool exitWhenDone;

  @override
  State<AutomationDemoHost> createState() => _AutomationDemoHostState();
}

class _AutomationDemoHostState extends State<AutomationDemoHost> {
  final GlobalKey _boundaryKey = GlobalKey();
  DemoClient? _client;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.host.isNotEmpty) _connect();
  }

  Future<void> _connect() async {
    final parts = widget.host.split(':');
    final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (port == null) {
      AppLogger.e('$automationHostDefine must be ip:port, got "${widget.host}"');
      return;
    }
    // Retries, so the tool may be started before or after the app.
    final client = await DemoClient.connectWithRetry(parts[0], port,
        retry: widget.retry, isCancelled: () => !mounted);
    if (client == null || !mounted) return;
    _client = client;
    // Demos run strictly one after another; asyncMap serializes them, and it
    // holds the stream's done event back until the last demo has finished —
    // which is what lets the restore run after the run rather than during it.
    _subscription =
        client.commands.asyncMap(_runDemo).listen((_) {}, onDone: _finish);
  }

  Future<void> _runDemo(StartCommand command) async {
    final client = _client!;
    var recording = false;
    try {
      await widget.onPrepare?.call(command.settings, command.language);
      final steps = localizeSteps(
          command.steps ?? widget.registry.get(command.demo).steps,
          command.texts);
      if (command.video) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        recording = await widget.recorder.start('demo_${command.demo}');
        if (!recording) throw StateError('screen recording was not started');
      }
      await _delay(startDelayMs);
      client.sendLine(DemoEvents.demoStarted(command.demo));
      final executor = StepExecutor(
        still: StillCapture(_boundaryKey),
        onStill: (name, png) =>
            client.sendLine(DemoEvents.screenshot(name, png)),
        actions: widget.registry.customActions,
      );
      await executor.run(steps, pixelRatio: command.pixelRatio);
      await _delay(endHoldMs);
      client.sendLine(DemoEvents.demoEnded(command.demo));
      if (recording) {
        recording = false;
        final bytes = await widget.recorder.stop();
        client.sendLine(DemoEvents.videoHeader(command.demo, bytes.length));
        await client.sendBytes(bytes);
      }
    } on Object catch (e, stack) {
      AppLogger.e('demo ${command.demo} failed', error: e, stackTrace: stack);
      client.sendLine(DemoEvents.error(e.toString()));
      if (recording) await widget.recorder.stop().catchError((_) => bytesNone);
    } finally {
      if (command.video) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  /// Hands the app back its own state and closes it; failures must not break
  /// teardown — the app still has to exit when the restore threw.
  Future<void> _finish() async {
    try {
      await widget.onRestore?.call();
    } on Object catch (e, stack) {
      AppLogger.e('restoring the app state failed', error: e, stackTrace: stack);
    }
    if (!widget.exitWhenDone) return;
    AppLogger.i('run finished; closing the app');
    await SystemNavigator.pop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: widget.child);

  Future<void> _delay(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
}

/// Placeholder for a failed recorder stop inside error handling.
final bytesNone = Uint8List(0);
