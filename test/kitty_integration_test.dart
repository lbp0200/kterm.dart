import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Keyboard Protocol', () {
    test('enables Kitty mode on CSI > 1u', () {
      final terminal = Terminal();

      // Send CSI > 1u to enable Kitty mode
      terminal.write('\x1b[>1u');

      expect(terminal.kittyMode, isTrue);
    });

    test('disables Kitty mode on CSI > 0u', () {
      final terminal = Terminal();

      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);
    });

    test('generates Kitty sequences for Shift+Enter', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Test the encoder directly
      // Note: Flutter's LogicalKeyboardKey.enter maps to keycode 13 in Kitty protocol
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[13;2u'),
      );
    });

    test('generates Kitty sequences with modifiers', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Test the encoder with Escape key and shift modifier
      // This verifies the encoder handles modifier combinations
      final result = terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.escape,
          modifiers: {SimpleModifier.shift},
        ),
      );
      // Should produce a non-empty Kitty sequence with shift modifier (2)
      expect(result, isNotEmpty);
      expect(result, contains('2')); // shift modifier
    });

    test('push and pop flags', () {
      final terminal = Terminal();

      // Enable Kitty mode first
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Push flags with value 1 (reportEvent bit)
      terminal.write('\x1b[>+1u');

      // Verify encoder switches to extended mode with reportEvent
      // Extended format: CSI > csiValue;eventType;keyCode;modifiersu
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[>1;1;13;2u'),
      );

      // Pop flags
      terminal.write('\x1b[>-1u');

      // Verify encoding still works after pop
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[13;2u'),
      );
    });

    test('push flag updates encoder flags', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isFalse);

      // Push flag with reportAllKeysAsEscape (bit 2 = 4)
      terminal.write('\x1b[>+4u');

      // Encoder should now have reportAllKeysAsEscape enabled
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isTrue);
    });

    test('pop flag restores previous encoder flags', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Push flag 4 (reportAllKeysAsEscape)
      terminal.write('\x1b[>+4u');
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isTrue);

      // Pop back to default (no flags, bit 2 = 0)
      terminal.write('\x1b[>-u');
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isFalse);
    });

    test('nested push/pop correctly restores flags', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Push flag 1 (reportEvent)
      terminal.write('\x1b[>+1u');
      expect(terminal.kittyEncoder.flags.reportEvent, isTrue);

      // Push flag 4 (reportAllKeysAsEscape) on top
      terminal.write('\x1b[>+4u');
      expect(terminal.kittyEncoder.flags.reportEvent, isFalse);
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isTrue);

      // Pop → back to flag 1 only
      terminal.write('\x1b[>-u');
      expect(terminal.kittyEncoder.flags.reportEvent, isTrue);
      expect(terminal.kittyEncoder.flags.reportAllKeysAsEscape, isFalse);

      // Pop → back to no flags
      terminal.write('\x1b[>-u');
      expect(terminal.kittyEncoder.flags.reportEvent, isFalse);
    });

    test('Ctrl+letter via keyInput produces raw control character', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      // Enable Kitty mode (mode doesn't affect keyInput path)
      terminal.write('\x1b[>1u');

      // Send Ctrl+U via keyInput (same path used by the Kitty-mode fix)
      final result = terminal.keyInput(TerminalKey.keyU, ctrl: true);

      expect(result, isTrue);
      expect(output, ['\x15']); // 0x15 = NAK = Ctrl+U
    });

    test('all Ctrl+A-Z via keyInput produce correct control codes', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      for (var i = 0; i < 26; i++) {
        output.clear();
        final key = TerminalKey.values[TerminalKey.keyA.index + i];
        terminal.keyInput(key, ctrl: true);
        expect(output, [String.fromCharCode(i + 1)],
            reason:
                'Ctrl+${String.fromCharCode(65 + i)} should produce 0x${(i + 1).toRadixString(16).padLeft(2, '0')}');
      }
    });

    test('Ctrl+letter via keyInput does not produce output without ctrl', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      // Bare letter keys are not handled by keyInput (go through IME/textInput)
      final result = terminal.keyInput(TerminalKey.keyU, ctrl: false);

      expect(result, isFalse);
      expect(output, isEmpty);
    });

    test('kitty mode defaults to false', () {
      final terminal = Terminal();

      // Kitty mode should be false by default
      expect(terminal.kittyMode, isFalse);
    });

    test('toggle Kitty mode multiple times', () {
      final terminal = Terminal();

      // Enable
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Disable
      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);

      // Enable again
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Disable again
      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);
    });
  });
}
