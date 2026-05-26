/// 知识图谱节点
class KnowledgeNode {
  const KnowledgeNode({
    required this.id,
    required this.label,
    this.description = '',
    this.nodeType = KnowledgeNodeType.course,
    this.x = 0,
    this.y = 0,
  });

  final String id;
  final String label;
  final String description;
  final KnowledgeNodeType nodeType;
  final double x;
  final double y;

  KnowledgeNode copyWith({double? x, double? y}) {
    return KnowledgeNode(
      id: id,
      label: label,
      description: description,
      nodeType: nodeType,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

/// 知识图谱边（节点之间的关联）
class KnowledgeEdge {
  const KnowledgeEdge({
    required this.fromId,
    required this.toId,
    this.label = '',
  });

  final String fromId;
  final String toId;
  final String label;
}

/// 节点类型
enum KnowledgeNodeType {
  course, // 课程
  note, // 笔记
  flashCard, // 闪卡
  task, // 任务
}

/// 知识图谱数据
class KnowledgeGraphData {
  const KnowledgeGraphData({
    required this.nodes,
    required this.edges,
  });

  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;

  bool get isEmpty => nodes.isEmpty;
}
