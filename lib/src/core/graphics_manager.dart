import 'dart:ui' as ui;

/// Entry for LRU cache tracking
class _ImageEntry {
  final ui.Image image;
  int lastAccess;
  final int sizeBytes;

  _ImageEntry({
    required this.image,
    required this.sizeBytes,
  }) : lastAccess = DateTime.now().millisecondsSinceEpoch;
}

/// Placement of an image at a specific position
class ImagePlacement {
  final int placementId;
  final int imageId;
  final int x;
  final int y;
  final int width;
  final int height;
  final bool overlay; // true = above text, false = below text

  ImagePlacement({
    required this.placementId,
    required this.imageId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.overlay = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImagePlacement &&
        other.placementId == placementId &&
        other.imageId == imageId;
  }

  @override
  int get hashCode => Object.hash(placementId, imageId);
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
  final Map<int, ImagePlacement> _placements = {};

  /// Get all placements (for rendering)
  Map<int, ImagePlacement> get placements => _placements;
  int _nextImageId = 1;
  int _nextPlacementId = 1;
  int _currentMemoryBytes = 0;

  /// Store an image, returns the image ID
  int storeImage(ui.Image image) {
    // Calculate image size in bytes (width * height * 4 for RGBA)
    final sizeBytes = (image.width * image.height * 4).toInt();

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

  /// Create a placement for an existing image, returns placement ID
  int createPlacement({
    required int imageId,
    required int x,
    required int y,
    required int width,
    required int height,
    bool overlay = false,
  }) {
    final placementId = _nextPlacementId++;
    _placements[placementId] = ImagePlacement(
      placementId: placementId,
      imageId: imageId,
      x: x,
      y: y,
      width: width,
      height: height,
      overlay: overlay,
    );
    return placementId;
  }

  /// Get placement by ID
  ImagePlacement? getPlacement(int placementId) {
    return _placements[placementId];
  }

  /// Get placement for image at position (returns first matching)
  ImagePlacement? getPlacementAt(int imageId, int x, int y) {
    for (final placement in _placements.values) {
      if (placement.imageId == imageId &&
          x >= placement.x &&
          x < placement.x + placement.width &&
          y >= placement.y &&
          y < placement.y + placement.height) {
        return placement;
      }
    }
    return null;
  }

  /// Get placement ID for image at position, returns 0 if none
  int getPlacementIdAt(int x, int y) {
    for (final entry in _placements.entries) {
      final p = entry.value;
      if (x >= p.x && x < p.x + p.width && y >= p.y && y < p.y + p.height) {
        return p.placementId;
      }
    }
    return 0;
  }

  /// Remove placement by ID
  void removePlacement(int placementId) {
    _placements.remove(placementId);
  }

  /// Clear all placements (keeps images)
  void clearPlacements() {
    _placements.clear();
    _nextPlacementId = 1;
  }

  /// Mark image as used (updates LRU)
  void touchImage(int imageId) {
    final entry = _images[imageId];
    if (entry != null) {
      entry.lastAccess = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Remove image by ID (also removes all its placements)
  void removeImage(int imageId) {
    final entry = _images.remove(imageId);
    if (entry != null) {
      _currentMemoryBytes -= entry.sizeBytes;
    }

    // Remove all placements for this image
    _placements.removeWhere((_, placement) => placement.imageId == imageId);
  }

  /// Clear all images and placements
  void clear() {
    _images.clear();
    _placements.clear();
    _currentMemoryBytes = 0;
    _nextImageId = 1;
    _nextPlacementId = 1;
  }

  /// Clean up stale placements that are no longer referenced by cells.
  /// This should be called periodically or when cells are cleared.
  /// Returns the number of placements removed.
  int cleanupStalePlacements(Set<int> activePlacementIds) {
    final toRemove = <int>[];
    for (final entry in _placements.entries) {
      if (!activePlacementIds.contains(entry.key)) {
        toRemove.add(entry.key);
      }
    }
    for (final id in toRemove) {
      _placements.remove(id);
    }
    return toRemove.length;
  }

  /// Get current memory usage
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Get image count
  int get imageCount => _images.length;

  /// Get placement count
  int get placementCount => _placements.length;

  /// Evict images if needed to make room for [requiredBytes]
  void _evictIfNeeded(int requiredBytes) {
    // Check if we need to evict
    if (_currentMemoryBytes + requiredBytes <= (maxMemoryBytes * 0.7).toInt() &&
        _images.length < maxImageCount) {
      return;
    }

    // Get placements that are in use
    final usedPlacementImageIds =
        _placements.values.map((p) => p.imageId).toSet();

    // Sort by last access (oldest first)
    final sortedEntries = _images.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));

    // Remove until under 50% of limit
    final targetMemory = (maxMemoryBytes * 0.5).toInt();
    while ((_currentMemoryBytes > targetMemory ||
            _images.length >= maxImageCount) &&
        sortedEntries.isNotEmpty) {
      final entry = sortedEntries.removeAt(0);

      // Don't evict images that have active placements
      if (usedPlacementImageIds.contains(entry.key)) {
        continue;
      }

      _currentMemoryBytes -= entry.value.sizeBytes;
      _images.remove(entry.key);
    }
  }
}
