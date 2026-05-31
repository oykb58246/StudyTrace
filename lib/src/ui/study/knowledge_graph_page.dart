import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/knowledge_node.dart';
import '../../services/knowledge_graph_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class KnowledgeGraphPage extends StatefulWidget {
  const KnowledgeGraphPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  final KnowledgeGraphService _service = KnowledgeGraphService();
  KnowledgeGraphData? _graphData;
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  KnowledgeNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    final courses = widget.controller.courseNames;
    _graphData = _service.buildGraph(
      tasks: widget.controller.studyTasks,
      notes: widget.controller.studyNotes,
      flashCards: widget.controller.flashCards,
      courses: courses,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_graphData == null || _graphData!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: StudyEmptyState(
            asset: AppAssets.uiRefreshFeatureKnowledge,
            title: '还没有知识图谱数据',
            message: '添加课程、笔记和闪卡后，会自动整理出知识点之间的关系。',
          ),
        ),
      );
    }

    return Stack(
      children: [
        // 图谱画布
        GestureDetector(
          onScaleStart: (details) {},
          onScaleUpdate: (details) {
            setState(() {
              _scale = (_scale * details.scale).clamp(0.3, 3.0);
              _panOffset += details.focalPointDelta;
            });
          },
          onTapUp: (details) {
            _handleTap(details.localPosition);
          },
          child: CustomPaint(
            painter: _GraphPainter(
              graph: _graphData!,
              panOffset: _panOffset,
              scale: _scale,
              selectedNodeId: _selectedNode?.id,
              isDarkMode: widget.isDarkMode,
              accent: widget.controller.primaryColor,
            ),
            size: Size.infinite,
          ),
        ),
        // 图例
        Positioned(
          left: 16,
          bottom: 16,
          child: _Legend(isDarkMode: widget.isDarkMode),
        ),
        // 选中节点详情
        if (_selectedNode != null)
          Positioned(
            right: 16,
            top: 16,
            child: _NodeDetailCard(
              node: _selectedNode!,
              isDarkMode: widget.isDarkMode,
              accent: widget.controller.primaryColor,
              onClose: () => setState(() => _selectedNode = null),
            ),
          ),
        // 缩放提示
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              _ZoomButton(
                icon: Icons.add,
                onTap: () => setState(() => _scale = (_scale * 1.3).clamp(0.3, 3.0)),
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                onTap: () => setState(() => _scale = (_scale / 1.3).clamp(0.3, 3.0)),
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.center_focus_strong,
                onTap: () => setState(() {
                  _panOffset = Offset.zero;
                  _scale = 1.0;
                }),
                isDarkMode: widget.isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleTap(Offset position) {
    if (_graphData == null) return;
    final adjustedPos = (position - _panOffset) / _scale;
    for (final node in _graphData!.nodes) {
      final nodeCenter = Offset(node.x, node.y);
      final distance = (adjustedPos - nodeCenter).distance;
      if (distance < 30) {
        setState(() => _selectedNode = node);
        return;
      }
    }
    setState(() => _selectedNode = null);
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.graph,
    required this.panOffset,
    required this.scale,
    required this.selectedNodeId,
    required this.isDarkMode,
    required this.accent,
  });

  final KnowledgeGraphData graph;
  final Offset panOffset;
  final double scale;
  final String? selectedNodeId;
  final bool isDarkMode;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(scale);

    // 绘制边
    final edgePaint = Paint()
      ..color = (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in graph.edges) {
      final from = _nodeById(edge.fromId);
      final to = _nodeById(edge.toId);
      if (from != null && to != null) {
        canvas.drawLine(
          Offset(from.x, from.y),
          Offset(to.x, to.y),
          edgePaint,
        );
      }
    }

    // 绘制节点
    for (final node in graph.nodes) {
      final isSelected = node.id == selectedNodeId;
      final nodeColor = _colorForType(node.nodeType);
      final radius = isSelected ? 22.0 : 18.0;

      // 节点背景
      final bgPaint = Paint()
        ..color = nodeColor.withValues(alpha: isSelected ? 0.9 : 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(node.x, node.y), radius, bgPaint);

      // 选中边框
      if (isSelected) {
        final borderPaint = Paint()
          ..color = accent
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(node.x, node.y), radius + 2, borderPaint);
      }

      // 节点图标（用简单文字代替）
      final iconPainter = TextPainter(
        text: TextSpan(
          text: _iconForType(node.nodeType),
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(node.x - iconPainter.width / 2,
            node.y - iconPainter.height / 2),
      );

      // 节点标签
      final labelPainter = TextPainter(
        text: TextSpan(
          text: node.label.length > 8
              ? '${node.label.substring(0, 8)}...'
              : node.label,
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF1D1B4B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: 100);
      labelPainter.paint(
        canvas,
        Offset(node.x - labelPainter.width / 2, node.y + radius + 4),
      );
    }

    canvas.restore();
  }

  Color _colorForType(KnowledgeNodeType type) {
    switch (type) {
      case KnowledgeNodeType.course:
        return const Color(0xFF4470E8);
      case KnowledgeNodeType.note:
        return const Color(0xFF4CB9FF);
      case KnowledgeNodeType.flashCard:
        return const Color(0xFFF8AA5B);
      case KnowledgeNodeType.task:
        return const Color(0xFF4BC4A1);
    }
  }

  KnowledgeNode? _nodeById(String id) {
    for (final node in graph.nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  String _iconForType(KnowledgeNodeType type) {
    switch (type) {
      case KnowledgeNodeType.course:
        return '📚';
      case KnowledgeNodeType.note:
        return '📝';
      case KnowledgeNodeType.flashCard:
        return '🃏';
      case KnowledgeNodeType.task:
        return '✅';
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        (isDarkMode ? const Color(0xFF1E2430) : Colors.white).withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: const Color(0xFF4470E8), label: '课程'),
          const SizedBox(height: 4),
          _LegendItem(color: const Color(0xFF4CB9FF), label: '笔记'),
          const SizedBox(height: 4),
          _LegendItem(color: const Color(0xFFF8AA5B), label: '闪卡'),
          const SizedBox(height: 4),
          _LegendItem(color: const Color(0xFF4BC4A1), label: '任务'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({
    required this.node,
    required this.isDarkMode,
    required this.accent,
    required this.onClose,
  });

  final KnowledgeNode node;
  final bool isDarkMode;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1E2430) : Colors.white;
    final textColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? AppColors.darkBody : AppColors.body;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 18, color: bodyColor),
              ),
            ],
          ),
          if (node.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              node.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _typeLabel(node.nodeType),
              style: TextStyle(color: accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(KnowledgeNodeType type) {
    switch (type) {
      case KnowledgeNodeType.course:
        return '课程';
      case KnowledgeNodeType.note:
        return '笔记';
      case KnowledgeNodeType.flashCard:
        return '闪卡';
      case KnowledgeNodeType.task:
        return '任务';
    }
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (isDarkMode ? const Color(0xFF1E2430) : Colors.white)
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon,
            size: 20,
            color: isDarkMode ? Colors.white70 : AppColors.body),
      ),
    );
  }
}
