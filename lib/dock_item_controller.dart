import 'package:flutter/material.dart';
import 'package:macos_dock/dock_controller.dart';

/// Manages items' animations controllers (swap and return)
final class DockItemController {
  /// Scale factor applied for items as the highest bound of scale
  static const _maxScaleFactor = 1.1;

  /// Highest Y axis translation
  static const _maxYTranslation = -10.0;

  /// No movement animation
  static final _idleAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset.zero,
  );

  /// Move to right animation
  static final _forwardAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset(1, 0),
  );

  /// Move to left animation
  static final _backwardAnimOffset = Tween<Offset>(
    begin: Offset.zero,
    end: Offset(-1, 0),
  );

  /// [GlobalKey] to determine item's positions
  final widgetPositionKey = GlobalKey();

  AnimationController? _swapController;

  /// Item's swap animation controller
  AnimationController get swapController => _swapController!;

  AnimationController? _returnController;

  /// Item's return animation controller
  AnimationController get returnController => _returnController!;

  late var _animatedPosition = _idleAnimOffset;

  /// Currently applied swap animation (idle, forward or backward)
  Tween<Offset> get animatedPosition => _animatedPosition;

  /// Is drag in the active stage
  bool isDragActive = false;

  /// Is item required to show 'return ui'
  bool isReturnAnimating = false;

  /// Initialises animations controllers
  void init({
    required AnimationController swapController,
    required AnimationController returnController,
  }) {
    _swapController = swapController;
    _returnController = returnController;
  }

  /// Launches swap movement animation
  /// (either backward or forward according to [isDragToRight]
  Future<void> move({required bool isDragToRight}) async {
    _animatedPosition = isDragToRight ? _backwardAnimOffset : _forwardAnimOffset;
    swapController.reset();
    await swapController.forward();
    _animatedPosition = _idleAnimOffset;
  }

  /// Calculates item's scale
  /// according to its position ([itemCenterRatio])
  /// and pointer ratio from [dockController]
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

  /// Calculates item's Y translation
  /// according to its position ([itemCenterRatio])
  /// and pointer ratio from [dockController]
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

  /// Calculates item's property in given constraints
  /// according to its position ([itemCenterRatio])
  /// and pointer ratio from [dockController]
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

  /// Clears animations controllers
  void dispose() {
    _swapController?.dispose();
    _swapController = null;

    _returnController?.dispose();
    _returnController = null;
  }
}