import 'package:flutter/material.dart';

import 'common_widgets.dart';

/// 给页面自动加上 Scaffold + AppBar（含返回箭头）
/// 用于原本没有 AppBar 的页面作为独立界面 push 时使用
class PageWithBackButton extends StatelessWidget {
  const PageWithBackButton({
    super.key,
    required this.title,
    required this.child,
    required this.isDarkMode,
    this.onBack,
    this.titleIcon,
    this.accent,
    this.compactHeader = false,
  });

  final String title;
  final Widget child;
  final bool isDarkMode;
  final VoidCallback? onBack;
  final IconData? titleIcon;
  final Color? accent;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    if (compactHeader) {
      return Scaffold(
        backgroundColor: StudyUi.background(isDarkMode),
        body: StudyScreenBackground(
          isDarkMode: isDarkMode,
          accent: accent ?? StudyUi.pathBlue,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: StudyCompactHeaderScope(
                    enabled: true,
                    child: child,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                    onPressed: () {
                      if (onBack != null) {
                        onBack!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final content = StudyScreenBackground(
      isDarkMode: isDarkMode,
      accent: accent ?? StudyUi.pathBlue,
      child: StudyCompactHeaderScope(
        enabled: false,
        child: child,
      ),
    );

    return Scaffold(
      backgroundColor: StudyUi.background(isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleIcon != null) ...[
                    StudyGlassIconNode(
                      icon: titleIcon,
                      accent: accent ?? StudyUi.pathBlue,
                      size: 32,
                      iconSize: 16,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: content,
    );
  }
}
