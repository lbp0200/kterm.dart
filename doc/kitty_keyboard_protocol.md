# Kitty Keyboard Protocol

## Overview

kterm implements the [Kitty Keyboard Protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/), which provides a way to report key events with full modifier information and distinguish between similar keys (e.g., Tab vs Ctrl+I).

## Enabling Kitty Mode

Kitty mode can be enabled via the terminal:

```dart
terminal.setKittyMode(true);   // Enable
terminal.setKittyMode(false);  // Disable
```

Or via escape sequences from the remote application:

```
CSI > 1 u    # Enable basic mode
CSI > 0 u    # Disable
CSI > + n u  # Push flags (progressive enhancement)
CSI > - u    # Pop flags
```

## Modes

### Basic Mode (CSI > 1 u)

When the remote application sends `CSI > 1 u`:

- `terminal.kittyMode` becomes `true`
- `terminal.kittyEncoder.flags.reportAllKeysAsEscape` remains `false`
- **Modifier + special key** combinations (Shift+Enter, Ctrl+Tab, etc.) are encoded as Kitty sequences
- **Bare keys** (no modifiers) and **alphanumeric keys** are handled via standard terminal input
- **KeyUp events are NOT encoded** (to prevent cursor jumping in shell prompts)

### Flags Mode (CSI > + n u)

When the remote application pushes flags with `CSI > + n u`:

- Flags are pushed onto a stack (supports nested modes)
- The effective flags determine encoding behavior:

| Flag Bit | Value | Name | Behavior |
|----------|-------|------|----------|
| 0 | 1 | `reportEvent` | Report key events (down/repeat/up) |
| 1 | 2 | `reportAlternateKeys` | Report alternate key representations |
| 2 | 4 | `reportAllKeysAsEscape` | Encode ALL keys as Kitty sequences |

When `reportAllKeysAsEscape` is `true`:
- **ALL key events** (including bare keys and alphanumeric) are Kitty-encoded
- **KeyUp events ARE encoded** (applications like vim may use this)

## Key Event Handling Flow

### 1. Shortcut Check (Highest Priority)

Terminal shortcuts (Cmd+V for paste, Cmd+C for copy, etc.) are checked first via `_shortcutManager`. If a shortcut matches, the event is handled and no Kitty encoding occurs.

### 2. Kitty Mode Handling

If Kitty mode is enabled and no shortcut matched:

```
KeyUp events:
  └─ reportAllKeysAsEscape=false → NOT encoded (returns ignored)
  └─ reportAllKeysAsEscape=true  → Encoded and sent

KeyDown events:
  ├─ reportAllKeysAsEscape=false:
  │   ├─ Modifier + special key → Kitty encoded
  │   ├─ Ctrl+letter (A-Z) → Raw ASCII control character
  │   ├─ Tab/Enter/Backspace → Standard terminal input
  │   ├─ Arrow keys, etc. → Standard key input
  │   └─ Alphanumeric → Returns ignored (handled by text input)
  │
  └─ reportAllKeysAsEscape=true:
      └─ ALL keys → Kitty encoded
```

### 3. Standard Handling (Fallback)

If Kitty mode is off or returns `ignored`, standard terminal key handling applies.

## KeyUp Event Encoding

KeyUp events are only encoded when `reportAllKeysAsEscape` is `true`. This prevents unexpected Kitty sequences from being sent to the remote shell when:

- Pasting via Cmd+V (KeyUp for V with Meta modifier)
- Using copy shortcuts (Cmd+C, Ctrl+C)
- Any modifier+letter key release

**Why this matters:** When KeyUp events are unnecessarily encoded, the remote shell receives escape sequences it doesn't understand, causing cursor jumping and garbled output.

## Escape Sequence Filtering in Paste

When text is pasted via `terminal.paste()`, the following filtering occurs:

1. **ANSI CSI sequences** (`ESC [ ...`) are removed
2. **Control characters** (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1A, 0x1C-0x1F) are removed
3. **Newlines** are normalized:
   - CRLF → LF
   - CR → LF
   - LF → CR (or CRLF in lineFeedMode)

Note: `ESC` (0x1B) is intentionally preserved to support OSC and other escape sequences.

## Integration Examples

### SSH Client (lbpSSH)

```dart
// Enable Kitty mode in terminal session constructor
if (terminalConfig.enableKittyProtocol) {
  terminal.setKittyMode(true);
} else {
  terminal.setKittyMode(false);
}
```

### Neovim/Vim

Neovim queries terminal capabilities on startup:
1. Sends `CSI c` (DA1) to check terminal type
2. May send `CSI > 0 u` to check Kitty support
3. If supported, enables Kitty mode for enhanced key reporting

### tmux

tmux uses Kitty protocol for:
- Distinguishing Tab from Ctrl+I
- Reporting modified keys (Ctrl+Shift+Arrow, etc.)
- Application-specific key modes

## Testing

Kitty keyboard protocol tests are in `test/kitty_*.dart`:

```bash
flutter test test/kitty_*.dart  # All Kitty protocol tests
flutter test test/kitty_keyboard_test.dart  # Key encoding tests
flutter test test/kitty_flags_test.dart     # Flag behavior tests
```

## References

- [Kitty Keyboard Protocol Documentation](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
- [kitty_protocol package](https://pub.dev/packages/kitty_protocol)
- [Terminal encoding reference](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
