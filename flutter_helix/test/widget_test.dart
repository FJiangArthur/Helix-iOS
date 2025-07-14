// Basic Flutter widget test for the Helix app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/app.dart';

void main() {
  testWidgets('Helix app launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HelixApp());

    // Verify that our app launches without errors
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}