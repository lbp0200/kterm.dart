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
  });
}
