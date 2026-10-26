// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adventure_map/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AdventureMapApp());

    // Verify that splash screen is shown
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}