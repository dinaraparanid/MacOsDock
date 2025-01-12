import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:macos_dock/dock_controller.dart';
import 'package:macos_dock/dock_item.dart';
import 'package:macos_dock/dock_item_controller.dart';

final class AnimatedDockItem<T extends Object> extends StatefulWidget {
  final int index;
  final T item;
  final double itemCenterRatio;
  final DockController<T> dockController;
  final DockItemController controller;

  /// Captures an event when mouse enters borders of an item
  final void Function(PointerEnterEvent) onEnter;

  /// Captures an event when mouse moves in bounds of an item
  final void Function(PointerHoverEvent) onHover;

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

final class _AnimatedDockItemState<T extends Object> extends State<AnimatedDockItem<T>>
  with TickerProviderStateMixin {

  /// Duration to animate item's scale
  static const _scaleAnimDuration = Duration(milliseconds: 200);

  /// Duration to animate swap transition
  static const _swapAnimDuration = Duration(milliseconds: 150);

  /// Duration to animate dragged item return
  /// to its position on dock when mouse is released
  static const _returnAnimDuration = Duration(milliseconds: 300);

  Animation<Offset>? _returnAnimation;

  void _dockControllerListener() {
    final isDragActive = widget.dockController.draggableItem != null;

    if (isDragActive != widget.controller.isDragActive) {
      setState(() => widget.controller.isDragActive = isDragActive);
    }
  }

  void _returnControllerListener() {
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
      dockController: widget.dockController,
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
  Widget build(BuildContext context) => _animatedItem();

  Widget _animatedItem() {
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
        offset: isDragging ? _returnAnimation?.value ?? Offset.zero : Offset.zero,
        child: Draggable<T>(
          data: widget.item,
          feedback: content,
          childWhenDragging: contentWhenDrag,
          onDragStarted: () {
            setState(() {
              widget.controller.isReturnAnimating = false;
              widget.dockController.setDraggableItem(widget.item);
            });
            widget.dockController.setStartPositionFromKey(
              widget.controller.widgetPositionKey
            );
          },
          onDraggableCanceled: (_, offset) async {
            setState(() {
              widget.dockController.setDragEndPosition(offset);
              widget.controller.isReturnAnimating = true;
            });

            _returnAnimation = Tween(
              begin: widget.dockController.returnPosition,
              end: Offset.zero,
            ).animate(widget.controller.returnController);

            widget.controller.returnController.reset();
            await widget.controller.returnController.forward();
            setState(() => widget.dockController.setDraggableItem(null));
          },
          child: contentWhenDrag,
        ),
      ),
    );
  }

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

  Widget _dragShadow({required Widget child}) {
    final isDragging = widget.dockController.draggableItem == widget.item;
    final isPointerInDock = widget.dockController.pointerRatio != null;

    if (widget.controller.isReturnAnimating) {
      return child;
    }

    if (isDragging && isPointerInDock) {
      return Opacity(opacity: 0, child: child);
    }

    if (isDragging) {
      return SizedBox();
    }

    return child;
  }
}
