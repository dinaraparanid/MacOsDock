import 'package:flutter/material.dart';
import 'package:macos_dock/animated_dock_item.dart';
import 'package:macos_dock/dock_controller.dart';
import 'package:macos_dock/dock_item_controller.dart';

/// Dock of the reorderable [items].
final class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>>
  with TickerProviderStateMixin {

  /// Scale factor applied for [Dock]
  /// when mouse is in its bounds.
  /// Also applied for items as the highest bound of scale
  static const _maxScaleFactor = 1.1;

  /// Duration to animate dock's and items' scales
  static const _scaleAnimDuration = Duration(milliseconds: 200);

  /// [GlobalKey] to determine dock constraints
  final _dockKey = GlobalKey();

  /// [T] items being manipulated
  late final _items = widget.items.toList();

  /// [DockController] that manages animation states
  /// (pointer position and dragging item with its positions)
  late final _dockController = DockController<T>();

  /// [DockItemController] for each item
  late final _itemsControllers = {
    for (var x in _items) x : DockItemController()
  };

  /// Determines item center ratio (from 0 to 1) by its index (from 0).
  ///
  /// Example: total = 5, index = 2 -> (2 + 0.5) / 5 = 0.5 (middle or 50%)
  double _itemCenterRatio(int index) => (index + 0.5) / _items.length;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _dockController.pointerRatio != null ? _maxScaleFactor : 1.0,
    duration: _scaleAnimDuration,
    child: MouseRegion(
      key: _dockKey,
      onEnter: (event) => _updatePointerState(position: event.position),
      onHover: (event) => _updatePointerState(position: event.position),
      onExit: (event) => setState(() => _dockController.resetPointerRatio()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black12,
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _items.indexed.map((indexedItem) {
            final (index, item) = indexedItem;
            return AnimatedDockItem(
              index: index,
              item: item,
              itemCenterRatio: _itemCenterRatio(index),
              controller: _itemsControllers[item]!,
              dockController: _dockController,
              onEnter: (event) {
                _updatePointerState(position: event.position);
                _updateListIfDragging(enteredItem: item);
              },
              onHover: (event) => _updatePointerState(position: event.position),
              child: widget.builder(item),
            );
          }).toList(growable: false),
        ),
      ),
    ),
  );

  /// Updates pointer ratio state via Dock constraints
  /// (obtained from [_dockKey]) and given pointer [position]
  void _updatePointerState({required Offset position}) => setState(() {
    final box = _dockKey.currentContext!.findRenderObject() as RenderBox;
    _dockController.updatePointerRatio(pointerPosition: position, dockBox: box);
  });

  /// Updates [_items] positions and launches swap animations
  /// for [enteredItem] and [_dockController.draggableItem]
  Future<void> _updateListIfDragging({required T enteredItem}) async {
    final dragItem = _dockController.draggableItem;

    // Ignore if not dragging or the same element
    if (dragItem == null || dragItem == enteredItem) return;

    // Updating start position (where to return if pointer is released)
    // from [enteredItem] current position
    final controller = _itemsControllers[enteredItem]!;
    setState(() => _dockController.setStartPositionFromKey(controller.widgetPositionKey));

    final beforeAnimDragIndex = _items.indexOf(dragItem);
    final beforeAnimEnterIndex = _items.indexOf(enteredItem);
    final isDragToRight = beforeAnimDragIndex < beforeAnimEnterIndex;

    // Launches swap animation (in opposite direction) for dragging element.
    // Intentionally not awaited (side effect) and mostly required
    // to synchronize animation for dragging item if it is released during swap
    _itemsControllers[dragItem]!.move(isDragToRight: !isDragToRight);

    // Launches swap animation for neighbouring element
    // List modifications must be launched after animation's completion
    // in order for item to preserve its position (otherwise will jump)
    await _itemsControllers[enteredItem]!.move(isDragToRight: isDragToRight);

    setState(() {
      // Perform actual swapping of elements
      final dragIndex = _items.indexOf(dragItem);
      final enteredIndex = _items.indexOf(enteredItem);
      _items.insert(enteredIndex, _items.removeAt(dragIndex));
    });
  }
}