import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('steps round-trip through JSON', () {
    const steps = [
      TapStep('settings_button'),
      TypeTextStep('hi', charDelayMs: 30),
      PauseStep(1.5),
      ScreenshotStep('home'),
      CustomStep('back'),
    ];
    final decoded = [for (final s in steps) DemoStep.fromJson(s.toJson())];
    expect([for (final s in decoded) s.toJson()],
        [for (final s in steps) s.toJson()]);
  });

  test('unknown type and missing field are FormatExceptions', () {
    expect(() => DemoStep.fromJson({'type': 'swipe'}),
        throwsA(isA<FormatException>()));
    expect(() => DemoStep.fromJson({'type': 'tap'}),
        throwsA(isA<FormatException>()));
  });

  test('localizeSteps fills placeholders in type_text only', () {
    const steps = [TypeTextStep('{price} = 20'), ScreenshotStep('{price}')];
    final localized = localizeSteps(steps, {'price': 'Preis'});
    expect((localized[0] as TypeTextStep).text, 'Preis = 20');
    expect((localized[1] as ScreenshotStep).name, '{price}');
    expect(localizeSteps(steps, {}), same(steps));
    expect(() => localizeSteps(steps, {'other': 'x'}), throwsArgumentError);
  });

  test('estimatedDuration counts delays plus start delay and end hold', () {
    const steps = [TypeTextStep('abc', charDelayMs: 100), PauseStep(2)];
    expect(estimatedDuration(steps),
        (startDelayMs + 300 + 2000 + endHoldMs) / 1000);
  });

  test('registry rejects duplicate ids and reports unknown ones', () {
    final registry = DemoRegistry()
      ..add([const DemoScript(id: 1, name: 'a', steps: [])]);
    expect(() => registry.add([const DemoScript(id: 1, name: 'b', steps: [])]),
        throwsArgumentError);
    expect(() => registry.get(7), throwsA(isA<UnknownDemoError>()));
    expect(registry.get(1).name, 'a');
  });
}
