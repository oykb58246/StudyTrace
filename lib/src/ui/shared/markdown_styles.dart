import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/app_theme.dart';
import 'local_image.dart';

const _markdownSecondary = Color(0xFF4F7EE8);

MarkdownStyleSheet buildStudyMarkdownStyleSheet({
  required bool isDarkMode,
  double bodyFontSize = 14,
  double bodyHeight = 1.6,
}) {
  final titleColor = AppColors.inkColor(isDarkMode);
  final bodyColor = AppColors.bodyColor(isDarkMode);
  final mutedColor = AppColors.mutedColor(isDarkMode);
  final codeBg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
  final inlineCodeBg =
      isDarkMode ? const Color(0xFF1A2332) : const Color(0xFFF0F2F5);

  return MarkdownStyleSheet(
    p: TextStyle(
      color: bodyColor,
      fontSize: bodyFontSize,
      height: bodyHeight,
    ),
    strong: TextStyle(
      color: titleColor,
      fontWeight: AppTypography.emphasis,
    ),
    em: TextStyle(
      color: bodyColor,
      fontStyle: FontStyle.italic,
    ),
    code: appCodeTextStyle(
      color: isDarkMode ? const Color(0xFF9DECF9) : _markdownSecondary,
      backgroundColor: inlineCodeBg,
      fontSize: bodyFontSize - 1,
      height: 1.45,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: codeBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE1E4E8),
      ),
    ),
    listBullet: TextStyle(color: titleColor),
    h1: TextStyle(
      color: titleColor,
      fontSize: bodyFontSize + 6,
      fontWeight: AppTypography.hero,
      height: 1.35,
    ),
    h2: TextStyle(
      color: titleColor,
      fontSize: bodyFontSize + 3,
      fontWeight: AppTypography.title,
      height: 1.4,
    ),
    h3: TextStyle(
      color: titleColor,
      fontSize: bodyFontSize + 1,
      fontWeight: AppTypography.title,
      height: 1.45,
    ),
    blockquote: TextStyle(
      color: mutedColor,
      fontSize: bodyFontSize,
      height: bodyHeight,
    ),
    blockquoteDecoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF1E2430) : const Color(0xFFF0F4FF),
      border: Border(
        left: BorderSide(
          color: isDarkMode ? const Color(0xFF4470E8) : const Color(0xFF7394F9),
          width: 3,
        ),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
  );
}

Widget buildStudyMarkdownImage(
  Uri uri,
  String? title,
  String? alt, {
  required bool isDarkMode,
}) {
  final source = _markdownImageSource(uri);
  final isRemote = source.startsWith('http://') || source.startsWith('https://');
  final image = isRemote
      ? Image.network(
          source,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _markdownImageError(isDarkMode),
        )
      : localImageFromPath(
          source,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _markdownImageError(isDarkMode),
        );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: image,
        ),
      ),
    ),
  );
}

String _markdownImageSource(Uri uri) {
  if (uri.scheme == 'file') {
    return uri.toFilePath(windows: true);
  }
  return Uri.decodeFull(uri.toString());
}

Widget _markdownImageError(bool isDarkMode) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF1E2430) : const Color(0xFFF2F5FC),
    ),
    child: Center(
      child: Icon(
        Icons.broken_image_rounded,
        color: AppColors.mutedColor(isDarkMode),
      ),
    ),
  );
}
