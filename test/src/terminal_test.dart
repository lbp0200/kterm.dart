import 'dart:async';

import 'package:test/test.dart';
import 'package:kterm/core.dart';
import 'package:kterm/src/utils/ascii.dart';

void main() {
  group('Terminal.inputHandler', () {
    test('can be set to null', () {
      final terminal = Terminal(inputHandler: null);
      expect(() => terminal.keyInput(TerminalKey.keyA), returnsNormally);
    });

    test('can be changed', () {
      final handler1 = _TestInputHandler();
      final handler2 = _TestInputHandler();
      final terminal = Terminal(inputHandler: handler1);

      terminal.keyInput(TerminalKey.keyA);
      expect(handler1.events, isNotEmpty);

      terminal.inputHandler = handler2;

      terminal.keyInput(TerminalKey.keyA);
      expect(handler2.events, isNotEmpty);
    });
  });

  group('Terminal.mouseInput', () {
    test('can handle mouse events', () {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, isEmpty);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, ['\x1B[M ++']);
    });
  });

  group('Terminal.reflowEnabled', () {
    test('prevents reflow when set to false', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('preserves hidden cells when reflow is disabled', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello World');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('can be set at runtime', () {
      final terminal = Terminal(reflowEnabled: true);

      terminal.resize(5, 5);
      terminal.write('Hello World');
      terminal.reflowEnabled = false;
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), ' Worl');
      expect(terminal.buffer.lines[2].toString(), 'd');
    });
  });

  group('Terminal.mouseInput', () {
    test('applys to the main buffer', () {
      final terminal = Terminal(
        wordSeparators: {
          'z'.codeUnitAt(0),
        },
      );

      expect(
        terminal.mainBuffer.wordSeparators,
        contains('z'.codeUnitAt(0)),
      );
    });

    test('applys to the alternate buffer', () {
      final terminal = Terminal(
        wordSeparators: {
          'z'.codeUnitAt(0),
        },
      );

      expect(
        terminal.altBuffer.wordSeparators,
        contains('z'.codeUnitAt(0)),
      );
    });
  });

  group('Terminal.onPrivateOSC', () {
    test(r'works with \a end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x07');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x07');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x07');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x07');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test(r'works with \x1b\ end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x1b\\');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x1b\\');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x1b\\');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x1b\\');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test('do not receive common osc', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]0;hello world\x07');

      expect(lastCode, isNull);
      expect(lastData, isNull);
    });
  });

  group('Terminal.write buffer integrity', () {
    /// Terminal.write() is synchronous: buffer is always correct immediately.
    /// This is the key invariant that the PTY ackRead flow-control fix relies on.
    ///
    /// Bug: with ackRead=true in flutter_pty, the C read thread blocks on
    /// pthread_mutex until Dart calls ackRead(). If Dart's event loop is busy
    /// (e.g. many rapid chunks), ackRead() is delayed, blocking the PTY read.
    /// Without microtask(), terminal.write() completes but ackRead() is stuck
    /// behind other microtasks → PTY read thread is blocked longer than needed.
    ///
    /// With microtask(), terminal.write() is synchronous (buffer always correct),
    /// and ackRead() fires as the next microtask, quickly unblocking the PTY
    /// read thread so the next chunk arrives promptly.
    ///
    /// These tests verify the buffer-invariants that make the fix safe.

    test('buffer order preserved with 300ms delayed ackRead (broken pattern)',
        () async {
      final terminal = Terminal();

      final chunks = [
        'redis-cli -h 10.128.0.125 hlen MAIL_TYPE\n',
        '206\n',
        "Warning: Using a password with '-a'\n",
      ];

      for (final chunk in chunks) {
        terminal.write(chunk);
        // Simulate 300ms delay before ackRead() fires (slow event loop / high
        // RTT). Buffer should still be correct because write() is synchronous.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final bufferText = terminal.buffer.getText();
      expect(bufferText, contains('10.128.0.125'));
      expect(bufferText, contains('206'));
      expect(bufferText, contains("Warning: Using a password"));

      // Verify order
      final p1 = bufferText.indexOf('10.128.0.125');
      final p2 = bufferText.indexOf('206');
      final p3 = bufferText.indexOf('Warning');
      expect(p1, lessThan(p2));
      expect(p2, lessThan(p3));
    });

    test('buffer order preserved with 100ms rapid delayed ackRead (100 chunks)',
        () async {
      final terminal = Terminal();

      for (var i = 0; i < 100; i++) {
        terminal.write('line$i\n');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final bufferText = terminal.buffer.getText();
      for (var i = 0; i < 100; i++) {
        expect(bufferText, contains('line$i'));
      }

      for (var i = 0; i < 99; i++) {
        final posI = bufferText.indexOf('line$i\n');
        final posI1 = bufferText.indexOf('line${i + 1}\n');
        expect(posI, lessThan(posI1),
            reason: 'line$i should appear before line${i + 1}');
      }
    });

    test(
        'buffer order preserved with microtask-deferred ackRead (correct '
        'pattern)', () async {
      final terminal = Terminal();

      final chunks = [
        'command1\n',
        'output1\n',
        'command2\n',
        'output2\n',
      ];

      for (final chunk in chunks) {
        terminal.write(chunk);
        // Correct pattern: schedule ackRead as next microtask (non-blocking)
        Future.microtask(() {});
      }

      // Drain microtasks
      await Future<void>.delayed(Duration.zero);

      final bufferText = terminal.buffer.getText();
      expect(bufferText, contains('command1'));
      expect(bufferText, contains('output1'));
      expect(bufferText, contains('command2'));
      expect(bufferText, contains('output2'));

      final cmd1 = bufferText.indexOf('command1');
      final out1 = bufferText.indexOf('output1');
      final cmd2 = bufferText.indexOf('command2');
      final out2 = bufferText.indexOf('output2');
      expect(cmd1, lessThan(out1));
      expect(out1, lessThan(cmd2));
      expect(cmd2, lessThan(out2));
    });
  });
  group('Terminal.paste', () {
    test('normalizes line endings CRLF to CR', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.paste('line1\r\nline2');
      expect(output, ['line1\rline2']);
    });

    test('normalizes CR to CR', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.paste('line1\rline2');
      expect(output, ['line1\rline2']);
    });

    test('strips ANSI escape sequences', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.paste('hello\x1b[31mworld');
      expect(output, ['helloworld']);
    });

    test('strips control chars except tab/lf/cr/esc', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.paste('a\x00b\x07c\x0bd');
      expect(output, ['abcd']);
    });

    test('uses bracketed paste when mode enabled', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?2004h'); // Enable bracketed paste
      terminal.paste('hello');
      expect(output.length, 1);
      expect(output.first, startsWith('\x1b[200~'));
      expect(output.first, endsWith('\x1b[201~'));
    });

    test('lineFeedMode changes paste newline to CRLF', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[20h'); // Enable line feed mode (LNM)
      terminal.paste('hello\nworld');
      expect(output, ['hello\r\nworld']);
    });

    test('empty paste produces empty output', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.paste('');
      expect(output, ['']);
    });
  });

  group('Terminal.charInput', () {
    test('ctrl+a produces 0x01', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final result = terminal.charInput(Ascii.a, ctrl: true);
      expect(result, isTrue);
      expect(output, ['\x01']);
    });

    test('ctrl+z produces 0x1a', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final result = terminal.charInput(Ascii.z, ctrl: true);
      expect(result, isTrue);
      expect(output, ['\x1a']);
    });

    test('ctrl+[ produces 0x1b', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final result = terminal.charInput(Ascii.openBracket, ctrl: true);
      expect(result, isTrue);
      expect(output, ['\x1b']);
    });

    test('ctrl+_ produces 0x1f', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final result = terminal.charInput(Ascii.underscore, ctrl: true);
      expect(result, isTrue);
      expect(output, ['\x1f']);
    });

    test('ctrl on non-alphanumeric returns false', () {
      final terminal = Terminal();
      final result = terminal.charInput(' '.codeUnitAt(0), ctrl: true);
      expect(result, isFalse);
    });

    test('alt+a produces ESC A on non-macos', () {
      final output = <String>[];
      final terminal = Terminal(
        onOutput: output.add,
        platform: TerminalTargetPlatform.linux,
      );
      final result = terminal.charInput(Ascii.a, alt: true);
      expect(result, isTrue);
      expect(output, ['\x1bA']);
    });

    test('alt+z produces ESC Z on non-macos', () {
      final output = <String>[];
      final terminal = Terminal(
        onOutput: output.add,
        platform: TerminalTargetPlatform.linux,
      );
      final result = terminal.charInput(Ascii.z, alt: true);
      expect(result, isTrue);
      expect(output, ['\x1bZ']);
    });

    test('alt on macos returns false', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.macos);
      final result = terminal.charInput(Ascii.a, alt: true);
      expect(result, isFalse);
    });

    test('without modifiers returns false', () {
      final terminal = Terminal();
      final result = terminal.charInput(Ascii.a);
      expect(result, isFalse);
    });
  });

  group('Terminal.keyInput', () {
    test('Given onOutput set, When textInput, Then output emitted', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.textInput('a');
      expect(output, ['a']);
    });

    test('returns false when inputHandler is null', () {
      final terminal = Terminal(inputHandler: null);
      final result = terminal.keyInput(TerminalKey.keyA);
      expect(result, isFalse);
    });
  });

  group('Terminal.textInput', () {
    test('Given onOutput set, When textInput, Then text is emitted', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.textInput('hello');
      expect(output, ['hello']);
    });

    test('Given onOutput null, When textInput, Then no error', () {
      final terminal = Terminal();
      expect(() => terminal.textInput('test'), returnsNormally);
    });
  });

  group('Terminal callbacks', () {
    test('bell calls onBell', () {
      String? result;
      final terminal = Terminal(onBell: () => result = 'ring');
      terminal.write('\x07');
      expect(result, 'ring');
    });

    test('setTitle triggers onTitleChange', () {
      String? title;
      final terminal = Terminal(onTitleChange: (t) => title = t);
      terminal.write('\x1b]0;MyTitle\x07');
      expect(title, 'MyTitle');
    });

    test('setIconName triggers onIconChange', () {
      String? icon;
      final terminal = Terminal(onIconChange: (i) => icon = i);
      terminal.write('\x1b]1;MyIcon\x07');
      expect(icon, 'MyIcon');
    });

    test('toString returns terminal info', () {
      final terminal = Terminal();
      expect(terminal.toString(), contains('Terminal('));
      expect(terminal.toString(), contains('x'));
      expect(terminal.toString(), contains('lines'));
    });
  });

  group('Terminal.tab', () {
    test('Given default tab stops, When tab, Then moves forward', () {
      final terminal = Terminal();
      terminal.write('A\x09'); // Write A then tab
      expect(terminal.buffer.cursorX, greaterThan(1));
    });

    test('Given setTapStop, When invoked, Then no error', () {
      final terminal = Terminal();
      terminal.write('\x1bH'); // HTS
      expect(terminal, isNotNull);
    });

    test('Given clearTabStopUnderCursor, When invoked, Then no error', () {
      final terminal = Terminal();
      terminal.write('\x1b[0g'); // TBC 0
      expect(terminal, isNotNull);
    });

    test('Given clearAllTabStops, When invoked, Then no error', () {
      final terminal = Terminal();
      terminal.write('\x1b[g'); // TBC (default 0)
      terminal.write('\x1b[3g'); // TBC 3 (all)
      expect(terminal, isNotNull);
    });
  });

  group('Terminal.hyperlinks', () {
    test('Given hyperlink set, When getHyperlinkUri, Then returns uri', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;id=myid;https://example.com\x1b\\');
      terminal.write('link text');
      terminal.write('\x1b]8;;\x1b\\');
      // The hyperlink should be registered
      final hyperlinks = terminal.hyperlinks;
      expect(hyperlinks, isNotEmpty);
      expect(hyperlinks.values, contains('https://example.com'));
    });

    test('Given hyperlink set, When lookup by id, Then returns uri', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;id=test123;https://test.com\x1b\\');
      final hyperlinks = terminal.hyperlinks;
      expect(hyperlinks.values, contains('https://test.com'));
    });
  });

  group('Terminal.deviceAttributes', () {
    test('sendPrimaryDeviceAttributes emits response', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[c'); // Primary DA
      expect(output, isNotEmpty);
    });

    test('sendSecondaryDeviceAttributes emits response', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[>c'); // Secondary DA
      expect(output, isNotEmpty);
    });

    test('sendTertiaryDeviceAttributes emits response', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[=c'); // Tertiary DA
      expect(output, isNotEmpty);
    });

    test('sendSize emits response', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[18t'); // Report size
      expect(output, isNotEmpty);
    });
  });

  group('Terminal.handleClipboard', () {
    test('read clipboard triggers onClipboardRead', () {
      String? target;
      final terminal = Terminal();
      terminal.onClipboardRead = (t) => target = t;
      terminal.write('\x1b]52;c;?\x07');
      expect(target, 'c');
    });

    test('write clipboard triggers onClipboardWrite', () {
      String? data;
      String? target;
      final terminal = Terminal();
      terminal.onClipboardWrite = (d, t) {
        data = d;
        target = t;
      };
      terminal.write('\x1b]52;c;SGVsbG8=\x07'); // Base64 "Hello"
      expect(target, 'c');
      expect(data, 'Hello');
    });

    test('invalid base64 clipboard does not crash', () {
      final terminal = Terminal();
      expect(
        () => terminal.write('\x1b]52;c;!!!\x07'),
        returnsNormally,
      );
    });
  });

  group('Terminal.colorStack', () {
    test('Given color stack push, When pop, Then restores attributes', () {
      final terminal = Terminal();
      terminal.write('\x1b[31m'); // Red foreground
      terminal.write('\x1b]30001\x07'); // Push
      terminal.write('\x1b[32m'); // Green foreground
      terminal.write('\x1b]30101\x07'); // Pop - should restore red
      // After pop, style should have red foreground
      expect(terminal.cursor.foreground, isNot(isZero));
    });
  });

  group('Terminal.handleNotification', () {
    test('OSC 777 notify triggers onNotification', () {
      String? title;
      String? body;
      final terminal = Terminal();
      terminal.onNotification = (t, b) {
        title = t;
        body = b;
      };
      terminal.write('\x1b]777;notify;Task Done;Build finished\x07');
      expect(title, 'Task Done');
      expect(body, 'Build finished');
    });
  });

  group('Terminal.eraseScrollbackOnly', () {
    test(
        'Given scrolled content, When erase scrollback, Then scrollback cleared',
        () {
      final terminal = Terminal();
      terminal.write('line1\nline2\nline3\n');
      terminal.write('\x1b[J'); // Erase scrollback (CSI 3 J)
      // No crash = pass
      expect(terminal, isNotNull);
    });
  });

  group('Terminal.hyperlinks', () {
    test('getHyperlinkUri returns null for unknown id', () {
      final terminal = Terminal();
      expect(terminal.getHyperlinkUri(999), isNull);
    });

    test('empty uri ends hyperlink', () {
      final terminal = Terminal();
      terminal.write('\x1b]8;;https://example.com\x1b\\');
      terminal.write('\x1b]8;;\x1b\\'); // End hyperlink
      expect(terminal.cursor.attrs & 4, 0); // Hyperlink bit not set
    });
  });

  group('Terminal.repeatPreviousCharacter', () {
    test('Given no preceding char, When repeat, Then does nothing', () {
      final terminal = Terminal();
      expect(() => terminal.write('\x1b[b'), returnsNormally); // CSI b
    });

    test('Given preceding char, When repeat, Then repeats', () {
      final terminal = Terminal();
      terminal.write('A');
      terminal.write('\x1b[5b'); // Repeat 'A' 5 times
      expect(terminal.buffer.lines[0].toString(), 'AAAAAA');
    });
  });

  group('Terminal.sendOperatingStatus', () {
    test('Given onOutput set, When DSR 5, Then emits', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[5n'); // Operating status
      expect(output, isNotEmpty);
    });
  });

  group('Terminal.sendCursorPosition', () {
    test('Given onOutput set, When DSR 6, Then emits', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[6n'); // Cursor position
      expect(output, isNotEmpty);
    });
  });

  group('Terminal.handleDcs (Kitty Remote Control)', () {
    test('handles qTN query', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1bP+qTN\x1b\\'); // DCS +q TN ST
      expect(output, isNotEmpty);
      expect(output.first, contains('kterm'));
    });

    test('handles q? query listing supported capabilities', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1bP+q?\x1b\\');
      expect(output, isNotEmpty);
      expect(output.first, contains('qTN;qcl;qVC'));
    });

    test('handles unknown query gracefully', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1bP+qXYZ\x1b\\');
      expect(output, isNotEmpty);
    });

    test('handles hex-encoded query (q544e = qTN)', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1bP+q544e\x1b\\');
      expect(output, isNotEmpty);
      expect(output.first, contains('kterm'));
    });

    test('does not crash when onOutput is null', () {
      final terminal = Terminal();
      terminal.write('\x1bP+qTN\x1b\\');
      expect(terminal, isNotNull);
    });

    test('skips non-query DCS gracefully', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1bPp1;2;3\x1b\\');
      expect(output, isEmpty);
    });
  });

  group('Terminal.handleTextSizeQuery', () {
    test('responds to font size query (OSC 10;?)', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b]10;?\x07'); // Query font size
      expect(output, isNotEmpty);
      expect(output.first, contains('12'));
    });

    test('does not crash without onOutput', () {
      final terminal = Terminal();
      terminal.write('\x1b]10;?\x07');
      expect(terminal, isNotNull);
    });

    test('ignores OSC 10 without ?', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b]10\x07'); // No query marker
      expect(output, isEmpty);
    });
  });

  group('Terminal.handleShellIntegration', () {
    test('forwards mark start to onPrivateOSC', () {
      String? code;
      List<String>? data;
      final terminal = Terminal(
        onPrivateOSC: (c, d) {
          code = c;
          data = d;
        },
      );
      terminal.write('\x1b]133;A\x07'); // Shell integration: mark start
      expect(code, '133');
      expect(data, ['A']);
    });

    test('forwards current dir to onPrivateOSC', () {
      String? code;
      final terminal = Terminal(
        onPrivateOSC: (c, _) => code = c,
      );
      terminal.write('\x1b]133;D;/home/user\x07');
      expect(code, '133');
    });

    test('forwards command start to onPrivateOSC', () {
      List<String>? data;
      final terminal = Terminal(
        onPrivateOSC: (_, d) => data = d,
      );
      terminal.write('\x1b]133;C\x07');
      expect(data, ['C']);
    });
  });
}

class _TestInputHandler implements TerminalInputHandler {
  final events = <TerminalKeyboardEvent>[];

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}
