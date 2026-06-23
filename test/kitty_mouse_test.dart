import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('SGR 1004 enable focus tracking', () {
    terminal.write('\x1b[?1004h');
    expect(terminal.reportFocusMode, isTrue);
  });

  test('SGR 1006 extended mouse encoding', () {
    terminal.write('\x1b[?1006h');
    expect(terminal.mouseReportMode, equals(MouseReportMode.sgr));
  });
}
