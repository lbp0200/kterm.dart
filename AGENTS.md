# AGENTS.md — kterm

A Flutter terminal emulator package (mobile + desktop). Published as `kterm` on pub.dev.

## Commands

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze lib/   # CI scope: no --fatal-infos needed — `flutter analyze lib/ --no-fatal-infos`

# Test runner (Makefile + run_test.sh):
make test            # full suite: flutter test (randomized order)
make smoke           # pure-Dart smoke tests (no Flutter SDK needed)
make golden          # golden file tests (test/src/terminal_view_test.dart)
make fuzz [N]        # random-seed re-runs (default 5)
make unit FILE=...   # run a single test file

# Direct test commands:
flutter test test/kitty_*.dart                      # CI: kitty protocol tests
flutter test test/src/core/                          # CI: core tests
flutter test test/src/utils/                         # CI: utils tests
flutter test test/src/terminal_test.dart             # CI: terminal integration
flutter test test/src/terminal_paste_test.dart       # CI: paste handling
flutter test test/src/zmodem_test.dart               # CI: ZModem mux tests
flutter test test/kterm_test.dart test/sequence_test.dart test/simple_ext_test.dart test/src/terminal_input_notify_test.dart  # CI: misc
# Not run in CI (golden / local-only):
flutter test test/src/terminal_view_test.dart        # golden/snapshot tests
flutter test test/src/suggestion_test.dart           # suggestion overlay widget tests
dart test test/src/utils/byte_consumer_test.dart     # pure-Dart smoke (4 files, see run_test.sh)
dart test test/src/utils/debugger_test.dart          # pure-Dart smoke
dart test test/src/utils/debugger_extended_test.dart # pure-Dart smoke
dart test test/src/utils/lookup_table_test.dart      # pure-Dart smoke
```

## Architecture

- **`lib/src/base/`** — Foundation mixins: `Observable` (listener pattern), `Event`, `Disposable`
- **`lib/src/core/`** — Frontend-independent terminal state machine:
  - `buffer/` — IndexAwareCircularBuffer scrollback, Line, Segment, CellOffset, Range, RangeBlock, RangeLine, CellFlags
  - `escape/` — Escape sequence parser (40298B), handler interface, emitter
  - `input/` — Input handler, key definitions, keytab system (record/parse/token/qt_keyname/default)
  - `mouse/` — Button, mode, handler, reporter
  - `cell.dart`, `cursor.dart`, `color.dart`, `charset.dart`, `tabs.dart`, `state.dart`, `platform.dart`, `reflow.dart`, `graphics_manager.dart`, `snapshot.dart`
- **`lib/src/ui/`** — Flutter widgets:
  - `controller.dart` — TerminalController (ChangeNotifier), search options
  - `painter.dart` — Custom terminal grid painter
  - `render.dart` — RenderBox for text grid rendering
  - `search_bar.dart` — Built-in search (regex, case, whole word)
  - `gesture/` — Gesture detector + handler
  - `shortcut/` — Shortcut actions
  - Also: themes, keyboard listener, infinite scroll, char metrics, input map, cursor type, selection mode, paragraph cache
- **`lib/src/terminal.dart`** — `Terminal` class (implements `EscapeHandler` + `TerminalState`, uses `Observable`)
- **`lib/src/terminal_view.dart`** — `TerminalView` widget
- **Entrypoint exports**:
  - `lib/core.dart` — core-only (no Flutter widgets)
  - `lib/ui.dart` — Flutter widgets
  - `lib/kterm.dart` — everything: core + ui + zmodem
  - `lib/zmodem.dart` — ZModem protocol support (wraps `zmodem_lbp`)
  - `lib/suggestion.dart` — `SuggestionPortal` overlay for autocomplete popups
  - `lib/utils.dart` — debug helpers

## Package dependencies

- `zmodem_lbp: ^0.0.10` — forked git dep (bugfixes: ZFIN frame handling + wrong LF byte). Import as `package:zmodem_lbp/`.
- `kitty_protocol: ^1.3.0` — upstream Kitty keyboard/graphics protocol; report bugs there
- `image: ^4.9.0` — image decoding for Kitty Graphics Protocol

## Conventions

- **Imports**: Use `package:kterm/src/...` paths (not relative imports) throughout `lib/`.
- **Testing**: Golden tests in `test/src/terminal_view_test.dart`; mockito-generated mocks in `*.mocks.dart`; pure-Dart tests use `dart test`, Flutter-dependent tests use `flutter test`.
- **Lints**: Follows `package:lints/recommended.yaml` with two overrides: `prefer_function_declarations_over_variables: false`, `prefer_conditional_assignment: false`.
- **CI**: Workflow in `.github/workflows/dart-ci.yml`. Runs `flutter analyze lib/ --no-fatal-infos` + `flutter test` on kitty_*, core, utils. On tag push, publishes to pub.dev.
- **Reactivity**: `Observable` mixin for core terminal; `ChangeNotifier` for controllers.

## Release

1. Bump version in `pubspec.yaml`, add entry to `CHANGELOG.md` (top, format `## [x.x.x] - YYYY-MM-DD`)
2. Commit, tag (`git tag v{x.x.x}`), push tag — CI publishes to pub.dev automatically
3. Failure modes: missing CHANGELOG entry, analyze errors in `example/` or `script/` (CI only checks `lib/`)
4. `.pubignore` excludes tests, examples, media, docs, scripts, .github, pubspec.lock

## Notes

### Kitty Keyboard Protocol

The Kitty keyboard protocol (`kitty_protocol: ^1.3.0`) is implemented across three layers:

- **`lib/src/core/escape/parser.dart`** — Parses `CSI > n u` (enable/disable), `CSI > + n u` (push flags), and `CSI > - u` (pop flags) from the application → terminal direction. Intermediate bytes (`+`/`-`) are stored in `_Csi.intermediates` and dispatched in `_handleKittyMode()`.

- **`lib/src/terminal.dart`** — `Terminal` owns the `_kittyFlagsStack` (list of pushed flag ints), `_kittyEncoder` (lazy-created `KittyKeyboardEncoder`), and `_kittyEncoderWrapper` (which delegates `encode()` and `flags` to the inner encoder, while fixing USB HID → Kitty keycode mapping for Enter).

- **`lib/src/terminal_view.dart`** — `TerminalViewState._handleKeyEvent()` intercepts key events when `terminal.kittyMode` is true. Key behavior:
  - `Ctrl+letter` (A-Z, pure Ctrl, no Shift/Alt): sent as raw ASCII control characters (`0x01`–`0x1A`) for shell backward compatibility.
  - `Modifier + special-key` (Shift+Enter, Ctrl+Tab, etc.): encoded via Kitty CSI u sequences.
  - `Modifier + letter` (Alt+A, Meta+U, etc.): Kitty encoder returns empty (letter keys not in keycode map), falls back to standard `keyInput`.
  - `Bare keys`: let Flutter IME handle.
  - Shortcuts (copy/paste/select-all): checked BEFORE Kitty mode so they always work.

### Kitty mode test files

```bash
flutter test test/kitty_*.dart                          # All Kitty protocol tests
flutter test test/src/core/escape/parser_test.dart       # CSI parser (incl. Kitty push/pop)
flutter test test/kitty_integration_test.dart            # Terminal integration (push/pop, Ctrl+letter)
flutter test test/kitty_keyboard_test.dart               # Encoder key encoding tests
flutter test test/kitty_flags_test.dart                  # Encoder flag behavior tests
```

### Known limitations

- `Ctrl+Space` in Kitty mode sends Kitty escape sequence `\x1b[0;5u` instead of raw NUL (`0x00`). This is per Kitty protocol spec — applications that enable Kittly protocol are expected to handle CSI u sequences.
- The `_onInsert` / IME path is Kitty-mode-agnostic (IME text always passes through directly). This is correct: Kitty protocol is a hardware keyboard protocol.
- `Alt+letter` on macOS returns null from `AltInputHandler` (macOS uses Alt for special character composition).
