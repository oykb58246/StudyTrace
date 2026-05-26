import '../models/achievement.dart';
import '../models/study_log_item.dart';
import '../models/study_task_item.dart';
import '../models/study_note.dart';
import '../models/ai_flash_card.dart';
import '../models/weekly_report_item.dart';

/// 积分规则
class _PointRules {
  static const int taskCompleted = 10;
  static const int logRecorded = 5;
  static const int noteCreated = 3;
  static const int flashCardCreated = 2;
  static const int reportGenerated = 10;
  static const int streakBonus = 5; // 每天连续打卡额外奖励
}

/// 游戏化服务：积分计算和成就检测
class GamificationService {
  GamificationService();

  /// 计算完成任务应得积分
  int pointsForTask(StudyTaskStatus status) {
    if (status == StudyTaskStatus.completed) return _PointRules.taskCompleted;
    return 0;
  }

  /// 计算记录日志应得积分
  int pointsForLog() => _PointRules.logRecorded;

  /// 计算创建笔记应得积分
  int pointsForNote() => _PointRules.noteCreated;

  /// 计算创建闪卡应得积分
  int pointsForFlashCard() => _PointRules.flashCardCreated;

  /// 计算生成周报应得积分
  int pointsForReport() => _PointRules.reportGenerated;

  /// 计算连续打卡奖励积分
  int pointsForStreak(int streakDays) {
    if (streakDays <= 1) return 0;
    return _PointRules.streakBonus * (streakDays - 1);
  }

  /// 检测并返回新解锁的成就列表
  List<Achievement> checkAchievements({
    required GamificationState currentState,
    required List<StudyTaskItem> tasks,
    required List<StudyLogItem> logs,
    required List<StudyNote> notes,
    required List<AiFlashCard> flashCards,
    required List<WeeklyReportItem> reports,
    required int streakDays,
    required int aiUsageCount,
  }) {
    final newAchievements = <Achievement>[];
    final unlocked = currentState.unlockedAchievements
        .map((u) => u.type)
        .toSet();

    void check(AchievementType type) {
      if (!unlocked.contains(type)) {
        final achievement = Achievement.findByType(type);
        if (achievement != null) newAchievements.add(achievement);
      }
    }

    // 首次记录日志
    if (logs.isNotEmpty) check(AchievementType.firstLog);

    // 完成任务数
    final completedTasks =
        tasks.where((t) => t.status == StudyTaskStatus.completed).length;
    if (completedTasks >= 1) check(AchievementType.firstTask);
    if (completedTasks >= 10) check(AchievementType.task10);
    if (completedTasks >= 50) check(AchievementType.task50);

    // 连续打卡
    if (streakDays >= 3) check(AchievementType.streak3);
    if (streakDays >= 7) check(AchievementType.streak7);
    if (streakDays >= 30) check(AchievementType.streak30);

    // 周报
    if (reports.isNotEmpty) check(AchievementType.firstReport);

    // 闪卡
    if (flashCards.length >= 10) check(AchievementType.flashCard10);

    // 笔记
    if (notes.isNotEmpty) check(AchievementType.firstNote);

    // 积分里程碑
    if (currentState.totalPoints >= 100) check(AchievementType.points100);
    if (currentState.totalPoints >= 500) check(AchievementType.points500);
    if (currentState.totalPoints >= 1000) check(AchievementType.points1000);

    // AI 使用
    if (aiUsageCount >= 10) check(AchievementType.aiUsage10);

    return newAchievements;
  }

  /// 获取成就对应的 Material Icon
  static String iconDataName(String iconName) => iconName;
}
