import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kitty_protocol/kitty_protocol.dart';
import 'package:kterm/src/core/buffer/cell_offset.dart';
import 'package:kterm/src/core/input/keys.dart';
import 'package:kterm/src/terminal.dart';
import 'package:kterm/src/ui/controller.dart';
import 'package:kterm/src/ui/cursor_type.dart';
import 'package:kterm/src/ui/custom_text_edit.dart';
import 'package:kterm/src/ui/gesture/gesture_handler.dart';
import 'package:kterm/src/ui/input_map.dart';
import 'package:kterm/src/ui/keyboard_listener.dart';
import 'package:kterm/src/ui/keyboard_visibility.dart';
import 'package:kterm/src/ui/render.dart';
import 'package:kterm/src/ui/scroll_handler.dart';
import 'package:kterm/src/ui/search_bar.dart';
import 'package:kterm/src/ui/shortcut/actions.dart';
import 'package:kterm/src/ui/shortcut/shortcuts.dart';
import 'package:kterm/src/ui/terminal_text_style.dart';
import 'package:kterm/src/ui/terminal_theme.dart';
import 'package:kterm/src/ui/themes.dart';

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    super.key,
    this.controller,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.textScaler,
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.mouseCursor = SystemMouseCursors.text,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.alwaysShowCursor = false,
    this.deleteDetection = false,
    this.shortcuts,
    this.onKeyEvent,
    this.readOnly = false,
    this.hardwareKeyboardOnly = false,
    this.simulateScroll = true,
    this.showSearchBar = false,
  });

  /// The underlying terminal that this widget renders.
  final Terminal terminal;

  final TerminalController? controller;

  /// The theme to use for this terminal.
  final TerminalTheme theme;

  /// The style to use for painting characters.
  final TerminalStyle textStyle;

  final TextScaler? textScaler;

  /// Padding around the inner [Scrollable] widget.
  final EdgeInsets? padding;

  /// Scroll controller for the inner [Scrollable] widget.
  final ScrollController? scrollController;

  /// Should this widget automatically notify the underlying terminal when its
  /// size changes. `true` by default.
  final bool autoResize;

  /// Opacity of the terminal background. Set to 0 to make the terminal
  /// background transparent.
  final double backgroundOpacity;

  /// An optional focus node to use as the focus node for this widget.
  final FocusNode? focusNode;

  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  final bool autofocus;

  /// Callback for when the user taps on the terminal.
  final void Function(TapUpDetails, CellOffset)? onTapUp;

  /// Function called when the user taps on the terminal with a secondary
  /// button.
  final void Function(TapDownDetails, CellOffset)? onSecondaryTapDown;

  /// Function called when the user stops holding down a secondary button.
  final void Function(TapUpDetails, CellOffset)? onSecondaryTapUp;

  /// The mouse cursor for mouse pointers that are hovering over the terminal.
  /// [SystemMouseCursors.text] by default.
  final MouseCursor mouseCursor;

  /// The type of information for which to optimize the text input control.
  /// [TextInputType.emailAddress] by default.
  final TextInputType keyboardType;

  /// The appearance of the keyboard. [Brightness.dark] by default.
  ///
  /// This setting is only honored on iOS devices.
  final Brightness keyboardAppearance;

  /// The type of cursor to use. [TerminalCursorType.block] by default.
  final TerminalCursorType cursorType;

  /// Whether to always show the cursor. This is useful for debugging.
  /// `false` by default.
  final bool alwaysShowCursor;

  /// Workaround to detect delete key for platforms and IMEs that does not
  /// emit hardware delete event. Prefered on mobile platforms. `false` by
  /// default.
  final bool deleteDetection;

  /// Shortcuts for this terminal. This has higher priority than input handler
  /// of the terminal If not provided, [defaultTerminalShortcuts] will be used.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Keyboard event handler of the terminal. This has higher priority than
  /// [shortcuts] and input handler of the terminal.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// True if no input should send to the terminal.
  final bool readOnly;

  /// True if only hardware keyboard events should be used as input. This will
  /// also prevent any on-screen keyboard to be shown.
  final bool hardwareKeyboardOnly;

  /// If true, when the terminal is in alternate buffer (for example running
  /// vim, man, etc), if the application does not declare that it can handle
  /// scrolling, the terminal will simulate scrolling by sending up/down arrow
  /// keys to the application. This is standard behavior for most terminal
  /// emulators. True by default.
  final bool simulateScroll;

  /// If true, shows a search bar above the terminal and enables search
  /// keyboard shortcuts (Ctrl+F / Cmd+F to open, F3 to find next,
  /// Shift+F3 to find previous, Escape to close).
  /// Default is false.
  final bool showSearchBar;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  late FocusNode _focusNode;

  late final ShortcutManager _shortcutManager;

  final _customTextEditKey = GlobalKey<CustomTextEditState>();

  final _scrollableKey = GlobalKey<ScrollableState>();

  final _viewportKey = GlobalKey();

  String? _composingText;

  late TerminalController _controller;

  late ScrollController _scrollController;

  bool _showSearchBar = false;

  RenderTerminal get renderTerminal {
    final context = _viewportKey.currentContext;
    if (context == null) {
      throw StateError('renderTerminal accessed before TerminalView is built');
    }
    return context.findRenderObject() as RenderTerminal;
  }

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TerminalController();
    _scrollController = widget.scrollController ?? ScrollController();
    _shortcutManager = ShortcutManager(
      shortcuts: widget.shortcuts ?? defaultTerminalShortcuts,
    );
    _showSearchBar = widget.showSearchBar;

    // Setup search callbacks
    _controller.onGetText = () => widget.terminal.buffer.getText();
    _controller.onCreateAnchor = (offset) {
      return widget.terminal.buffer.createAnchorFromOffset(offset);
    };

    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TerminalController();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? ScrollController();
    }
    _shortcutManager.shortcuts = widget.shortcuts ?? defaultTerminalShortcuts;
    if (oldWidget.showSearchBar != widget.showSearchBar) {
      _showSearchBar = widget.showSearchBar;
      if (!_showSearchBar) {
        _controller.closeSearch();
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _shortcutManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).padding;
    final textScaler = widget.textScaler ?? MediaQuery.textScalerOf(context);
    Widget child = Scrollable(
      key: _scrollableKey,
      controller: _scrollController,
      viewportBuilder: (context, offset) {
        return _TerminalView(
          key: _viewportKey,
          terminal: widget.terminal,
          controller: _controller,
          offset: offset,
          padding: viewPadding,
          autoResize: widget.autoResize,
          textStyle: widget.textStyle,
          textScaler: textScaler,
          theme: widget.theme,
          focusNode: _focusNode,
          cursorType: widget.cursorType,
          alwaysShowCursor: widget.alwaysShowCursor,
          onEditableRect: _onEditableRect,
          composingText: _composingText,
        );
      },
    );

    child = TerminalScrollGestureHandler(
      terminal: widget.terminal,
      simulateScroll: widget.simulateScroll,
      getCellOffset: (offset) => renderTerminal.getCellOffset(offset),
      getLineHeight: () => renderTerminal.lineHeight,
      child: child,
    );

    if (!widget.hardwareKeyboardOnly) {
      child = CustomTextEdit(
        key: _customTextEditKey,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        inputType: widget.keyboardType,
        keyboardAppearance: widget.keyboardAppearance,
        deleteDetection: widget.deleteDetection,
        onInsert: _onInsert,
        onDelete: () {
          _scrollToBottom();
          widget.terminal.keyInput(TerminalKey.backspace);
        },
        onComposing: _onComposing,
        onAction: (action) {
          _scrollToBottom();
          // Android sends TextInputAction.newline when the user presses the virtual keyboard's enter key.
          if (action == TextInputAction.done ||
              action == TextInputAction.newline) {
            widget.terminal.keyInput(TerminalKey.enter);
          }
        },
        onKeyEvent: _handleKeyEvent,
        readOnly: widget.readOnly,
        child: child,
      );
    } else if (!widget.readOnly) {
      // Only listen for key input from a hardware keyboard.
      child = CustomKeyboardListener(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onInsert: _onInsert,
        onComposing: _onComposing,
        onKeyEvent: _handleKeyEvent,
        child: child,
      );
    }

    child = TerminalActions(
      terminal: widget.terminal,
      controller: _controller,
      child: child,
    );

    child = KeyboardVisibility(
      onKeyboardShow: _onKeyboardShow,
      child: child,
    );

    child = TerminalGestureHandler(
      terminalView: this,
      terminalController: _controller,
      onTapUp: _onTapUp,
      onTapDown: _onTapDown,
      onSecondaryTapDown:
          widget.onSecondaryTapDown != null ? _onSecondaryTapDown : null,
      onSecondaryTapUp:
          widget.onSecondaryTapUp != null ? _onSecondaryTapUp : null,
      readOnly: widget.readOnly,
      child: child,
    );

    child = MouseRegion(
      cursor: widget.mouseCursor,
      child: child,
    );

    child = Container(
      color:
          widget.theme.background.withValues(alpha: widget.backgroundOpacity),
      padding: widget.padding,
      child: child,
    );

    // Add search bar if enabled
    if (_showSearchBar) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.isSearching) {
                return TerminalSearchBar(
                  controller: _controller,
                  onClose: () {
                    _controller.closeSearch();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(child: child),
        ],
      );
    }

    // Wrap with keyboard shortcuts handler for search
    if (_showSearchBar) {
      child = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Ctrl+F / Cmd+F - Open search
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            _controller.openSearch();
          },
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
            _controller.openSearch();
          },
          // F3 - Next match
          const SingleActivator(LogicalKeyboardKey.f3): () {
            _controller.searchNext();
          },
          // Shift+F3 - Previous match
          const SingleActivator(LogicalKeyboardKey.f3, shift: true): () {
            _controller.searchPrevious();
          },
          // Cmd+G - Next match (macOS)
          const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
            _controller.searchNext();
          },
          // Cmd+Shift+G - Previous match (macOS)
          const SingleActivator(LogicalKeyboardKey.keyG,
              meta: true, shift: true): () {
            _controller.searchPrevious();
          },
        },
        child: Focus(
          autofocus: false,
          child: child,
        ),
      );
    }

    return child;
  }

  void requestKeyboard() {
    _customTextEditKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _customTextEditKey.currentState?.closeKeyboard();
  }

  Rect get cursorRect {
    return renderTerminal.cursorOffset & renderTerminal.cellSize;
  }

  Rect get globalCursorRect {
    return renderTerminal.localToGlobal(renderTerminal.cursorOffset) &
        renderTerminal.cellSize;
  }

  void _onTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onTapUp?.call(details, offset);
  }

  void _onTapDown(TapDownDetails details) {
    if (_controller.selection != null) {
      _controller.clearSelection();
    } else {
      if (!widget.hardwareKeyboardOnly) {
        _customTextEditKey.currentState?.requestKeyboard();
      } else {
        _focusNode.requestFocus();
      }
    }
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapDown?.call(details, offset);
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapUp?.call(details, offset);
  }

  bool get hasInputConnection {
    return _customTextEditKey.currentState?.hasInputConnection == true;
  }

  void _onInsert(String text) {
    // macOS 将 Enter 和 Shift+Enter 都通过文本输入系统发送 \r，
    // 无法在 _handleKeyEvent 中区分，故在此检测 Shift 状态。
    if (text == '\r' && HardwareKeyboard.instance.isShiftPressed) {
      widget.terminal.textInput('\n');
      _scrollToBottom();
      return;
    }

    // 多字符文本可能来自：
    // 1. IME 粘贴（macOS 上 Cmd+V 的 IME 路径）
    // 2. 某些没有通过快捷键路径粘贴的平台（回退路径）
    // 3. IME 输入法确认（如中文/日文输入）
    //
    // 使用 terminal.paste() 确保 ANSI 过滤、控制字符清理、
    // 换行符规范化以及 bracketed paste 模式正确处理。
    if (text.length > 1) {
      // macOS 上快捷键路径已处理粘贴，跳过 IME 重复
      if (_controller.consumePasteFromShortcut()) {
        _scrollToBottom();
        return;
      }
      widget.terminal.paste(text);
      _scrollToBottom();
      return;
    }

    final key = charToTerminalKey(text.trim());

    // On mobile platforms there is no guarantee that virtual keyboard will
    // generate hardware key events. So we need first try to send the key
    // as a hardware key event. If it fails, then we send it as a text input.
    final consumed = key == null ? false : widget.terminal.keyInput(key);

    if (!consumed) {
      widget.terminal.textInput(text);
    }

    _scrollToBottom();
  }

  void _onComposing(String? text) {
    setState(() => _composingText = text);
  }

  /// Try to send the key through the standard keytab/keyInput pipeline.
  /// Returns `true` if the key was handled and the view should scroll.
  bool _tryKeyInput(
    LogicalKeyboardKey logicalKey, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    final key = keyToTerminalKey(logicalKey);
    if (key == null) return false;
    final handled = widget.terminal.keyInput(
      key,
      ctrl: ctrl,
      alt: alt,
      shift: shift,
    );
    if (handled) _scrollToBottom();
    return handled;
  }

  /// Handle a key event under Kitty keyboard protocol mode.
  /// Returns a [KeyEventResult] indicating whether the event was consumed.
  KeyEventResult _handleKittyKeyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final hasModifiers = keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed;

    final isSpecialKey = _isSpecialKey(event.logicalKey);

    // Handle KeyUp events - only encode if reportAllKeysAsEscape or modifiers pressed
    if (event is KeyUpEvent) {
      final shouldEncodeKeyUp =
          widget.terminal.kittyEncoder.flags.reportAllKeysAsEscape ||
              hasModifiers;
      if (shouldEncodeKeyUp) {
        final seq = _encodeWithKitty(event);
        if (seq != null && seq.isNotEmpty) {
          widget.terminal.onOutput?.call(seq);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // First pass: use Kitty encoding for modifier + special key combinations
    // (Shift+Enter, Ctrl+Tab, etc.) or when reportAllKeysAsEscape is enabled.
    final useKittyNow = hasModifiers
        ? isSpecialKey
        : widget.terminal.kittyEncoder.flags.reportAllKeysAsEscape;

    if (useKittyNow) {
      final seq = _encodeWithKitty(event);
      if (seq != null && seq.isNotEmpty) {
        widget.terminal.onOutput?.call(seq);
        return KeyEventResult.handled;
      }
    }

    // KeyDown / KeyRepeat: try standard handling with Kitty encoding fallback
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Ctrl+letter (A-Z, pure Ctrl, no Shift/Alt):
      // Send raw ASCII control characters for shell backward compatibility.
      if (keyboard.isControlPressed &&
          !keyboard.isShiftPressed &&
          !keyboard.isAltPressed) {
        final stdKey = keyToTerminalKey(event.logicalKey);
        if (stdKey != null &&
            stdKey.index >= TerminalKey.keyA.index &&
            stdKey.index <= TerminalKey.keyZ.index) {
          if (_tryKeyInput(event.logicalKey, ctrl: true)) {
            return KeyEventResult.handled;
          }
        }
      }

      // Decide whether to use Kitty encoding vs. standard handling
      final useKittyEncoding =
          widget.terminal.kittyEncoder.flags.reportAllKeysAsEscape ||
              hasModifiers;

      if (!useKittyEncoding) {
        // Standard handling for bare keys (no modifiers, not report-all)
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          widget.terminal.textInput('\t');
          _scrollToBottom();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          widget.terminal.textInput('\r');
          _scrollToBottom();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          widget.terminal.textInput('\x7f');
          _scrollToBottom();
          return KeyEventResult.handled;
        }
        // Other special keys (arrows, home, end, page up/down, etc.)
        if (_tryKeyInput(
          event.logicalKey,
          ctrl: keyboard.isControlPressed,
          alt: keyboard.isAltPressed,
          shift: keyboard.isShiftPressed,
        )) {
          return KeyEventResult.handled;
        }
        // Alphanumeric keys: let Flutter's TextInputClient handle them
        return KeyEventResult.ignored;
      }

      // Try Kitty encoding
      final seq = _encodeWithKitty(event);
      if (seq != null && seq.isNotEmpty) {
        widget.terminal.onOutput?.call(seq);
        return KeyEventResult.handled;
      }

      // Kitty encoding produced nothing — fall back to standard keytab input
      // for modifier+letter combinations (Alt+A, Meta+U, etc.)
      if (_tryKeyInput(
        event.logicalKey,
        ctrl: keyboard.isControlPressed,
        alt: keyboard.isAltPressed,
        shift: keyboard.isShiftPressed,
      )) {
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    // For alphanumeric keys, let Flutter's TextInputClient handle them
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    final resultOverride = widget.onKeyEvent?.call(focusNode, event);
    if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
      return resultOverride;
    }

    // Check shortcuts BEFORE Kitty mode, so copy/paste/select-all work
    // regardless of Kitty keyboard protocol state.
    // ignore: invalid_use_of_protected_member
    final shortcutResult = _shortcutManager.handleKeypress(
      focusNode.context!,
      event,
    );
    if (shortcutResult != KeyEventResult.ignored) {
      return shortcutResult;
    }

    // Intercept with Kitty keyboard protocol if enabled
    if (widget.terminal.kittyMode) {
      return _handleKittyKeyEvent(event);
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = keyToTerminalKey(event.logicalKey);

    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = widget.terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );

    if (handled) {
      _scrollToBottom();
    }

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onKeyboardShow() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _onEditableRect(Rect rect, Rect caretRect) {
    _customTextEditKey.currentState?.setEditableRect(rect, caretRect);
  }

  void _scrollToBottom() {
    final position = _scrollableKey.currentState?.position;
    if (position != null) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  /// Check if the key is a special key (Enter, Tab, Backspace, Space, Arrows, etc.)
  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12 ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.insert ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown;
  }

  String? _encodeWithKitty(KeyEvent event) {
    // Handle KeyUp events - encode them to signal key release
    final isKeyUp = event is KeyUpEvent;

    if (isKeyUp || event is KeyDownEvent || event is KeyRepeatEvent) {
      final modifiers = <SimpleModifier>{};
      final keyboard = HardwareKeyboard.instance;

      if (keyboard.isShiftPressed) modifiers.add(SimpleModifier.shift);
      if (keyboard.isControlPressed) modifiers.add(SimpleModifier.control);
      if (keyboard.isAltPressed) modifiers.add(SimpleModifier.alt);
      if (keyboard.isMetaPressed) modifiers.add(SimpleModifier.meta);

      final keyEvent = SimpleKeyEvent(
        logicalKey: event.logicalKey,
        modifiers: modifiers,
        isKeyUp: isKeyUp,
        isKeyRepeat: event is KeyRepeatEvent,
      );

      return widget.terminal.kittyEncoder.encode(keyEvent);
    }
    return null;
  }
}

class _TerminalView extends LeafRenderObjectWidget {
  const _TerminalView({
    super.key,
    required this.terminal,
    required this.controller,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.textStyle,
    required this.textScaler,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.alwaysShowCursor,
    this.onEditableRect,
    this.composingText,
  });

  final Terminal terminal;

  final TerminalController controller;

  final ViewportOffset offset;

  final EdgeInsets padding;

  final bool autoResize;

  final TerminalStyle textStyle;

  final TextScaler textScaler;

  final TerminalTheme theme;

  final FocusNode focusNode;

  final TerminalCursorType cursorType;

  final bool alwaysShowCursor;

  final EditableRectCallback? onEditableRect;

  final String? composingText;

  @override
  RenderTerminal createRenderObject(BuildContext context) {
    return RenderTerminal(
      terminal: terminal,
      controller: controller,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      textStyle: textStyle,
      textScaler: textScaler,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      alwaysShowCursor: alwaysShowCursor,
      onEditableRect: onEditableRect,
      composingText: composingText,
      graphicsManager: terminal.graphicsManager,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTerminal renderObject) {
    renderObject
      ..terminal = terminal
      ..controller = controller
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..textStyle = textStyle
      ..textScaler = textScaler
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..alwaysShowCursor = alwaysShowCursor
      ..onEditableRect = onEditableRect
      ..composingText = composingText;
  }
}
