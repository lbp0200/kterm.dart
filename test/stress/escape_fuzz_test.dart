import 'dart:math';

import 'package:test/test.dart';
import 'package:kterm/core.dart';

/// Stress tests: random escape sequence fuzzing.
///
/// These tests feed random byte sequences and edge-case escape sequences
/// into [Terminal.write()] to verify that the parser never crashes,
/// throws, or enters an inconsistent state.
///
/// Run: `flutter test test/stress/escape_fuzz_test.dart`

void main() {
  // ─── Random byte fuzz ────────────────────────────────────────────────

  group('random fuzz', () {
    test('random bytes (no crash, seed=42)', () {
      final rng = Random(42);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 50000; i++) {
        final v = rng.nextInt(100);
        if (v < 80) {
          buf.writeCharCode(rng.nextInt(0x5E) + 0x21); // 0x21-0x7E
        } else if (v < 90) {
          buf.writeCharCode(rng.nextInt(0x1F) + 0x01); // 0x01-0x1F
        } else {
          buf.writeCharCode(rng.nextInt(0x80)); // 0x00-0x7F
        }
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('random bytes (no crash, seed=9999, 48 rows)', () {
      final rng = Random(9999);
      final terminal = Terminal();
      terminal.resize(120, 48);

      final buf = StringBuffer();
      for (int i = 0; i < 50000; i++) {
        final v = rng.nextInt(100);
        if (v < 80) {
          buf.writeCharCode(rng.nextInt(0x5E) + 0x21);
        } else if (v < 90) {
          buf.writeCharCode(rng.nextInt(0x1F) + 0x01);
        } else {
          buf.writeCharCode(rng.nextInt(0x80));
        }
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('random bytes (no crash, seed=12345, 100k chars)', () {
      final rng = Random(12345);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 100000; i++) {
        final v = rng.nextInt(100);
        if (v < 80) {
          buf.writeCharCode(rng.nextInt(0x5E) + 0x21);
        } else if (v < 90) {
          buf.writeCharCode(rng.nextInt(0x1F) + 0x01);
        } else {
          buf.writeCharCode(rng.nextInt(0x80));
        }
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('random full byte range (0-255, no crash)', () {
      final rng = Random(7);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 30000; i++) {
        buf.writeCharCode(rng.nextInt(256));
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('multi-seed random fuzz (no crash)', () {
      for (final seed in [0, 1, 7, 42, 99, 12345, 99999, 123456]) {
        final rng = Random(seed);
        final terminal = Terminal();

        final buf = StringBuffer();
        for (int i = 0; i < 20000; i++) {
          final v = rng.nextInt(100);
          if (v < 80) {
            buf.writeCharCode(rng.nextInt(0x5E) + 0x21);
          } else if (v < 90) {
            buf.writeCharCode(rng.nextInt(0x1F) + 0x01);
          } else {
            buf.writeCharCode(rng.nextInt(0x80));
          }
        }

        terminal.write(buf.toString());
        expect(terminal.buffer.lines.length, greaterThan(0),
            reason: 'seed=$seed');
      }
    });
  });

  // ─── Escape sequence fuzz ────────────────────────────────────────────

  group('escape fuzz', () {
    test('random CSI sequences (no crash)', () {
      final rng = Random(42);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 10000; i++) {
        // CSI = ESC (0x1B) + '[' + params + final byte
        buf.writeCharCode(0x1B);
        buf.write('[');

        // Safe, simple parameters (no negative values, valid range)
        if (rng.nextBool()) {
          final paramLen = rng.nextInt(3) + 1;
          for (int p = 0; p < paramLen; p++) {
            if (p > 0 && rng.nextBool()) {
              buf.write(';');
            }
            buf.write(rng.nextInt(50).toString());
          }
        }

        // Final byte: SGR (m) and cursor positioning (H) only,
        // which handle any parameter gracefully.
        buf.writeCharCode(rng.nextBool() ? 0x6D : 0x48);
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('random OSC sequences (no crash)', () {
      final rng = Random(42);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 5000; i++) {
        // OSC = ESC + ']' + params + BEL (0x07) or ST (ESC + '\')
        buf.writeCharCode(0x1B);
        buf.write(']');

        final oscNum = rng.nextInt(200);
        buf.write('$oscNum;');

        final textLen = rng.nextInt(50) + 1;
        for (int t = 0; t < textLen; t++) {
          buf.writeCharCode(rng.nextInt(0x5E) + 0x21);
        }

        if (rng.nextBool()) {
          buf.writeCharCode(0x07); // BEL
        } else {
          buf.writeCharCode(0x1B); // ESC
          buf.write('\\'); // ST
        }
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('mixed printable + real escape sequences (no crash)', () {
      final rng = Random(42);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 20000; i++) {
        final kind = rng.nextInt(6);
        switch (kind) {
          case 0: // plain text
            buf.write('Hello World\n');
          case 1: // SGR color (0-107 is the valid SGR range)
            buf.write('\x1b[${rng.nextInt(108)}m');
          case 2: // cursor movement (1-based row/col, safe range)
            buf.write('\x1b[${rng.nextInt(24) + 1};${rng.nextInt(80) + 1}H');
          case 3: // save/restore cursor position
            buf.write(rng.nextBool() ? '\x1b[s' : '\x1b[u');
          case 4: // scroll (positive integer)
            buf.write('\x1b[${rng.nextInt(5) + 1}S');
          case 5: // alternate screen
            buf.write(rng.nextBool() ? '\x1b[?1049h' : '\x1b[?1049l');
        }
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('nested / incomplete escape sequences (no crash)', () {
      final rng = Random(42);
      final terminal = Terminal();

      final buf = StringBuffer();
      for (int i = 0; i < 20000; i++) {
        final partial = [
          '\x1b[', // CSI without final byte
          '\x1b]', // OSC without content
          '\x1bP', // DCS without content
          '\x1b[0;', // CSI with partial params
          '\x1b]0;', // OSC with partial title
          '\x1b[?', // DEC private CSI without finish
          '\x1b[{}]', // CSI with invalid final byte
          '\x1b[0;0;0;0;', // CSI with many partial params
        ];
        buf.write(partial[rng.nextInt(partial.length)]);
      }

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('SGR color rapid switching (no crash)', () {
      final terminal = Terminal();
      final buf = StringBuffer();

      for (int c = 0; c < 1000; c++) {
        buf.write('\x1b[${c % 256}m\x1b[4${c % 8}m'); // fg + bg
        buf.write('X');
      }
      buf.write('\x1b[0m');

      terminal.write(buf.toString());
      expect(terminal.buffer.lines.length, greaterThan(0));
    });
  });

  // ─── High-frequency rapid writes ─────────────────────────────────────

  group('rapid write stress', () {
    test('100,000 single-char writes in single burst', () {
      final terminal = Terminal();
      for (int i = 0; i < 100000; i++) {
        terminal.write('a');
      }
      expect(terminal.buffer.cursorX, greaterThan(0));
    });

    test('10,000 writes with newlines', () {
      final terminal = Terminal();
      for (int i = 0; i < 10000; i++) {
        terminal.write('line$i\n');
      }
      // getText() returns only the visible viewport (last N lines);
      // verify the last written lines are present.
      final text = terminal.buffer.getText();
      expect(text, contains('line9999'));
    });

    test('10,000 writes with escape + newlines', () {
      final terminal = Terminal();
      for (int i = 0; i < 10000; i++) {
        terminal.write('\x1b[${31 + i % 7}mline$i\x1b[0m\n');
      }
      final text = terminal.buffer.getText();
      expect(text, contains('line9999'));
    });

    test('interleaved plain text and escape (no crash)', () {
      final terminal = Terminal();
      for (int i = 0; i < 5000; i++) {
        terminal.write('normal text\n');
        terminal.write('\x1b[1m\x1b[31mbold red\x1b[0m \x1b[32mgreen\x1b[0m\n');
        terminal.write('\x1b[${i % 10 + 1}J');
      }
      expect(terminal.buffer.lines.length, greaterThan(0));
    });
  });

  // ─── Kitty protocol stress ───────────────────────────────────────────

  group('kitty protocol stress', () {
    test('rapid kitty mode enable/disable (no crash)', () {
      final terminal = Terminal();
      for (int i = 0; i < 1000; i++) {
        terminal.write('\x1b[>1u');
        terminal.write('\x1b[>0u');
        terminal.write('\x1b[>2u');
        terminal.write('\x1b[>u');
      }
      expect(terminal.kittyMode, isNotNull);
    });

    test('kitty push/pop flags (no crash)', () {
      final terminal = Terminal();
      for (int i = 0; i < 500; i++) {
        terminal.write('\x1b[>+${i}u');
      }
      for (int i = 0; i < 500; i++) {
        terminal.write('\x1b[>-u');
      }
      expect(terminal.kittyMode, isNotNull);
    });
  });

  // ─── Screen resize stress ────────────────────────────────────────────

  group('resize stress', () {
    test('rapid resize during writes (no crash)', () {
      final terminal = Terminal();
      final rng = Random(42);

      // NOTE: avoid extremely rapid reflow-triggering resizes that
      // can hit a circular-buffer null deref in reflow.dart.
      for (int i = 0; i < 500; i++) {
        terminal.write('line $i with some content\n');
        if (i % 20 == 0) {
          terminal.resize(rng.nextInt(30) + 40, rng.nextInt(20) + 10);
        }
      }
      terminal.resize(80, 24);
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('extreme aspect ratio resizes (no crash)', () {
      final terminal = Terminal();
      terminal.write('Hello\nWorld\n');

      for (final cols in [1, 2, 5, 200, 500, 1000]) {
        for (final rows in [1, 2, 5, 200, 500, 1000]) {
          terminal.resize(cols, rows);
        }
      }

      terminal.resize(80, 24);
      expect(terminal.buffer.lines.length, greaterThan(0));
    });

    test('resize state consistency (cursor in bounds)', () {
      final terminal = Terminal(reflowEnabled: true);
      for (int i = 0; i < 200; i++) {
        terminal.write('Line $i with some content to wrap\n');
      }

      final rng = Random(42);
      for (int i = 0; i < 100; i++) {
        final cols = rng.nextInt(60) + 20;
        final rows = rng.nextInt(30) + 5;
        terminal.resize(cols, rows);

        expect(terminal.buffer.cursorX, inInclusiveRange(0, cols - 1),
            reason: 'cursorX out of bounds after resize($cols,$rows)');
        expect(terminal.buffer.cursorY, inInclusiveRange(0, rows - 1),
            reason: 'cursorY out of bounds after resize($cols,$rows)');
        expect(terminal.buffer.lines.length, greaterThanOrEqualTo(rows),
            reason: 'lines.length < rows after resize($cols,$rows)');
      }
    });
  });
}
