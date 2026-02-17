# Kitty Graphics Protocol Implementation Plan (Tasks 1 & 2)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement basic Kitty Graphics Protocol support with image storage/management and APC parsing for f=32 (RGBA) and f=100 (PNG) formats.

**Architecture:** Extend EscapeParser for APC G command handling, create GraphicsManager with LRU cache for image storage, pack image IDs into existing CellData structure.

**Tech Stack:** Dart, Flutter (ui.Image), dart:convert (Base64)

---

## Task 1: GraphicsManager (Image Storage & Management)

### Overview
Create a GraphicsManager class to store images by ID with LRU eviction and memory limits.

### Files
- Create: `lib/src/core/graphics_manager.dart`
- Modify: `lib/src/core/cell.dart` (add image ID packing)
- Modify: `lib/src/core/buffer/line.dart` (handle image ID in cells)

---

### Step 1: Create GraphicsManager class

**File:** Create `lib/src/core/graphics_manager.dart`

```dart
import 'dart:ui';

/// Entry for LRU cache tracking
class _ImageEntry {
  final ui.Image image;
  int lastAccess;
  int sizeBytes;

  _ImageEntry({required this.image, required this.sizeBytes})
      : lastAccess = DateTime.now().millisecondsSinceEpoch;
}

/// Manages terminal images with LRU eviction and memory limits
class GraphicsManager {
  GraphicsManager({
    this.maxMemoryBytes = 100 * 1024 * 1024,
    this.maxImageCount = 1000,
  });

  /// Maximum memory allowed for image cache (default: 100MB)
  final int maxMemoryBytes;

  /// Maximum number of images (default: 1000)
  final int maxImageCount;

  final Map<int, _ImageEntry> _images = {};
  int _nextImageId = 1;
  int _currentMemoryBytes = 0;

  /// Store an image, returns the image ID
  int storeImage(ui.Image image) {
    // Calculate image size in bytes (width * height * 4 for RGBA)
    final sizeBytes = image.width * image.height * 4;

    // Evict if necessary
    _evictIfNeeded(sizeBytes);

    final imageId = _nextImageId++;
    _images[imageId] = _ImageEntry(image: image, sizeBytes: sizeBytes);
    _currentMemoryBytes += sizeBytes;

    return imageId;
  }

  /// Get image by ID, returns null if not found
  ui.Image? getImage(int imageId) {
    final entry = _images[imageId];
    if (entry == null) return null;

    // Update LRU
    entry.lastAccess = DateTime.now().millisecondsSinceEpoch;
    return entry.image;
  }

  /// Mark image as used (updates LRU)
  void touchImage(int imageId) {
    final entry = _images[imageId];
    if (entry != null) {
      entry.lastAccess = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Remove image by ID
  void removeImage(int imageId) {
    final entry = _images.remove(imageId);
    if (entry != null) {
      _currentMemoryBytes -= entry.sizeBytes;
    }
  }

  /// Clear all images
  void clear() {
    _images.clear();
    _currentMemoryBytes = 0;
    _nextImageId = 1;
  }

  /// Get current memory usage
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Get image count
  int get imageCount => _images.length;

  /// Evict images if needed to make room for [requiredBytes]
  void _evictIfNeeded(int requiredBytes) {
    // Check if we need to evict
    if (_currentMemoryBytes + requiredBytes <= maxMemoryBytes * 0.7 &&
        _images.length < maxImageCount) {
      return;
    }

    // Sort by last access (oldest first)
    final sortedEntries = _images.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));

    // Remove until under 50% of limit
    final targetMemory = maxMemoryBytes * 0.5;
    while ((_currentMemoryBytes > targetMemory || _images.length >= maxImageCount) &&
           sortedEntries.isNotEmpty) {
      final entry = sortedEntries.removeAt(0);
      _currentMemoryBytes -= entry.value.sizeBytes;
      _images.remove(entry.key);
    }
  }
}
```

**Step 2: Run dart analyze to verify**

Run: `dart analyze lib/src/core/graphics_manager.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/src/core/graphics_manager.dart
git commit -m "feat(graphics): add GraphicsManager with LRU cache"
```

---

### Step 2: Add image ID to CellData

**File:** Modify `lib/src/core/cell.dart`

Add image ID packing constants and helper methods:

```dart
// Add after CellContent class:

abstract class CellImage {
  /// Image ID is stored in upper 16 bits
  static const imageIdShift = 16;
  static const imageIdMask = 0xFFFF0000;

  /// Placement ID is stored in lower 16 bits
  static const placementIdShift = 0;
  static const placementIdMask = 0x0000FFFF;

  /// Pack image ID and placement ID into single integer
  static int packImageData(int imageId, int placementId) {
    return ((imageId << imageIdShift) & imageIdMask) |
           ((placementId << placementIdShift) & placementIdMask);
  }

  /// Extract image ID from packed integer
  static int getImageId(int packed) {
    return (packed & imageIdMask) >> imageIdShift;
  }

  /// Extract placement ID from packed integer
  static int getPlacementId(int packed) {
    return (packed & placementIdMask) >> placementIdShift;
  }
}
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/core/cell.dart`
Expected: No errors

**Step 3: Commit**

```dart
git add lib/src/core/cell.dart
git commit -m "feat(graphics): add CellImage packing helpers for image ID storage"
```

---

### Step 3: Update BufferLine to handle image ID

**File:** Modify `lib/src/core/buffer/line.dart`

Update constants and methods to handle image data:

```dart
// Update constants - change _cellSize from 6 to 7 if needed
// Actually, we can reuse the existing underlineStyle slot for image data
// since we're packing both into one integer
// So no changes needed to _cellSize!

// Add new helper methods after setUnderlineColor:

int getImageData(int index) {
  // Reuse underline color slot for packed image data
  return _data[index * _cellSize + _cellUnderlineColor];
}

void setImageData(int index, int value) {
  _data[index * _cellSize + _cellUnderlineColor] = value;
}
```

Note: We'll store packed image data in the underlineColor slot since underline styles use their own field now.

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/core/buffer/line.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/src/core/buffer/line.dart
git commit -f "feat(graphics): add getImageData/setImageData to BufferLine"
```

---

## Task 2: APC Parsing for Kitty Graphics

### Overview
Extend EscapeParser to handle APC G command and parse key-value pairs for graphics transmission.

### Files
- Modify: `lib/src/core/escape/handler.dart` (add handler methods)
- Modify: `lib/src/core/escape/parser.dart` (add APC handling)
- Modify: `lib/src/terminal.dart` (implement handlers)
- Modify: `lib/src/utils/debugger.dart` (implement stub handlers)

---

### Step 1: Add handler methods to EscapeHandler

**File:** Modify `lib/src/core/escape/handler.dart`

Add before the OSC section:

```dart
/* Kitty Graphics Protocol */

void graphicsCommandStart(Map<String, String> args);

void graphicsDataChunk(List<int> data);

void graphicsCommandEnd();
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/core/escape/handler.dart`
Expected: Error about missing implementations in implementing classes

**Step 3: Commit**

```bash
git add lib/src/core/escape/handler.dart
git commit -m "feat(graphics): add GraphicsHandler methods to EscapeHandler"
```

---

### Step 2: Implement APC parsing in EscapeParser

**File:** Modify `lib/src/core/escape/parser.dart`

Add the APC handler to _escHandlers map:

```dart
// In _escHandlers map, add:
// '_'.charCode: _escHandleAPC,  // APC (Application Program Command)

// Add new method:

/// Handle APC (Application Program Command) sequences
bool _escHandleAPC() {
  if (_queue.isEmpty) return false;

  final command = _queue.consume();
  // Kitty Graphics Protocol uses 'G'
  if (command != 'G'.codeUnitAt(0)) {
    // Unknown APC command, skip
    return true;
  }

  return _handleKittyGraphics();
}

/// Handle Kitty Graphics Protocol sequence
bool _handleKittyGraphics() {
  // Parse key-value pairs until we hit ';' (payload start) or ST
  final args = <String, String>{};
  final keyBuffer = StringBuffer();
  final valueBuffer = StringBuffer();
  var inKey = true;

  while (_queue.isNotEmpty) {
    final char = _queue.consume();

    // End of arguments, start of payload
    if (char == Ascii.semicolon) {
      break;
    }

    // String terminator - end of sequence
    if (char == Ascii.ESC) {
      if (_queue.isNotEmpty && _queue.peek() == Ascii.backslash) {
        _queue.consume(); // Consume backslash
        break;
      }
    }

    if (char == Ascii.equals) {
      inKey = false;
      continue;
    }

    if (char == Ascii.comma) {
      // Save current key-value pair
      if (keyBuffer.isNotEmpty) {
        args[keyBuffer.toString()] = valueBuffer.toString();
      }
      keyBuffer.clear();
      valueBuffer.clear();
      inKey = true;
      continue;
    }

    if (inKey) {
      keyBuffer.writeCharCode(char);
    } else {
      valueBuffer.writeCharCode(char);
    }
  }

  // Save last key-value pair
  if (keyBuffer.isNotEmpty) {
    args[keyBuffer.toString()] = valueBuffer.toString();
  }

  // Notify handler that graphics command is starting
  handler.graphicsCommandStart(args);

  // Now parse payload (Base64 encoded data)
  // Read until ST (ESC \) or end of input
  final payloadBuffer = StringBuffer();
  while (_queue.isNotEmpty) {
    final char = _queue.consume();

    if (char == Ascii.ESC) {
      if (_queue.isNotEmpty && _queue.peek() == Ascii.backslash) {
        _queue.consume(); // Consume backslash
        break;
      }
      // ESC alone terminates
      break;
    }

    if (char == Ascii.BEL) {
      break;
    }

    payloadBuffer.writeCharCode(char);
  }

  // Send payload to handler
  if (payloadBuffer.isNotEmpty) {
    final base64String = payloadBuffer.toString();
    // Convert Base64 string to bytes
    final bytes = _base64Decode(base64String);
    handler.graphicsDataChunk(bytes);
  }

  handler.graphicsCommandEnd();
  return true;
}

/// Decode Base64 string to bytes
List<int> _base64Decode(String input) {
  // Remove any whitespace
  final cleaned = input.replaceAll(RegExp(r'\s'), '');
  // Use dart:convert
  final decoder = Base64Decoder();
  return decoder.convert(cleaned);
}
```

**Add import at top of file:**

```dart
import 'dart:convert' show Base64Decoder;
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/core/escape/parser.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/src/core/escape/parser.dart
git commit -m "feat(graphics): add APC parsing for Kitty Graphics Protocol"
```

---

### Step 3: Implement handler in Terminal

**File:** Modify `lib/src/terminal.dart`

Add instance variable and handler implementation:

```dart
// Add import
import 'package:kterm/src/core/graphics_manager.dart';

// Add to Terminal class:
late final graphicsManager = GraphicsManager();

// Current graphics transmission state
Map<String, String> _currentGraphicsArgs = {};
List<List<int>> _graphicsChunks = [];
bool _graphicsTransmissionActive = false;
```

Add handler methods (before OSC section):

```dart
/* Kitty Graphics Protocol */

@override
void graphicsCommandStart(Map<String, String> args) {
  _currentGraphicsArgs = args;
  _graphicsChunks.clear();
  _graphicsTransmissionActive = true;
}

@override
void graphicsDataChunk(List<int> data) {
  if (_graphicsTransmissionActive) {
    _graphicsChunks.add(data);
  }
}

@override
void graphicsCommandEnd() {
  if (!_graphicsTransmissionActive) return;

  _graphicsTransmissionActive = false;

  // Concatenate all chunks
  final totalLength = _graphicsChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
  final combinedData = List<int>.filled(totalLength, 0);
  var offset = 0;
  for (final chunk in _graphicsChunks) {
    combinedData.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  _graphicsChunks.clear();

  // Process based on format
  final format = int.tryParse(_currentGraphicsArgs['f'] ?? '') ?? 0;

  ui.Image? image;

  switch (format) {
    case 32: // RGBA raw
      image = _createRgbaImage(combinedData);
      break;
    case 100: // PNG
    case 98:  // JPEG
      image = _createPngImage(combinedData);
      break;
    default:
      // Unsupported format
      return;
  }

  if (image == null) return;

  // Store image and get ID
  final imageId = graphicsManager.storeImage(image);

  // Get placement coordinates
  final x = int.tryParse(_currentGraphicsArgs['x'] ?? '') ?? 0;
  final y = int.tryParse(_currentGraphicsArgs['y'] ?? '') ?? 0;
  final width = int.tryParse(_currentGraphicsArgs['w'] ?? '') ?? 1;
  final height = int.tryParse(_currentGraphicsArgs['h'] ?? '') ?? 1;

  // Mark cells with image reference
  _placeImage(imageId, x, y, width, height);

  _currentGraphicsArgs.clear();
}

/// Create image from RGBA pixel data
ui.Image? _createRgbaImage(List<int> data) async {
  final width = int.tryParse(_currentGraphicsArgs['w'] ?? '') ?? 1;
  final height = int.tryParse(_currentGraphicsArgs['h'] ?? '') ?? 1;

  if (data.length < width * height * 4) {
    return null;
  }

  final completer = Completer<ui.Image?>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(data),
    width,
    height,
    ui.PixelFormat.rgba8888,
    (img) => completer.complete(img),
    rowBytes: width * 4,
  );

  return completer.future;
}

/// Create image from PNG/JPEG data
ui.Image? _createPngImage(List<int> data) {
  return ui.decodeImageFromList(Uint8List.fromList(data));
}

/// Place image at cell position
void _placeImage(int imageId, int x, int y, int width, int height) {
  final line = buffer.lines.isNotEmpty ? buffer.lines[y] : null;
  if (line == null) return;

  // Pack image data
  final imageData = CellImage.packImageData(imageId, 0);

  // Mark cells in the image area
  for (var dy = 0; dy < height && y + dy < buffer.height; dy++) {
    final bufferLine = buffer.lines[y + dy];
    if (bufferLine == null) continue;

    for (var dx = 0; dx < width && x + dx < buffer.width; dx++) {
      bufferLine.setImageData(dx, imageData);
    }
  }
}
```

Add required imports:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:kterm/src/core/cell.dart';
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/terminal.dart`
Expected: Errors about missing imports and method signatures

**Step 3: Fix any issues**

Add the Completer import:
```dart
import 'dart:async';
```

**Step 4: Commit**

```bash
git add lib/src/terminal.dart
git commit -m "feat(graphics): implement graphics handlers in Terminal"
```

---

### Step 4: Add stub handlers to debugger

**File:** Modify `lib/src/utils/debugger.dart`

Add stub implementations:

```dart
@Override
void graphicsCommandStart(Map<String, String> args) {
  onCommand('graphicsCommandStart($args)');
}

@Override
void graphicsDataChunk(List<int> data) {
  onCommand('graphicsDataChunk(${data.length} bytes)');
}

@Override
void graphicsCommandEnd() {
  onCommand('graphicsCommandEnd');
}
```

**Step 2: Run dart analyze**

Run: `dart analyze lib/src/utils/debugger.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/src/utils/debugger.dart
git commit -m "feat(graphics): add debugger stub handlers"
```

---

## Verification

### Run Analysis

```bash
dart analyze lib/
```

Expected: No errors (warnings about deprecated API are OK)

### Test Commands

After implementation, test with:

1. **Minimal RGBA test:**
   ```bash
   # Send APC G command with f=32
   printf '\033_Gf=32,t=d,w=1,h=1,x=0,y=0;AAAA\033\\'
   ```

2. **Base64 encoded:**
   ```bash
   # Send APC G command with f=32, t=t (base64)
   printf '\033_Gf=32,t=t,w=1,h=1,x=0,y=0;iVBORw0KGgo\033\\'
   ```

---

## Summary

This implementation provides:
- GraphicsManager with configurable memory limits and LRU eviction
- APC G command parsing in EscapeParser
- Base64 decoding for chunked transmission
- RGBA and PNG/JPEG image support
- Cell-level image placement

Next steps (for future tasks):
- Add rendering in TerminalPainter
- Support z-index (above/below text)
- Add tests for parser and GraphicsManager
