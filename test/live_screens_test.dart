import 'package:automated_screenshot_connector/src/live_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry rejects duplicate screen names', () {
    final registry = LiveScreenRegistry();
    registry.add([_screen('home')]);

    expect(() => registry.add([_screen('home')]), throwsArgumentError);
  });

  test('unknown screen error lists available names', () {
    final registry = LiveScreenRegistry()
      ..add([_screen('home'), _screen('settings')]);

    expect(
      () => registry.get('missing'),
      throwsA(
        isA<UnknownScreenError>().having(
          (error) => error.message,
          'message',
          contains('home, settings'),
        ),
      ),
    );
  });

  test('screen JSON uses the live protocol keys', () {
    expect(_screen('settings', needsLogin: true).toJson(), {
      'name': 'settings',
      'description': 'Settings screen',
      'needs_login': true,
    });
  });
}

LiveScreen _screen(String name, {bool needsLogin = false}) => LiveScreen(
  name: name,
  description: 'Settings screen',
  needsLogin: needsLogin,
  open: () async {},
);
