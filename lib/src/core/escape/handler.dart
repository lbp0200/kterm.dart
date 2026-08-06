import 'package:kterm/src/core/mouse/mode.dart';

/// Receives decoded escape sequences from [EscapeParser].
///
/// The terminal frontend implements this interface to react to control
/// sequences (SBC, ANSI, CSI, OSC, DCS, DEC private modes, SGR and the
/// Kitty keyboard / graphics protocols). Every method corresponds to one
/// decoded sequence; unknown or unsupported sequences are routed to the
/// `unknown*` / `unsupported*` callbacks instead of being dropped.
///
/// Implementations should treat these calls as ordered events: the parser
/// invokes them in the exact order the sequences appear in the input stream.
abstract class EscapeHandler {
  /// Write a single character to the screen.
  void writeChar(int char);

  /// Write a batch of consecutive plain-text characters.
  /// Called by [EscapeParser] when it detects a run of printable characters
  /// with no escape sequences or control characters in between.
  /// Default implementation falls back to per-character [writeChar].
  void writeString(String text) {
    for (final char in text.runes) {
      writeChar(char);
    }
  }

  /* SBC */

  /// Ring the terminal bell (BEL, `\x07`).
  void bell();

  /// Move the cursor back one column (BS, `\x08`).
  void backspaceReturn();

  /// Move the cursor to the next tab stop (HT, `\x09`).
  void tab();

  /// Move the cursor down one line, scrolling if at the bottom (LF, `\x0a`).
  void lineFeed();

  /// Move the cursor to the first column of the current line (CR, `\x0d`).
  void carriageReturn();

  /// Switch to the G1 character set (SO, `\x0e`).
  void shiftOut();

  /// Switch back to the G0 character set (SI, `\x0f`).
  void shiftIn();

  /// An unrecognized single-byte control character was received.
  void unknownSBC(int char);

  /* ANSI sequence */

  /// Save the current cursor position and attributes (ESC 7).
  void saveCursor();

  /// Restore the previously saved cursor position and attributes (ESC 8).
  void restoreCursor();

  /// Move the cursor down one line without scrolling (IND, ESC D).
  void index();

  /// Move the cursor to the start of the next line (NEL, ESC E).
  void nextLine();

  /// Set a tab stop at the current cursor column (HTS, ESC H).
  void setTapStop();

  /// Move the cursor up one line, scrolling if at the top (RI, ESC M).
  void reverseIndex();

  /// Designate a character set for G0–G3 (ESC ( / ESC ) / ESC * / ESC +).
  void designateCharset(int charset, int name);

  /// An unrecognized ESC sequence with final byte [char] was received.
  void unknownEscape(int char);

  /* CSI */

  /// Repeat the previous output character [n] times (CSI n b, REP).
  void repeatPreviousCharacter(int n);

  /// Move the cursor to row [y], column [x] (CSI x ; y H, CUP).
  void setCursor(int x, int y);

  /// Move the cursor to column [x] on the current row (CSI x G, CHA).
  void setCursorX(int x);

  /// Move the cursor to row [y] in the current column (CSI y d, VPA).
  void setCursorY(int y);

  /// Reply to a primary device attributes query (CSI c, DA1).
  void sendPrimaryDeviceAttributes();

  /// Clear the tab stop under the cursor (CSI g, TBC 0).
  void clearTabStopUnderCursor();

  /// Clear all tab stops (CSI 3 g, TBC 3).
  void clearAllTabStops();

  /// Move the cursor [offset] columns; negative moves left (CUB), positive
  /// moves right (CUF).
  void moveCursorX(int offset);

  /// Move the cursor [n] rows; negative moves up (CUU), positive moves
  /// down (CUD).
  void moveCursorY(int n);

  /// Reply to a secondary device attributes query (CSI > c, DA2).
  void sendSecondaryDeviceAttributes();

  /// Reply to a tertiary device attributes query (CSI = c, DA3).
  void sendTertiaryDeviceAttributes();

  /// Reply to an operating status query (CSI 5 n, DSR).
  void sendOperatingStatus();

  /// Reply to a cursor position query (CSI 6 n, CPR).
  void sendCursorPosition();

  /// Set the scrolling region to rows [i] through [bottom] (CSI r, DECSTBM).
  void setMargins(int i, [int? bottom]);

  /// Move the cursor to the first column [amount] rows down (CSI n E, CNL).
  void cursorNextLine(int amount);

  /// Move the cursor to the first column [amount] rows up (CSI n F, CPL).
  void cursorPrecedingLine(int amount);

  /// Erase from the cursor to the bottom of the screen (CSI 0 J, ED).
  void eraseDisplayBelow();

  /// Erase from the top of the screen to the cursor (CSI 1 J, ED).
  void eraseDisplayAbove();

  /// Erase the entire screen (CSI 2 J, ED).
  void eraseDisplay();

  /// Erase the scrollback buffer, keeping the visible screen (CSI 3 J, ED).
  void eraseScrollbackOnly();

  /// Erase from the cursor to the end of the line (CSI 0 K, EL).
  void eraseLineRight();

  /// Erase from the start of the line to the cursor (CSI 1 K, EL).
  void eraseLineLeft();

  /// Erase the entire line (CSI 2 K, EL).
  void eraseLine();

  /// Insert [amount] blank lines above the cursor (CSI n L, IL).
  void insertLines(int amount);

  /// Delete [amount] lines below the cursor (CSI n M, DL).
  void deleteLines(int amount);

  /// Delete [amount] characters at the cursor (CSI n P, DCH).
  void deleteChars(int amount);

  /// Scroll the visible screen up [amount] lines (CSI n S, SU).
  void scrollUp(int amount);

  /// Scroll the visible screen down [amount] lines (CSI n T, SD).
  void scrollDown(int amount);

  /// Erase [amount] characters at the cursor, leaving the cursor in place
  /// (CSI n X, ECH).
  void eraseChars(int amount);

  /// Insert [amount] blank characters at the cursor (CSI n @, ICH).
  void insertBlankChars(int amount);

  /// An unrecognized CSI sequence with final byte [finalByte] was received.
  void unknownCSI(int finalByte);

  /* Modes */

  /// Enable or disable insert mode (SM/RM 4, IRM).
  void setInsertMode(bool enabled);

  /// Enable or disable line feed / new line mode (SM/RM 20, LNM).
  void setLineFeedMode(bool enabled);

  /// An unrecognized ANSI mode [mode] was set or reset.
  void setUnknownMode(int mode, bool enabled);

  /* DEC Private modes */

  /// Enable or disable application cursor keys (DECSET/DECRST 1, DECCKM).
  void setCursorKeysMode(bool enabled);

  /// Enable or disable ANSI mode (DECSET/DECRST 2, DECANM). When disabled the
  /// terminal operates in VT52 mode.
  void setAnsiMode(bool enabled);

  /// Enable or disable reverse display (DECSET/DECRST 5, DECSCNM).
  void setReverseDisplayMode(bool enabled);

  /// Enable or disable origin mode (DECSET/DECRST 6, DECOM).
  void setOriginMode(bool enabled);

  /// Enable or disable 132-column mode (DECSET/DECRST 3, DECCOLM).
  void setColumnMode(bool enabled);

  /// Enable or disable auto-wrap at the right margin (DECSET/DECRST 7,
  /// DECAWM).
  void setAutoWrapMode(bool enabled);

  /// Set the mouse reporting mode (DECSET/DECRST 9, 1000–1006).
  void setMouseMode(MouseMode mode);

  /// Enable or disable the blinking cursor (DECSET/DECRST 12).
  void setCursorBlinkMode(bool enabled);

  /// Show or hide the cursor (DECSET/DECRST 25, DECTCEM).
  void setCursorVisibleMode(bool enabled);

  /// Switch to the alternate screen buffer.
  void useAltBuffer();

  /// Switch back to the main screen buffer.
  void useMainBuffer();

  /// Clear the alternate screen buffer.
  void clearAltBuffer();

  /// Enable or disable application keypad mode (ESC = / ESC >, DECPAM/
  /// DECPNM).
  void setAppKeypadMode(bool enabled);

  /// Enable or disable focus reporting (DECSET/DECRST 1004).
  void setReportFocusMode(bool enabled);

  /// Set the mouse report encoding (e.g. SGR 1006, UTF-8 1005).
  void setMouseReportMode(MouseReportMode mode);

  /// Enable or disable alternate buffer mouse scroll reporting (DECSET
  /// 1007).
  void setAltBufferMouseScrollMode(bool enabled);

  /// Enable or disable bracketed paste mode (DECSET/DECRST 2004).
  void setBracketedPasteMode(bool enabled);

  /// An unrecognized DEC private mode [mode] was set or reset.
  void setUnknownDecMode(int mode, bool enabled);

  /* Kitty keyboard protocol */

  /// Enable or disable the Kitty keyboard protocol (CSI > n u).
  void setKittyMode(bool enabled);

  /// Push [flags] onto the Kitty keyboard flags stack (CSI > + n u).
  void pushKittyFlags(int flags);

  /// Pop the top of the Kitty keyboard flags stack (CSI > - u).
  void popKittyFlags();

  /// Resize the terminal to [cols] columns and [rows] rows.
  void resize(int cols, int rows);

  /// Reply to a window/terminal size query.
  void sendSize();

  /* Select Graphic Rendition (SGR) */

  /// Reset the cursor style to the default (SGR 0).
  void resetCursorStyle();

  /// Make the text bold (SGR 1).
  void setCursorBold();

  /// Make the text faint / dim (SGR 2).
  void setCursorFaint();

  /// Make the text italic (SGR 3).
  void setCursorItalic();

  /// Underline the text (SGR 4).
  void setCursorUnderline();

  /// Set the underline style, e.g. 4:0 straight or 4:3 curly (SGR 4 : n).
  void setCursorUnderlineStyle(int style);

  /// Make the text blink (SGR 5).
  void setCursorBlink();

  /// Reverse video: swap foreground and background (SGR 7).
  void setCursorInverse();

  /// Make the text invisible (SGR 8).
  void setCursorInvisible();

  /// Strike through the text (SGR 9).
  void setCursorStrikethrough();

  /// Disable bold (SGR 22).
  void unsetCursorBold();

  /// Disable faint / dim (SGR 22).
  void unsetCursorFaint();

  /// Disable italic (SGR 23).
  void unsetCursorItalic();

  /// Disable underline (SGR 24).
  void unsetCursorUnderline();

  /// Disable blink (SGR 25).
  void unsetCursorBlink();

  /// Disable reverse video (SGR 27).
  void unsetCursorInverse();

  /// Make the text visible again (SGR 28).
  void unsetCursorInvisible();

  /// Disable strikethrough (SGR 29).
  void unsetCursorStrikethrough();

  /// Set the underline color from the 256-color palette (SGR 58 ; 5 ; n).
  void setUnderlineColor256(int color);

  /// Set the underline color to an RGB value (SGR 58 ; 2 ; r ; g ; b).
  void setUnderlineColorRgb(int r, int g, int b);

  /// Reset the underline color to the default (SGR 59).
  void resetUnderlineColor();

  /// Set the foreground color from the 16-color palette (SGR 30–37).
  void setForegroundColor16(int color);

  /// Set the foreground color from the 256-color palette (SGR 38 ; 5 ; n).
  void setForegroundColor256(int index);

  /// Set the foreground color to an RGB value (SGR 38 ; 2 ; r ; g ; b).
  void setForegroundColorRgb(int r, int g, int b);

  /// Reset the foreground color to the default (SGR 39).
  void resetForeground();

  /// Set the background color from the 16-color palette (SGR 40–47).
  void setBackgroundColor16(int color);

  /// Set the background color from the 256-color palette (SGR 48 ; 5 ; n).
  void setBackgroundColor256(int index);

  /// Set the background color to an RGB value (SGR 48 ; 2 ; r ; g ; b).
  void setBackgroundColorRgb(int r, int g, int b);

  /// Reset the background color to the default (SGR 49).
  void resetBackground();

  /// An unsupported SGR style parameter [param] was received.
  void unsupportedStyle(int param);

  /* Kitty Graphics Protocol */

  /// Start a graphics command with its parsed `a=…` key-value arguments
  /// (CSI _ G …).
  void graphicsCommandStart(Map<String, String> args);

  /// Append a chunk of raw payload data for the in-flight graphics command.
  void graphicsDataChunk(List<int> data);

  /// Finish the in-flight graphics command.
  void graphicsCommandEnd();

  /* OSC */

  /// Set the window/terminal title (OSC 0/2).
  void setTitle(String name);

  /// Set the icon name (OSC 1).
  void setIconName(String name);

  /// Set or clear the OSC 8 hyperlink; a null [id] clears it.
  void setHyperlink(String? id, String uri);

  /// Handle an OSC 52 clipboard request with [target] (e.g. `c`) and
  /// base64-encoded [data].
  void handleClipboard(String target, String data);

  /// Handle a desktop notification: OSC 99 (title/body form) or OSC 777
  /// (command form).
  void handleNotification(List<String> args);

  /// Handle an OSC text-size query.
  void handleTextSizeQuery(int command);

  /// Handle an OSC 133 shell integration command (e.g. prompt/command
  /// boundaries).
  void handleShellIntegration(String cmd, List<String> args);

  /// Push (OSC 30001) or pop (OSC 30101) the color stack.
  void handleColorStack({required bool push});

  /// Handle DCS (Device Control String) sequences.
  /// Used for the Remote Control protocol: `DCS +q query ST`.
  void handleDcs(String command, List<String> args, List<int>? data);

  /// An unrecognized OSC sequence with code [code] was received.
  void unknownOSC(String code, List<String> args);
}
