import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal();
  });

  test('OSC 52 get clipboard query', () {
    // Just verify no crash - clipboard query depends on platform
    terminal.write('\x1b]52;c;?\x1b\\');
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
    // Just verify no crash - clipboard sync is protocol-level
    terminal.write('\x1b]5522;sync;start\x1b\\');
  });
}
