import 'package:flutter/material.dart';
import 'package:macos_dock/utils/global_position.dart';

/// Manages animation states of Dock
/// (pointer position and dragging item with its positions)
final class DockController<T> with ChangeNotifier {
  T? _draggableItem;

  /// Currently dragging item
  T? get draggableItem => _draggableItem;

  /// Updates currently dragging item and notifies listeners
  void setDraggableItem(T? item) {
    _draggableItem = item;
    notifyListeners();
  }

  double? _pointerRatio;

  /// Pointer ratio inside dock (e.g. in middle of dock is 0.5)
  double? get pointerRatio => _pointerRatio;

  Offset _dragStartPosition = Offset.zero;

  /// Global position where [draggableItem] must return
  /// when pointer will be released
  Offset get dragStartPosition => _dragStartPosition;

  /// Updates [draggableItem] global start position and notifies listeners
  void setDragStartPosition(Offset position) {
    _dragStartPosition = position;
    notifyListeners();
  }

  Offset _dragEndPosition = Offset.zero;

  /// Global position where drag pointer was released
  Offset get dragEndPosition => _dragEndPosition;

  /// Updates [draggableItem] global end position and notifies listeners
  void setDragEndPosition(Offset position) {
    _dragEndPosition = position;
    notifyListeners();
  }

  /// Offset from [draggableItem] final position
  /// to the released pointer's position
  Offset get returnVector => dragEndPosition - dragStartPosition;

  /// Computes [pointerRatio] and notifies listeners
  /// (relative position between start and end of dock widget)
  void updatePointerRatio({
    required Offset pointerPosition,
    required RenderBox dockBox,
  }) {
    final startOffset = dockBox.localToGlobal(Offset.zero).dx;
    final dockWidth = dockBox.size.width;
    _pointerRatio = (pointerPosition.dx - startOffset) / dockWidth;
    notifyListeners();
  }

  /// Resets [pointerRatio] to null and notifies listeners
  void resetPointerRatio() {
    _pointerRatio = null;
    notifyListeners();
  }

  /// Resets [dragStartPosition] and [dragEndPosition]
  /// to zero and notifies listeners
  void resetDragPositions() {
    _dragStartPosition = Offset.zero;
    _dragEndPosition = Offset.zero;
    notifyListeners();
  }

  /// Computes new [dragStartPosition]
  /// from the global position of given items' [key]
  void setStartPositionFromKey(GlobalKey key) {
    final startingPosition = key.globalPosition;
    if (startingPosition != null) {
      _dragStartPosition = startingPosition;
    }
  }
}
