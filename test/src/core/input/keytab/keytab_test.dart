import 'package:test/test.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/core/input/keytab/keytab.dart';

void main() {
  group('Keytab.find()', () {
    test('can match keyPad', () {
      final keytab = Keytab.parse(r'key Home +KeyPad : "TEST"');
      final record = keytab.find(TerminalKey.home, keyPad: true);
      expect(record!.action.unescapedValue(), 'TEST');

      final record1 = keytab.find(TerminalKey.home);
      expect(record1, isNull);
    });

    test('matches Ansi records by default, VT52 records only when ansi=false',
        () {
      final keytab = Keytab.parse(r'''
key Home -Ansi : "VT52"
key Home +Ansi : "ANSI"
''');

      // Default find() is ANSI mode: the -Ansi (VT52) record is skipped.
      expect(keytab.find(TerminalKey.home)!.action.unescapedValue(), 'ANSI');
      expect(keytab.find(TerminalKey.home, ansi: true)!.action.unescapedValue(),
          'ANSI');

      // VT52 mode picks the -Ansi record.
      expect(
          keytab.find(TerminalKey.home, ansi: false)!.action.unescapedValue(),
          'VT52');
    });

    test('records without an ansi flag match in both modes', () {
      final keytab = Keytab.parse(r'key Home : "PLAIN"');
      expect(keytab.find(TerminalKey.home)!.action.unescapedValue(), 'PLAIN');
      expect(
          keytab.find(TerminalKey.home, ansi: false)!.action.unescapedValue(),
          'PLAIN');
    });
  });
}
