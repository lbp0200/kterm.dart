# AGENTS.md — kterm

A Flutter terminal emulator package (mobile + desktop). Published as `kterm` on pub.dev.

## Commands

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze lib/ --no-fatal-infos   # CI scope: lib/ only, not --fatal-infos
# Tests are run in groups by CI:
flutter test test/kitty_*.dart
flutter test test/src/core/
flutter test test/src/utils/
flutter test test/                  # local: all at once is fine
```

## Architecture

- **Core** (`lib/src/core/`) — frontend-independent terminal state machine (buffer, escape parser, input, mouse, cell data)
- **UI** (`lib/src/ui/`) — Flutter widgets: TerminalView, TerminalController, painter, render, search bar, themes
- **Exports**: `core.dart` (core-only), `ui.dart` (Flutter widgets), `kterm.dart` (both + zmodem), `utils.dart` (debug helpers)
- **Entrypoints**: `lib/src/terminal.dart` (Terminal, implements EscapeHandler + TerminalState), `lib/src/terminal_view.dart` (TerminalView widget), `lib/src/ui/controller.dart` (TerminalController)
- **Patterns**: Observable mixin for reactivity; IndexAwareCircularBuffer for scrollback; custom Painter + RenderBox for text grid

## Package dependencies

- `zmodem_lbp` — forked git dep (`pub.dev/packages/zmodem` v0.0.6 with 2 bugfixes: ZFIN frame handling + wrong LF byte). Import as `package:zmodem_lbp/`.
- `kitty_protocol` — upstream Kitty keyboard/graphics protocol bugs should be reported there

## Release

1. Bump version in `pubspec.yaml`, add entry to `CHANGELOG.md` (top, format `## [x.x.x] - YYYY-MM-DD`)
2. Commit, tag (`git tag v{x.x.x}`), push tag — CI publishes to pub.dev automatically
3. Failure modes: missing CHANGELOG entry, analyze errors in `example/` or `script/` (CI only checks `lib/`)
