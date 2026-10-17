import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';

import 'screens.dart';

void main() => runApp(LiveScreensExample());

/// Small Windows app that exposes two routes to the live screenshot tool.
class LiveScreensExample extends StatelessWidget {
  /// Creates the example, optionally targeting a test listener.
  LiveScreensExample({
    super.key,
    this.host = const String.fromEnvironment(automationHostDefine),
  });

  /// TCP `ip:port` for the connector, defaulted from `AUTOMATION_HOST`.
  final String host;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => AutomationDemoHost(
    host: host,
    registry: DemoRegistry(),
    screens: host.isEmpty ? null : buildLiveScreens(_navigatorKey),
    onPrepare: (_, __) async {
      _navigatorKey.currentState?.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    },
    child: MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: !demoModeEnabled,
      home: const HomeScreen(),
    ),
  );
}
