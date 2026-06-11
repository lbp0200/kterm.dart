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
  });
}
