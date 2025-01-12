import 'package:flutter/material.dart';
import 'package:macos_dock/utils/global_position.dart';

final class DockController<T> with ChangeNotifier {
  T? _draggableItem;
  T? get draggableItem => _draggableItem;

  void setDraggableItem(T? item) {
    _draggableItem = item;
    notifyListeners();
  }

  double? _pointerRatio;
  double? get pointerRatio => _pointerRatio;

  Offset _dragStartPosition = Offset.zero;
  Offset get dragStartPosition => _dragStartPosition;

  void setDragStartPosition(Offset position) {
    _dragStartPosition = position;
    notifyListeners();
  }

  Offset _dragEndPosition = Offset.zero;
  Offset get dragEndPosition => _dragEndPosition;

  void setDragEndPosition(Offset position) {
    _dragEndPosition = position;
    notifyListeners();
  }

  Offset get returnPosition => dragEndPosition - dragStartPosition;

  void updatePointerRatio({
    required Offset pointerPosition,
    required RenderBox dockBox,
  }) {
    final startOffset = dockBox.localToGlobal(Offset.zero).dx;
    final dockWidth = dockBox.size.width;
    _pointerRatio = (pointerPosition.dx - startOffset) / dockWidth;
    notifyListeners();
  }

  void resetPointerRatio() {
    _pointerRatio = null;
    notifyListeners();
  }

  void resetDragPositions() {
    _dragStartPosition = Offset.zero;
    _dragEndPosition = Offset.zero;
    notifyListeners();
  }

  void setStartPositionFromKey(GlobalKey key) {
    final startingPosition = key.globalPosition;
    if (startingPosition != null) {
      _dragStartPosition = startingPosition;
    }
  }
}
