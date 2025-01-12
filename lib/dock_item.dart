import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Dock item representation.
/// Captures mouse events and handles them via [onEnter] and [onHover].
/// Allows to be scaled via [scale] (e.g. when mouse approaches),
/// translated on Y axis via [translationY] (e.g. when mouse approaches),
/// moved via [offset] (e.g. for drag & drop of nearest items)
final class DockItem<T> extends StatelessWidget {
  static const _animationDuration = Duration(milliseconds: 200);

  /// Y axis translation
  final double translationY;

  /// Item scale
  final double scale;

  /// Animated temporary move offset (for DND animation)
  final Animation<Offset> offset;

  /// Captures an event when mouse enters borders of an item
  final void Function(PointerEnterEvent) onEnter;

  /// Captures an event when mouse moves in bounds of an item
  final void Function(PointerHoverEvent) onHover;

  /// Item content itself
  final Widget child;

  const DockItem({
    super.key,
    this.translationY = 0,
    this.scale = 1.0,
    required this.offset,
    required this.onEnter,
    required this.onHover,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: offset,
    child: MouseRegion(
      onEnter: onEnter,
      onHover: onHover,
      child: Wrap(children: [
        AnimatedContainer(
          duration: _animationDuration,
          transform: Matrix4.identity()..translate(0.0, translationY, 0.0),
          alignment: Alignment.center,
          padding: EdgeInsets.all(8),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        ),
      ]),
    ),
  );
}
