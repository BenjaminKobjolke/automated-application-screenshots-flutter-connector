import 'package:automated_screenshot_connector/src/live_screens.dart';
import 'package:flutter/widgets.dart';
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
    expect(
      _screen(
        'todo_detail',
        record: LiveScreenRecord(meaning: 'todo id', open: (_) async {}),
      ).toJson()['record_id'],
      'todo id',
    );
  });

  test(
    'opener uses the plain callback when no record id is supplied',
    () async {
      var plainOpenCalled = false;
      final screen = _screen(
        'todo_detail',
        record: LiveScreenRecord(meaning: 'todo id', open: (_) async {}),
        open: () async => plainOpenCalled = true,
      );

      await screen.opener(null)();

      expect(plainOpenCalled, isTrue);
    },
  );

  test('opener passes a record id to its record callback', () async {
    int? openedId;
    final screen = _screen(
      'todo_detail',
      record: LiveScreenRecord(
        meaning: 'todo id',
        open: (id) async => openedId = id,
      ),
    );

    await screen.opener(7)();

    expect(openedId, 7);
  });

  test('opener rejects a record id when the screen has no record callback', () {
    expect(
      () => _screen('settings').opener(7),
      throwsA(
        isA<RecordIdNotSupportedError>().having(
          (error) => error.message,
          'message',
          contains('settings'),
        ),
      ),
    );
  });

  test('sections are included in JSON only when registered', () {
    expect(_screen('home').toJson().containsKey('sections'), isFalse);
    expect(
      _screen('home', sections: {'summary': GlobalKey()}).toJson()['sections'],
      ['summary'],
    );
  });

  test('unknown section error lists available keys or none', () {
    final screen = _screen('home', sections: {'summary': GlobalKey()});
    expect(
      () => screen.section('missing'),
      throwsA(
        isA<UnknownSectionError>().having(
          (error) => error.message,
          'message',
          contains('available: summary'),
        ),
      ),
    );
    expect(
      () => _screen('empty').section('missing'),
      throwsA(
        isA<UnknownSectionError>().having(
          (error) => error.message,
          'message',
          contains('available: none'),
        ),
      ),
    );
  });
}

LiveScreen _screen(
  String name, {
  bool needsLogin = false,
  Map<String, GlobalKey> sections = const {},
  LiveScreenRecord? record,
  ScreenOpen? open,
}) => LiveScreen(
  name: name,
  description: 'Settings screen',
  needsLogin: needsLogin,
  sections: sections,
  open: open ?? () async {},
  record: record,
);
