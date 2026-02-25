/// No-op haptics implementation used on non-Windows platforms (web, macOS,
/// Linux, Android, iOS) and as a fallback whenever WinRT is unavailable.
library;

import 'haptics_controller.dart';

/// Returns the [StubHapticsController] on platforms without dart:ffi.
HapticsController createHapticsController() => StubHapticsController();

/// No-op [HapticsController]; all methods are intentional no-ops.
class StubHapticsController implements HapticsController {
  @override
  Future<void> initialize() async {}

  @override
  void startDrawingFeedback({required int pointerId, double intensity = 1.0}) {}

  @override
  void updateIntensity(double intensity) {}

  @override
  void stopFeedback() {}

  @override
  void dispose() {}
}
