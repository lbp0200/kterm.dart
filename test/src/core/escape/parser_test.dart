import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:kterm/kterm.dart';

@GenerateNiceMocks([MockSpec<EscapeHandler>()])
import 'parser_test.mocks.dart';

void main() {
  group('EscapeParser', () {
    test('can parse window manipulation', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[8;24;80t');
      verify(parser.handler.resize(80, 24));
    });

    group('SGR color', () {
      // Foreground color — CSI 38 ; 5 ; N m
      test('38;5;N sets 256-color foreground', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[38;5;42m');
        verify(parser.handler.setForegroundColor256(42));
        verifyNoMoreInteractions(parser.handler);
      });

      test('38;2;R;G;B sets RGB foreground', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[38;2;10;20;30m');
        verify(parser.handler.setForegroundColorRgb(10, 20, 30));
        verifyNoMoreInteractions(parser.handler);
      });

      test('38;5 without index does not leak mode into next param', () {
        final parser = EscapeParser(MockEscapeHandler());
        // 38;5m — missing index. Old code: i++ after insufficient params
        // made mode=5 the next param, triggering setCursorBlink().
        // New code: i+=2 skips past both 38 and 5 silently.
        parser.write('\x1b[38;5m');
        // No leak: mode=5 should NOT trigger cursor blink
        verifyNever(parser.handler.setCursorBlink());
      });

      test('38 without mode does not crash', () {
        final parser = EscapeParser(MockEscapeHandler());
        // 38 alone — params=[38], no mode value. Should skip silently.
        parser.write('\x1b[38m');
        // No style call should be leaked
        verifyNever(parser.handler.unsetCursorInverse());
      });

      // Background color — CSI 48 ; 5 ; N m
      test('48;5;N sets 256-color background', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[48;5;99m');
        verify(parser.handler.setBackgroundColor256(99));
        verifyNoMoreInteractions(parser.handler);
      });

      test('48;2;R;G;B sets RGB background', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[48;2;100;200;255m');
        verify(parser.handler.setBackgroundColorRgb(100, 200, 255));
        verifyNoMoreInteractions(parser.handler);
      });

      test('48;5 without index does not leak mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[48;5m');
        // No leak: mode=5 should NOT trigger cursor blink
        verifyNever(parser.handler.setCursorBlink());
      });

      // Underline color — CSI 58 ; 5 ; N m
      test('58;5;N sets 256-color underline', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[58;5;7m');
        verify(parser.handler.setUnderlineColor256(7));
        verifyNoMoreInteractions(parser.handler);
      });

      test('58;2;R;G;B sets RGB underline', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[58;2;0;128;255m');
        verify(parser.handler.setUnderlineColorRgb(0, 128, 255));
        verifyNoMoreInteractions(parser.handler);
      });

      test('58;5 without index does not leak mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[58;5m');
        // No leak: mode=5 should NOT trigger cursor blink
        verifyNever(parser.handler.setCursorBlink());
      });

      // Unknown color mode is skipped safely
      test('38;99 unknown mode skips both params without crash', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[38;99m');
        // Unknown mode 99 should not leak into a style param
        verifyNever(parser.handler.unsetCursorInverse());
      });
    });

    group('CSI cursor movement', () {
      test('A moves cursor up', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[3A');
        verify(parser.handler.moveCursorY(-3));
      });

      test('B moves cursor down', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[5B');
        verify(parser.handler.moveCursorY(5));
      });

      test('C moves cursor forward', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[7C');
        verify(parser.handler.moveCursorX(7));
      });

      test('D moves cursor backward', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[2D');
        verify(parser.handler.moveCursorX(-2));
      });

      test('default param 0 maps to 1 for cursor up', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[0A');
        verify(parser.handler.moveCursorY(-1));
      });
    });

    group('CSI erase', () {
      test('J 0 erases display below', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[0J');
        verify(parser.handler.eraseDisplayBelow());
      });

      test('J 1 erases display above', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[1J');
        verify(parser.handler.eraseDisplayAbove());
      });

      test('J 2 erases entire display', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[2J');
        verify(parser.handler.eraseDisplay());
      });

      test('J 3 erases scrollback', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[3J');
        verify(parser.handler.eraseScrollbackOnly());
      });

      test('K 0 erases line right', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[0K');
        verify(parser.handler.eraseLineRight());
      });

      test('K 1 erases line left', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[1K');
        verify(parser.handler.eraseLineLeft());
      });

      test('K 2 erases entire line', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[2K');
        verify(parser.handler.eraseLine());
      });
    });

    group('CSI device status report', () {
      test('DSR 5 sends operating status', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[5n');
        verify(parser.handler.sendOperatingStatus());
      });

      test('DSR 6 sends cursor position', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[6n');
        verify(parser.handler.sendCursorPosition());
      });
    });

    group('CSI device attributes with prefix', () {
      test('> c sends secondary DA', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>c');
        verify(parser.handler.sendSecondaryDeviceAttributes());
      });

      test('= c sends tertiary DA', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[=c');
        verify(parser.handler.sendTertiaryDeviceAttributes());
      });

      test('c sends primary DA', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[c');
        verify(parser.handler.sendPrimaryDeviceAttributes());
      });
    });

    group('CSI Kitty keyboard protocol', () {
      test('> 0 u disables kitty mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>0u');
        verify(parser.handler.setKittyMode(false));
      });

      test('> 1 u enables kitty mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>1u');
        verify(parser.handler.setKittyMode(true));
      });

      test('> + 1 u pushes flags', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>+1u');
        verify(parser.handler.pushKittyFlags(1));
      });

      test('> + 5 u pushes flags value 5', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>+5u');
        verify(parser.handler.pushKittyFlags(5));
      });

      test('> - u pops flags', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>-u');
        verify(parser.handler.popKittyFlags());
      });

      test('> - 1 u pops flags (numeric param ignored)', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>-1u');
        verify(parser.handler.popKittyFlags());
      });

      test('> + u without param does not push', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>+u');
        verifyNever(parser.handler.pushKittyFlags(0));
        verifyNever(parser.handler.popKittyFlags());
      });
    });

    group('SGR style attributes', () {
      test('0 resets cursor style', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[0m');
        verify(parser.handler.resetCursorStyle());
      });

      test('1 sets bold', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[1m');
        verify(parser.handler.setCursorBold());
      });

      test('7 sets inverse', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[7m');
        verify(parser.handler.setCursorInverse());
      });

      test('21 unsets bold', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[21m');
        verify(parser.handler.unsetCursorBold());
      });

      test('30-37 set foreground 16-color black-white', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[31m');
        verify(parser.handler.setForegroundColor16(NamedColor.red));
      });

      test('40-47 set background 16-color', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[42m');
        verify(parser.handler.setBackgroundColor16(NamedColor.green));
      });

      test('90-97 set bright foreground', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[91m');
        verify(parser.handler.setForegroundColor16(NamedColor.brightRed));
      });

      test('100-107 set bright background', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[102m');
        verify(parser.handler.setBackgroundColor16(NamedColor.brightGreen));
      });
    });

    group('SGR extended underline', () {
      test('4;2 sets double underline', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[4;2m');
        verify(parser.handler.setCursorUnderlineStyle(2));
      });

      test('4 alone sets single underline', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[4m');
        verify(parser.handler.setCursorUnderline());
      });

      test('59 resets underline color', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[58;2;0;100;200m\x1b[59m');
        verify(parser.handler.setUnderlineColorRgb(0, 100, 200));
        verify(parser.handler.resetUnderlineColor());
      });
    });

    group('Escape sequences (non-CSI)', () {
      test('ESC 7 saves cursor', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b7');
        verify(parser.handler.saveCursor());
      });

      test('ESC 8 restores cursor', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b8');
        verify(parser.handler.restoreCursor());
      });

      test('ESC D indexes', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1bD');
        verify(parser.handler.index());
      });

      test('ESC E next line', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1bE');
        verify(parser.handler.nextLine());
      });

      test('ESC H sets tab stop', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1bH');
        verify(parser.handler.setTapStop());
      });

      test('ESC M reverse index', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1bM');
        verify(parser.handler.reverseIndex());
      });

      test('ESC = sets app keypad mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b=');
        verify(parser.handler.setAppKeypadMode(true));
      });

      test('ESC > resets app keypad mode', () {
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b>');
        verify(parser.handler.setAppKeypadMode(false));
      });
    });

    group('Incomplete sequences', () {
      test('partial CSI buffers and resumes', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1b['); // incompleto
        parser.write('3A'); // ahora completo
        verify(handler.moveCursorY(-3));
      });

      test('partial ESC buffers and resumes', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1b'); // incompleto
        parser.write('[');
        parser.write('H');
        // Final: ESC [ H = setTabStop... wait, no. ESC H = setTapStop.
        // ESC [ H = cursorPosition. Let's check: partial ESC + CSI H
        verify(handler.setCursor(0, 0));
      });
    });

    group('DCS (Device Control String)', () {
      test('DCS +q query calls handleDcs', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1bP+qTN\x1b\\');
        // Parser strips '+' then appends 'q' prefix with remainder
        verify(handler.handleDcs('+qqTN', [], null));
      });

      test('DCS +q with hex-encoded query calls handleDcs', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1bP+q544e\x1b\\');
        verify(handler.handleDcs('+qq544e', [], null));
      });

      test('DCS +q? calls handleDcs with ?', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1bP+q?\x1b\\');
        verify(handler.handleDcs('+qq?', [], null));
      });

      test('non-query DCS is skipped', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1bPp1;2;3\x1b\\');
        verifyNever(handler.handleDcs(any, any, any));
      });

      test('DCS with no ST terminator is handled gracefully', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        // DCS without terminator should not crash
        parser.write('\x1bP+qTN');
        // The handler may or may not be called depending on buffer state
      });
    });

    group('APC (Application Program Command)', () {
      test('APC G calls graphicsCommandStart', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1b_Gf=100,m=1\x1b\\');
        verify(handler.graphicsCommandStart({'f': '100', 'm': '1'}));
      });

      test('non-G APC is skipped', () {
        final handler = MockEscapeHandler();
        final parser = EscapeParser(handler);
        parser.write('\x1b_Xcustom\x1b\\');
        verifyNever(handler.graphicsCommandStart(any));
      });
    });
  });
}
