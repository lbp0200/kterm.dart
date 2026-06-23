import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/selection_mode.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.child,
  });

  final Terminal terminal;

  final TerminalController controller;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) async {
            // macOS 上 Cmd+V 会同时触发快捷键路径和 IME 路径：
            //   1. 快捷键路径：此处读取剪贴板并调用 terminal.paste()
            //   2. IME 路径：系统通过 updateEditingValue → _onInsert 再次投递文本
            // 为避免重复粘贴和 IME 高亮导致的全选问题，此处仅清空选择，
            // 实际的粘贴操作由 _onInsert（多字符文本检测）委托给 terminal.paste() 处理。
            controller.clearSelection();
            return null;
          },
        ),
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (intent) async {
            final selection = controller.selection;

            if (selection == null) {
              return;
            }

            final text = terminal.buffer.getText(selection);

            await Clipboard.setData(ClipboardData(text: text));

            return null;
          },
        ),
        SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
          onInvoke: (intent) {
            controller.setSelection(
              terminal.buffer.createAnchor(
                0,
                terminal.buffer.height - terminal.viewHeight,
              ),
              terminal.buffer.createAnchor(
                terminal.viewWidth,
                terminal.buffer.height - 1,
              ),
              mode: SelectionMode.line,
            );
            return null;
          },
        ),
      },
      child: child,
    );
  }
}
