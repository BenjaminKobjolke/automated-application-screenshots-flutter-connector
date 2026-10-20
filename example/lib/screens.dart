import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';

final GlobalKey _bottomSectionKey = GlobalKey();

/// Builds the example's named screens using the app's navigator key.
LiveScreenRegistry buildLiveScreens(GlobalKey<NavigatorState> navigatorKey) {
  return LiveScreenRegistry()..add([
    LiveScreen(
      name: 'home',
      description: 'Home screen',
      needsLogin: false,
      open: () async {
        // A push Future completes only when its route is popped.
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      },
    ),
    LiveScreen(
      name: 'details',
      description: 'Details screen',
      needsLogin: false,
      open: () async {
        // A push Future completes only when its route is popped.
        navigatorKey.currentState!.pushReplacement<void, void>(
          MaterialPageRoute<void>(builder: (_) => const DetailsScreen()),
        );
      },
    ),
    LiveScreen(
      name: 'long',
      description: 'Long scrollable screen',
      needsLogin: false,
      sections: {'bottom': _bottomSectionKey},
      open: () async {
        navigatorKey.currentState!.pushReplacement<void, void>(
          MaterialPageRoute<void>(builder: (_) => const LongScreen()),
        );
      },
    ),
  ]);
}

/// The first route in the example.
class HomeScreen extends StatelessWidget {
  /// Creates the home route.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home screen')),
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(builder: (_) => const DetailsScreen()),
        ),
        child: const Text('Open details'),
      ),
    ),
  );
}

/// The second route in the example.
class DetailsScreen extends StatelessWidget {
  /// Creates the details route.
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Details')),
    body: const Center(child: Text('Details screen')),
  );
}

/// A tall example route with a section registered for scroll navigation.
class LongScreen extends StatelessWidget {
  /// Creates the long route.
  const LongScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Long screen')),
    body: SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 1600),
          Text('Bottom section', key: _bottomSectionKey),
        ],
      ),
    ),
  );
}
