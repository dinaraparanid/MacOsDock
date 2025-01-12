import 'package:flutter/cupertino.dart';

extension GlobalPosition on GlobalKey {

  /// Determines [Widget] global position from its [RenderBox]
  Offset? get globalPosition {
    final box = currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero);
  }
}