/// App-side connector for the automated-application-screenshots tool
/// (network mode): the app connects to the tool, plays scripted demos,
/// records video on the device and sends stills in-app.
library;

export 'src/app_logger.dart';
export 'src/client.dart';
export 'src/demo_host.dart';
export 'src/protocol.dart';
export 'src/registry.dart';
export 'src/screen_recorder.dart';
export 'src/step_executor.dart';
export 'src/steps.dart';
export 'src/still_capture.dart';
