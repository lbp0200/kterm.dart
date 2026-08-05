import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 10 query font size', () {
    final output = <String>[];
    terminal.onOutput = output.add;
    terminal.write('\x1b]10;?\x1b\\');
    expect(output, contains('\x1b]10;12\x1b\\'));
  });

  test('OSC 133 query font family', () {
    String? receivedCmd;
    List<String>? receivedArgs;
    terminal.onPrivateOSC = (cmd, args) {
      receivedCmd = cmd;
      receivedArgs = args;
    };
    terminal.write('\x1b]133;A\x1b\\');
    expect(receivedCmd, equals('133'));
    expect(receivedArgs, equals(['A']));
  });
}
