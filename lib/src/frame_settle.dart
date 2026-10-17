import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Maximum time a live command waits for animations and route transitions.
const Duration liveSettleTimeout = Duration(seconds: 3);

/// Waits for a frame with no transient callbacks, or until [timeout] expires.
Future<void> waitForSettledFrame({Duration timeout = liveSettleTimeout}) async {
  final binding = SchedulerBinding.instance;
  final timedOut = Completer<void>();
  final timer = Timer(timeout, timedOut.complete);

  try {
    while (true) {
      binding.scheduleFrame();
      await Future.any<void>([binding.endOfFrame, timedOut.future]);
      if (timedOut.isCompleted || binding.transientCallbackCount == 0) return;
    }
  } finally {
    timer.cancel();
  }
}
