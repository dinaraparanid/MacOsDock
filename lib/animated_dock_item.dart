import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:macos_dock/dock.dart';
import 'package:macos_dock/dock_controller.dart';
import 'package:macos_dock/dock_item.dart';
import 'package:macos_dock/dock_item_controller.dart';

/// [DockItem] with self-controlled animations
/// (drag & drop and return to position)
final class AnimatedDockItem<T extends Object> extends StatefulWidget {

  /// Item's current index in global list of items
  final int index;

  /// Current item in global list of items
  final T item;

  /// Coefficient that is used to determine
  /// influence of pointer ratio on the item (translation and scale).
  ///
  /// Example: total = 5, index = 2 -> (2 + 0.5) / 5 = 0.5 (middle or 50%).
  /// If pointer is in middle, influence will be highest for this item.
  final double itemCenterRatio;

  /// [DockController] that manages animation states
  /// (pointer position and dragging item with its positions)
  final DockController<T> dockController;

  /// [DockItemController] for this item
  /// (manages animations' controllers and provides states)
  final DockItemController controller;

  /// Captures an event when mouse enters borders of an item
  final void Function(PointerEnterEvent) onEnter;

  /// Captures an event when mouse moves in bounds of an item
  final void Function(PointerHoverEvent) onHover;

  /// Content for the [DockItem]
  final Widget child;

  const AnimatedDockItem({
    super.key,
    required this.index,
    required this.item,
    required this.itemCenterRatio,
    required this.dockController,
    required this.controller,
    required this.onEnter,
    required this.onHover,
    required this.child,
  });

  @override
  State<StatefulWidget> createState() => _AnimatedDockItemState();
}

final class _AnimatedDockItemState<T extends Object>
  extends State<AnimatedDockItem<T>> with TickerProviderStateMixin {

  /// Duration to animate item's scale
  static const _scaleAnimDuration = Duration(milliseconds: 200);

  /// Duration to animate swap transition
  static const _swapAnimDuration = Duration(milliseconds: 150);

  /// Duration to animate dragged item return
  /// to its position on dock when mouse is released
  static const _returnAnimDuration = Duration(milliseconds: 300);

  /// Animation that is applied to return item to
  /// the required position in [Dock] when drag pointer is released
  Animation<Offset>? _returnAnimation;

  /// Notifies widget about events related to [widget.dockController]
  void _dockControllerListener() {
    // Notify widget if drag is started / stopped
    final isDragActive = widget.dockController.draggableItem != null;

    if (isDragActive != widget.controller.isDragActive) {
      setState(() => widget.controller.isDragActive = isDragActive);
    }
  }

  /// Notifies widget about events related to [widget.controller.returnController]
  void _returnControllerListener() {
    // Resets return animation and drag start/end positions
    if (widget.controller.returnController.isCompleted) {
      widget.controller.returnController.reset();
      _returnAnimation = null;
      widget.dockController.resetDragPositions();
      setState(() => widget.controller.isReturnAnimating = false);
    }
  }

  @override
  void initState() {
    super.initState();

    widget.controller.init(
      swapController: AnimationController(
        duration: _swapAnimDuration,
        vsync: this,
      ),
      returnController: AnimationController(
        duration: _returnAnimDuration,
        vsync: this,
      ),
    );

    widget.dockController.addListener(_dockControllerListener);
    widget.controller.returnController.addListener(_returnControllerListener);
  }

  @override
  void dispose() {
    super.dispose();
    widget.dockController.removeListener(_dockControllerListener);
    widget.controller.returnController.removeListener(_returnControllerListener);
    widget.controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = widget.item == widget.dockController.draggableItem;
    final content = _item();
    final contentWhenDrag = AnimatedSize(
      duration: _scaleAnimDuration,
      child: _dragShadow(child: content),
    );

    return AnimatedBuilder(
      key: widget.controller.widgetPositionKey,
      animation: widget.controller.returnController,
      builder: (context, _) => Transform.translate(
        // Translates item back to dock with animation.
        // In order to launch animation item is required
        // to still be dragged by widget.dockController.draggableItem
        offset: isDragging ? _returnAnimation?.value ?? Offset.zero : Offset.zero,
        child: Draggable<T>(
          data: widget.item,
          feedback: content,
          childWhenDragging: contentWhenDrag,
          onDragStarted: () {
            setState(() {
              // Cancel return ui
              widget.controller.isReturnAnimating = false;
              widget.dockController.setDraggableItem(widget.item);
            });

            // Should not be in setState
            // in order to finish return animation
            widget.dockController.setStartPositionFromKey(
              widget.controller.widgetPositionKey
            );
          },
          onDraggableCanceled: (_, offset) async {
            setState(() {
              // Setting end position and showing return ui
              widget.dockController.setDragEndPosition(offset);
              widget.controller.isReturnAnimating = true;
            });

            _returnAnimation = Tween(
              begin: widget.dockController.returnVector,
              end: Offset.zero,
            ).animate(widget.controller.returnController);

            // Launching return animation
            widget.controller.returnController.reset();
            await widget.controller.returnController.forward();

            // Clearing draggable item
            setState(() => widget.dockController.setDraggableItem(null));
          },
          child: contentWhenDrag,
        ),
      ),
    );
  }

  /// Content of [DockItem] with
  /// scale, Y translation and swap offsets applied
  Widget _item() => DockItem(
    key: Key('${widget.item}'),
    translationY: widget.controller.itemTranslationY(
      index: widget.index,
      itemCenterRatio: widget.itemCenterRatio,
      dockController: widget.dockController,
    ),
    scale: widget.controller.itemScale(
      index: widget.index,
      itemCenterRatio: widget.itemCenterRatio,
      dockController: widget.dockController,
    ),
    offset: widget.controller.animatedPosition
      .animate(widget.controller.swapController),
    onEnter: widget.onEnter,
    onHover: widget.onHover,
    child: widget.child,
  );

  /// Item content during drag / return events
  Widget _dragShadow({required Widget child}) {
    final isDragging = widget.dockController.draggableItem == widget.item;
    final isPointerInDock = widget.dockController.pointerRatio != null;

    // Return ui
    if (widget.controller.isReturnAnimating) {
      return child;
    }

    // Pointer is in dock, beneath item is empty space
    if (isDragging && isPointerInDock) {
      return Opacity(opacity: 0, child: child);
    }

    // Pointer is outside of dock, free space
    if (isDragging) {
      return SizedBox();
    }

    return child;
  }
}
