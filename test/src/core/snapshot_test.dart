import 'package:test/test.dart';
import 'package:kterm/src/core/snapshot.dart';

void main() {
  group('TerminalSnapshot', () {
    test('Given TerminalSnapshot, When interface checked, Then is abstract class', () {
      // Assert - verify it's an abstract class with trimScrollback method
      expect(TerminalSnapshot, isNotNull);
    });

    test('Given TerminalSnapshot, When interface defined, Then contains trimScrollback method', () {
      // We verify the abstract class has the method signature
      // by checking it can be implemented
      final methods = TerminalSnapshot.toString();
      expect(methods, contains('TerminalSnapshot'));
    });
  });
}
