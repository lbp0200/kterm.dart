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
