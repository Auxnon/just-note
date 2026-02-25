import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:just_note/main.dart';

void main() {
  testWidgets('App renders DrawingPage with toolbar', (tester) async {
    await tester.pumpWidget(const JustNoteApp());

    // The app-bar title should be visible.
    expect(find.text('JustNote'), findsOneWidget);

    // The clear-canvas button should be present.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
