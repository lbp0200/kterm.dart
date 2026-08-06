import 'package:test/test.dart';
import 'package:kterm/src/core/input/keytab/keytab.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('defaultInputHandler', () {
    test('supports numpad enter', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.keyInput(TerminalKey.numpadEnter);
      expect(output, ['\r']);
    });
  });

  group('KeytabInputHandler', () {
    test('can insert modifier code', () {
      final handler = KeytabInputHandler(
        Keytab.parse(r'key Home +AnyMod : "\E[1;*H"'),
      );

      final terminal = Terminal(inputHandler: handler);

      late String output;

      terminal.onOutput = (data) {
        output = data;
      };

      terminal.keyInput(TerminalKey.home, ctrl: true);

      expect(output, '\x1b[1;5H');

      terminal.keyInput(TerminalKey.home, shift: true);

      expect(output, '\x1b[1;2H');
    });

    test('emits VT52 sequences when DECANM is reset (CSI ? 2 l)', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      // Default state is ANSI mode: Up sends the ANSI CSI sequence.
      expect(terminal.ansiMode, isTrue);
      terminal.keyInput(TerminalKey.arrowUp);
      expect(output.last, '\x1b[A');

      // DECANM reset switches the terminal to VT52 mode: Up sends ESC A.
      terminal.write('\x1b[?2l');
      expect(terminal.ansiMode, isFalse);
      terminal.keyInput(TerminalKey.arrowUp);
      expect(output.last, '\x1bA');

      // DECANM set restores ANSI mode.
      terminal.write('\x1b[?2h');
      expect(terminal.ansiMode, isTrue);
      terminal.keyInput(TerminalKey.arrowUp);
      expect(output.last, '\x1b[A');
    });

    test('Shift+Tab emits plain tab in VT52 mode, backtab in ANSI mode', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[?2l'); // VT52 mode
      terminal.keyInput(TerminalKey.tab, shift: true);
      expect(output.last, '\t');

      terminal.write('\x1b[?2h'); // ANSI mode
      terminal.keyInput(TerminalKey.tab, shift: true);
      expect(output.last, '\x1b[Z');
    });
  });
}
