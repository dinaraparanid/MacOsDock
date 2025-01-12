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

  final dockKey = GlobalKey();

  /// [T] items being manipulated.
  late final _items = widget.items.toList();

  late final _dockController = DockController<T>();

  late final _itemsControllers = {
    for (var x in _items) x : DockItemController()
  };

  double itemCenterRatio(int index) => (index + 0.5) / _items.length;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _dockController.pointerRatio != null ? _maxScaleFactor : 1.0,
    duration: _scaleAnimDuration,
    child: MouseRegion(
      key: dockKey,
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
              itemCenterRatio: itemCenterRatio(index),
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

  void _updatePointerState({required Offset position}) => setState(() {
    final box = dockKey.currentContext!.findRenderObject() as RenderBox;
    _dockController.updatePointerRatio(pointerPosition: position, dockBox: box);
  });

  Future<void> _updateListIfDragging({required T enteredItem}) async {
    final dragItem = _dockController.draggableItem;
    if (dragItem == null || dragItem == enteredItem) return;

    final controller = _itemsControllers[enteredItem]!;
    setState(() => _dockController.setStartPositionFromKey(controller.widgetPositionKey));

    final beforeAnimDragIndex = _items.indexOf(dragItem);
    final beforeAnimEnterIndex = _items.indexOf(enteredItem);
    final isDragToRight = beforeAnimDragIndex < beforeAnimEnterIndex;

    _itemsControllers[dragItem]!.move(isDragToRight: !isDragToRight);
    await _itemsControllers[enteredItem]!.move(isDragToRight: isDragToRight);

    setState(() {
      final dragIndex = _items.indexOf(dragItem);
      final enteredIndex = _items.indexOf(enteredItem);
      _items.insert(enteredIndex, _items.removeAt(dragIndex));
    });
  }
}