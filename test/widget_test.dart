import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:olympusgates/widgets/olympus_button.dart';

void main() {
  testWidgets('OlympusButton renders its label and responds to taps',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OlympusButton(
              label: 'PLAY',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('PLAY'), findsOneWidget);
    await tester.tap(find.text('PLAY'));
    expect(tapped, isTrue);
  });
}
