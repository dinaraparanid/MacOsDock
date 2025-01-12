import 'package:flutter/material.dart';
import 'package:macos_dock/dock_controller.dart';

final class DockItemController {
  /// Scale factor applied for items as the highest bound of scale
  static const _maxScaleFactor = 1.1;

  /// Highest Y axis translation
  static const _maxYTranslation = -10.0;

  static final _idleAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset.zero,
  );

  static final _forwardAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset(1, 0),
  );

  static final _backwardAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset(-1, 0),
  );

  final widgetPositionKey = GlobalKey();

  AnimationController? _swapController;
  AnimationController get swapController => _swapController!;

  AnimationController? _returnController;
  AnimationController get returnController => _returnController!;

  late var _animatedPosition = _idleAnimOffset;
  Tween<Offset> get animatedPosition => _animatedPosition;

  bool isDragActive = false;
  bool isReturnAnimating = false;

  void init({
    required AnimationController swapController,
    required AnimationController returnController,
    required DockController dockController,
  }) {
    _swapController = swapController;
    _returnController = returnController;
  }

  Future<void> move({required bool isDragToRight}) async {
    _animatedPosition = isDragToRight ? _backwardAnimOffset : _forwardAnimOffset;
    swapController.reset();
    await swapController.forward();
    _animatedPosition = _idleAnimOffset;
  }

  double itemScale({
    required int index,
    required double itemCenterRatio,
    required DockController dockController,
  }) => _itemProperty(
    index: index,
    itemCenterRatio: itemCenterRatio,
    baseValue: 1.0,
    maxValue: _maxScaleFactor,
    dockController: dockController,
  );

  double itemTranslationY({
    required int index,
    required double itemCenterRatio,
    required DockController dockController,
  }) => _itemProperty(
    index: index,
    itemCenterRatio: itemCenterRatio,
    baseValue: 0.0,
    maxValue: _maxYTranslation,
    dockController: dockController,
  );

  double _itemProperty({
    required int index,
    required double itemCenterRatio,
    required double baseValue,
    required double maxValue,
    required DockController dockController,
  }) {
    final pointerRatio = dockController.pointerRatio;
    if (pointerRatio == null) return baseValue;
    final difference = (pointerRatio - itemCenterRatio).abs();
    final ratio = 1 - difference;
    final res = baseValue * (1.0 - ratio) + maxValue * ratio;
    return res;
  }

  void dispose() {
    _swapController?.dispose();
    _swapController = null;

    _returnController?.dispose();
    _returnController = null;
  }
}