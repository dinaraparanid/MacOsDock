import 'package:flutter/material.dart';
import 'package:macos_dock/dock_item.dart';
import 'package:macos_dock/utils/global_position.dart';

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

  /// Highest Y axis translation
  static const _maxYTranslation = -10.0;

  /// Duration to animate dock's and items' scales
  static const _scaleAnimDuration = Duration(milliseconds: 200);

  /// Duration to animate swap transition
  static const _swapAnimDuration = Duration(milliseconds: 100);

  /// Duration to animate dragged item return
  /// to its position on dock when mouse is released
  static const _returnAnimDuration = Duration(milliseconds: 300);

  final dockKey = GlobalKey();

  /// [T] items being manipulated.
  late final _items = widget.items.toList();
  late final _itemsKeys = { for (var x in _items) x : GlobalKey() };

  double? _pointerRatio;
  int? _draggableIndex;

  var _dragStartPosition = Offset.zero;
  var _dragEndPosition = Offset.zero;

  late final _swapController = AnimationController(
    duration: _swapAnimDuration,
    vsync: this,
  );

  late final _returnController = AnimationController(
    duration: _returnAnimDuration,
    vsync: this,
  );

  Animation<Offset>? _returnAnimation;
  late var _offsetAnimations = _idleAnimatedOffsets;

  Tween<Offset> get _idleAnimOffset => Tween<Offset>(
    begin: Offset.zero,
    end: Offset.zero,
  );

  Tween<Offset> get _forwardAnimOffset => Tween<Offset>(
    begin: Offset.zero,
    end: Offset(1, 0),
  );

  Tween<Offset> get _backwardAnimOffset => Tween<Offset>(
    begin: Offset.zero,
    end: Offset(-1, 0),
  );

  List<Tween<Offset>> get _idleAnimatedOffsets =>
    List.generate(_items.length, (_) => _idleAnimOffset);

  double _itemScale(int index) => _itemProperty(
    index: index,
    baseValue: 1.0,
    maxValue: _maxScaleFactor,
  );

  double _itemTranslationY(int index) => _itemProperty(
    index: index,
    baseValue: 0.0,
    maxValue: _maxYTranslation,
  );

  double _itemProperty({
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

  void _setStartPositionFromKey(GlobalKey key) {
    final startingPosition = key.globalPosition;
    if (startingPosition != null) {
      _dragStartPosition = startingPosition;
    }
  }

  void _resetPositions() {
    _dragStartPosition = Offset.zero;
    _dragEndPosition = Offset.zero;
  }

  void _resetReturnController() {
    if (_returnController.isCompleted) {
      _returnController.reset();
      _returnAnimation = null;
      _resetPositions();
    }
  }

  @override
  void initState() {
    super.initState();
    _returnController.addListener(_resetReturnController);
  }

  @override
  void dispose() {
    super.dispose();
    _returnController.removeListener(_resetReturnController);
    _swapController.dispose();
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
            return _animatedItem(index: index, item: item);
          }).toList(growable: false),
        ),
      ),
    ),
  );

  Widget _animatedItem({
    required int index,
    required T item,
  }) {
    final isDragging = index == _draggableIndex;
    final key = _itemsKeys[item]!;
    final content = _item(index: index, item: item);
    final contentWhenDrag = AnimatedSize(
      duration: _scaleAnimDuration,
      child: _dragShadow(index: index, child: content),
    );

    return AnimatedBuilder(
      key: key,
      animation: _returnController,
      builder: (context, _) => Transform.translate(
        offset: isDragging ? _returnAnimation?.value ?? Offset.zero : Offset.zero,
        child: Draggable<T>(
          data: item,
          feedback: content,
          childWhenDragging: contentWhenDrag,
          onDragStarted: () {
            setState(() => _draggableIndex = index);
            _setStartPositionFromKey(key);
          },
          onDraggableCanceled: (_, offset) {
            setState(() {
              _dragEndPosition = offset;
              _swapController.reset();
            });

            _returnAnimation = Tween(
              begin: _dragEndPosition - _dragStartPosition,
              end: Offset.zero,
            ).animate(_returnController);

            _returnController.forward();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _draggableIndex = null;
            });
          },
          child: contentWhenDrag,
        ),
      ),
    );
  }

  Widget _item({
    required int index,
    required T item,
  }) => DockItem(
    key: Key('$item'),
    translationY: _itemTranslationY(index),
    scale: _itemScale(index),
    offset: _offsetAnimations[index].animate(_swapController),
    onEnter: (event) {
      _updatePointerState(position: event.position);
      _updateListIfDragging(enteredIndex: index);
    },
    onHover: (event) => _updatePointerState(position: event.position),
    child: widget.builder(item),
  );

  Widget _dragShadow({
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

    _offsetAnimations = _idleAnimatedOffsets;
    _offsetAnimations[enteredIndex] = isDragToRight
      ? _backwardAnimOffset : _forwardAnimOffset;

    _swapController.reset();
    await _swapController.forward();

    setState(() {
      _offsetAnimations = _idleAnimatedOffsets;

      if (_draggableIndex != null) {
        _draggableIndex = enteredIndex;
      }

      _items.insert(enteredIndex, _items.removeAt(dragIndex));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setStartPositionFromKey(_itemsKeys[_items[enteredIndex]]!);
    });
  }
}