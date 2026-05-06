import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide LinearGradient;

typedef RiveInitCallback = void Function(Artboard artboard);

class SafeRiveAsset extends StatelessWidget {
  const SafeRiveAsset({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.fallback,
    this.artboard,
    this.animations,
    this.stateMachines,
    this.controllers,
    this.onInit,
  });

  final String asset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Widget? fallback;
  final String? artboard;
  final List<String>? animations;
  final List<String>? stateMachines;
  final List<RiveAnimationController>? controllers;
  final RiveInitCallback? onInit;

  bool get _isWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context) {
    if (_isWidgetTest) {
      return SizedBox(
        width: width,
        height: height,
        child: fallback ??
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0x33FFFFFF), Color(0x11000000)],
                ),
              ),
            ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: RiveAnimation.asset(
        asset,
        artboard: artboard,
        animations: animations ?? const [],
        stateMachines: stateMachines ?? const [],
        controllers: controllers ?? const [],
        fit: fit,
        alignment: alignment,
        onInit: onInit,
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 30,
    this.color = const Color(0xCCFFFFFF),
    this.blurSigma = 18,
    this.enableBlur = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final double blurSigma;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2217203A),
            blurRadius: 24,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );
  }
}
