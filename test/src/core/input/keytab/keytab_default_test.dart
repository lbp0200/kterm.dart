import 'package:test/test.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/core/input/keytab/keytab.dart';

void main() {
  group('Keytab.defaultKeytab', () {
    test('parses the full default table without error', () {
      // Keytab.defaultKeytab is a lazy static; merely accessing it exercises
      // tokenize + parse of the whole ~700-line default table.
      expect(Keytab.defaultKeytab.records, isNotEmpty);
    });

    test('matches common key mappings', () {
      final keytab = Keytab.defaultKeytab;

      expect(keytab.find(TerminalKey.escape)!.action.unescapedValue(), '\x1b');
      expect(keytab.find(TerminalKey.tab)!.action.unescapedValue(), '\t');
      expect(
          keytab.find(TerminalKey.backspace)!.action.unescapedValue(), '\x7f');
    });

    test('respects modifier variants', () {
      final keytab = Keytab.defaultKeytab;

      // Shift+Tab resolves to the ANSI backwards-tab sequence, not plain tab.
      final shiftTab = keytab.find(TerminalKey.tab, shift: true);
      expect(shiftTab, isNotNull);
      expect(shiftTab!.action.unescapedValue(), '\x1b[Z');

      // Ctrl+Backspace sends ^H (0x08) while plain Backspace sends DEL (0x7f).
      final ctrlBackspace = keytab.find(TerminalKey.backspace, ctrl: true);
      expect(ctrlBackspace!.action.unescapedValue(), '\b');
    });

    test('uses VT52 arrow-key sequences when ansi=false', () {
      final keytab = Keytab.defaultKeytab;

      // VT52 mode arrow keys send ESC A-D, not the ANSI CSI sequences.
      expect(
          keytab
              .find(TerminalKey.arrowUp, ansi: false)!
              .action
              .unescapedValue(),
          '\x1bA');
      expect(
          keytab
              .find(TerminalKey.arrowDown, ansi: false)!
              .action
              .unescapedValue(),
          '\x1bB');
      expect(
          keytab
              .find(TerminalKey.arrowRight, ansi: false)!
              .action
              .unescapedValue(),
          '\x1bC');
      expect(
          keytab
              .find(TerminalKey.arrowLeft, ansi: false)!
              .action
              .unescapedValue(),
          '\x1bD');

      // In ANSI mode the same keys use the CSI cursor sequences.
      expect(
          keytab.find(TerminalKey.arrowUp)!.action.unescapedValue(), '\x1b[A');
      expect(keytab.find(TerminalKey.arrowDown)!.action.unescapedValue(),
          '\x1b[B');
      expect(keytab.find(TerminalKey.arrowRight)!.action.unescapedValue(),
          '\x1b[C');
      expect(keytab.find(TerminalKey.arrowLeft)!.action.unescapedValue(),
          '\x1b[D');
    });

    test('Shift+Tab falls back to plain tab in VT52 mode', () {
      final keytab = Keytab.defaultKeytab;

      expect(
          keytab
              .find(TerminalKey.tab, shift: true, ansi: false)!
              .action
              .unescapedValue(),
          '\t');
      expect(
          keytab
              .find(TerminalKey.tab, shift: true, ansi: true)!
              .action
              .unescapedValue(),
          '\x1b[Z');
    });
  });
}
