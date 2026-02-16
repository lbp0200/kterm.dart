import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitty_key_encoder/kitty_key_encoder.dart';
import 'package:kterm/xterm.dart';

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
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[28;2u'),
      );
    });

    test('generates Kitty sequences for Ctrl+A', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // Test the encoder directly - Ctrl+A should produce keycode 1 with ctrl modifier
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            modifiers: {SimpleModifier.control},
          ),
        ),
        equals('\x1b[1;5u'),
      );
    });

    test('push and pop flags', () {
      final terminal = Terminal();

      // Enable Kitty mode first
      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      // Push flags with value 1
      terminal.write('\x1b[>+1u');

      // Verify we can still encode
      expect(
        terminal.kittyEncoder.encode(
          SimpleKeyEvent(
            logicalKey: LogicalKeyboardKey.enter,
            modifiers: {SimpleModifier.shift},
          ),
        ),
        equals('\x1b[28;2u'),
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
        equals('\x1b[28;2u'),
      );
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
