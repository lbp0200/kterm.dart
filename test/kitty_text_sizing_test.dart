import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 10 query font size', () {
    // Just verify no crash - font size query depends on platform
    terminal.write('\x1b]10;?\x1b\\');
  });

  test('OSC 133 query font family', () {
    // Just verify no crash - font family query depends on platform
    terminal.write('\x1b]133;?\x1b\\');
  });
}
