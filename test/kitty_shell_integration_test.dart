import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 133 A shell started', () {
    String? oscCode;
    List<String>? oscArgs;
    terminal.onPrivateOSC = (code, args) {
      oscCode = code;
      oscArgs = args;
    };
    terminal.write('\x1b]133;A\x1b\\');
    expect(oscCode, equals('133'));
    expect(oscArgs, contains('A'));
  });

  test('OSC 133 D command executed', () {
    String? oscCode;
    List<String>? oscArgs;
    terminal.onPrivateOSC = (code, args) {
      oscCode = code;
      oscArgs = args;
    };
    terminal.write('\x1b]133;D\x1b\\');
    expect(oscCode, equals('133'));
    expect(oscArgs, contains('D'));
  });
}
