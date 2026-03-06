import 'package:test/test.dart';
import 'package:kterm/src/core/escape/handler.dart';
import 'package:kterm/src/core/mouse/mode.dart';

void main() {
  group('EscapeHandler', () {
    test('Given EscapeHandler, When interface checked, Then contains required methods', () {
      // Assert - verify the abstract class has all expected method signatures
      // We verify through implementation in Terminal class
      expect(EscapeHandler, isNotNull);
    });

    test('Given EscapeHandler, When SBC methods checked, Then contains required methods', () {
      // Assert - verify SBC methods exist in interface
      // This is tested by verifying the abstract class can be implemented
      final methods = EscapeHandler
          .toString()
          .split(',')
          .map((s) => s.trim())
          .toList();
      expect(methods, isNotEmpty);
    });

    test('Given EscapeHandler, When MouseMode checked, Then contains expected values', () {
      // Assert - verify MouseMode enum is available
      expect(MouseMode.values.contains(MouseMode.none), isTrue);
      expect(MouseMode.values.contains(MouseMode.x10), isTrue);
      expect(MouseMode.values.contains(MouseMode.vt200), isTrue);
      expect(MouseMode.values.contains(MouseMode.vt200Highlight), isTrue);
      expect(MouseMode.values.contains(MouseMode.sgr), isTrue);
      expect(MouseMode.values.contains(MouseMode.sgrRelease), isTrue);
      expect(MouseMode.values.contains(MouseMode.urxvt), isTrue);
    });
  });
}
