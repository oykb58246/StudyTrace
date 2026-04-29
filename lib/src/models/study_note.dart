import 'note_block.dart';

class StudyNote {
  final String id;
  final String title;
  final String content;
  final String courseName;
  final String? parentId;
  final bool isFolder;
  final List<NoteBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyNote({
    required this.id,
    required this.title,
    required this.content,
    this.courseName = '',
    this.parentId,
    this.isFolder = false,
    this.blocks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  StudyNote copyWith({
    String? title,
    String? content,
    String? courseName,
    String? parentId,
    bool? isFolder,
    List<NoteBlock>? blocks,
    DateTime? updatedAt,
  }) =>
      StudyNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        courseName: courseName ?? this.courseName,
        parentId: parentId ?? this.parentId,
        isFolder: isFolder ?? this.isFolder,
        blocks: blocks ?? this.blocks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'courseName': courseName,
        if (parentId != null) 'parentId': parentId,
        if (isFolder) 'isFolder': isFolder,
        if (blocks.isNotEmpty)
          'blocks': blocks.map((b) => b.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    final List<NoteBlock> blocks = [];
    if (rawBlocks is List) {
      for (final item in rawBlocks) {
        if (item is Map<String, dynamic>) {
          blocks.add(NoteBlock.fromJson(item));
        }
      }
    }
    return StudyNote(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      courseName: (json['courseName'] as String?) ?? '',
      parentId: json['parentId'] as String?,
      isFolder: json['isFolder'] as bool? ?? false,
      blocks: blocks,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
