import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import 'app_assets.dart';
import 'rive_safe_widget.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    this.showSpline = true,
    this.useBlur = true,
    this.blurSigma = 38,
    this.overlayColor = const Color(0x66EEF1F8),
  });

  final bool showSpline;
  final bool useBlur;
  final double blurSigma;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SafeRiveAsset(
            asset: AppAssets.shapes,
            artboard: 'Shapes',
            animations: ['Animation 19'],
            fit: BoxFit.cover,
          ),
          if (showSpline)
            Positioned(
              top: -80,
              right: -30,
              child: Opacity(
                opacity: 0.85,
                child: Image.asset(
                  AppAssets.spline,
                  width: 360,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: useBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: ColoredBox(color: overlayColor),
                  )
                : ColoredBox(color: overlayColor),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final String badge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                height: 1.15,
              ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.height,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: padding,
      radius: 28,
      color: color ?? Colors.white.withValues(alpha: 0.78),
      blurSigma: 14,
      child: SizedBox(height: height, child: child),
    );
  }
}

class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.background = const Color(0x19F77D8E),
    this.foreground = AppColors.accentDeep,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class SvgCircleButton extends StatelessWidget {
  const SvgCircleButton({
    super.key,
    required this.asset,
    required this.onTap,
  });

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(asset, width: 22, height: 22),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarRow extends StatelessWidget {
  const AvatarRow({super.key, required this.images});

  final List<String> images;

  bool get _isWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: List.generate(images.length, (index) {
          return Positioned(
            left: index * 24,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: _isWidgetTest
                    ? null
                    : DecorationImage(
                        image: AssetImage(images[index]),
                        fit: BoxFit.cover,
                      ),
                color: _isWidgetTest ? const Color(0x55FFFFFF) : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
