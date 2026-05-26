import 'dart:convert';

/// 成就类型
enum AchievementType {
  /// 首次记录学习日志
  firstLog,

  /// 连续打卡 3 天
  streak3,

  /// 连续打卡 7 天
  streak7,

  /// 连续打卡 30 天
  streak30,

  /// 完成第一个任务
  firstTask,

  /// 完成 10 个任务
  task10,

  /// 完成 50 个任务
  task50,

  /// 生成首份周报
  firstReport,

  /// 创建 10 张闪卡
  flashCard10,

  /// 创建第一条笔记
  firstNote,

  /// 积分达到 100
  points100,

  /// 积分达到 500
  points500,

  /// 积分达到 1000
  points1000,

  /// 使用 AI 助手 10 次
  aiUsage10,
}

/// 成就定义
class Achievement {
  const Achievement({
    required this.type,
    required this.title,
    required this.description,
    required this.iconName,
    required this.points,
  });

  final AchievementType type;
  final String title;
  final String description;
  final String iconName;
  final int points;

  /// 所有成就定义
  static const List<Achievement> all = [
    Achievement(
      type: AchievementType.firstLog,
      title: '学习起步',
      description: '记录第一条学习日志',
      iconName: 'edit_note',
      points: 10,
    ),
    Achievement(
      type: AchievementType.firstTask,
      title: '任务新手',
      description: '完成第一个学习任务',
      iconName: 'task_alt',
      points: 15,
    ),
    Achievement(
      type: AchievementType.task10,
      title: '任务达人',
      description: '累计完成 10 个学习任务',
      iconName: 'emoji_events',
      points: 50,
    ),
    Achievement(
      type: AchievementType.task50,
      title: '任务大师',
      description: '累计完成 50 个学习任务',
      iconName: 'military_tech',
      points: 200,
    ),
    Achievement(
      type: AchievementType.streak3,
      title: '初见坚持',
      description: '连续学习打卡 3 天',
      iconName: 'local_fire_department',
      points: 20,
    ),
    Achievement(
      type: AchievementType.streak7,
      title: '一周不断',
      description: '连续学习打卡 7 天',
      iconName: 'whatshot',
      points: 50,
    ),
    Achievement(
      type: AchievementType.streak30,
      title: '月度学霸',
      description: '连续学习打卡 30 天',
      iconName: 'stars',
      points: 200,
    ),
    Achievement(
      type: AchievementType.firstReport,
      title: '周报初体验',
      description: '生成第一份学习周报',
      iconName: 'summarize',
      points: 15,
    ),
    Achievement(
      type: AchievementType.flashCard10,
      title: '闪卡收藏家',
      description: '累计创建 10 张知识闪卡',
      iconName: 'style',
      points: 30,
    ),
    Achievement(
      type: AchievementType.firstNote,
      title: '笔记启蒙',
      description: '创建第一条学习笔记',
      iconName: 'menu_book',
      points: 10,
    ),
    Achievement(
      type: AchievementType.points100,
      title: '百分选手',
      description: '累计积分达到 100',
      iconName: 'toll',
      points: 30,
    ),
    Achievement(
      type: AchievementType.points500,
      title: '五百分俱乐部',
      description: '累计积分达到 500',
      iconName: 'workspace_premium',
      points: 100,
    ),
    Achievement(
      type: AchievementType.points1000,
      title: '千分大神',
      description: '累计积分达到 1000',
      iconName: 'diamond',
      points: 300,
    ),
    Achievement(
      type: AchievementType.aiUsage10,
      title: 'AI 好伙伴',
      description: '使用 AI 助手 10 次',
      iconName: 'smart_toy',
      points: 20,
    ),
  ];

  static Achievement? findByType(AchievementType type) {
    for (final a in all) {
      if (a.type == type) return a;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'description': description,
        'iconName': iconName,
        'points': points,
      };
}

/// 已解锁的成就记录
class UnlockedAchievement {
  const UnlockedAchievement({
    required this.type,
    required this.unlockedAt,
  });

  final AchievementType type;
  final DateTime unlockedAt;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) {
    return UnlockedAchievement(
      type: AchievementType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AchievementType.firstLog,
      ),
      unlockedAt: DateTime.tryParse(json['unlockedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// 游戏化状态
class GamificationState {
  const GamificationState({
    this.totalPoints = 0,
    this.unlockedAchievements = const [],
  });

  final int totalPoints;
  final List<UnlockedAchievement> unlockedAchievements;

  bool isUnlocked(AchievementType type) {
    return unlockedAchievements.any((u) => u.type == type);
  }

  GamificationState copyWith({
    int? totalPoints,
    List<UnlockedAchievement>? unlockedAchievements,
  }) {
    return GamificationState(
      totalPoints: totalPoints ?? this.totalPoints,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'unlockedAchievements':
            unlockedAchievements.map((u) => u.toJson()).toList(),
      };

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    return GamificationState(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      unlockedAchievements: (json['unlockedAchievements'] as List?)
              ?.map((e) =>
                  UnlockedAchievement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
