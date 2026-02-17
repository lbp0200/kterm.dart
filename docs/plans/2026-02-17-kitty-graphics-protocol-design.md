# Kitty Graphics Protocol Implementation Design

## Overview

This document outlines the design for implementing basic Kitty Graphics Protocol support in kterm.dart. The implementation supports:
- APC G command for graphics transmission
- f=32 (RGBA) and f=100 (PNG) image formats
- Chunked transmission (m flag) with Base64 decoding
- Image placement at specific cell positions
- Memory-efficient management with LRU eviction

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      EscapeParser                           │
│  (Extended to handle APC G sequences)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   GraphicsManager                           │
│  - Image storage (LRU cache)                               │
│  - Chunk reassembly                                        │
│  - Memory guard (configurable limit)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   TerminalPainter                           │
│  - Image rendering via drawImageRect                       │
│  - Z-index support (above/below text)                      │
└─────────────────────────────────────────────────────────────┘
```

## Task 1: Image Storage & Management

### GraphicsManager Class

**Location:** `lib/src/core/graphics_manager.dart`

**Responsibilities:**
- Store images by ID
- Manage image lifecycle (cleanup unused)
- Reassemble chunked transmissions
- Enforce memory limits (LRU eviction)

**API:**

```dart
class GraphicsManager {
  GraphicsManager({this.maxMemoryBytes = 100 * 1024 * 1024});

  /// Maximum memory allowed for image cache (default: 100MB)
  final int maxMemoryBytes;

  /// Maximum number of images (default: 1000)
  final int maxImageCount = 1000;

  /// Store an image, returns the image ID
  int storeImage(ui.Image image);

  /// Get image by ID, returns null if not found
  ui.Image? getImage(int imageId);

  /// Mark image as used (updates LRU)
  void touchImage(int imageId);

  /// Remove image by ID
  void removeImage(int imageId);

  /// Clear all images
  void clear();

  /// Get current memory usage
  int get currentMemoryBytes;

  /// Get image count
  int get imageCount;
}
```

### Memory Guard Strategy

1. **LRU Cache:** Track image access order, evict least recently used first
2. **Memory Tracking:** Each image reports its byte size on insertion
3. **Eviction Triggers:**
   - Memory exceeds maxMemoryBytes (70% threshold for eviction)
   - Image count exceeds maxImageCount
4. **Eviction Algorithm:**
   - Sort by last access time (oldest first)
   - Remove until under 50% of limit
   - Always keep images currently referenced by cells

### Cell Data Compression

To avoid expanding CellData further, we'll pack image reference into existing fields:

**New Cell Field Layout (6 integers):**
| Index | Field | Bits | Description |
|-------|-------|------|-------------|
| 0 | foreground | 32 | Color encoding |
| 1 | background | 32 | Color encoding |
| 2 | flags | 32 | Bold, italic, etc. |
| 3 | content | 22 | Codepoint + width |
| 4 | underline | 6 | Style + color |
| 5 | **image** | **32** | **Image ID (upper 16) + placement ID (lower 16)** |

**Encoding:**
- Image ID: Upper 16 bits (0-65535)
- Placement ID: Lower 16 bits (0-65535, for multi-placement of same image)

This avoids adding new fields while supporting image references.

## Task 2: APC Parsing

### APC Sequence Format

Kitty Graphics uses APC (Application Program Command):
```
ESC _ G <key>=<value>,<key>=<value>,... ; <payload> ST
```

**Example:**
```
ESC _ G f=32,t=d,w=80,h=24,m=1 ; BASE64DATA ST
```

### Parser Extension

**Location:** `lib/src/core/escape/parser.dart`

**New Handler Methods:**

```dart
abstract class EscapeHandler {
  // ... existing methods ...

  /// Called when graphics command starts
  void graphicsCommandStart(Map<String, String> args);

  /// Called with graphics data chunk (for m=1)
  void graphicsDataChunk(List<int> data);

  /// Called when graphics command completes
  void graphicsCommandEnd();
}
```

### State Machine

```
[Initial] ──► [ParsingArgs] ──► [ParsingPayload] ──► [Complete]
     │              │                    │
     │              │ m=1 (more data)    │ m=0 (last chunk)
     │              ▼                    ▼
     │         [WaitingForChunk] ───────┘
     │
     ▼
 [Error/Reset]
```

### Key-Value Parsing

**Supported Keys:**
| Key | Type | Description |
|-----|------|-------------|
| f | int | Format (32=RGBA, 100=PNG, 98=JPEG) |
| t | char | Transmit type (d=direct, t=base64) |
| w | int | Width in cells |
| h | int | Height in cells |
| x | int | X position in cells |
| y | int | Y position in cells |
| m | int | More flag (0=done, 1=more chunks) |
| s | int | Cell size width |
| v | int | Cell size height |
| a | char | Placement action (a=overlay, p=replace) |
| S | char | z-index (S=screen, C=cursor) |

### Chunked Transmission (m flag)

1. **First chunk (m=1):**
   - Parse args, store chunk data
   - Wait for subsequent chunks

2. **Subsequent chunks (m=1):**
   - Append data to buffer

3. **Final chunk (m=0):**
   - Append final data
   - Decode Base64 to bytes
   - Create ui.Image
   - Store in GraphicsManager

### Base64 Decoding

- Use `dart:convert` Base64Decoder
- Accumulate chunks in `List<int>`
- On final chunk, decode all at once

## Data Flow

```
1. ESC _ detected → Enter APC mode
2. 'G' detected → Parse key=value pairs until ';'
3. ';' detected → Begin payload accumulation
4. ST (ESC \) detected → Process complete graphics command
   a. Decode Base64 payload
   b. Create ui.Image (RGBA: raw pixels, PNG: ui.decodeImageFromList)
   c. Store in GraphicsManager
   d. Mark cells for image placement
```

## Rendering Integration

### Painter Extension

```dart
class TerminalPainter {
  /// Paint image at cell position
  void paintCellImage(Canvas canvas, Offset offset, CellData cellData) {
    final imageId = cellData.imageId;
    if (imageId == 0) return;

    final image = graphicsManager.getImage(imageId);
    if (image == null) return;

    // Calculate destination rect based on cell position
    // Calculate source rect based on image placement
    canvas.drawImageRect(...);
  }
}
```

### Z-index Support

- **Below text (default):** Render images before text in each cell
- **Above text:** Render images after text in each cell
- Use z-index flag from graphics command (S=screen, C=cursor)

## Error Handling

1. **Invalid APC:** Ignore, return to normal parsing
2. **Unknown format (f):** Log warning, skip image
3. **Decode failure:** Log error, skip image
4. **Memory limit exceeded:** Evict LRU images, retry
5. **Missing dimensions:** Use 1x1 default

## Configuration

```dart
class Terminal {
  // Graphics settings
  final graphicsManager = GraphicsManager(
    maxMemoryBytes: 100 * 1024 * 1024,  // 100MB default
    maxImageCount: 1000,
  );
}
```

## Testing Considerations

1. **Unit tests:**
   - Key-value parser
   - Base64 chunk reassembly
   - Memory eviction logic

2. **Integration tests:**
   - Full APC sequence parsing
   - Image rendering
   - Memory limit behavior

3. **Manual tests:**
   - Use `img2txt` or Kitty terminal to send test images
   - Verify chunked transmission with large images

## Dependencies

- `dart:convert` - Base64 decoding
- `dart:ui` - Image handling (already available)
- No new pub packages required

## Implementation Order

1. GraphicsManager class
2. Extend EscapeHandler interface
3. Extend EscapeParser for APC
4. Extend Terminal implementation
5. Extend CellData for image ID
6. Extend TerminalPainter for rendering
7. Integration testing
