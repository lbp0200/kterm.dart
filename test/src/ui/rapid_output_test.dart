import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

/// Tests for rapid sequential output handling.
///
/// This test suite addresses a bug where rapidly sequential PTY output
/// causes interleaved/jumbled display in kterm while other terminals show
/// correct output.
///
/// Bug symptom:
/// - Normal terminal: command1 echo → command2 echo → output1 → warning → output2
/// - kterm: output1 → command2 echo fragment → warning → output2
///   (command2 echo is missing or interleaved incorrectly)
///
/// The bug is likely in Flutter's rendering scheduling (markNeedsPaint timing)
/// rather than Terminal.write() itself, which processes data synchronously.
/// These tests verify Terminal's buffer handling is correct.

void main() {
  group('Rapid Sequential Output', () {
    late Terminal terminal;
    late TerminalController controller;

    setUp(() {
      terminal = Terminal();
      controller = TerminalController();
    });

    tearDown(() {
      controller.dispose();
    });

    Future<void> pumpTerminalView(
      WidgetTester tester, {
      Size size = const Size(800, 600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autofocus: false,
              alwaysShowCursor: true,
            ),
          ),
        ),
      );

      await tester.pump();
    }

    /// Test: Rapid writes should preserve data order in buffer.
    ///
    /// This tests Terminal.write() behavior with rapid sequential calls.
    /// Terminal.write() is synchronous, so buffer should always be correct.
    testWidgets(
      'Given rapid sequential writes, When writes happen rapidly, '
      'Then buffer contains all data in correct order',
      (tester) async {
        await pumpTerminalView(tester);

        // Simulate rapid PTY chunks arriving (like two redis-cli commands)
        // Chunk 1: command 1 echo
        terminal.write(
            'redis-cli --raw -h 10.128.0.125 -p 19000 hlen MAIL_TYPE_UNREAD_500008_101300000057838501\n');
        await tester.pump(const Duration(milliseconds: 1));

        // Chunk 2: command 2 echo
        terminal.write(
            'redis-cli --raw -h twdchat-mail-migrate-pub.redis.rds-aliyun-america.rds.aliyuncs.com -a \'twdchat:TwdChatTair_qCitEn44\' hlen MAIL_TYPE_UNREAD_500008_101300000057838501\n');
        await tester.pump(const Duration(milliseconds: 1));

        // Chunk 3: output 1
        terminal.write('206\n');
        await tester.pump(const Duration(milliseconds: 1));

        // Chunk 4: warning
        terminal.write(
            'Warning: Using a password with \'-a\' or \'-u\' option on the command line interface may not be safe.\n');
        await tester.pump(const Duration(milliseconds: 1));

        // Chunk 5: output 2
        terminal.write('206\n');
        await tester.pump(const Duration(milliseconds: 1));

        // Verify buffer contains all data in correct order
        final bufferText = terminal.buffer.getText();
        expect(bufferText, contains('10.128.0.125'));
        expect(bufferText, contains('twdchat-mail-migrate-pub'));
        expect(bufferText, contains('206'));
        expect(bufferText, contains('Warning: Using a password'));

        // Verify order: first command should appear before second command
        final pos1 = bufferText.indexOf('10.128.0.125');
        final pos2 = bufferText.indexOf('twdchat-mail-migrate-pub');
        expect(pos1, lessThan(pos2),
            reason: 'First command should appear before second command');
      },
    );

    /// Test: Zero-delay rapid writes (back-to-back).
    ///
    /// This tests what happens when writes come without any pump() between them.
    /// In real PTY scenario, chunks come via async stream, so there might be
    /// microtasks between chunks.
    testWidgets(
      'Given zero-delay writes, When writes happen without pump, '
      'Then buffer contains all data in correct order',
      (tester) async {
        await pumpTerminalView(tester);

        // Back-to-back writes without pump() between
        terminal.write('chunk1');
        terminal.write('chunk2');
        terminal.write('chunk3');

        await tester.pump();

        final bufferText = terminal.buffer.getText();
        expect(bufferText, contains('chunk1'));
        expect(bufferText, contains('chunk2'));
        expect(bufferText, contains('chunk3'));

        // Verify order
        expect(bufferText.indexOf('chunk1'),
            lessThan(bufferText.indexOf('chunk2')));
        expect(bufferText.indexOf('chunk2'),
            lessThan(bufferText.indexOf('chunk3')));
      },
    );

    /// Test: Simulates actual redis-cli output pattern.
    ///
    /// This mimics the real-world scenario:
    /// 1. Command 1 input (echoed by shell)
    /// 2. Command 1 output
    /// 3. Command 2 input (echoed by shell)
    /// 4. Command 2 output
    testWidgets(
      'Given redis-cli-like pattern, When commands run sequentially, '
      'Then all output appears in correct order',
      (tester) async {
        await pumpTerminalView(tester);

        // Simulate: command 1 input (echoed by PTY/shell)
        terminal.write('echo "first"\n');
        await tester.pump(const Duration(milliseconds: 5));

        // Simulate: command 1 output
        terminal.write('first\n');
        await tester.pump(const Duration(milliseconds: 5));

        // Simulate: command 2 input
        terminal.write('echo "second"\n');
        await tester.pump(const Duration(milliseconds: 5));

        // Simulate: command 2 output
        terminal.write('second\n');
        await tester.pump(const Duration(milliseconds: 5));

        final bufferText = terminal.buffer.getText();

        // All content should be present
        expect(bufferText, contains('echo "first"'));
        expect(bufferText, contains('first'));
        expect(bufferText, contains('echo "second"'));
        expect(bufferText, contains('second'));

        // Verify ordering: first command block before second command block
        final firstCmdPos = bufferText.indexOf('echo "first"');
        final firstOutputPos = bufferText.indexOf('first\n');
        final secondCmdPos = bufferText.indexOf('echo "second"');
        final secondOutputPos = bufferText.indexOf('second\n');

        expect(firstCmdPos, lessThan(firstOutputPos),
            reason: 'First command echo should appear before its output');
        expect(firstOutputPos, lessThan(secondCmdPos),
            reason: 'First output should appear before second command');
        expect(secondCmdPos, lessThan(secondOutputPos),
            reason: 'Second command echo should appear before its output');
      },
    );

    /// Test: Very long rapid write sequence.
    ///
    /// This tests if many rapid chunks could cause buffer issues.
    testWidgets(
      'Given 100 rapid writes, When all written, Then buffer is correct',
      (tester) async {
        await pumpTerminalView(tester);

        // Write 100 chunks rapidly
        for (var i = 0; i < 100; i++) {
          terminal.write('line$i\n');
        }
        await tester.pump();

        final bufferText = terminal.buffer.getText();

        // Verify all lines present
        for (var i = 0; i < 100; i++) {
          expect(bufferText, contains('line$i'),
              reason: 'line$i should be present');
        }

        // Verify order: earlier lines should appear before later lines
        for (var i = 0; i < 99; i++) {
          final posI = bufferText.indexOf('line$i\n');
          final posI1 = bufferText.indexOf('line${i + 1}\n');
          expect(posI, lessThan(posI1),
              reason: 'line$i should appear before line${i + 1}');
        }
      },
    );

    /// Test: Rapid writes with escape sequences.
    ///
    /// Tests that escape sequences in rapid writes don't corrupt state.
    testWidgets(
      'Given rapid writes with escape sequences, When written, '
      'Then content is preserved and escape sequences are parsed correctly',
      (tester) async {
        await pumpTerminalView(tester);

        terminal.write('\x1b[31mred\x1b[0m');
        await tester.pump(const Duration(milliseconds: 1));

        terminal.write('\x1b[32mgreen\x1b[0m');
        await tester.pump(const Duration(milliseconds: 1));

        terminal.write('\x1b[33myellow\x1b[0m');
        await tester.pump(const Duration(milliseconds: 1));

        final bufferText = terminal.buffer.getText();

        expect(bufferText, contains('red'));
        expect(bufferText, contains('green'));
        expect(bufferText, contains('yellow'));
      },
    );

    /// Test: Verifies cursor position after rapid writes.
    ///
    /// Cursor position should be correct after rapid sequential writes.
    testWidgets(
      'Given rapid writes, When complete, Then cursor is at correct position',
      (tester) async {
        await pumpTerminalView(tester);

        terminal.write('abc');
        await tester.pump(const Duration(milliseconds: 1));
        terminal.write('def');
        await tester.pump(const Duration(milliseconds: 1));
        terminal.write('ghi');
        await tester.pump();

        // Cursor should be at position 9 (end of "abcdefghi")
        expect(terminal.buffer.cursorX, equals(9));
      },
    );
  });
}
