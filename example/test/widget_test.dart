import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:kterm_example/mock.dart';

void main() {
  // The example app's real entry point (main.dart) spawns a PTY via
  // flutter_pty, which cannot run inside the widget-test environment. The
  // mock.dart variant wires the same TerminalView up to a pure-Dart MockRepl,
  // so these smoke tests exercise the real example widget tree end-to-end.
  testWidgets('renders the terminal and the mock pty welcome banner',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();

    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    final terminal = view.terminal;

    // MockRepl writes a welcome banner into the terminal on construction.
    expect(terminal.buffer.lines[0].toString(), contains('Welcome to kterm!'));
    expect(terminal.buffer.lines[1].toString(),
        contains('Type "help" for more information.'));
  });

  testWidgets('enter key is echoed back by the mock pty',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();

    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    final terminal = view.terminal;

    // MockRepl leaves the cursor on a fresh "$ " prompt line.
    expect(terminal.buffer.lines[terminal.buffer.cursorY].toString(), '\$ ');

    // Enter is the only key with a keytab record that echoes through the
    // MockRepl: keyInput -> KeytabInputHandler -> onOutput -> MockRepl.write
    // -> terminal.write (echoes "\r\n$ ").
    terminal.keyInput(TerminalKey.enter);
    // Let the post-frame editable-rect callback run while the tree is still
    // attached; otherwise it fires during teardown and hits the 'attached'
    // assertion in RenderObject.getTransformTo.
    await tester.pump();

    expect(terminal.buffer.lines[terminal.buffer.cursorY].toString(), '\$ ');
    expect(terminal.buffer.cursorY, greaterThan(0));
  });
}
