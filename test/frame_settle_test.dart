import 'package:automated_screenshot_connector/src/frame_settle.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waits until a finite animation settles', (tester) async {
    final controller = AnimationController(
      vsync: _TestTickerProvider(),
      duration: const Duration(milliseconds: 40),
    )..forward();
    var settled = false;
    final settling = waitForSettledFrame().then((_) => settled = true);
    var advanced = Duration.zero;

    while (!settled && advanced < const Duration(seconds: 1)) {
      const step = Duration(milliseconds: 10);
      await tester.pump(step);
      advanced += step;
    }

    await settling;
    expect(settled, isTrue);
    expect(advanced, lessThan(const Duration(seconds: 1)));
    controller.dispose();
  });

  testWidgets('returns at timeout for a repeating animation', (tester) async {
    final controller = AnimationController(
      vsync: _TestTickerProvider(),
      duration: const Duration(milliseconds: 80),
    )..repeat();
    const timeout = Duration(milliseconds: 100);
    var settled = false;
    final settling = waitForSettledFrame(timeout: timeout)
        .then((_) => settled = true);
    var advanced = Duration.zero;

    while (!settled && advanced < timeout * 2) {
      const step = Duration(milliseconds: 10);
      await tester.pump(step);
      advanced += step;
    }

    await settling;
    expect(advanced, greaterThanOrEqualTo(timeout));
    expect(advanced, lessThan(timeout * 2));
    controller.dispose();
  });
}

class _TestTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
