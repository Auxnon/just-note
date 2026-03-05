/// Platform-agnostic interface for haptic feedback during pen drawing.
///
/// Use [HapticsController.create] to obtain the correct platform
/// implementation at runtime.  On Windows the returned object wraps the
/// WinRT `SimpleHapticsController`; on every other platform a no-op stub
/// is returned so the drawing experience is unaffected.
library;

import 'haptics_controller_stub.dart'
    // On any native platform that has dart:ffi available, load the
    // implementation that can check Platform.isWindows at runtime and
    // return the Windows WinRT variant when appropriate.
    if (dart.library.ffi) 'haptics_controller_native.dart';

abstract class HapticsController {
  /// Factory constructor that returns the best implementation for the
  /// current platform.
  factory HapticsController.create() => createHapticsController();

  /// Prepare the controller.  Must be called before any feedback methods.
  ///
  /// On Windows this loads `combase.dll` and initialises the WinRT runtime.
  Future<void> initialize();

  /// Begin the continuous ink-friction haptic waveform.
  ///
  /// [pointerId] is the Flutter pointer ID for the active stylus pointer,
  /// which maps to the Windows `POINTER_ID` used by
  /// `IPenDeviceStatics::GetFromPointerId`.
  ///
  /// [intensity] is a value in `[0.0, 1.0]`; 1.0 corresponds to maximum
  /// sensation.
  void startDrawingFeedback({required int pointerId, double intensity = 1.0});

  /// Update the haptic intensity without interrupting the current waveform.
  void updateIntensity(double intensity);

  /// Stop any active haptic feedback immediately.
  void stopFeedback();

  /// Release resources.  After calling [dispose] the object must not be used.
  void dispose();
}
