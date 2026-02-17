import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_key_encoder/kitty_key_encoder.dart';
import 'package:kterm/xterm.dart';

void main() {
  group('Kitty sequence verification', () {
    test('Shift+Enter keycode is 8 in Kitty protocol', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Simulate Shift+Enter
      final seq = terminal.kittyEncoder.encode(SimpleKeyEvent(
        logicalKey: LogicalKeyboardKey.enter,
        modifiers: {SimpleModifier.shift},
        isKeyUp: false,
        isKeyRepeat: false,
      ));

      print('Sequence: "$seq"');
      print('Bytes: ${seq.codeUnits}');
      print('First char (ESC): ${seq.codeUnitAt(0)} == 27: ${seq.codeUnitAt(0) == 27}');

      // Kitty protocol uses keycode 8 for Enter, not ASCII 13
      expect(seq.codeUnitAt(0), equals(27)); // ESC
      expect(seq, contains('8')); // Enter keycode is 8
      expect(seq, contains('2')); // Shift modifier
    });

    test('Enter without modifiers produces sequence', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      final seq = terminal.kittyEncoder.encode(SimpleKeyEvent(
        logicalKey: LogicalKeyboardKey.enter,
        modifiers: {},
        isKeyUp: false,
        isKeyRepeat: false,
      ));

      print('Enter sequence: "$seq"');
      print('Bytes: ${seq.codeUnits}');

      expect(seq.codeUnitAt(0), equals(27)); // ESC
    });
  });
}
