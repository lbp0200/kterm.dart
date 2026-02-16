# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xterm.dart is a fast, fully-featured terminal emulator for Flutter applications supporting mobile and desktop platforms. The terminal core is frontend-independent, with a separate Flutter UI layer.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Verify formatting
dart format --set-exit-if-changed .

# Analyze with fatal infos
flutter analyze --fatal-infos

# Run tests with coverage
flutter test --coverage

# Run a single test file
flutter test test/path/to/file_test.dart
```

## Architecture

**Core/UI Separation:** The terminal core (`lib/src/core/`) is frontend-independent. The Flutter UI layer is in `lib/src/ui/`. Exports are organized via `core.dart`, `ui.dart`, and `xterm.dart`.

**Main Classes:**
- `Terminal` (`lib/src/terminal.dart`) - Implements `TerminalState` and `EscapeHandler`, manages buffers, parses escape sequences, handles input
- `TerminalView` - Flutter widget for rendering the terminal
- `TerminalController` - Flutter controller for TerminalView

**Key Components:**
- `lib/src/core/buffer/` - Buffer management (scrollback, lines, cells)
- `lib/src/core/escape/` - ANSI escape sequence parsing
- `lib/src/core/input/` - Keyboard input handling
- `lib/src/core/mouse/` - Mouse input handling
- `lib/src/ui/painter.dart` and `lib/src/ui/render.dart` - Rendering logic

**Patterns:**
- Uses `Observable` mixin for state notifications
- Callbacks: `onBell`, `onTitleChange`, `onOutput`, `onResize`
- Buffer uses `IndexAwareCircularBuffer<BufferLine>` for scrollback
