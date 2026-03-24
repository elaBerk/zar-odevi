// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_deneme/main.dart';

void main() {
  testWidgets('Dice throw screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify initial throw button is shown.
    expect(find.text('Zar At 🎲'), findsOneWidget);

    // Verify initial dice value is visible.
    expect(find.textContaining('Sonuç:'), findsOneWidget);

    // Ensure dice face is present before tapping.
    expect(find.byType(Container), findsWidgets);

    // Tap the throw button and verify animation begins.
    await tester.tap(find.text('Zar At 🎲'));
    await tester.pump();

    expect(find.text('Atılıyor...'), findsOneWidget);
    expect(find.textContaining('Sonuç:'), findsOneWidget);
  });
}
