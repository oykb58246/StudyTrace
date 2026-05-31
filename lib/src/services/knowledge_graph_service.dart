import 'dart:math' as dart_math;
import 'dart:ui';

import '../models/knowledge_node.dart';
import '../models/study_task_item.dart';
import '../models/study_note.dart';
import '../models/ai_flash_card.dart';

/// 知识图谱服务：从学习数据中提取知识点关系
class KnowledgeGraphService {
  KnowledgeGraphService();

  /// 从课程、笔记、闪卡、任务中构建知识图谱
  KnowledgeGraphData buildGraph({
    required List<StudyTaskItem> tasks,
    required List<StudyNote> notes,
    required List<AiFlashCard> flashCards,
    required List<String> courses,
  }) {
    final nodes = <KnowledgeNode>[];
    final edges = <KnowledgeEdge>[];
    final addedIds = <String>{};

    // 添加课程节点
    for (final course in courses) {
      final id = 'course_$course';
      if (addedIds.add(id)) {
        nodes.add(KnowledgeNode(
          id: id,
          label: course,
          nodeType: KnowledgeNodeType.course,
        ));
      }
    }

    // 添加笔记节点并关联到课程
    for (final note in notes) {
      final id = 'note_${note.id}';
      if (addedIds.add(id)) {
        nodes.add(KnowledgeNode(
          id: id,
          label: note.title,
          description: note.content,
          nodeType: KnowledgeNodeType.note,
        ));
        if (note.courseName.isNotEmpty) {
          edges.add(KnowledgeEdge(
            fromId: 'course_${note.courseName}',
            toId: id,
          ));
        }
      }
    }

    // 添加闪卡节点并关联到课程
    for (final card in flashCards) {
      final id = 'card_${card.id}';
      if (addedIds.add(id)) {
        nodes.add(KnowledgeNode(
          id: id,
          label: card.question,
          description: card.answer,
          nodeType: KnowledgeNodeType.flashCard,
        ));
        if (card.groupName.isNotEmpty) {
          edges.add(KnowledgeEdge(
            fromId: 'course_${card.groupName}',
            toId: id,
          ));
        }
      }
    }

    // 添加任务节点并关联到课程
    for (final task in tasks) {
      final id = 'task_${task.id}';
      if (addedIds.add(id)) {
        nodes.add(KnowledgeNode(
          id: id,
          label: task.title,
          nodeType: KnowledgeNodeType.task,
        ));
        if (task.courseName.isNotEmpty) {
          edges.add(KnowledgeEdge(
            fromId: 'course_${task.courseName}',
            toId: id,
          ));
        }
      }
    }

    // 使用力导向布局计算位置
    _applyForceLayout(nodes, edges);

    return KnowledgeGraphData(nodes: nodes, edges: edges);
  }

  /// 简单的力导向布局算法
  void _applyForceLayout(List<KnowledgeNode> nodes, List<KnowledgeEdge> edges) {
    if (nodes.isEmpty) return;

    final nodePositions = <String, Offset>{};
    final centerX = 400.0;
    final centerY = 400.0;

    // 初始位置：课程节点在中心，其他节点围绕
    final courseNodes =
        nodes.where((n) => n.nodeType == KnowledgeNodeType.course).toList();

    // 课程节点放在中心区域
    for (var i = 0; i < courseNodes.length; i++) {
      final angle = (2 * dart_math.pi * i) / courseNodes.length;
      final radius = 120.0;
      nodePositions[courseNodes[i].id] = Offset(
        centerX + radius * dart_math.cos(angle),
        centerY + radius * dart_math.sin(angle),
      );
    }

    // 其他节点围绕各自的课程节点
    final courseChildren = <String, List<KnowledgeNode>>{};
    for (final edge in edges) {
      final fromNode = _nodeById(nodes, edge.fromId);
      final toNode = _nodeById(nodes, edge.toId);
      if (fromNode != null && toNode != null) {
        courseChildren
            .putIfAbsent(edge.fromId, () => [])
            .add(toNode);
      }
    }

    for (final entry in courseChildren.entries) {
      final parentPos = nodePositions[entry.key];
      if (parentPos == null) continue;
      final children = entry.value;
      for (var i = 0; i < children.length; i++) {
        final angle = (2 * dart_math.pi * i) / children.length;
        final radius = 80.0 + (i % 3) * 30.0;
        nodePositions[children[i].id] = Offset(
          parentPos.dx + radius * dart_math.cos(angle),
          parentPos.dy + radius * dart_math.sin(angle),
        );
      }
    }

    // 没有边连接的节点放在底部
    for (final node in nodes) {
      if (!nodePositions.containsKey(node.id)) {
        final idx = nodes.indexOf(node);
        nodePositions[node.id] = Offset(
          100.0 + (idx % 5) * 150.0,
          600.0 + (idx ~/ 5) * 80.0,
        );
      }
    }

    // 更新节点位置
    for (var i = 0; i < nodes.length; i++) {
      final pos = nodePositions[nodes[i].id];
      if (pos != null) {
        nodes[i] = nodes[i].copyWith(x: pos.dx, y: pos.dy);
      }
    }
  }

  KnowledgeNode? _nodeById(List<KnowledgeNode> nodes, String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}
