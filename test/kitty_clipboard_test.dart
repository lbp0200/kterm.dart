import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 52 get clipboard query', () {
    String? queriedTarget;
    terminal.onClipboardRead = (target) {
      queriedTarget = target;
    };
    terminal.write('\x1b]52;c;?\x1b\\');
    expect(queriedTarget, equals('c'));
  });

  test('OSC 52 set clipboard', () {
    String? clipboardData;
    terminal.onClipboardWrite = (data, target) {
      clipboardData = data;
    };
    terminal.write('\x1b]52;c;aGVsbG8=\x1b\\');
    expect(clipboardData, equals('hello'));
  });

  test('OSC 5522 extended clipboard sync start', () {
    // Protocol-level marker with no handler in Terminal; the parser routes it
    // to unknownOSC which is a no-op. Keep as a no-crash guard.
    terminal.write('\x1b]5522;sync;start\x1b\\');
  });
}
