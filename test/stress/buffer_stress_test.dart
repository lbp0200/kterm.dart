import 'dart:math';

import 'package:test/test.dart';
import 'package:kterm/core.dart';

/// Stress tests: buffer / scrollback memory and correctness under load.
///
/// These tests exercise the scrollback buffer at large capacities,
/// long lines, and frequent operations to detect OOM or data corruption.
///
/// Run: `flutter test test/stress/buffer_stress_test.dart`

void main() {
  // ─── Large scrollback ────────────────────────────────────────────────

  group('large scrollback', () {
    test('10,000 lines of scrollback (default maxLines)', () {
      final terminal = Terminal(maxLines: 10000);
      for (int i = 0; i < 11000; i++) {
        terminal.write('line $i\n');
      }
      final text = terminal.buffer.getText();
      expect(text, contains('line 10999'));
    });

    test('50,000 lines of scrollback', () {
      final terminal = Terminal(maxLines: 50000);
      for (int i = 0; i < 52000; i++) {
        terminal.write('line $i\n');
      }
      final text = terminal.buffer.getText();
      expect(text, contains('line 51999'));
    });

    test('100,000 lines of scrollback', () {
      final terminal = Terminal(maxLines: 100000);
      for (int i = 0; i < 102000; i++) {
        terminal.write('line $i\n');
      }
      final text = terminal.buffer.getText();
      expect(text, contains('line 101999'));
    });

    test('scrollback with long lines (500 chars each)', () {
      final terminal = Terminal(maxLines: 10000);
      for (int i = 0; i < 5000; i++) {
        terminal.write('${'X' * 500} $i\n');
      }
      final text = terminal.buffer.getText();
      expect(text, contains('4999'));
    });

    test('scrollback with SGR colored long lines', () {
      final terminal = Terminal(maxLines: 5000);
      final buf = StringBuffer();
      for (int i = 0; i < 3000; i++) {
        buf.write('\x1b[${31 + i % 7}m');
        buf.write('${'X' * 200} $i');
        buf.write('\x1b[0m\n');
      }
      terminal.write(buf.toString());

      final text = terminal.buffer.getText();
      expect(text, contains('2999'));
    });
  });

  // ─── Line wrapping / reflow stress ───────────────────────────────────

  group('reflow stress', () {
    test('reflow large content across many resizes', () {
      final terminal = Terminal(reflowEnabled: true);
      for (int i = 0; i < 500; i++) {
        terminal.write('Line number $i with some descriptive text\n');
      }

      final rng = Random(42);
      for (int i = 0; i < 200; i++) {
        terminal.resize(rng.nextInt(60) + 20, rng.nextInt(30) + 5);
      }

      terminal.resize(80, 24);
      final text = terminal.buffer.getText();
      expect(text, contains('Line number 499'));
    });

    test('reflow with very narrow terminal', () {
      final terminal = Terminal(reflowEnabled: true);
      terminal.resize(5, 10);
      for (int i = 0; i < 100; i++) {
        terminal.write('Line $i here\n');
      }

      terminal.resize(3, 5);
      terminal.resize(80, 24);

      final text = terminal.buffer.getText();
      expect(text, contains('Line 99'));
    });

    test('reflow disabled: no crash under resize storm', () {
      final terminal = Terminal(reflowEnabled: false);
      for (int i = 0; i < 500; i++) {
        terminal.write('Line $i\n');
      }

      final rng = Random(42);
      for (int i = 0; i < 200; i++) {
        terminal.resize(rng.nextInt(60) + 20, rng.nextInt(30) + 5);
      }

      terminal.resize(80, 24);
      final text = terminal.buffer.getText();
      expect(text, contains('Line 499'));
    });
  });

  // ─── Alternating buffer stress ───────────────────────────────────────

  group('alternate buffer stress', () {
    test('rapid alt/main screen switching with content', () {
      final terminal = Terminal(maxLines: 5000);
      for (int cycle = 0; cycle < 100; cycle++) {
        terminal.write('main content $cycle\n');
        terminal.write('\x1b[?1049h');
        terminal.write('alt content $cycle\n');
        terminal.write('\x1b[?1049l');
      }

      final text = terminal.buffer.getText();
      expect(text, contains('main content 99'));
    });

    test('alt buffer with large content', () {
      final terminal = Terminal();
      terminal.write('\x1b[?1049h');
      for (int i = 0; i < 10000; i++) {
        terminal.write('alt line $i\n');
      }
      terminal.write('\x1b[?1049l');

      expect(terminal.buffer.lines.length, greaterThan(0));
    });
  });

  // ─── Tab / column stress ─────────────────────────────────────────────

  group('tab / column stress', () {
    test('many tabs across long lines', () {
      final terminal = Terminal();
      final buf = StringBuffer();
      for (int i = 0; i < 5000; i++) {
        buf.write('\tcolumn$i\t');
      }
      terminal.write(buf.toString());
      expect(terminal.buffer.cursorX, greaterThan(0));
    });

    test('carriage return stress', () {
      final terminal = Terminal();
      final buf = StringBuffer();
      for (int i = 0; i < 5000; i++) {
        buf.write('\rline $i');
      }
      terminal.write(buf.toString());
      final text = terminal.buffer.getText();
      expect(text, contains('line 4999'));
    });

    test('backspace stress', () {
      final terminal = Terminal();
      final buf = StringBuffer();
      for (int i = 0; i < 10000; i++) {
        buf.write('X\x08');
      }
      terminal.write(buf.toString());
      expect(terminal.buffer.cursorX, lessThan(2));
    });
  });

  // ─── Data integrity ─────────────────────────────────────────────────

  group('data integrity', () {
    test('all unique lines recoverable after scrollback', () {
      final terminal = Terminal(maxLines: 5000);
      for (int i = 0; i < 3000; i++) {
        terminal.write('UNIQUE_LINE_${i}\n');
      }
      final text = terminal.buffer.getText();
      // Verify every line is present in the buffer
      for (int i = 0; i < 3000; i++) {
        expect(text, contains('UNIQUE_LINE_$i'),
            reason: 'Missing line $i in scrollback');
      }
    });

    test('content survives reflow resize cycle', () {
      final terminal = Terminal(reflowEnabled: true, maxLines: 5000);
      for (int i = 0; i < 500; i++) {
        terminal.write('REFLLOW_LINE_${i}\n');
      }

      final rng = Random(7);
      for (int i = 0; i < 50; i++) {
        terminal.resize(rng.nextInt(60) + 20, rng.nextInt(30) + 5);
      }
      terminal.resize(80, 24);

      final text = terminal.buffer.getText();
      for (int i = 0; i < 500; i++) {
        expect(text, contains('REFLLOW_LINE_$i'),
            reason: 'Line $i lost after reflow cycle');
      }
    });

    test('cursor in bounds after repeated resize', () {
      final terminal = Terminal(reflowEnabled: true);
      for (int i = 0; i < 200; i++) {
        terminal.write('Line $i\n');
      }

      final rng = Random(42);
      for (int i = 0; i < 100; i++) {
        final cols = rng.nextInt(60) + 20;
        final rows = rng.nextInt(30) + 5;
        terminal.resize(cols, rows);

        expect(terminal.buffer.cursorX, inInclusiveRange(0, cols - 1),
            reason: 'seed=42 i=$i resize($cols,$rows)');
        expect(terminal.buffer.cursorY, inInclusiveRange(0, rows - 1),
            reason: 'seed=42 i=$i resize($cols,$rows)');
      }
    });

    test('full buffer cycling does not lose data', () {
      final terminal = Terminal(maxLines: 100);
      // Write more than maxLines to force full cycling
      for (int i = 0; i < 500; i++) {
        terminal.write('CYCLE_LINE_${i}\n');
      }

      final text = terminal.buffer.getText();
      // The buffer should have maxLines entries
      expect(terminal.buffer.lines.length, lessThanOrEqualTo(100));

      // The last few lines written should always be present
      for (int i = 490; i < 500; i++) {
        expect(text, contains('CYCLE_LINE_$i'),
            reason: 'Missing recent line $i after buffer cycling');
      }
      // The very first line should have been evicted
      expect(text, isNot(contains('CYCLE_LINE_0')));
    });
  });
}
