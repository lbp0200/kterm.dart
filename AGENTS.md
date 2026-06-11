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
- `kitty_protocol: ^1.2.3` — upstream Kitty keyboard/graphics protocol; report bugs there
- `image: ^4.2.0` — image decoding for Kitty Graphics Protocol
- `overlay_support: ^2.0.0` — overlay popups

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

(Add project-specific notes here.)
