import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';

import 'screens.dart';

void main() => runApp(LiveScreensExample());

/// Small Windows app that exposes named routes to the live screenshot tool.
class LiveScreensExample extends StatefulWidget {
  /// Creates the example, optionally targeting a test listener.
  LiveScreensExample({
    super.key,
    this.host = const String.fromEnvironment(automationHostDefine),
  });

  /// TCP `ip:port` for the connector, defaulted from `AUTOMATION_HOST`.
  final String host;

  @override
  State<LiveScreensExample> createState() => _LiveScreensExampleState();
}

class _LiveScreensExampleState extends State<LiveScreensExample> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutomationDemoHost(
    host: widget.host,
    registry: DemoRegistry(),
    screens: widget.host.isEmpty ? null : buildLiveScreens(_navigatorKey),
    onSetTheme: (brightness) async {
      _themeMode.value = brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    },
    onPrepare: (_, __) async {
      _navigatorKey.currentState?.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    },
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: !demoModeEnabled,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: const HomeScreen(),
      ),
    ),
  );
}
