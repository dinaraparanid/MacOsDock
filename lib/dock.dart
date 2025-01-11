import 'package:flutter/material.dart';
import 'package:macos_dock/dock_item.dart';

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

  static const _maxScaleFactor = 1.1;
  static const _maxYTranslation = -10.0;

  static const _scaleAnimDuration = Duration(milliseconds: 200);
  static const _swapAnimDuration = Duration(milliseconds: 100);
  static const _returnAnimDuration = Duration(milliseconds: 300);
  static const _dragResetDuration = Duration(milliseconds: 10);

  final dockKey = GlobalKey();
  late final Map<T, GlobalKey> _itemsKeys;

  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();

  double? _pointerRatio;
  int? _draggableIndex;

  var _positions = (Offset.zero, Offset.zero);

  late final AnimationController _transitionController;
  late final AnimationController _returnController;
  Animation<Offset>? _returnAnimation;
  late List<Tween<Offset>> _offsetAnimations;

  Tween<Offset> get _idleOffsetAnim => Tween<Offset>(
    begin: Offset.zero,
    end: Offset.zero,
  );

  Tween<Offset> get _forwardOffsetAnim => Tween<Offset>(
    begin: Offset.zero,
    end: Offset(1, 0),
  );

  Tween<Offset> get _backwardOffsetAnim => Tween<Offset>(
    begin: Offset.zero,
    end: Offset(-1, 0),
  );

  double itemScale(int index) => itemProperty(
    index: index,
    baseValue: 1.0,
    maxValue: _maxScaleFactor,
  );

  double itemTranslationY(int index) => itemProperty(
    index: index,
    baseValue: 0.0,
    maxValue: _maxYTranslation,
  );

  double itemProperty({
    required int index,
    required double baseValue,
    required double maxValue,
  }) {
    final pointerPos = _pointerRatio;
    if (pointerPos == null) return baseValue;
    final itemPos = (index + 0.5) / _items.length;
    final difference = (pointerPos - itemPos).abs();
    final ratio = 1 - difference;
    final res = baseValue * (1.0 - ratio) + maxValue * ratio;
    return res;
  }

  void initPositions() {
    _positions = (Offset.zero, Offset.zero);
  }

  Offset? findPosition(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero);
  }

  @override
  void initState() {
    super.initState();

    _itemsKeys = { for (var x in _items) x : GlobalKey() };

    _transitionController = AnimationController(
      duration: _swapAnimDuration,
      vsync: this,
    );

    _returnController = AnimationController(
      duration: _returnAnimDuration,
      vsync: this,
    );

    _offsetAnimations = List.generate(_items.length, (_) => _idleOffsetAnim);
  }

  @override
  void dispose() {
    super.dispose();
    _transitionController.dispose();
    _returnController.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pointerRatio != null ? _maxScaleFactor : 1.0,
    duration: _scaleAnimDuration,
    child: MouseRegion(
      key: dockKey,
      onEnter: (event) => _updatePointerState(position: event.position),
      onHover: (event) => _updatePointerState(position: event.position),
      onExit: (event) => setState(() => _pointerRatio = null),
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
            final key = _itemsKeys[item]!;
            final widget = _item(index: index, item: item);
            final widgetWhenDrag = AnimatedSize(
              duration: _scaleAnimDuration,
              child: _itemWhenDragged(index: index, child: widget),
            );

            final isDragging = index == _draggableIndex;

            return AnimatedBuilder(
              key: key,
              animation: _returnController,
              builder: (context, _) => Transform.translate(
                offset: isDragging ? _returnAnimation?.value ?? Offset.zero : Offset.zero,
                child: Draggable<T>(
                  data: item,
                  feedback: widget,
                  childWhenDragging: widgetWhenDrag,
                  onDragStarted: () {
                    setState(() => _draggableIndex = index);

                    final startingPosition = findPosition(key);
                    if (startingPosition != null) {
                      _positions = (startingPosition, _positions.$2);
                    }
                  },
                  onDraggableCanceled: (_, offset) async {
                    if (offset == _positions.$1) {
                      initPositions();
                      return;
                    }

                    setState(() {
                      _positions = (_positions.$1, offset);
                      _transitionController.reset();
                    });

                    final dragStartPos = _positions.$1;
                    final dragEndPos = offset;

                    _returnAnimation = Tween(
                      begin: dragEndPos - dragStartPos,
                      end: Offset.zero,
                    ).animate(_returnController);

                    _returnController.forward();

                    Future<void>.delayed(
                      _dragResetDuration,
                      () =>_draggableIndex = null,
                    );

                    Future<void>.delayed(_returnAnimDuration, () {
                      if (mounted) {
                        setState(() {
                          _returnController.reset();
                          _returnAnimation = null;
                          initPositions();
                        });
                      }
                    });
                  },
                  child: widgetWhenDrag,
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    ),
  );

  Widget _item({
    required int index,
    required T item,
  }) => DockItem(
    key: Key('$item'),
    translation: itemTranslationY(index),
    scale: itemScale(index),
    offset: _offsetAnimations[index].animate(_transitionController),
    onEnter: (event) async {
      _updatePointerState(position: event.position);
      await _updateListIfDragging(enteredIndex: index);
    },
    onHover: (event) => setState(() => _updatePointerState(
      position: event.position,
    )),
    child: widget.builder(item),
  );

  Widget _itemWhenDragged({
    required int index,
    required Widget child,
  }) {
    if (_draggableIndex == index && _returnAnimation?.isAnimating == true) {
      return child;
    }

    if (_draggableIndex == index && _pointerRatio != null) {
      return Opacity(opacity: 0, child: child);
    }

    if (_draggableIndex == index) {
      return SizedBox();
    }

    return child;
  }

  void _updatePointerState({required Offset position}) => setState(() {
    final box = dockKey.currentContext!.findRenderObject() as RenderBox;
    final startOffset = box.localToGlobal(Offset.zero).dx;
    final dockWidth = box.size.width;
    _pointerRatio = (position.dx - startOffset) / dockWidth;
  });

  Future<void> _updateListIfDragging({required int enteredIndex}) async {
    final dragIndex = _draggableIndex;
    if (dragIndex == null || dragIndex == enteredIndex) return;

    final isDragToRight = dragIndex < enteredIndex;

    _offsetAnimations = List.generate(_items.length, (_) => _idleOffsetAnim);
    _offsetAnimations[enteredIndex] = isDragToRight ? _backwardOffsetAnim : _forwardOffsetAnim;

    _transitionController.reset();
    await _transitionController.forward();

    setState(() {
      _offsetAnimations = List.generate(_items.length, (_) => _idleOffsetAnim);
      if (_draggableIndex != null) _draggableIndex = enteredIndex;
      _items.insert(enteredIndex, _items.removeAt(dragIndex));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final startingPosition = findPosition(_itemsKeys[_items[enteredIndex]]!);
        if (startingPosition != null) {
          _positions = (startingPosition, _positions.$2);
        }
      });
    });
  }
}