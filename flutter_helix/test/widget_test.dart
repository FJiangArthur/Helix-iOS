// Basic Flutter widget test for the Helix app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/main.dart';

void main() {
  testWidgets('Helix app launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HelixApp());

    // Verify that our app launches with the correct content
    expect(find.text('AI-Powered Conversation Intelligence'), findsOneWidget);
    expect(find.text('Flutter Architecture Foundation Ready! 🚀'), findsOneWidget);
    expect(find.byIcon(Icons.headset_mic), findsOneWidget);
  });
}