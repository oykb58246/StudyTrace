enum NoteBlockType {
  text,
  heading,
  bullet,
  markdown,
  image,
  code,
  divider,
  todo;

  String get label {
    switch (this) {
      case NoteBlockType.text:
        return '正文';
      case NoteBlockType.heading:
        return '标题';
      case NoteBlockType.bullet:
        return '列表';
      case NoteBlockType.markdown:
        return 'Markdown';
      case NoteBlockType.image:
        return '图片';
      case NoteBlockType.code:
        return '代码';
      case NoteBlockType.divider:
        return '分割线';
      case NoteBlockType.todo:
        return '待办';
    }
  }
}

class NoteBlock {
  final String id;
  final NoteBlockType type;
  final String content;
  final bool checked;

  const NoteBlock({
    required this.id,
    this.type = NoteBlockType.text,
    this.content = '',
    this.checked = false,
  });

  NoteBlock copyWith({
    NoteBlockType? type,
    String? content,
    bool? checked,
  }) =>
      NoteBlock(
        id: id,
        type: type ?? this.type,
        content: content ?? this.content,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        if (checked) 'checked': checked,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
        id: json['id'] as String? ?? '',
        type: NoteBlockType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NoteBlockType.text,
        ),
        content: json['content'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
      );
}
