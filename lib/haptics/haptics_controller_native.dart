/// Native (non-web) haptics factory: returns the Windows implementation on
/// Windows and the stub on all other native platforms.
library;

import 'dart:io';

import 'haptics_controller.dart';
import 'haptics_controller_stub.dart';
import 'haptics_controller_windows.dart';

/// Returns a [WindowsHapticsController] on Windows and a
/// [StubHapticsController] on all other platforms.
HapticsController createHapticsController() {
  if (Platform.isWindows) {
    return WindowsHapticsController();
  }
  return StubHapticsController();
}
