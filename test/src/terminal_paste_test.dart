import 'package:test/test.dart';
import 'package:kterm/core.dart';

void main() {
  group('Terminal.paste', () {
    test('Given plain text, When paste called, Then keeps text unchanged', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      terminal.paste('hello world');

      expect(terminalOutput.join(), equals('hello world'));
    });

    test(
        'Given text with ANSI escape sequences, When paste called, Then filters out escape sequences',
        () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Text with ANSI color codes
      terminal.paste('\x1b[31mred text\x1b[0m');

      // Escape sequences should be filtered, leaving only the visible text
      expect(terminalOutput.join(), equals('red text'));
    });

    test(
        'Given text with multiple ANSI escape sequences, When paste called, Then filters all escape sequences',
        () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Text with multiple ANSI codes (bold, color, underline)
      terminal.paste('\x1b[1m\x1b[31m\x1b[4mstyled\x1b[0m');

      expect(terminalOutput.join(), equals('styled'));
    });

    test('Given text with cursor movement sequences, When paste called, Then filters sequences', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Text with cursor movement
      terminal.paste('line1\x1b[2Jline2\x1b[1Gtext');

      // All escape sequences filtered
      expect(terminalOutput.join(), equals('line1line2text'));
    });

    test('Given empty text, When paste called, Then outputs empty string', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      terminal.paste('');

      expect(terminalOutput.join(), isEmpty);
    });

    // Note: The current regex doesn't handle colon-separated parameters like \x1b[4:5m
    // This test documents the current behavior (colons are not filtered)
    test('Given text with colon-style escape sequences, When paste called, Then filters standard CSI but not colon variants', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Standard semicolon-style is filtered; colon-style is not
      terminal.paste('\x1b[0m\x1b[4:5m');

      // Only the standard sequence is filtered, colon-style remains
      expect(terminalOutput.join(), contains('\x1b[4:5m'));
    });

    test(
        'Given bracketed paste mode enabled, When paste called, Then wraps text with paste markers',
        () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Enable bracketed paste mode
      terminal.write('\x1b[?2004h');

      terminal.paste('test');

      final output = terminalOutput.join();
      // Should start with \x1b[200~ and end with \x1b[201~
      expect(output, startsWith('\x1b[200~'));
      expect(output, endsWith('\x1b[201~'));
      expect(output, contains('test'));
    });

    test(
        'Given bracketed paste mode disabled, When paste called, Then does not wrap with markers',
        () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Ensure bracketed paste mode is disabled (default)
      terminal.write('\x1b[?2004l');

      terminal.paste('test');

      expect(terminalOutput.join(), equals('test'));
    });

    test(
        'Given text with mixed content and escape sequences, When paste called, Then filters escape sequences and keeps text',
        () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // Mixed content: regular text + ANSI codes + regular text
      terminal.paste('Hello \x1b[1;31mWorld\x1b[0m!');

      expect(terminalOutput.join(), equals('Hello World!'));
    });

    test('Given text with 256-color escape codes, When paste called, Then filters sequences', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // 256-color code
      terminal.paste('\x1b[38;5;196mred\x1b[0m');

      expect(terminalOutput.join(), equals('red'));
    });

    test('Given text with RGB escape codes, When paste called, Then filters sequences', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // RGB color code
      terminal.paste('\x1b[38;2;255;0;0mred\x1b[0m');

      expect(terminalOutput.join(), equals('red'));
    });

    // Note: The current regex only handles CSI sequences (\x1b[...letter),
    // not OSC sequences (\x1b]...\x1b\\ or \x1b]...\x07)
    test('Given text with OSC escape codes, When paste called, Then does not filter OSC sequences', () {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      // OSC (Operating System Command) - often used for window titles
      terminal.paste('\x1b]0;title\x1b\\text');

      // OSC sequences are not filtered by current implementation
      expect(terminalOutput.join(), contains('\x1b]0;title\x1b\\'));
      expect(terminalOutput.join(), contains('text'));
    });
  });
}
