import 'package:flutter_test/flutter_test.dart';

import 'package:just_note/haptics/haptics_controller.dart';
import 'package:just_note/haptics/haptics_controller_stub.dart';

void main() {
  group('StubHapticsController', () {
    late StubHapticsController controller;

    setUp(() => controller = StubHapticsController());

    test('initialize completes without error', () async {
      await expectLater(controller.initialize(), completes);
    });

    test('startDrawingFeedback is a no-op', () {
      expect(
        () => controller.startDrawingFeedback(pointerId: 1, intensity: 0.8),
        returnsNormally,
      );
    });

    test('updateIntensity is a no-op', () {
      expect(() => controller.updateIntensity(0.5), returnsNormally);
    });

    test('stopFeedback is a no-op', () {
      expect(() => controller.stopFeedback(), returnsNormally);
    });

    test('dispose is a no-op', () {
      expect(() => controller.dispose(), returnsNormally);
    });
  });

  group('HapticsController.create', () {
    test('returns a HapticsController instance', () {
      // On non-Windows test environments the factory returns a stub.
      final controller = HapticsController.create();
      expect(controller, isA<HapticsController>());
    });

    test('created instance initialises without error', () async {
      final controller = HapticsController.create();
      await expectLater(controller.initialize(), completes);
      controller.dispose();
    });
  });
}
