import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/trash_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.trashItems;
        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return RefreshIndicator(
          onRefresh: () async => controller.notifyListeners(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '回收站',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (items.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _emptyAll(context),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('清空回收站'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF6850),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '删除的数据会移入这里，支持恢复或永久删除。',
                style: TextStyle(color: bodyColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                StudyCard(
                  color: isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Text(
                    '回收站为空。',
                    style: TextStyle(color: bodyColor, height: 1.55),
                  ),
                )
              else
                ...items.map((item) => _TrashCard(
                      item: item,
                      isDarkMode: isDarkMode,
                      bodyColor: bodyColor,
                      textColor: textColor,
                      controller: controller,
                    )),
            ],
          ),
        );
      },
    );
  }

  void _emptyAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('确定要永久删除回收站中的所有内容吗？该操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.emptyTrash();
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF6850)),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.item,
    required this.isDarkMode,
    required this.bodyColor,
    required this.textColor,
    required this.controller,
  });

  final TrashItem item;
  final bool isDarkMode;
  final Color bodyColor;
  final Color textColor;
  final AppDataController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StudyCard(
        color: isDarkMode
            ? const Color(0xFF242B37).withValues(alpha: 0.9)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF6850).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.entityTypeLabel,
                        style: const TextStyle(
                          color: Color(0xFFEF6850),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '删除于 ${_fmtTime(item.deletedAt)}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restore_rounded, size: 20),
              tooltip: '恢复',
              color: const Color(0xFF4BC4A1),
              onPressed: () => controller.restoreFromTrash(item.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              tooltip: '永久删除',
              color: const Color(0xFFEF6850),
              onPressed: () => _deletePermanently(context),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePermanently(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('永久删除「${item.title}」'),
        content: const Text('删除后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteTrashItemPermanently(item.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF6850)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
