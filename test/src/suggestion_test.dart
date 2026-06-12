import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/suggestion.dart';

void main() {
  group('SuggestionPortalController', () {
    test('Given new controller, When created, Then isShowing is false', () {
      final controller = SuggestionPortalController();
      expect(controller.isShowing, isFalse);
    });

    test('Given controller, When update called, Then becomes showing', () {
      final controller = SuggestionPortalController();

      controller.update(const Rect.fromLTWH(10, 20, 100, 30));

      expect(controller.isShowing, isTrue);
    });

    test(
        'Given controller showing, When update called multiple times, Then still showing',
        () {
      final controller = SuggestionPortalController();
      controller.update(const Rect.fromLTWH(0, 0, 10, 10));
      controller.update(const Rect.fromLTWH(5, 5, 20, 20));

      expect(controller.isShowing, isTrue);
    });

    test('Given controller, When show called, Then isShowing is true', () {
      final controller = SuggestionPortalController();
      controller.show();
      expect(controller.isShowing, isTrue);
    });

    test('Given controller showing, When hide called, Then isShowing is false',
        () {
      final controller = SuggestionPortalController();
      controller.show();
      controller.hide();
      expect(controller.isShowing, isFalse);
    });
  });

  group('SuggestionLayout', () {
    testWidgets('Given SuggestionLayout, When built, Then renders child',
        (tester) async {
      final cursorRect = ValueNotifier<Rect>(Rect.zero);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(8),
              cursorMargin: const EdgeInsets.all(4),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given SuggestionLayout, When cursorRect changes, Then relayouts',
        (tester) async {
      final cursorRect = ValueNotifier<Rect>(Rect.zero);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(8),
              cursorMargin: const EdgeInsets.all(4),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      // Trigger a cursorRect change
      cursorRect.value = const Rect.fromLTWH(10, 20, 100, 30);
      await tester.pump();

      // Widget still renders after cursor rect change
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given SuggestionLayout, When padding changes, Then updates render object',
        (tester) async {
      final cursorRect = ValueNotifier<Rect>(Rect.zero);
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              key: key,
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(8),
              cursorMargin: const EdgeInsets.all(4),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      // Change padding
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              key: key,
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(16),
              cursorMargin: const EdgeInsets.all(4),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'Given SuggestionLayout, When cursorMargin changes, Then updates render object',
        (tester) async {
      final cursorRect = ValueNotifier<Rect>(Rect.zero);
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              key: key,
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(8),
              cursorMargin: const EdgeInsets.all(4),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      // Change cursorMargin
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionLayout(
              key: key,
              cursorRect: cursorRect,
              padding: const EdgeInsets.all(8),
              cursorMargin: const EdgeInsets.all(8),
              child: const SizedBox(width: 50, height: 30),
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });

  group('SuggestionPortal', () {
    testWidgets('Given SuggestionPortal, When child built, Then shows child',
        (tester) async {
      final controller = SuggestionPortalController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestionPortal(
              controller: controller,
              overlayBuilder: (context) =>
                  const SizedBox(width: 100, height: 50),
              child: const Text('terminal-content'),
            ),
          ),
        ),
      );

      expect(find.text('terminal-content'), findsOneWidget);
    });
  });
}
