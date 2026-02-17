# Kitty Keyboard Protocol Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate `kitty_key_encoder` into kterm (forked from xterm.dart) to support the Kitty Keyboard Protocol as a first-class feature, enabling modern key combinations like Ctrl+Enter, Ctrl+Backspace, etc.

**Architecture:**
1. Add kitty_key_encoder dependency
2. Extend Terminal class with KittyEncoder state tracking (5 progressive enhancement flags)
3. Modify EscapeParser to recognize `CSI > n u`, `CSI > + n u`, `CSI > - n u` sequences
4. Intercept keyboard input flow in TerminalView to use Kitty encoding when enabled

**Tech Stack:** Flutter, Dart, kitty_key_encoder package

---

## Task 1: Update pubspec.yaml

**Files:**
- Modify: `pubspec.yaml:1-18`

**Step 1: Update pubspec.yaml**

Add `kitty_key_encoder` dependency and rename package to `kterm`:

```yaml
name: kterm
description: kterm is a fast and fully-featured terminal emulator for Flutter applications, with support for mobile and desktop platforms.
version: 4.0.0
homepage: https://github.com/lbp0200/kterm.dart

dependencies:
  kitty_key_encoder: ^1.0.0
  convert: ^3.0.0
  # ... rest of dependencies
```

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Downloads kitty_key_encoder package

**Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "feat: add kitty_key_encoder dependency and rename to kterm"
```

---

## Task 2: Add KittyEncoder state to Terminal

**Files:**
- Modify: `lib/src/terminal.dart:1-30` (add imports)
- Modify: `lib/src/terminal.dart:73-86` (add constructor params)
- Modify: `lib/src/terminal.dart:88-92` (add KittyEncoder instance)
- Modify: `lib/src/terminal.dart:148-160` (add state getters)

**Step 1: Add imports**

Add to imports:
```dart
import 'package:kitty_key_encoder/kitty_key_encoder.dart';
```

**Step 2: Add KittyEncoder and state to Terminal class**

After line 148 (after `_bracketedPasteMode`), add:

```dart
// Kitty Keyboard Protocol state
KittyEncoder? _kittyEncoder;

bool _kittyMode = false;

final List<int> _kittyFlagsStack = [];

KittyEncoder get kittyEncoder {
  _kittyEncoder ??= KittyEncoder();
  return _kittyEncoder!;
}

bool get kittyMode => _kittyMode;
```

**Step 3: Add EscapeHandler methods for Kitty sequences**

Add these methods to the Terminal class (implementing EscapeHandler interface):

```dart
/// Handle CSI > n u - Set Kitty keyboard mode
void setKittyMode(bool enabled) {
  _kittyMode = enabled;
}

/// Handle CSI > + n u - Push (enable) Kitty flags
void pushKittyFlags(int flags) {
  _kittyFlagsStack.add(flags);
  _updateKittyEncoder();
}

/// Handle CSI > - n u - Pop (disable) Kitty flags
void popKittyFlags() {
  if (_kittyFlagsStack.isNotEmpty) {
    _kittyFlagsStack.removeLast();
    _updateKittyEncoder();
  }
}

void _updateKittyEncoder() {
  if (_kittyEncoder == null) return;
  // Apply flags from stack - use the last flags pushed
  final flags = _kittyFlagsStack.isNotEmpty ? _kittyFlagsStack.last : 0;
  // Update encoder flags based on Kitty protocol flags
}
```

**Step 4: Commit**

```bash
git add lib/src/terminal.dart
git commit -m "feat: add KittyEncoder state to Terminal"
```

---

## Task 3: Extend EscapeParser for Kitty sequences

**Files:**
- Modify: `lib/src/core/escape/parser.dart:192-205` (modify _escHandleCSI)
- Modify: `lib/src/core/escape/parser.dart:270-300` (add CSI handlers for 'u')
- Modify: `lib/src/core/escape/handler.dart` (add new handler methods)

**Step 1: Modify _escHandleCSI to detect Kitty sequences**

The CSI format for Kitty is `CSI > n u` where `>` is the private marker. Update `_escHandleCSI`:

```dart
bool _escHandleCSI() {
  final consumed = _consumeCsi();
  if (!consumed) return false;

  // Check for Kitty keyboard protocol: CSI > n u
  if (_csi.prefix == Ascii.greaterThan && _csi.finalByte == Ascii.u) {
    return _handleKittyMode();
  }

  final csiHandler = _csiHandlers[_csi.finalByte];
  // ... rest unchanged
}

bool _handleKittyMode() {
  if (_csi.params.isEmpty) return true;

  final firstParam = _csi.params[0];

  // CSI > n u - Set mode (0 = disable, 1 = enable)
  if (firstParam == 0) {
    handler.setKittyMode(false);
  } else if (firstParam == 1) {
    handler.setKittyMode(true);
  }
  // CSI > + n u - Push flags
  else if (firstParam == '+'.codeUnitAt(0)) {
    if (_csi.params.length > 1) {
      handler.pushKittyFlags(_csi.params[1]);
    }
  }
  // CSI > - n u - Pop flags
  else if (firstParam == '-'.codeUnitAt(0)) {
    handler.popKittyFlags();
  }

  return true;
}
```

**Step 2: Add handler methods to EscapeHandler**

Add to `lib/src/core/escape/handler.dart`:

```dart
void setKittyMode(bool enabled);
void pushKittyFlags(int flags);
void popKittyFlags();
```

**Step 3: Implement handlers in Terminal**

The Terminal class already implements EscapeHandler, so the methods added in Task 2 will be called.

**Step 4: Commit**

```bash
git add lib/src/core/escape/parser.dart lib/src/core/escape/handler.dart
git commit -m "feat: add Kitty keyboard protocol sequence parsing"
```

---

## Task 4: Intercept keyboard input flow

**Files:**
- Modify: `lib/src/terminal_view.dart:389-427` (_handleKeyEvent)

**Step 1: Add imports**

Add import at top of terminal_view.dart:
```dart
import 'package:kitty_key_encoder/kitty_key_encoder.dart';
import 'package:flutter/services.dart';
```

**Step 2: Modify _handleKeyEvent to intercept with Kitty encoder**

Replace the current _handleKeyEvent implementation:

```dart
KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
  final resultOverride = widget.onKeyEvent?.call(focusNode, event);
  if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
    return resultOverride;
  }

  // Intercept with Kitty keyboard protocol if enabled
  if (widget.terminal.kittyMode) {
    final seq = _encodeWithKitty(event);
    if (seq != null) {
      widget.terminal.onOutput?.call(seq);
      return KeyEventResult.handled;
    }
  }

  // ... rest of existing logic
}

String? _encodeWithKitty(KeyEvent event) {
  if (event is KeyDownEvent || event is KeyRepeatEvent) {
    final modifiers = <SimpleModifier>{};
    final keyboard = HardwareKeyboard.instance;

    if (keyboard.isShiftPressed) modifiers.add(SimpleModifier.shift);
    if (keyboard.isControlPressed) modifiers.add(SimpleModifier.control);
    if (keyboard.isAltPressed) modifiers.add(SimpleModifier.alt);
    if (keyboard.isMetaPressed) modifiers.add(SimpleModifier.meta);

    final keyEvent = SimpleKeyEvent(
      logicalKey: event.logicalKey,
      modifiers: modifiers,
      isKeyUp: event is KeyUpEvent,
      isKeyRepeat: event is KeyRepeatEvent,
    );

    return widget.terminal.kittyEncoder.encode(keyEvent);
  }
  return null;
}
```

**Step 3: Commit**

```bash
git add lib/src/terminal_view.dart
git commit -m "feat: intercept keyboard input with Kitty encoder"
```

---

## Task 5: Write integration test

**Files:**
- Create: `test/kitty_integration_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

void main() {
  group('Kitty Keyboard Protocol', () {
    test('enables Kitty mode on CSI > 1u', () {
      final terminal = Terminal();

      // Send CSI > 1u to enable Kitty mode
      terminal.write('\x1b[>1u');

      expect(terminal.kittyMode, isTrue);
    });

    test('disables Kitty mode on CSI > 0u', () {
      final terminal = Terminal();

      terminal.write('\x1b[>1u');
      expect(terminal.kittyMode, isTrue);

      terminal.write('\x1b[>0u');
      expect(terminal.kittyMode, isFalse);
    });

    test('generates Kitty sequences for Shift+Enter', () {
      final terminal = Terminal();
      terminal.write('\x1b[>1u');

      // This would require mocking key events - simplified test
      // In real implementation, we'd test the encoder directly
      expect(terminal.kittyEncoder.encode(
        SimpleKeyEvent(
          logicalKey: LogicalKeyboardKey.enter,
          modifiers: {SimpleModifier.shift},
        ),
      ), equals('\x1b[28;2u'));
    });

    test('push and pop flags', () {
      final terminal = Terminal();

      terminal.write('\x1b[>1u');  // Enable
      terminal.write('\x1b[>+1u'); // Push flags

      terminal.write('\x1b[>-1u'); // Pop flags
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/kitty_integration_test.dart`
Expected: Tests should compile and show current behavior

**Step 3: Commit**

```bash
git add test/kitty_integration_test.dart
git commit -m "test: add Kitty keyboard protocol integration tests"
```

---

## Task 6: Update package exports

**Files:**
- Modify: `lib/kterm.dart` or `lib/xterm.dart` (rename/update exports)

**Step 1: Rename and update exports**

Ensure the package exports all necessary classes with the new `kterm` name.

**Step 2: Commit**

```bash
git add lib/
git commit -m "chore: rename package exports to kterm"
```

---

## Summary

After completing these tasks, kterm will:
1. Recognize `CSI > n u` sequences from backend applications (like Neovim)
2. Track the 5 progressive enhancement flags of the Kitty protocol
3. Intercept keyboard input and encode it using kitty_key_encoder when enabled
4. Have tests verifying the functionality

This enables full support for modern key combinations required by Neovim, Helix, LazyGit, etc.
