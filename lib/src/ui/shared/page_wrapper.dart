import 'package:flutter/material.dart';

/// 给页面自动加上 Scaffold + AppBar（含返回箭头）
/// 用于原本没有 AppBar 的页面作为独立界面 push 时使用
class PageWithBackButton extends StatelessWidget {
  const PageWithBackButton({
    super.key,
    required this.title,
    required this.child,
    required this.isDarkMode,
    this.onBack,
  });

  final String title;
  final Widget child;
  final bool isDarkMode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF05070D) : const Color(0xFFF6F7FB),
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
        title: Text(
          title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: child,
    );
  }
}
