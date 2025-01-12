import 'package:flutter/cupertino.dart';

extension GlobalPosition on GlobalKey {
  Offset? get globalPosition {
    final box = currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero);
  }
}