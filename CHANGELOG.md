## [1.5.0] - 2026-06-24

### Bug Fixes

- **Fix htop-style apps showing spurious underlines on letters**: `_flushRun` paragraph cache key was missing the `underline` flag, causing cache collisions between underlined and non-underlined runs with identical text/color/weight/italic — `lib/src/ui/painter.dart`
- **Remove dead code**: `paintCellUnderline` had an unreachable `CellAttr.underlineStyleSingle` switch case (single underline is handled by Flutter `TextStyle` via `_flushRun`) — `lib/src/ui/painter.dart`

## [1.4.2] - 2026-06-24

### Performance

- **Coalesce notifications**: `Terminal.write()` defers `notifyListeners()` via microtask, coalescing rapid data chunks (e.g. `tail -f`) into a single notification pass — `lib/src/terminal.dart`
- **Coalesce layout/paint**: `RenderTerminal._onTerminalChange` uses `addPostFrameCallback` to merge multiple content changes within one frame into a single layout/paint pass — `lib/src/ui/render.dart`
- **Batch drawParagraph calls**: `TerminalPainter.paintLine` now does two-pass rendering (background per-cell, foreground batched by style-run) so consecutive same-style characters produce one `drawParagraph` instead of one-per-cell — `lib/src/ui/painter.dart`
- **Skip unnecessary layout**: `_onTerminalChange` calls `markNeedsPaint()` instead of `markNeedsLayout()` when not scrolled to bottom; `_onControllerUpdate` uses `markNeedsPaint()` since selection/search changes are visual-only — `lib/src/ui/render.dart`

## [1.4.1] - 2026-06-23

### Bug Fixes
- Fix paste shortcut (Cmd+V/Ctrl+V) broken on Linux/Windows — `PasteTextIntent` handler now reads clipboard directly instead of depending on macOS-only IME path
- Fix macOS IME paste duplicate: skip IME text when shortcut already handled paste

## [1.4.0] - 2026-06-22

### Bug Fixes
- Fix Kitty Graphics Protocol chunked transmission: `m=1` (non-final) chunks now properly parse and accumulate payload data instead of leaving raw base64 in the parser queue
- Fix X10 mouse protocol row coordinate encoding: remove extra `+1` that caused CellOffset y to be reported as 2-based instead of 1-based
- Fix tertiary (middle) mouse button gesture: `onTertiaryTapUp` was using `TerminalMouseButton.right` instead of `.middle`, inconsistent with `onTertiaryTapDown`
- Fix `KeyboardVisibilty` class name typo: renamed to `KeyboardVisibility` (missing 'i')

### Code Quality
- Upgrade `kitty_protocol` dependency from `^1.2.3` to `^1.3.1`
- Fix unused local variable warnings in `keyboard_visibility_test.dart`

### Tests
- Add APC parser tests: `m=1` with payload verifies dataChunk without commandEnd (2 tests)

## [1.3.0] - 2026-06-22

### Bug Fixes
- Fix Ctrl+letter combinations (Ctrl+U/A/E/C, etc.) being silently dropped in Kitty Keyboard Protocol mode — sends raw ASCII control characters for shell backward compatibility
- Fix Kitty Keyboard Protocol push/pop flag stack: `CSI > + n u` and `CSI > - u` sequences now correctly parse intermediate bytes (`+`/`-`) instead of stripping them
- Fix `_KittyKeyboardEncoderWrapper.flags` returning default values (wrapper now delegates `flags` to the inner encoder via super constructor)
- Fix `_updateKittyKeyboardEncoder` lazy init skipping the first push/pop call
- Fix KeyUp events sending empty strings to `onOutput` when Kitty encoder cannot encode the key
- Fix modifier+letter keys (Alt+A, Meta+U, etc.) being dropped when Kitty encoder returns empty — fall back to standard keytab input
- Fix copy/paste/select-all shortcuts not working in Kitty mode (checked before Kitty dispatch now)
- Fix unknown CSI intermediate bytes in `>+` sequences accidentally triggering `setKittyMode`

### Code Quality
- Refactor `_handleKeyEvent` (180+ lines) into clean dispatcher: extract `_handleKittyKeyEvent` and `_tryKeyInput` helper, eliminating 3 duplicate keyInput patterns
- Add `.pubignore` to exclude test, example, media, docs from published package

### Documentation
- Update AGENTS.md with comprehensive Kitty Keyboard Protocol architecture, test commands, and known limitations
- Fix README: correct Flutter version requirement to `>=3.19.0`, fix screenshot URLs pointing to old `xterm.dart` repo, remove misleading "What's new in 3.0.0" section from fork
- Fix README: merge duplicated "Key Features" and "Features" sections

### Tests
- Add CSI parser tests: push/pop with `+`/`-` intermediate bytes (5 tests)
- Add Terminal integration tests: push/pop flag stack, Ctrl+letter control codes via keyInput (9 tests, all 26 Ctrl+A–Z verified)

## [1.2.0] - 2025-07-11

### Bug Fixes
- Fix `_evictIfNeeded` memory eviction loop: while condition now checks future memory state (`current + required > target`) instead of current memory, preventing leaked memory under 50% threshold
- Fix `OverlayPortal.targetsRootOverlay` deprecation: replace with `OverlayPortal` (Flutter 3.33+)
- Fix `handleTextSizeQuery` dead code: remove unreachable `command == 133` branch

### Code Quality
- Migrate lint config from `package:lints/recommended.yaml` to `package:flutter_lints/flutter.yaml` (+30 Flutter-specific rules)
- Fix 12 info-level lint issues: `unnecessary_library_name`, `unintended_html_in_doc_comment`, `avoid_print`, `sort_child_properties_last`, `prefer_const_constructors_in_immutables`, `sized_box_for_whitespace`, `avoid_unnecessary_containers`
- Add DCS (Kitty Remote Control), text size query, and shell integration test coverage (+19 tests)
- Add `_evictIfNeeded` LRU eviction edge-case tests: count limit, memory threshold, 50% target stop, LRU ordering (+4 tests)
- Add `pointer_input_test.dart` completing 100% test coverage for all 73 `lib/src/` source files (+14 tests)
- Fix `analysis_options.yaml`: remove stale `deprecated_member_use: ignore`
- Sync `AGENTS.md` CI command list with `.github/workflows/dart-ci.yml`

### Bug Fixes
- Fix SGR 38/48/58 malformed color recovery: incomplete color spec no longer causes subsequent params to be misparsed
- Add CSI params size limit (256) to prevent OOM from malformed sequences
- Remove dead code `case 10061000` in DECSET handler

## [1.1.10] - 2026-05-18

### Bug Fixes
- Fix `Future.delayed` zombie callback in graphics manager test: replace with `tester.pump`
- Fix `gesture_detector.dart` double-tap timer disposal on widget dispose

### Code Quality
- Fix test isolation: eliminate async callback leaks across test files
- Add `run_test.sh` unified test runner with smoke/full/golden/fuzz modes
- Add `Makefile` with convenient targets: `make test`, `make smoke`, `make golden`, `make fuzz`
- Add gesture detector timer cleanup verification (already had `dispose`, confirmed correct)

## [1.1.9] - 2026-05-15

### Bug Fixes
- Fix example imports: replace removed `xterm.dart` with `kterm.dart` across 6 files
- Fix `withOpacity` deprecation: migrate to `withValues(alpha:)` (Flutter 3.27+)

### Code Quality
- Add `publish_to: 'none'` to suppress invalid_dependency warning (zmodem_lbp git dep)
- Add ZModem protocol decoding tests: ZMPHDR frame type parsing, file info header (29 new assertions across 7 tests)
- Clean up `AGENTS.md` with accurate test commands

## [1.1.8] - 2026-05-13
