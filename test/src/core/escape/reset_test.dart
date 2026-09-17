import 'package:test/test.dart';
import 'package:kterm/core.dart';

/// Regression tests for `reset(1)` support:
/// - RIS (`ESC c`) performs a full reset (xterm `rs1`).
/// - DECSTR (`CSI ! p`) performs a soft reset (xterm `rs2`/`is2`).
/// - HTS (`ESC H`) actually sets a tab stop (was a no-op query).
void main() {
  group('RIS (ESC c)', () {
    test('clears the screen and homes the cursor', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('hello\r\nworld');
      expect(terminal.buffer.getText(), contains('hello'));
      expect(terminal.buffer.getText(), contains('world'));

      terminal.write('\x1bc');

      expect(terminal.buffer.getText().trim(), isEmpty);
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
    });

    test('resets graphic rendition', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[1m'); // bold
      expect(terminal.cursor.isBold, isTrue);

      terminal.write('\x1bc');

      expect(terminal.cursor.isBold, isFalse);
    });

    test('resets modes to power-up defaults', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[4h'); // insert mode on
      terminal.write('\x1b[?25l'); // hide cursor
      terminal.write('\x1b[?2004h'); // bracketed paste on
      expect(terminal.insertMode, isTrue);
      expect(terminal.cursorVisibleMode, isFalse);
      expect(terminal.bracketedPasteMode, isTrue);

      terminal.write('\x1bc');

      expect(terminal.insertMode, isFalse);
      expect(terminal.cursorVisibleMode, isTrue);
      expect(terminal.bracketedPasteMode, isFalse);
      expect(terminal.autoWrapMode, isTrue);
    });

    test('resets scroll margins and tab stops', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[2;5r'); // shrink scroll region
      terminal.write('\x1b[3g'); // clear all tab stops
      expect(terminal.buffer.marginTop, 1);
      expect(terminal.buffer.marginBottom, 4);

      terminal.write('\x1bc');

      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, terminal.viewHeight - 1);
      // default tab stop every 8 columns is back
      terminal.write('\t');
      expect(terminal.buffer.cursorX, 8);
    });
  });

  group('DECSTR (CSI ! p)', () {
    test('resets modes and rendition but keeps screen and cursor', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('hello');
      terminal.write('\x1b[1m'); // bold
      terminal.write('\x1b[4h'); // insert mode on
      terminal.write('\x1b[2;5r'); // shrink scroll region
      final x = terminal.buffer.cursorX;
      final y = terminal.buffer.cursorY;

      terminal.write('\x1b[!p');

      expect(terminal.buffer.getText(), contains('hello'));
      expect(terminal.buffer.cursorX, x);
      expect(terminal.buffer.cursorY, y);
      expect(terminal.cursor.isBold, isFalse);
      expect(terminal.insertMode, isFalse);
      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, terminal.viewHeight - 1);
    });

    test('preserves tab stops', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[3g'); // clear all tab stops
      terminal.write('\x1b[!p');
      // no default stops: a tab runs to the right margin
      terminal.write('\t');
      expect(terminal.buffer.cursorX, terminal.viewWidth - 1);
    });

    test('plain CSI p without ! is ignored', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('hi');
      expect(() => terminal.write('\x1b[p'), returnsNormally);
      expect(terminal.buffer.getText(), contains('hi'));
    });
  });

  group('HTS (ESC H)', () {
    test('sets a tab stop at the cursor column', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[3g'); // clear all tab stops
      terminal.write('     '); // move to column 5
      terminal.write('\x1bH'); // set tab stop here
      terminal.write('\r'); // back to column 0
      terminal.write('\t');
      expect(terminal.buffer.cursorX, 5);
    });
  });

  group('reset(1) byte stream', () {
    test('real xterm reset sequence leaves no garbage', () {
      final terminal = Terminal(inputHandler: null);
      // Mess the state up first: text, rendition, modes, margins, tabs.
      terminal.write('some mess\r\n\x1b[1mBOLD');
      terminal.write('\x1b[4h\x1b[?25l\x1b[2;5r\x1b[3g');

      // Byte-exact capture of /usr/bin/reset on xterm-256color:
      // tab init first (TBC + CR + 8 spaces + HTS per stop),
      // then rs1/rs2 (RIS + DECSTR + DECRST + keypad reset), then CR.
      final resetStream = StringBuffer('\r\x1b[3g');
      for (var i = 0; i < 9; i++) {
        resetStream.write('        \x1bH');
      }
      resetStream.write('\r\x1bc\x1b[!p\x1b[?3;4l\x1b[4l\x1b>\r');
      terminal.write(resetStream.toString());

      expect(terminal.buffer.getText().trim(), isEmpty);
      expect(terminal.buffer.getText(), isNot(contains('c[!p')));
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.cursor.isBold, isFalse);
      expect(terminal.insertMode, isFalse);
      expect(terminal.cursorVisibleMode, isTrue);
      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, terminal.viewHeight - 1);
      // tab stops re-initialized by the HTS loop
      terminal.write('\t');
      expect(terminal.buffer.cursorX, 8);
    });
  });
}
