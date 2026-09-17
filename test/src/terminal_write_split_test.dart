import 'package:test/test.dart';
import 'package:kterm/core.dart';

/// Regression tests for chunk-split escape sequences.
///
/// PTY output is split at arbitrary byte boundaries. `Terminal.write` used
/// to fast-path any chunk without an ESC byte straight into the buffer,
/// even while the parser held an incomplete sequence from the previous
/// chunk — printing the sequence tail as literal text. Real-world fallout:
/// - `reset(1)` leaking `c[!p[?3;4l[4l>%` and a row of `H`s
///   (`ESC` split from `c`, `ESC` split from `H`);
/// - starship prompt SGR leaking `;5;244m` (`ESC[48` split from `;5;244m`)
///   and wrecking the redrawn command line.
void main() {
  group('split sequences never leak', () {
    test('SGR split at every byte boundary', () {
      const seq = '\x1b[48;5;244m';
      final runes = seq.runes.toList();
      for (var i = 1; i < runes.length; i++) {
        final terminal = Terminal(inputHandler: null);
        terminal.write(String.fromCharCodes(runes.sublist(0, i)));
        terminal.write(String.fromCharCodes(runes.sublist(i)));
        expect(
          terminal.buffer.getText().trim(),
          isEmpty,
          reason: 'SGR split at byte $i leaked',
        );
      }
    });

    test('split SGR still takes effect', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('ab\x1b[48');
      terminal.write(';5;244mCD');
      expect(terminal.buffer.getText(), contains('abCD'));
      expect(terminal.buffer.getText(), isNot(contains(';5;244m')));
    });

    test('split RIS still resets instead of printing', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('mess');
      terminal.write('\x1b');
      terminal.write('c');
      expect(terminal.buffer.getText().trim(), isEmpty);
    });

    test('split HTS still sets the tab stop', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('\x1b[3g'); // clear all stops
      terminal.write('     '); // column 5
      terminal.write('\x1b');
      terminal.write('H');
      terminal.write('\r\t');
      expect(terminal.buffer.cursorX, 5);
    });

    test('split OSC still parsed instead of printed', () {
      var title = '';
      final terminal = Terminal(
        inputHandler: null,
        onTitleChange: (t) => title = t,
      );
      terminal.write('\x1b]0;ti');
      terminal.write('tle\x07');
      expect(title, 'title');
      expect(terminal.buffer.getText().trim(), isEmpty);
    });

    test('split CSI cursor move still moves', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('abcd');
      terminal.write('\x1b[2');
      terminal.write('D');
      expect(terminal.buffer.cursorX, 2);
      expect(terminal.buffer.getText(), contains('abcd'));
    });

    test('fast path still used for plain text', () {
      final terminal = Terminal(inputHandler: null);
      terminal.write('hello world');
      expect(terminal.buffer.getText(), contains('hello world'));
    });
  });
}
