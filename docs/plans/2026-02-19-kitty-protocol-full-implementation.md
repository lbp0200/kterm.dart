# Kitty Protocol Full Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete all 19 Kitty Protocol features with full implementation, unit tests, and example demos.

**Architecture:** Add protocol handlers to Terminal class (lib/src/terminal.dart) implementing EscapeHandler interface. Each protocol area gets a dedicated handler method. GraphicsManager already handles images. Callbacks on Terminal for UI integration (onNotification, onClipboard, etc.).

**Tech Stack:** Flutter, kitty_protocol package v1.1.0, dart:typed_data for binary handling

---

## Pre-requisite: Verify Current State

**Step 1: Run existing tests to confirm baseline**

```bash
cd /Users/lbp/Projects/kterm.dart
flutter test test/kitty_*.dart --coverage
```

Expected: Most tests pass (keyboard, graphics already partially implemented)

---

## Phase 1: Core Protocol Infrastructure

### Task 1: Hyperlinks (OSC 8)

**Files:**
- Modify: `lib/src/terminal.dart` - add hyperlink support in handleOsc
- Modify: `lib/src/core/cell.dart` - add hyperlinkId field to CellData
- Modify: `lib/src/core/buffer/line.dart` - propagate hyperlink to cells
- Test: `test/kitty_hyperlinks_test.dart` (create)
- Demo: `example/lib/main.dart` - add "Test Hyperlink" button

**Step 1: Write the failing test**

```dart
// test/kitty_hyperlinks_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 8 hyperlink start', () {
    terminal.write('\x1b]8;id=example;https://dart.dev\x1b\\');
    // Check that current cell has hyperlink
    final cell = terminal.buffer.activeBuffer.lines[0].cells[0];
    expect(cell.hyperlinkId, isNotNull);
  });

  test('OSC 8 hyperlink end', () {
    terminal.write('\x1b]8;;\x1b\\');
    final cell = terminal.buffer.activeBuffer.lines[0].cells[0];
    expect(cell.hyperlinkId, isNull);
  });

  test('hyperlink with text', () {
    terminal.write('\x1b]8;;https://dart.dev\x1b\\Dart');
    terminal.write('\x1b]8;;\x1b\\');
    expect(terminal.buffer.activeBuffer.lines[0].cells[0].hyperlinkId,
           equals(terminal.buffer.activeBuffer.lines[0].cells[3].hyperlinkId));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_hyperlinks_test.dart
```

Expected: FAIL - hyperlinkId field doesn't exist

**Step 3: Write minimal implementation**

Add to `lib/src/core/cell.dart`:
```dart
class CellData {
  // ... existing fields
  int? hyperlinkId;  // Add this
}
```

Add handler in `lib/src/terminal.dart`:
```dart
@override
void handleOsc(int command, List<String> args, int? callbackId) {
  switch (command) {
    case 8: // Hyperlinks
      _handleHyperlink(args);
      break;
    // ... existing cases
  }
}

void _handleHyperlink(List<String> args) {
  if (args.isEmpty) return;
  final uri = args[0];
  if (uri.isEmpty) {
    // End hyperlink
    _currentHyperlinkId = null;
  } else {
    // Parse id=scheme;uri or just uri
    String? id;
    String actualUri = uri;
    if (uri.contains(';')) {
      final parts = uri.split(';');
      for (var part in parts) {
        if (part.startsWith('id=')) {
          id = part.substring(3);
        } else if (part.isNotEmpty) {
          actualUri = part;
        }
      }
    }
    _currentHyperlinkId = _registerHyperlink(actualUri, id);
  }
}

int? _currentHyperlinkId;
final _hyperlinks = <int, _HyperlinkEntry>{};
int _hyperlinkIdCounter = 1;

int _registerHyperlink(String uri, String? id) {
  final key = id ?? uri;
  for (var entry in _hyperlinks.entries) {
    if (entry.value.uri == uri && entry.value.id == key) {
      return entry.key;
    }
  }
  final newId = _hyperlinkIdCounter++;
  _hyperlinks[newId] = _HyperlinkEntry(uri, key);
  return newId;
}

class _HyperlinkEntry {
  final String uri;
  final String id;
  _HyperlinkEntry(this.uri, this.id);
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_hyperlinks_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/core/cell.dart lib/src/terminal.dart test/kitty_hyperlinks_test.dart
git commit -m "feat: implement OSC 8 hyperlinks protocol

- Add hyperlinkId to CellData
- Implement OSC 8 start/end hyperlink sequences
- Add hyperlink registry for URI dedup

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Wide Gamut Colors (SGR 38/48)

**Files:**
- Modify: `lib/src/core/cell.dart` - extend color handling for wide gamut
- Modify: `lib/src/terminal.dart` - parse SGR 38:2/48:2 (RGB) and 38:5/48:5 (256+)
- Test: `test/kitty_colors_test.dart` (create)
- Demo: `example/lib/main.dart` - add color picker demo

**Step 1: Write the failing test**

```dart
// test/kitty_colors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('SGR 38:2 RGB true color', () {
    terminal.write('\x1b[38:2:255:128:0m'); // Orange RGB
    terminal.write('X');
    final cell = terminal.buffer.activeBuffer.lines[0].cells[0];
    expect(cell.attributes.foreground.r, equals(255));
    expect(cell.attributes.foreground.g, equals(128));
    expect(cell.attributes.foreground.b, equals(0));
  });

  test('SGR 48:2 RGB true color background', () {
    terminal.write('\x1b[48:2:0:0:255m'); // Blue background
    terminal.write('X');
    final cell = terminal.buffer.activeBuffer.lines[0].cells[0];
    expect(cell.attributes.background.r, equals(0));
    expect(cell.attributes.background.g, equals(0));
    expect(cell.attributes.background.b, equals(255));
  });

  test('SGR 38:5 256+ colors', () {
    terminal.write('\x1b[38:5:196m'); // Bright red
    terminal.write('X');
    final cell = terminal.buffer.activeBuffer.lines[0].cells[0];
    expect(cell.attributes.foreground.colorSpace, equals(ColorSpace.indexed256));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_colors_test.dart
```

Expected: FAIL - SGR 38:2 not parsed

**Step 3: Write minimal implementation**

Add color classes to `lib/src/core/cell.dart`:
```dart
enum ColorSpace { default_, indexed256, rgb }

class TerminalColor {
  final ColorSpace space;
  final int r, g, b;
  final int? index;

  const TerminalColor.default_()
      : space = ColorSpace.default_,
        r = 0,
        g = 0,
        b = 0,
        index = null;

  const TerminalColor.indexed256(this.index)
      : space = ColorSpace.indexed256,
        r = 0,
        g = 0,
        b = 0;

  const TerminalColor.rgb(this.r, this.g, this.b) : space = ColorSpace.rgb, index = null;
}
```

Update CellAttributes to use TerminalColor.

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_colors_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/core/cell.dart lib/src/terminal.dart test/kitty_colors_test.dart
git commit -m "feat: implement wide gamut colors (SGR 38:2, 48:2, 38:5)

- Add ColorSpace enum and TerminalColor class
- Support RGB true color and 256+ indexed colors
- Parse SGR colormode:colorspace:params sequences

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Bracketed Paste Mode (SGR 2004)

**Files:**
- Modify: `lib/src/terminal.dart` - add bracketed paste state machine
- Modify: `lib/src/ui/controller.dart` - integrate with text input
- Test: `test/kitty_paste_test.dart` (create)
- Demo: Already in example via TerminalView

**Step 1: Write the failing test**

```dart
// test/kitty_paste_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('enable bracketed paste mode', () {
    terminal.write('\x1b[?2004h');
    expect(terminal.bracketedPasteMode, isTrue);
  });

  test('disable bracketed paste mode', () {
    terminal.write('\x1b[?2004h');
    terminal.write('\x1b[?2004l');
    expect(terminal.bracketedPasteMode, isFalse);
  });

  test('paste wrapped in escape sequences', () {
    terminal.write('\x1b[?2004h');
    terminal.write('\x1b[200~paste text\x1b[201~');
    // Should receive paste text without escape sequences
    expect(terminal.buffer.activeBuffer.lines[0].cells[0].char, equals('p'));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_paste_test.dart
```

Expected: FAIL - bracketedPasteMode not defined

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
bool _bracketedPasteMode = false;
bool get bracketedPasteMode => _bracketedPasteMode;

// In handleCsi or setMode:
case '?2004':
  if (val == 1 || val == 'h') _bracketedPasteMode = true;
  if (val == 0 || val == 'l') _bracketedPasteMode = false;

// Track paste start/end:
// On \x1b[200~, set _inPaste = true
// On \x1b[201~, set _inPaste = false, fire onPaste with collected text
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_paste_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_paste_test.dart
git commit -m "feat: implement bracketed paste mode (SGR 2004)

- Track paste mode state via CSI ?2004h/l
- Wrap pasted text with 200~/201~ delimiters
- Add onPaste callback for UI integration

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Mouse Tracking Enhancements (SGR 1004/1006)

**Files:**
- Modify: `lib/src/core/mouse/mouse.dart` - add SGR 1004/1006 support
- Test: `test/kitty_mouse_test.dart` (create)
- Demo: `example/lib/main.dart` - add mouse tracking toggle

**Step 1: Write the failing test**

```dart
// test/kitty_mouse_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('SGR 1004: enable focus tracking', () {
    terminal.write('\x1b[?1004h');
    expect(terminal.focusTrackingEnabled, isTrue);
  });

  test('SGR 1006: extended mouse encoding', () {
    terminal.write('\x1b[?1006h');
    expect(terminal.extendedMouseEncoding, isTrue);
  });

  test('mouse event with SGR 1006 format', () {
    terminal.write('\x1b[?1006h');
    terminal.write('\x1b[<0;10;20M'); // Button 0 at x=10, y=20
    // Should parse to mouse event
    expect(terminal.lastMouseEvent?.x, equals(9)); // 1-indexed to 0-indexed
    expect(terminal.lastMouseEvent?.y, equals(19));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_mouse_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/core/mouse/mouse.dart`:
```dart
bool _focusTrackingEnabled = false;
bool get focusTrackingEnabled => _focusTrackingEnabled;

bool _extendedMouseEncoding = false;
bool get extendedMouseEncoding => _extendedMouseEncoding;

// Parse SGR 1004/1006 in setMode
// For 1006, parse \x1b[<button;x;yM and \x1b[<button;x;ym
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_mouse_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/core/mouse/mouse.dart test/kitty_mouse_test.dart
git commit -m "feat: implement SGR 1004 focus tracking and SGR 1006 extended mouse

- Add SGR 1004 focus event tracking
- Add SGR 1006 extended mouse encoding format
- Parse button;x;y format for precise mouse events

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Styled Underlines (CSI 4:3)

**Files:**
- Modify: `lib/src/core/cell.dart` - add underlineStyle to CellAttributes
- Modify: `lib/src/terminal.dart` - parse CSI 4:3 for underline styles
- Test: `test/kitty_underline_test.dart` (create)
- Demo: `example/lib/main.dart` - show underline styles

**Step 1: Write the failing test**

```dart
// test/kitty_underline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('CSI 4:0 no underline', () {
    terminal.write('\x1b[4:0m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.none));
  });

  test('CSI 4:1 single underline', () {
    terminal.write('\x1b[4:1m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.single));
  });

  test('CSI 4:3 double underline', () {
    terminal.write('\x1b[4:3m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.double));
  });

  test('CSI 4:4 curly underline', () {
    terminal.write('\x1b[4:4m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.curly));
  });

  test('CSI 4:5 dotted underline', () {
    terminal.write('\x1b[4:5m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.dotted));
  });

  test('CSI 4:6 dashed underline', () {
    terminal.write('\x1b[4:6m');
    final attr = terminal.currentAttributes;
    expect(attr.underlineStyle, equals(UnderlineStyle.dashed));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_underline_test.dart
```

Expected: FAIL - underlineStyle doesn't exist

**Step 3: Write minimal implementation**

Add to `lib/src/core/cell.dart`:
```dart
enum UnderlineStyle { none, single, double, curly, dotted, dashed }

class CellAttributes {
  // ... existing fields
  UnderlineStyle underlineStyle = UnderlineStyle.none;
  // ... existing fields
}
```

Parse in `lib/src/terminal.dart` SGR handler.

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_underline_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/core/cell.dart lib/src/terminal.dart test/kitty_underline_test.dart
git commit -m "feat: implement styled underlines (CSI 4:n)

- Add UnderlineStyle enum: none, single, double, curly, dotted, dashed
- Parse CSI 4:0-6 for underline styling
- Store in CellAttributes for rendering

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Pointer Shapes (OSC 22)

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 22 pointer shape handler
- Add: `lib/src/core/cursor.dart` - add pointerShape field
- Test: `test/kitty_pointer_test.dart` (create)
- Demo: `example/lib/main.dart` - show pointer shape changes

**Step 1: Write the failing test**

```dart
// test/kitty_pointer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 22 set pointer shape', () {
    terminal.write('\x1b]22;pointer\x1b\\');
    expect(terminal.pointerShape, equals('pointer'));
  });

  test('OSC 22 query pointer shape', () {
    terminal.write('\x1b]22;?\x1b\\');
    // Should output OSC 22;cursor_type;num
    expect(terminal.lastOutput, contains('\x1b]22;'));
  });

  test('OSC 22 clear pointer shape', () {
    terminal.write('\x1b]22;pointer\x1b\\');
    terminal.write('\x1b]22;\x1b\\');
    expect(terminal.pointerShape, isNull);
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_pointer_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
String? _pointerShape;

String? get pointerShape => _pointerShape;

// In handleOsc:
case 22: // Pointer shape
  if (args.isEmpty) break;
  if (args[0] == '?') {
    // Query - emit response
    _emit('\x1b]22;${_pointerShape ?? "default"}\x1b\\');
  } else if (args[0].isEmpty) {
    _pointerShape = null;
  } else {
    _pointerShape = args[0];
    onPointerShapeChange?.call(_pointerShape!);
  }
  break;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_pointer_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_pointer_test.dart
git commit -m "feat: implement OSC 22 pointer shape protocol

- Handle OSC 22 to set/query pointer shapes
- Add onPointerShapeChange callback for UI
- Support common shapes: pointer, text, crosshair, etc.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 2: Advanced Features

### Task 7: Clipboard (OSC 52 basic + OSC 5522 extended)

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 52/5522 handlers
- Modify: `lib/src/ui/controller.dart` - integrate with system clipboard
- Test: `test/kitty_clipboard_test.dart` (create)
- Demo: `example/lib/main.dart` - copy/paste buttons

**Step 1: Write the failing test**

```dart
// test/kitty_clipboard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 52 get clipboard', () {
    // OSC 52 ; ? ; base64
    terminal.write('\x1b]52;c;?\x1b\\');
    // Should query clipboard
    expect(terminal.clipboardQueryIssued, isTrue);
  });

  test('OSC 52 set clipboard', () {
    // OSC 52 ; c ; base64("hello")
    terminal.write('\x1b]52;c;aGVsbG8=\x1b\\');
    expect(terminal.lastClipboardSet, equals('hello'));
  });

  test('OSC 5522 extended clipboard', () {
    terminal.write('\x1b]5522;sync;start\x1b\\');
    expect(terminal.extendedClipboardEnabled, isTrue);
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_clipboard_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
bool _clipboardQueryIssued = false;
bool get clipboardQueryIssued => _clipboardQueryIssued;

String? _lastClipboardSet;
String? get lastClipboardSet => _lastClipboardSet;

bool _extendedClipboardEnabled = false;
bool get extendedClipboardEnabled => _extendedClipboardEnabled;

// In handleOsc:
case 52: // Clipboard
  _handleClipboard(args);
  break;
case 5522: // Extended clipboard
  _handleExtendedClipboard(args);
  break;

void _handleClipboard(List<String> args) {
  if (args.length < 2) return;
  final target = args[0]; // c=clipboard, p=primary, etc.
  final data = args[1];

  if (data == '?') {
    _clipboardQueryIssued = true;
    onClipboardRead?.call(target);
  } else {
    // Decode base64 and set clipboard
    final decoded = _base64Decode(data);
    _lastClipboardSet = decoded;
    onClipboardWrite?.call(decoded, target);
  }
}

void _handleExtendedClipboard(List<String> args) {
  if (args.isEmpty) return;
  final cmd = args[0];
  if (cmd == 'sync' && args.length > 1) {
    final action = args[1];
    if (action == 'start') {
      _extendedClipboardEnabled = true;
    }
  }
}
```

Add callbacks:
```dart
void Function(String target)? onClipboardRead;
void Function(String data, String target)? onClipboardWrite;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_clipboard_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_clipboard_test.dart
git commit -m "feat: implement clipboard protocol (OSC 52, OSC 5522)

- OSC 52: get/set clipboard with base64 encoding
- OSC 5522: extended clipboard sync
- Add onClipboardRead/Write callbacks for system integration

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 8: Desktop Notifications (OSC 99 + OSC 777)

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 99/777 handlers
- Test: `test/kitty_notifications_test.dart` (create)
- Demo: `example/lib/main.dart` - notification demo button

**Step 1: Write the failing test**

```dart
// test/kitty_notifications_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 99 send notification', () {
    terminal.write('\x1b]99;title;body\x1b\\');
    expect(terminal.lastNotification?.title, equals('title'));
    expect(terminal.lastNotification?.body, equals('body'));
  });

  test('OSC 777 notification query', () {
    terminal.write('\x1b]777;notify;?\x1b\\');
    // Should respond with capability
    expect(terminal.lastOutput, contains('\x1b]777;notify;'));
  });

  test('OSC 777 notification show', () {
    terminal.write('\x1b]777;notify;title\x1b\\');
    expect(terminal.lastNotification?.title, equals('title'));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_notifications_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
class Notification {
  final String? title;
  final String? body;
  final String? icon;
  final int? id;
  Notification({this.title, this.body, this.icon, this.id});
}

Notification? _lastNotification;
Notification? get lastNotification => _lastNotification;

// In handleOsc:
case 99: // Desktop notifications
case 777: // Alternate notification command
  _handleNotification(args, command);
  break;

void _handleNotification(List<String> args, int command) {
  if (args.isEmpty) return;

  String? title;
  String? body;

  if (command == 99) {
    // OSC 99;title;body
    title = args.isNotEmpty ? args[0] : null;
    body = args.length > 1 ? args[1] : null;
  } else {
    // OSC 777;notify;title;body
    if (args[0] == 'notify') {
      title = args.length > 1 ? args[1] : null;
      body = args.length > 2 ? args[2] : null;
    }
  }

  _lastNotification = Notification(title: title, body: body);
  onNotification?.call(_lastNotification!);
}

// Callback
void Function(Notification)? onNotification;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_notifications_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_notifications_test.dart
git commit -m "feat: implement desktop notifications (OSC 99, OSC 777)

- Handle OSC 99 title;body notifications
- Handle OSC 777;notify;title;body format
- Add onNotification callback for system notification APIs

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 9: Text Sizing Protocol

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 133/10/110/111 handlers for text sizing
- Test: `test/kitty_text_sizing_test.dart` (create)
- Demo: `example/lib/main.dart` - text size adjustment

**Step 1: Write the failing test**

```dart
// test/kitty_text_sizing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 10 font size query', () {
    terminal.write('\x1b]10;?\x1b\\');
    expect(terminal.lastOutput, contains('\x1b]10;'));
  });

  test('OSC 10 set font size', () {
    terminal.write('\x1b]10;14\x1b\\');
    expect(terminal.fontSize, equals(14));
  });

  test('OSC 133 font family query', () {
    terminal.write('\x1b]133;?\x1b\\');
    expect(terminal.lastOutput, contains('\x1b]133;'));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_text_sizing_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
double _fontSize = 12.0;
double get fontSize => _fontSize;

String? _fontFamily;
String? get fontFamily => _fontFamily;

// In handleOsc:
case 10: // Font size
  _handleTextSize(args, 10);
  break;
case 133: // Font family
  _handleTextSize(args, 133);
  break;

void _handleTextSize(List<String> args, int command) {
  if (args.isEmpty) return;
  final value = args[0];

  if (value == '?') {
    // Query
    if (command == 10) {
      _emit('\x1b]10;${_fontSize.toInt()}\x1b\\');
    } else if (command == 133) {
      _emit('\x1b]133;${_fontFamily ?? "monospace"}\x1b\\');
    }
  } else {
    // Set
    if (command == 10) {
      _fontSize = double.tryParse(value) ?? _fontSize;
      onFontSizeChange?.call(_fontSize);
    } else if (command == 133) {
      _fontFamily = value;
      onFontFamilyChange?.call(_fontFamily!);
    }
  }
}

void Function(double)? onFontSizeChange;
void Function(String)? onFontFamilyChange;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_text_sizing_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_text_sizing_test.dart
git commit -m "feat: implement text sizing protocol (OSC 10, 133)

- OSC 10: get/set font size
- OSC 133: get/set font family
- Add onFontSizeChange/onFontFamilyChange callbacks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 10: Color Stack (OSC 30001/30101)

**Files:**
- Modify: `lib/src/terminal.dart` - add color stack handlers
- Test: `test/kitty_color_stack_test.dart` (create)
- Demo: Demo in example (background colors)

**Step 1: Write the failing test**

```dart
// test/kitty_color_stack_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 30001 push color', () {
    terminal.write('\x1b]30001;rgb:ff/00/00\x1b\\'); // Push red
    expect(terminal.colorStackDepth, equals(1));
  });

  test('OSC 30101 pop color', () {
    terminal.write('\x1b]30001;rgb:ff/00/00\x1b\\');
    terminal.write('\x1b]30101\x1b\\');
    expect(terminal.colorStackDepth, equals(0));
  });

  test('color stack saves foreground', () {
    terminal.write('\x1b[31m'); // Red fg
    terminal.write('\x1b]30001;push\x1b\\');
    terminal.write('\x1b[32m'); // Green fg
    terminal.write('\x1b]30101;pop\x1b\\');
    // Should restore to red
    expect(terminal.currentAttributes.foreground.isRed, isTrue);
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_color_stack_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
final List<CellAttributes> _colorStack = [];
int get colorStackDepth => _colorStack.length;

// In handleOsc:
case 30001: // Push color
  _handleColorStack(args, push: true);
  break;
case 30101: // Pop color
  _handleColorStack(args, push: false);
  break;

void _handleColorStack(List<String> args, {required bool push}) {
  if (push) {
    _colorStack.add(_currentAttributes.copy());
  } else {
    if (_colorStack.isNotEmpty) {
      _currentAttributes = _colorStack.removeLast();
    }
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_color_stack_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_color_stack_test.dart
git commit -m "feat: implement color stack (OSC 30001, 30101)

- OSC 30001: push current colors to stack
- OSC 30101: pop colors from stack
- Implement stack for foreground/background colors

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 11: Shell Integration (OSC 133)

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 133 prompt detection
- Test: `test/kitty_shell_integration_test.dart` (create)
- Demo: Demo in example (shell prompt markers)

**Step 1: Write the failing test**

```dart
// test/kitty_shell_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 133 A - shell started', () {
    terminal.write('\x1b]133;A\x1b\\');
    expect(terminal.shellIntegrationActive, isTrue);
  });

  test('OSC 133 D - command executed', () {
    terminal.write('\x1b]133;D\x1b\\');
    expect(terminal.lastShellEvent, equals('commandExecuted'));
  });

  test('OSC 133 P - set command', () {
    terminal.write('\x1b]133;P:dir=ls\x1b\\');
    expect(terminal.commandId, equals('ls'));
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_shell_integration_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
bool _shellIntegrationActive = false;
bool get shellIntegrationActive => _shellIntegrationActive;

String? _commandId;
String? get commandId => _commandId;

String? _lastShellEvent;

// In handleOsc:
case 133: // Shell integration
  _handleShellIntegration(args);
  break;

void _handleShellIntegration(List<String> args) {
  if (args.isEmpty) return;
  final type = args[0];

  switch (type) {
    case 'A': // Shell started
      _shellIntegrationActive = true;
      _lastShellEvent = 'shellStarted';
      onShellIntegration?.call('shellStarted');
      break;
    case 'D': // Command executed
      _lastShellEvent = 'commandExecuted';
      onShellIntegration?.call('commandExecuted');
      break;
    case 'P': // Set command id
      if (args.length > 1 && args[1].startsWith('dir=')) {
        _commandId = args[1].substring(4);
      }
      break;
  }
}

void Function(String)? onShellIntegration;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_shell_integration_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_shell_integration_test.dart
git commit -m "feat: implement shell integration (OSC 133)

- OSC 133;A: shell started
- OSC 133;D: command executed
- OSC 133;P: set command ID
- Add onShellIntegration callback

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 12: Remote Control (DCS)

**Files:**
- Modify: `lib/src/terminal.dart` - add DCS handler for remote queries
- Test: `test/kitty_remote_control_test.dart` (create)
- Demo: Demo in example (query terminal info)

**Step 1: Write the failing test**

```dart
// test/kitty_remote_control_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('DCS query terminal name', () {
    terminal.write('\x1bP+q544e\x1b\\'); // Get terminal name
    expect(terminal.lastOutput, contains('kterm'));
  });

  test('DCS query clipboard', () {
    terminal.write('\x1bP+q636c\x1b\\'); // Get clipboard
    // Should respond with clipboard content
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_remote_control_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
// In handleDcs (add method):
@override
void handleDcs(String command, List<String> args, Uint8List? data) {
  if (command.startsWith('+q')) {
    final query = command.substring(2);
    _handleRemoteQuery(query, args, data);
  }
}

void _handleRemoteQuery(String query, List<String> args, Uint8List? data) {
  String response = '';

  switch (query) {
    case '544e': // TN = Terminal Name
      response = 'kterm';
      break;
    case '636c': // cl = Clipboard
      // Query clipboard
      break;
    // Add more queries as needed
  }

  if (response.isNotEmpty) {
    _emit('\x1bP1+r$response\x1b\\');
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_remote_control_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_remote_control_test.dart
git commit -m "feat: implement remote control protocol (DCS +q)

- Handle DCS +q queries
- Support terminal name query (TN)
- Support clipboard query (cl)
- Emit responses in DCS format

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 13: File Transfer (OSC 5113)

**Files:**
- Modify: `lib/src/terminal.dart` - add OSC 5113 file transfer handler
- Test: `test/kitty_file_transfer_test.dart` (create)
- Demo: `example/lib/main.dart` - file transfer UI

**Step 1: Write the failing test**

```dart
// test/kitty_file_transfer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('OSC 5113 start file transfer', () {
    terminal.write('\x1b]5113;S|filename.txt|0|100\x1b\\');
    expect(terminal.fileTransferActive, isTrue);
  });

  test('OSC 5113 chunk transfer', () {
    terminal.write('\x1b]5113;C|0|base64data\x1b\\');
    // Should receive chunk
  });

  test('OSC 5113 complete transfer', () {
    terminal.write('\x1b]5113;E|0\x1b\\');
    expect(terminal.fileTransferActive, isFalse);
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_file_transfer_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Add to `lib/src/terminal.dart`:
```dart
bool _fileTransferActive = false;
bool get fileTransferActive => _fileTransferActive;

// In handleOsc:
case 5113: // File transfer
  _handleFileTransfer(args);
  break;

void _handleFileTransfer(List<String> args) {
  if (args.isEmpty) return;
  final type = args[0];

  switch (type) {
    case 'S': // Start
      // Parse filename, size
      _fileTransferActive = true;
      onFileTransferStart?.call(args[1], int.tryParse(args[2]) ?? 0);
      break;
    case 'C': // Chunk
      final chunk = args[2];
      onFileTransferChunk?.call(_base64Decode(chunk));
      break;
    case 'E': // End
      _fileTransferActive = false;
      onFileTransferEnd?.call(int.tryParse(args[1]) ?? 0);
      break;
  }
}

void Function(String filename, int size)? onFileTransferStart;
void Function(Uint8List data)? onFileTransferChunk;
void Function(int status)? onFileTransferEnd;
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_file_transfer_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_file_transfer_test.dart
git commit -m "feat: implement file transfer protocol (OSC 5113)

- OSC 5113;S: start transfer with filename/size
- OSC 5113;C: transfer chunk with base64 data
- OSC 5113;E: end transfer
- Add callbacks for UI integration

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 14: DEC Modes (DECSC/DECRC)

**Files:**
- Modify: `lib/src/terminal.dart` - enhance DEC private mode handling
- Test: `test/kitty_dec_modes_test.dart` (create)
- Demo: Demo in example (DEC mode toggles)

**Step 1: Write the failing test**

```dart
// test/kitty_dec_modes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  late Terminal terminal;

  setUp(() {
    terminal = Terminal(width: 80, height: 24);
  });

  test('DECSC save cursor', () {
    terminal.write('\x1b7'); // DECSC
    expect(terminal.savedCursorPosition, isNotNull);
  });

  test('DECRC restore cursor', () {
    terminal.write('\x1b7'); // Save
    terminal.write('\x1b[10;20H'); // Move
    terminal.write('\x1b8'); // Restore
    expect(terminal.cursor.x, equals(0));
    expect(terminal.cursor.y, equals(0));
  });

  test('DECSCUSR cursor style', () {
    terminal.write('\x1b[?16;0;128c'); // Block blinking
    expect(terminal.cursorStyle.blink, isTrue);
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/kitty_dec_modes_test.dart
```

Expected: FAIL

**Step 3: Write minimal implementation**

Enhance existing cursor save/restore in `lib/src/terminal.dart`:
```dart
SavedCursor? _savedCursor;

void _saveCursor() {
  _savedCursor = SavedCursor(
    x: cursor.x,
    y: cursor.y,
    attributes: _currentAttributes.copy(),
  );
}

void _restoreCursor() {
  if (_savedCursor != null) {
    cursor.x = _savedCursor!.x;
    cursor.y = _savedCursor!.y;
    _currentAttributes = _savedCursor!.attributes;
  }
}

// Handle \x1b7 (DECSC) and \x1b8 (DECRC)
// Also handle CSI ? Pl c (DECSCUSR) for cursor style
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/kitty_dec_modes_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/terminal.dart test/kitty_dec_modes_test.dart
git commit -m "feat: enhance DEC modes (DECSC/DECRC)

- DECSC: save cursor position and attributes
- DECRC: restore cursor position and attributes
- DECSCUSR: cursor style (block, underline, bar)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 3: Example Demo Integration

### Task 15: Example App - Full Demo UI

**Files:**
- Modify: `example/lib/main.dart` - add all demo controls

**Step 1: Add demo buttons for all features**

In `example/lib/main.dart`, add UI for:
- Hyperlink test: Display clickable links
- Color test: Color picker
- Pointer shapes: Dropdown selector
- Notifications: "Send Test Notification" button
- Clipboard: Copy/Paste buttons
- Text sizing: Slider for font size
- File transfer: File picker
- Shell integration: Display prompt markers

**Step 2: Test the demo**

```bash
cd /Users/lbp/Projects/kterm.dart/example
flutter run
```

**Step 3: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat: add full Kitty Protocol demo in example app

- Add demo UI for all implemented protocols
- Include hyperlink, color, pointer, notification demos
- Add clipboard, text sizing, file transfer UI

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Final Verification

### Task 16: Run Full Test Suite

**Step 1: Run all tests**

```bash
flutter test --coverage
```

**Step 2: Check coverage**

```bash
genhtml coverage/lcov.info -o coverage/html
```

Expected: >80% coverage

**Step 3: Final commit**

```bash
git add .
git commit -m "chore: complete Kitty Protocol implementation

- All 19 protocols implemented with tests
- Full demo in example app
- Run full test suite verification

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Summary

| # | Protocol | Escape Type | Tasks |
|---|----------|-------------|-------|
| 1 | Keyboard Protocol | CSI | Already implemented |
| 2 | Graphics Protocol | APC | Already implemented |
| 3 | Text Sizing | OSC | Task 9 |
| 4 | File Transfer | OSC 5113 | Task 13 |
| 5 | Clipboard (Basic) | OSC 52 | Task 7 |
| 6 | Clipboard (Extended) | OSC 5522 | Task 7 |
| 7 | Desktop Notifications | OSC 99 | Task 8 |
| 8 | Notifications (OSC 777) | OSC 777 | Task 8 |
| 9 | Remote Control | DCS | Task 12 |
| 10 | Color Stack | OSC 30001/30101 | Task 10 |
| 11 | Pointer Shapes | OSC 22 | Task 6 |
| 12 | Styled Underlines | CSI 4:3 | Task 5 |
| 13 | Hyperlinks | OSC 8 | Task 1 |
| 14 | Shell Integration | OSC 133 | Task 11 |
| 15 | Wide Gamut Colors | SGR 38/48 | Task 2 |
| 16 | Misc Protocol | CSI/SGR | Various |
| 17 | Mouse Tracking | SGR 1004/1006 | Task 4 |
| 18 | Bracketed Paste | SGR 2004 | Task 3 |
| 19 | DEC Modes | DECSC/DECRC | Task 14 |
