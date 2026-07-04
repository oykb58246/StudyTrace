import '../models/ai_action_record.dart';
import '../models/ai_flash_card.dart';
import '../models/learning_moment.dart';
import '../models/note_block.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_sub_task_item.dart';
import '../models/study_task_item.dart';
import '../models/weekly_report_item.dart';

class FinalDemoSeed {
  const FinalDemoSeed({
    required this.courses,
    required this.logs,
    required this.tasks,
    required this.notes,
    required this.flashCards,
    required this.reports,
    required this.actionRecords,
    required this.moments,
  });

  final List<String> courses;
  final List<StudyLogItem> logs;
  final List<StudyTaskItem> tasks;
  final List<StudyNote> notes;
  final List<AiFlashCard> flashCards;
  final List<WeeklyReportItem> reports;
  final List<AiActionRecord> actionRecords;
  final List<LearningMoment> moments;

  int get itemCount =>
      courses.length +
      logs.length +
      tasks.length +
      notes.length +
      flashCards.length +
      reports.length +
      actionRecords.length +
      moments.length;
}

class FinalDemoSeedResult {
  const FinalDemoSeedResult({
    required this.logs,
    required this.tasks,
    required this.flashCards,
    required this.moments,
    required this.totalItems,
  });

  final int logs;
  final int tasks;
  final int flashCards;
  final int moments;
  final int totalItems;
}

class DemoSeedService {
  const DemoSeedService();

  static const idPrefix = 'demo_final_sprint_';

  FinalDemoSeed build({DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day, 20);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final threeDaysAgo = today.subtract(const Duration(days: 3));
    final fourDaysAgo = today.subtract(const Duration(days: 4));
    final fiveDaysAgo = today.subtract(const Duration(days: 5));
    final sixDaysAgo = today.subtract(const Duration(days: 6));
    final weekStart = today.subtract(const Duration(days: 6));

    return FinalDemoSeed(
      courses: const ['高等数学', '大学英语', '计算机导论'],
      logs: [
        StudyLogItem(
          id: '${idPrefix}log_today',
          date: today,
          courseName: '高等数学',
          content: '复盘极限与洛必达法则，错题集中在适用条件判断和等价无穷小替换。',
          problems: '洛必达使用前没有先判断 0/0 或无穷/无穷型，容易直接套公式。',
          thoughts: '需要把条件边界单独整理成表格，并用小测确认是否真正掌握。',
          nextPlan: '整理洛必达适用条件表，再做 3 道边界判断题。',
          createdAt: today,
        ),
        StudyLogItem(
          id: '${idPrefix}log_yesterday',
          date: yesterday,
          courseName: '高等数学',
          content: '完成极限题组 12 道，正确率约 58%。',
          problems: '连续错在题型迁移，看到复合函数时分不清先化简还是直接求导。',
          thoughts: '错题不是计算问题，而是概念边界和步骤选择不稳。',
          nextPlan: '明天先做 20 分钟条件判断，再重做错题。',
          createdAt: yesterday,
        ),
        StudyLogItem(
          id: '${idPrefix}log_project',
          date: twoDaysAgo,
          courseName: '计算机导论',
          content: '整理课堂上的二叉树遍历例题，把先序、中序、后序的区别写进笔记。',
          problems: '看代码时能跟着走，但自己画递归过程容易漏掉返回顺序。',
          thoughts: '需要把抽象概念画成步骤图，再用小例子练一遍。',
          nextPlan: '补一张遍历顺序对照表，明天用 10 分钟复述。',
          createdAt: twoDaysAgo,
        ),
        StudyLogItem(
          id: '${idPrefix}log_three_days',
          date: threeDaysAgo,
          courseName: '高等数学',
          content: '第一次整理极限题型，发现等价无穷小替换容易漏条件。',
          problems: '能算出结果，但说不清每一步为什么合法。',
          thoughts: '需要把“能做题”转成“能解释条件”。',
          nextPlan: '建立极限方法选择表。',
          createdAt: threeDaysAgo,
        ),
        StudyLogItem(
          id: '${idPrefix}log_four_days',
          date: fourDaysAgo,
          courseName: '高等数学',
          content: '做完 8 道极限基础题，简单代入和因式分解较稳。',
          problems: '遇到复合函数和无穷小比较时速度明显下降。',
          thoughts: '先把基础题稳住，再处理洛必达边界。',
          nextPlan: '明天复习等价无穷小和洛必达条件。',
          createdAt: fourDaysAgo,
        ),
        StudyLogItem(
          id: '${idPrefix}log_five_days',
          date: fiveDaysAgo,
          courseName: '大学英语',
          content: '完成四级阅读 2 篇，错题集中在长难句定位。',
          problems: '读得慢，容易忽略转折词。',
          thoughts: '英语阅读适合短时间坚持，和高数复习错峰安排更轻松。',
          nextPlan: '保留 15 分钟阅读复盘。',
          createdAt: fiveDaysAgo,
        ),
        StudyLogItem(
          id: '${idPrefix}log_six_days',
          date: sixDaysAgo,
          courseName: '计算机导论',
          content: '第一次用学迹整理本周安排：高数错题、英语阅读、计算机导论笔记分开记录。',
          problems: '以前每天只记待办，过两天就忘了当时为什么这样安排。',
          thoughts: '把当天学了什么、卡在哪里、下一步做什么写清楚，后面回看会省很多时间。',
          nextPlan: '每天晚上用 2 分钟补一条学习记录。',
          createdAt: sixDaysAgo,
        ),
      ],
      tasks: [
        _task(
          id: '${idPrefix}task_action_card',
          title: '今日下一步：洛必达条件表 + 3 道边界题',
          courseName: '高等数学',
          deadline: today.add(const Duration(hours: 2)),
          status: StudyTaskStatus.inProgress,
          note: '来自学习复盘：概念边界不清，容易忘。',
          subTasks: [
            _subTask('${idPrefix}sub_table', '整理适用条件表', today,
                status: SubTaskStatus.completed),
            _subTask('${idPrefix}sub_quiz', '完成 3 道边界判断题', today),
            _subTask('${idPrefix}sub_review', '记录错因与下一步', today),
          ],
          createdAt: yesterday,
        ),
        _task(
          id: '${idPrefix}task_video',
          title: '完成计算机导论二叉树遍历小练习',
          courseName: '计算机导论',
          deadline: today.add(const Duration(days: 1)),
          status: StudyTaskStatus.notStarted,
          note: '来自课堂笔记：递归返回顺序还不稳，先用 3 个小树练手。',
          subTasks: [
            _subTask('${idPrefix}sub_script', '画出遍历过程图', today),
            _subTask('${idPrefix}sub_capture', '完成 3 道小练习',
                today.add(const Duration(days: 1))),
          ],
          createdAt: twoDaysAgo,
        ),
        _task(
          id: '${idPrefix}task_done',
          title: '完成极限错题重做 5 题',
          courseName: '高等数学',
          deadline: threeDaysAgo,
          status: StudyTaskStatus.completed,
          note: '完成后掌握度从 42% 提升到 58%。',
          createdAt: threeDaysAgo,
        ),
      ],
      notes: [
        StudyNote(
          id: '${idPrefix}note_lhopital',
          title: '洛必达适用条件速查表',
          content: '先判断未定式，再确认可导性，最后检查变形是否保持等价。',
          courseName: '高等数学',
          blocks: [
            NoteBlock(
              id: '${idPrefix}block_1',
              type: NoteBlockType.heading,
              content: '洛必达使用前检查',
            ),
            NoteBlock(
              id: '${idPrefix}block_2',
              type: NoteBlockType.bullet,
              content: '必须是 0/0 或无穷/无穷型。',
            ),
            NoteBlock(
              id: '${idPrefix}block_3',
              type: NoteBlockType.bullet,
              content: '分子分母在邻域内可导，且分母导数不为 0。',
            ),
          ],
          createdAt: today,
          updatedAt: today,
        ),
        StudyNote(
          id: '${idPrefix}note_method_table',
          title: '极限题方法选择表',
          content: '先代入看形式；能因式分解先化简；出现 0/0 或无穷/无穷型再考虑洛必达。',
          courseName: '高等数学',
          blocks: [
            NoteBlock(
              id: '${idPrefix}block_method_1',
              type: NoteBlockType.heading,
              content: '做极限题先选方法',
            ),
            NoteBlock(
              id: '${idPrefix}block_method_2',
              type: NoteBlockType.todo,
              content: '先直接代入，判断是否为未定式。',
            ),
            NoteBlock(
              id: '${idPrefix}block_method_3',
              type: NoteBlockType.todo,
              content: '优先尝试因式分解、等价无穷小或有理化。',
            ),
            NoteBlock(
              id: '${idPrefix}block_method_4',
              type: NoteBlockType.todo,
              content: '确认条件后，再使用洛必达法则。',
            ),
          ],
          createdAt: yesterday,
          updatedAt: today,
        ),
      ],
      flashCards: [
        _card(
          id: '${idPrefix}card_lhopital_1',
          question: '使用洛必达法则前必须先确认哪两类未定式？',
          answer: '0/0 型或无穷/无穷型。',
          hint: '先判断极限形式，再考虑求导。',
          nextReviewDate: today,
          reviewCount: 2,
          lastReviewScore: 4,
          lastReviewedAt: yesterday,
        ),
        _card(
          id: '${idPrefix}card_lhopital_2',
          question: '为什么不能看到分式极限就直接套洛必达？',
          answer: '因为需要先确认未定式、可导性和分母导数条件，否则会得到错误结论。',
          hint: '条件边界是今天的主要难点。',
          nextReviewDate: today.add(const Duration(days: 1)),
          reviewCount: 1,
          lastReviewScore: 2,
          lastReviewedAt: today,
          weakTags: const ['适用条件', '薄弱'],
        ),
        _card(
          id: '${idPrefix}card_story',
          question: '每天晚上用学迹记录哪三件事？',
          answer: '今天学了什么、卡在哪里、下一步做什么。',
          courseName: '计算机导论',
          hint: '这三件事会变成明天首页上的学习安排。',
          nextReviewDate: today,
          reviewCount: 3,
          lastReviewScore: 5,
          lastReviewedAt: today,
        ),
        _card(
          id: '${idPrefix}card_method_order',
          question: '做极限题时，为什么要先化简再决定是否用洛必达？',
          answer: '化简后可能不再是未定式，也可能出现更简单的方法；先判断能避免机械套公式。',
          hint: '先看形式，再选方法。',
          nextReviewDate: today.add(const Duration(days: 2)),
          reviewCount: 1,
          lastReviewScore: 3,
          lastReviewedAt: yesterday,
          weakTags: const ['方法选择'],
        ),
      ],
      reports: [
        WeeklyReportItem(
          id: '${idPrefix}report_week',
          startDate: weekStart,
          endDate: today,
          content:
              '本周主要围绕高等数学极限复习：留下 7 条学习记录，发现 2 类重复难点，整理 4 张复习闪卡、2 页笔记和 2 个下一步任务。掌握度从 42% 提升到 58%，接下来继续练洛必达适用条件。',
          sourceLogIds: [
            '${idPrefix}log_today',
            '${idPrefix}log_yesterday',
            '${idPrefix}log_project',
            '${idPrefix}log_three_days',
            '${idPrefix}log_four_days',
            '${idPrefix}log_five_days',
            '${idPrefix}log_six_days',
          ],
          createdAt: today,
        ),
      ],
      actionRecords: [
        AiActionRecord(
          id: '${idPrefix}action_reflection',
          toolId: 'loop.create_from_source',
          targetTitle: '高等数学复盘回顾',
          status: AiActionStatus.executed,
          resultMessage: '已整理今日 3 件事和复习闪卡',
          params: {
            'loopSchemaVersion': 'final-demo-v2',
            'sourceMaterials': [
              {
                'type': 'reflection',
                'summary': '高等数学 7 天复盘与闪卡判分',
                'confidence': 0.82,
              }
            ],
            'reflectionAnalysis': {
              'summary': '极限与洛必达复盘',
              'blockers': ['适用条件判断不清', '题型迁移弱'],
              'emotion': {'label': '焦虑', 'intensity': 0.72},
              'mastery': {'极限': 0.58, '洛必达': 0.42},
              'forgettingRisk': 'high',
              'nextActions': ['整理条件表', '重做 3 道边界题', '明晚 5 分钟回忆测试'],
              'explanation': '连续 3 天出现条件边界问题，且最近一次闪卡判分只有 2 分。',
            },
          },
          createdAt: today,
        ),
        AiActionRecord(
          id: '${idPrefix}action_focus',
          toolId: 'timer.start_focus_with_task',
          targetId: '${idPrefix}task_action_card',
          targetTitle: '洛必达条件表专注 25 分钟',
          status: AiActionStatus.executed,
          resultMessage: '完成一次 25 分钟专注，并推进了条件表整理',
          params: {
            'durationMinutes': 25,
            'courseName': '高等数学',
          },
          createdAt: today.subtract(const Duration(hours: 1)),
        ),
        AiActionRecord(
          id: '${idPrefix}action_diagram',
          toolId: 'media.generate_image',
          targetTitle: '极限方法选择图解',
          status: AiActionStatus.executed,
          resultMessage: '已整理成一张极限方法选择图解',
          params: {
            'sourceText': '把极限题方法选择做成学习图解：代入、化简、判断未定式、再考虑洛必达。',
          },
          createdAt: yesterday.add(const Duration(hours: 2)),
        ),
      ],
      moments: [
        LearningMoment(
          id: '${idPrefix}moment_trace',
          content:
              '今天把“错在哪里”拆成了条件判断、题型迁移和情绪压力三件事，整理出的下一步比泛泛计划更容易开始。\n下一步：整理洛必达适用条件表；重做 3 道边界判断题；明晚 5 分钟回忆测试',
          courseName: '高等数学',
          sourceType: 'learning_loop',
          sourceId: '${idPrefix}action_reflection',
          createdAt: today,
        ),
        LearningMoment(
          id: '${idPrefix}moment_focus',
          content:
              '刚完成 25 分钟专注，把洛必达适用条件表补到一半。最有帮助的是先把“能不能用”写在公式前面，而不是直接开始求导。\n下一步：把今天错的 3 道题按条件重新标一遍',
          courseName: '高等数学',
          sourceType: 'task_progress',
          sourceId: '${idPrefix}task_action_card',
          createdAt: today.subtract(const Duration(hours: 1)),
        ),
        LearningMoment(
          id: '${idPrefix}moment_diagram',
          content:
              '把极限题方法选择整理成了图解：先代入看形式，再化简，最后判断是否需要洛必达。回看时比单独看公式更容易接上思路。\n下一步：把图解旁边补 2 个反例',
          courseName: '高等数学',
          sourceType: 'media_image',
          sourceId: '${idPrefix}action_diagram',
          createdAt: yesterday.add(const Duration(hours: 2)),
        ),
      ],
    );
  }

  StudyTaskItem _task({
    required String id,
    required String title,
    required String courseName,
    required DateTime deadline,
    required StudyTaskStatus status,
    required String note,
    List<StudySubTaskItem> subTasks = const [],
    required DateTime createdAt,
  }) {
    return StudyTaskItem(
      id: id,
      title: title,
      type: courseName == '计算机导论'
          ? StudyTaskType.projectDev
          : StudyTaskType.examReview,
      courseName: courseName,
      deadline: deadline,
      status: status,
      note: note,
      subTasks: subTasks,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  StudySubTaskItem _subTask(
    String id,
    String title,
    DateTime deadline, {
    SubTaskStatus status = SubTaskStatus.notStarted,
  }) {
    return StudySubTaskItem(
      id: id,
      title: title,
      deadline: deadline,
      status: status,
      createdAt: deadline,
      updatedAt: deadline,
      completedAt: status == SubTaskStatus.completed ? deadline : null,
    );
  }

  AiFlashCard _card({
    required String id,
    required String question,
    required String answer,
    required String hint,
    String courseName = '高等数学',
    DateTime? nextReviewDate,
    int reviewCount = 0,
    int? lastReviewScore,
    DateTime? lastReviewedAt,
    List<String> weakTags = const [],
  }) {
    final now = DateTime.now();
    return AiFlashCard(
      id: id,
      question: question,
      answer: answer,
      courseName: courseName,
      hint: hint,
      groupName: '每日复习',
      createdAt: now,
      reviewCount: reviewCount,
      nextReviewDate: nextReviewDate,
      lastReviewScore: lastReviewScore,
      lastReviewedAt: lastReviewedAt,
      weakTags: weakTags,
    );
  }
}
