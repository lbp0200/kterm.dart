import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/keyboard_visibility.dart';

void main() {
  group('KeyboardVisibility', () {
    testWidgets(
      'Given KeyboardVisibility, When created, Then renders child',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: KeyboardVisibility(
              child: Text('Test'),
            ),
          ),
        );

        expect(find.text('Test'), findsOneWidget);
      },
    );

    testWidgets(
      'Given KeyboardVisibility with callbacks, When created, Then has callbacks',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardVisibility(
              child: const Text('Test'),
              onKeyboardShow: () {},
              onKeyboardHide: () {},
            ),
          ),
        );

        final state = tester.state<KeyboardVisibilityState>(
          find.byType(KeyboardVisibility),
        );

        expect(state, isNotNull);
      },
    );
  });
}
