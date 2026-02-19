# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

kterm is a high-performance terminal emulator engine for Flutter applications supporting mobile and desktop platforms. The terminal core is frontend-independent, with a separate Flutter UI layer.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Verify formatting
dart format --set-exit-if-changed .

# Analyze with fatal infos
flutter analyze --fatal-infos

# Run tests (requires proxy to be unset if behind firewall)
unset http_proxy https_proxy
flutter test --coverage

# Run a single test file
flutter test test/path/to/file_test.dart
```

## Architecture

**Core/UI Separation:** The terminal core (`lib/src/core/`) is frontend-independent. The Flutter UI layer is in `lib/src/ui/`. Exports are organized via `core.dart`, `ui.dart`, and `kterm.dart`.

**Main Classes:**
- `Terminal` (`lib/src/terminal.dart`) - Implements `TerminalState` and `EscapeHandler`, manages buffers, parses escape sequences, handles input
- `TerminalView` (`lib/src/terminal_view.dart`) - Flutter widget for rendering the terminal
- `TerminalController` (`lib/src/ui/controller.dart`) - Flutter controller for TerminalView

**Key Components:**
- `lib/src/core/buffer/` - Buffer management (scrollback, lines, cells)
- `lib/src/core/escape/` - ANSI escape sequence parsing (parser.dart handles CSI, ESC, OSC sequences; handler.dart defines the interface)
- `lib/src/core/input/` - Keyboard input handling
- `lib/src/core/mouse/` - Mouse input handling
- `lib/src/core/graphics_manager.dart` - Kitty Graphics Protocol image storage and placement
- `lib/src/ui/painter.dart` and `lib/src/ui/render.dart` - Rendering logic

**Escape Sequence Handling:**
- `parser.dart` - Parses incoming escape sequences and calls handler methods
- `handler.dart` - Defines `EscapeHandler` interface with methods for each SGR, CSI, OSC sequence
- `terminal.dart` - Implements `EscapeHandler` to process parsed sequences

**Cell Data:**
- `lib/src/core/cell.dart` - CellData class stores character content, attributes (colors, flags), and image references
- `lib/src/core/buffer/line.dart` - BufferLine stores cells and cell attributes

**Kitty Graphics Protocol:**
- Uses APC G command: `\x1b_G<keys>=<value>,...;<payload>\x1b\\`
- Supports PNG (f=100), RGBA (f=32), JPEG (f=98) formats
- Images stored in GraphicsManager with LRU eviction
- Placements track position (x,y), dimensions (cells or pixels), and layering (above/below text)

**Patterns:**
- Uses `Observable` mixin for state notifications
- Callbacks: `onBell`, `onTitleChange`, `onOutput`, `onResize`
- Buffer uses `IndexAwareCircularBuffer<BufferLine>` for scrollback
- Cell image data packed as: imageId (upper 16 bits) + placementId (lower 16 bits)

## Kitty Protocol

**Reference Implementation:**
- Source code: `../KittyProtocol/`
- Documentation: `../KittyProtocol/doc/kitty/docs`

**Protocol Requirements:**
- Ensure all APC sequences are terminated with ST (`\x1b\\`).
- Payload encoding uses standard Base64 as specified in the protocol.

**Note:** If bugs are found in the Kitty Protocol implementation (keyboard/graphics), please report them so they can be fixed in the upstream `kitty_protocol` package.

## Key Implementation Patterns

**Terminal Core:**
- `Terminal` (lib/src/terminal.dart): The central state machine. Implements EscapeHandler.

**Parser:**
- `Parser` (lib/src/core/escape/parser.dart): Hardened ANSI/XTerm/Kitty parser.

**Buffer:**
- `Buffer` (lib/src/core/buffer/): Efficient scrollback via IndexAwareCircularBuffer.

**Graphics:**
- Managed by GraphicsManager, supporting Kitty Graphics Protocol (APC _G).

**Keyboard:**
- Use KittyEncoder from package:kitty_protocol.

**Reactivity:**
- Uses Observable mixin for state changes.

**Rendering:**
- Custom Painter and RenderBox for high-performance text grid rendering.

## Maintenance Notes

- **Pub Hygiene:** Keep the package lean. Refer to `.pubignore` before adding large assets.
- **Backward Compatibility:** Maintain stable API for all exported libraries.
- **Bugs:** Report protocol-level issues to kitty_protocol upstream.
