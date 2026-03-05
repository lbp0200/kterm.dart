import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kterm/src/ui/controller.dart';

/// A search bar widget for terminal search functionality.
class TerminalSearchBar extends StatefulWidget {
  const TerminalSearchBar({
    super.key,
    required this.controller,
    this.onClose,
    this.autoFocus = true,
    this.searchBackgroundColor,
    this.searchBorderColor,
  });

  final TerminalController controller;
  final VoidCallback? onClose;
  final bool autoFocus;

  /// Custom background color for the search bar.
  /// If not provided, defaults to theme-dependent colors.
  final Color? searchBackgroundColor;

  /// Custom border color for the search bar.
  /// If not provided, defaults to theme-dependent colors.
  final Color? searchBorderColor;

  @override
  State<TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<TerminalSearchBar> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.searchPattern ?? '');
    _focusNode = FocusNode();

    _textController.addListener(_onTextChanged);

    widget.controller.addListener(_onControllerChanged);

    // Auto focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onTextChanged() {
    widget.controller.search(_textController.text);
  }

  void _onControllerChanged() {
    // Sync text if changed externally
    if (_textController.text != (widget.controller.searchPattern ?? '')) {
      _textController.text = widget.controller.searchPattern ?? '';
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Enter - search next
        if (HardwareKeyboard.instance.isShiftPressed) {
          widget.controller.searchPrevious();
        } else {
          widget.controller.searchNext();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.controller.searchPrevious();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.controller.searchNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use custom colors or fall back to theme-dependent defaults
    final backgroundColor = widget.searchBackgroundColor ??
        (isDark ? const Color(0xFF252526) : Colors.white);
    final borderColor = widget.searchBorderColor ??
        (isDark ? const Color(0xFF3C3C3C) : Colors.grey.shade300);
    final inputTextColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          children: [
            // Search input
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontSize: 14,
                    color: inputTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Result count
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final hasResults = widget.controller.hasSearchResults;
                final current = widget.controller.currentSearchIndex;
                final total = widget.controller.searchResultCount;

                if (!widget.controller.isSearching || _textController.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  width: 70,
                  child: Text(
                    hasResults ? '${current + 1}/$total' : 'No results',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasResults
                          ? inputTextColor
                          : (isDark ? Colors.orange : Colors.orange.shade700),
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            const SizedBox(width: 8),

            // Previous button - min 44x44 for touch targets
            Semantics(
              label: 'Previous search result',
              button: true,
              child: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_up,
                  size: 20,
                  color: iconColor,
                ),
                onPressed: widget.controller.searchPrevious,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Previous match (Shift+F3)',
              ),
            ),

            // Next button - min 44x44 for touch targets
            Semantics(
              label: 'Next search result',
              button: true,
              child: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: iconColor,
                ),
                onPressed: widget.controller.searchNext,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Next match (F3)',
              ),
            ),

            const SizedBox(width: 4),

            // Options menu
            Semantics(
              label: 'Search options',
              button: true,
              child: PopupMenuButton<SearchOption>(
                icon: Icon(
                  Icons.tune,
                  size: 20,
                  color: iconColor,
                ),
                tooltip: 'Search options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onSelected: (option) {
                  widget.controller.toggleSearchOption(option);
                },
                itemBuilder: (context) => [
                  _buildOptionMenuItem(
                    SearchOption.caseSensitive,
                    'Match Case',
                    'Aa',
                    widget.controller,
                  ),
                  _buildOptionMenuItem(
                    SearchOption.regex,
                    'Use Regular Expression',
                    '.*',
                    widget.controller,
                  ),
                  _buildOptionMenuItem(
                    SearchOption.wholeWord,
                    'Match Whole Word',
                    'word',
                    widget.controller,
                  ),
                ],
              ),
            ),

            // Close button - min 44x44 for touch targets
            Semantics(
              label: 'Close search',
              button: true,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: iconColor,
                ),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Close search (Escape)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SearchOption> _buildOptionMenuItem(
    SearchOption option,
    String label,
    String shortcut,
    TerminalController controller,
  ) {
    final isSelected = controller.searchOptions.contains(option);

    return PopupMenuItem<SearchOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: isSelected ? Colors.blue : null,
          ),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            shortcut,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
