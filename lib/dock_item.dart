import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

final class DockItem<T> extends StatelessWidget {
  static const _animationDuration = Duration(milliseconds: 200);

  final double translation;
  final double scale;
  final Animation<Offset> offset;
  final void Function(PointerEnterEvent) onEnter;
  final void Function(PointerHoverEvent) onHover;
  final Widget child;

  const DockItem({
    super.key,
    this.translation = 0,
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
          transform: Matrix4.identity()..translate(0.0, translation, 0.0),
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
