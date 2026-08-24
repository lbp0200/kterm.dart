import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

/// Stress tests: Flutter rendering / UI under heavy load.
///
/// These tests exercise [TerminalView] with rapid write+pump cycles,
/// large output volumes, and frequent operations to verify that the
/// Flutter rendering layer does not crash, OOM, or drop data.
///
/// Run: `flutter test test/stress/render_stress_test.dart`

Widget buildApp(Terminal terminal, TerminalController controller) {
  return MaterialApp(
    home: Scaffold(
      body: TerminalView(
        terminal,
        controller: controller,
        autofocus: false,
      ),
    ),
  );
}

Future<void> pumpView(WidgetTester tester, Terminal terminal,
    TerminalController controller) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(buildApp(terminal, controller));
  await tester.pump();
}

/// After all writes, pump extra frames to flush pending microtasks
/// from [_scheduleNotify] and resulting render callbacks.
Future<void> flushMicrotasks(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('rendering stress', () {
    testWidgets('rapid 500 writes with pump after each', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 500; i++) {
        terminal.write('line $i\n');
        await tester.pump(const Duration(milliseconds: 1));
      }

      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('line 499'));
    });

    testWidgets('rapid 1000 writes without pump between', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 1000; i++) {
        terminal.write('DATA_LINE_$i\n');
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('DATA_LINE_999'));
      // Verify data integrity: sample key lines
      for (final i in [0, 50, 100, 500, 999]) {
        expect(text, contains('DATA_LINE_$i'),
            reason: 'Missing DATA_LINE_$i after 1000 writes');
      }
    });

    testWidgets('rapid writes with SGR color (500 lines)', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 500; i++) {
        terminal.write('\x1b[${31 + i % 7}mcolored line $i\x1b[0m\n');
        if (i % 10 == 0) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('colored line 499'));
    });

    testWidgets('rapid writes with cursor movement', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 500; i++) {
        terminal.write('\x1b[${i % 24 + 1};1H');
        terminal.write('position $i');
        terminal.write('\x1b[${i % 24 + 1};50H');
        terminal.write('col $i\n');
        if (i % 20 == 0) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('position 499'));
    });

    testWidgets('erase + rewrite storm', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 500; i++) {
        terminal.write('\x1b[2J'); // clear screen
        terminal.write('\x1b[H'); // home cursor
        terminal.write('content after clear $i\n');
        if (i % 50 == 0) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('content after clear 499'));
    });

    testWidgets('alternate screen rapid switching', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      await pumpView(tester, terminal, controller);

      for (int i = 0; i < 200; i++) {
        terminal.write('\x1b[?1049h'); // alt screen
        terminal.write('alt $i\n');
        terminal.write('\x1b[?1049l'); // main screen
        terminal.write('main $i\n');
        if (i % 20 == 0) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('main 199'));
    });
  });

  group('large output rendering', () {
    testWidgets('50 KB of text rendered in TerminalView', (tester) async {
      final terminal = Terminal(maxLines: 10000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(terminal, controller));
      await tester.pump();

      // Write 1000 lines
      final buf = StringBuffer();
      for (int i = 0; i < 1000; i++) {
        buf.write('Line $i: ${'text ' * 10}\n');
      }
      terminal.write(buf.toString());
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('Line 999'));
    });

    testWidgets('100 KB of SGR-colored text rendered', (tester) async {
      final terminal = Terminal(maxLines: 10000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(terminal, controller));
      await tester.pump();

      // Write 2000 lines with SGR colors
      final buf = StringBuffer();
      for (int i = 0; i < 2000; i++) {
        buf.write('\x1b[${31 + i % 7}m');
        buf.write('Line $i: ${'X' * 40}');
        buf.write('\x1b[0m\n');
      }
      terminal.write(buf.toString());
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('Line 1999'));
    });

    testWidgets('resize during large output', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(terminal, controller));
      await tester.pump();

      // Write data, then resize view
      for (int i = 0; i < 300; i++) {
        terminal.write('Line $i with some longer text to wrap\n');
        if (i % 50 == 0) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }

      // Resize viewport
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      terminal.write('after resize\n');
      // Resize back
      tester.view.physicalSize = const Size(800, 600);
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('after resize'));
    });

    testWidgets('data integrity after large output', (tester) async {
      final terminal = Terminal(maxLines: 5000);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(terminal, controller));
      await tester.pump();

      // Write 500 unique lines
      final buf = StringBuffer();
      for (int i = 0; i < 500; i++) {
        buf.write('INTEGRITY_CHECK_${i}: ${'data ' * 20}\n');
      }
      terminal.write(buf.toString());
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      // Verify a sample of lines across the output
      for (final i in [0, 1, 50, 99, 100, 249, 250, 499]) {
        expect(text, contains('INTEGRITY_CHECK_$i'),
            reason: 'Missing INTEGRITY_CHECK_$i after large output');
      }
    });
  });

  group('reflow stress (widget)', () {
    testWidgets('reflow enabled: rapid resize with content', (tester) async {
      final terminal = Terminal(reflowEnabled: true);
      terminal.resize(80, 24);
      final controller = TerminalController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildApp(terminal, controller));
      await tester.pump();

      // Fill terminal with data
      for (int i = 0; i < 200; i++) {
        terminal.write('Data line $i: ${'word ' * 10}\n');
      }
      await tester.pump();

      // Resize rapidly
      for (final w in [60, 100, 40, 120, 80]) {
        tester.view.physicalSize = Size(w * 10, 600);
        await tester.pump();
      }
      await flushMicrotasks(tester);

      final text = terminal.buffer.getText();
      expect(text, contains('Data line 199'));
    });
  });
}
