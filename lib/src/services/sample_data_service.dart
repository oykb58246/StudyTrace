import '../models/ai_flash_card.dart';
import '../models/study_log_item.dart';
import '../models/study_sub_task_item.dart';
import '../models/study_task_item.dart';
import '../models/weekly_report_item.dart';

class SampleDataService {
  static int _idCounter = 0;

  /// Generate a unique ID
  static String _generateId(String prefix) {
    _idCounter++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  /// Generate one month of sample study data (from 30 days ago to today)
  static SampleData generateSampleData() {
    _idCounter = 0; // Reset counter
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    final courses = [
      'Flutter 开发',
      'Python 数据分析',
      '计算机网络',
      '数据库原理',
      '算法与数据结构',
    ];

    final tasks = _generateSampleTasks(monthAgo, now, courses);
    final logs = _generateSampleLogs(monthAgo, now, courses);
    final reports = _generateSampleReports(monthAgo, now, logs);
    final flashCards = _generateSampleFlashCards(courses);

    return SampleData(
      tasks: tasks,
      logs: logs,
      reports: reports,
      flashCards: flashCards,
    );
  }

  static List<StudyTaskItem> _generateSampleTasks(
    DateTime start,
    DateTime end,
    List<String> courses,
  ) {
    final tasks = <StudyTaskItem>[];
    final taskTitles = [
      'Flutter Widget 教程学习',
      'Python 数据清洗练习',
      '网络分层模型详解',
      'SQL 查询优化方案',
      '排序算法实现与分析',
      '完成课堂作业第5套',
      '阅读论文：深度学习应用',
      '实验报告提交',
      '项目需求分析文档',
      '期末复习计划制定',
    ];

    final statuses = [
      StudyTaskStatus.completed,
      StudyTaskStatus.completed,
      StudyTaskStatus.inProgress,
      StudyTaskStatus.notStarted,
    ];

    final types = [
      StudyTaskType.classHomework,
      StudyTaskType.paperReading,
      StudyTaskType.programmingHomework,
      StudyTaskType.labReport,
      StudyTaskType.projectDev,
      StudyTaskType.examReview,
    ];

    for (int i = 0; i < 12; i++) {
      final daysOffset = (i * 2) % 30;
      final deadline = start.add(Duration(days: daysOffset + 5));
      final createdAt = start.add(Duration(days: daysOffset));

      tasks.add(
        StudyTaskItem(
          id: _generateId('task'),
          title: taskTitles[i % taskTitles.length],
          type: types[i % types.length],
          courseName: courses[i % courses.length],
          deadline: deadline,
          status: statuses[i % statuses.length],
          note: i % 3 == 0 ? '这是一个重要的任务，需要认真完成' : '',
          createdAt: createdAt,
          updatedAt: createdAt.add(Duration(hours: i)),
          subTasks: i % 2 == 0
              ? [
                  StudySubTaskItem(
                    id: _generateId('subtask'),
                    title: '第一步：理解基础概念',
                    deadline: deadline.subtract(const Duration(days: 2)),
                    status: SubTaskStatus.completed,
                    createdAt: createdAt,
                    updatedAt: createdAt.add(const Duration(hours: 2)),
                  ),
                  StudySubTaskItem(
                    id: _generateId('subtask'),
                    title: '第二步：完成代码示例',
                    deadline: deadline.subtract(const Duration(days: 1)),
                    status: SubTaskStatus.completed,
                    createdAt: createdAt.add(const Duration(days: 1)),
                    updatedAt: createdAt.add(const Duration(days: 1, hours: 3)),
                  ),
                  StudySubTaskItem(
                    id: _generateId('subtask'),
                    title: '第三步：提交作业',
                    deadline: deadline,
                    status: i % 4 == 0
                        ? SubTaskStatus.completed
                        : SubTaskStatus.notStarted,
                    createdAt: createdAt.add(const Duration(days: 2)),
                    updatedAt: createdAt.add(const Duration(days: 2, hours: 2)),
                  ),
                ]
              : [],
        ),
      );
    }

    return tasks;
  }

  static List<StudyLogItem> _generateSampleLogs(
    DateTime start,
    DateTime end,
    List<String> courses,
  ) {
    final logs = <StudyLogItem>[];

    final logContents = [
      '今天学习了 Flutter 中 Provider 的使用方法，理解了状态管理的核心概念。',
      '完成了 Python 数据清洗的第三个模块，学会了处理缺失数据的方法。',
      '复习了计算机网络的 TCP/IP 模型，重点理解了各层协议的功能。',
      '进行了数据库的 JOIN 查询练习，掌握了多表联合查询的技巧。',
      '实现了快速排序算法，并分析了其时间复杂度和空间复杂度。',
      '阅读了关于深度学习的学术论文，了解了最新的研究方向。',
    ];

    final problems = [
      '对于异步编程的理解还不够深入，需要更多实践。',
      '数据规范化处理时遇到了一些边界情况需要处理。',
      '对于 UDP 协议的应用场景理解不透彻。',
      '复杂 JOIN 查询时性能优化还需要改进。',
      '分治法的思想理解有些困难。',
    ];

    final thoughts = [
      '通过今天的学习，感觉状态管理不再神秘了。',
      '数据处理的细节决定了最终的质量。',
      '网络协议的层次设计真的很巧妙。',
      '好的索引策略对查询性能影响巨大。',
      '算法的优化往往需要时间和空间的权衡。',
    ];

    final plans = [
      '明天计划学习 GetX 状态管理框架。',
      '下一步学习数据可视化的内容。',
      '继续深入学习网络编程的实践应用。',
      '研究数据库优化的最佳实践。',
      '学习其他排序算法并对比性能。',
    ];

    var dayCounter = 0;
    for (int i = 0; i < 24; i++) {
      final logDate = start.add(Duration(days: dayCounter));
      if (logDate.isAfter(end)) break;

      logs.add(
        StudyLogItem(
          id: _generateId('log'),
          date: logDate,
          courseName: courses[i % courses.length],
          content: logContents[i % logContents.length],
          problems: i % 2 == 0 ? problems[i % problems.length] : '',
          thoughts: i % 3 == 0 ? thoughts[i % thoughts.length] : '',
          nextPlan: plans[i % plans.length],
          createdAt: logDate.add(Duration(hours: 18, minutes: i % 60)),
        ),
      );

      dayCounter += i % 2 == 0 ? 1 : 2;
    }

    return logs;
  }

  static List<WeeklyReportItem> _generateSampleReports(
    DateTime start,
    DateTime end,
    List<StudyLogItem> logs,
  ) {
    final reports = <WeeklyReportItem>[];

    for (int week = 0; week < 4; week++) {
      final weekStart = start.add(Duration(days: week * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final weekLogs = logs
          .where((l) => !l.date.isBefore(weekStart) && !l.date.isAfter(weekEnd))
          .toList();

      if (weekLogs.isNotEmpty) {
        final reportContent = '''## 第 ${week + 1} 周学习总结

### 📚 本周学习内容
${weekLogs.length} 次学习记录，涵盖 ${_getUniqueCourses(weekLogs).length} 门课程

主要学习内容包括：
${weekLogs.take(3).map((l) => '- ${l.courseName}: ${l.content.substring(0, (l.content.length).clamp(0, 30))}...').join('\n')}

### 🎯 学习成果
- 完成了基础概念的学习和实践
- 解决了 ${weekLogs.where((l) => l.problems.isNotEmpty).length} 个学习难点
- 深化了对知识点的理解

### 💭 反思与感悟
通过本周的学习，对 ${_getUniqueCourses(weekLogs).join('、')} 等方向有了更深入的认识。

### 📋 下周计划
- 继续深化本周内容的学习
- 开始新章节的学习
- 完成相关作业和项目''';

        reports.add(
          WeeklyReportItem(
            id: _generateId('report'),
            startDate: weekStart,
            endDate: weekEnd,
            content: reportContent,
            sourceLogIds: weekLogs.map((l) => l.id).toList(),
            createdAt: weekEnd.add(const Duration(hours: 20)),
          ),
        );
      }
    }

    return reports;
  }

  static List<AiFlashCard> _generateSampleFlashCards(List<String> courses) {
    final cards = <AiFlashCard>[];
    final random = DateTime.now().microsecondsSinceEpoch.remainder(1000);

    final allCardData = [
      {
        'course': '算法与数据结构',
        'q': '什么是时间复杂度？',
        'a': '时间复杂度是指算法执行所需的时间与输入数据规模的关系。常用 Big O 记号表示，如 O(n)、O(n²) 等。',
        'hint': '考虑算法执行次数和输入规模的关系',
      },
      {
        'course': '算法与数据结构',
        'q': '快速排序的平均时间复杂度是多少？',
        'a': '快速排序的平均时间复杂度是 O(n log n)，但最坏情况下为 O(n²)。',
        'hint': '与分治法有关',
      },
      {
        'course': 'Flutter 开发',
        'q': '什么是 Provider 状态管理？',
        'a': 'Provider 是一个基于 ChangeNotifier 的状态管理框架，通过组件树传递状态，实现跨组件数据共享。',
        'hint': '一种响应式的状态管理方式',
      },
      {
        'course': 'Flutter 开发',
        'q': 'Flutter 的生命周期有哪些？',
        'a':
            'StatefulWidget 的生命周期包括：createState、initState、build、didUpdateWidget、deactivate、dispose。',
        'hint': '按执行顺序列举',
      },
      {
        'course': '计算机网络',
        'q': 'TCP 和 UDP 有什么区别？',
        'a': 'TCP 是面向连接、可靠的、有序的传输协议；UDP 是无连接、不可靠、无序的传输协议。',
        'hint': '从连接、可靠性、有序性考虑',
      },
      {
        'course': '计算机网络',
        'q': 'HTTP 和 HTTPS 的主要区别是什么？',
        'a': 'HTTPS 是在 HTTP 基础上加入了 SSL/TLS 加密，确保通信的安全性和隐私性。',
        'hint': '关键词：加密',
      },
      {
        'course': '数据库原理',
        'q': '什么是数据库规范化？',
        'a': '数据库规范化是通过分解关系来消除冗余数据，提高数据完整性和一致性的过程。包括 1NF、2NF、3NF 等。',
        'hint': '消除冗余，保证数据一致性',
      },
      {
        'course': '数据库原理',
        'q': '什么是数据库索引？',
        'a': '数据库索引是一种数据结构，用来快速定位和访问数据库中的数据，通常使用 B+ 树实现。',
        'hint': '用来加快查询速度',
      },
      {
        'course': 'Python 数据分析',
        'q': 'Pandas 中 DataFrame 是什么？',
        'a': '	DataFrame 是一个二维表格数据结构，具有标记的行和列，类似于 SQL 表或 Excel 电子表格。',
        'hint': 'Pandas 的核心数据结构',
      },
      {
        'course': 'Python 数据分析',
        'q': 'NumPy 和 Pandas 有什么区别？',
        'a': 'NumPy 用于数值计算，提供 N 维数组；Pandas 建立在 NumPy 基础上，提供更高级的数据分析工具。',
        'hint': '前者用于科学计算，后者用于数据分析',
      },
      {
        'course': '计算机网络',
        'q': '什么是 OSI 七层模型？',
        'a': 'OSI 模型从下到上分别为：物理层、数据链路层、网络层、传输层、会话层、表示层、应用层。',
        'hint': '网络通信的基础理论',
      },
      {
        'course': '数据库原理',
        'q': 'SQL 中的 JOIN 有哪些类型？',
        'a':
            '主要有 INNER JOIN、LEFT JOIN、RIGHT JOIN、FULL OUTER JOIN 和 CROSS JOIN。',
        'hint': '表连接操作',
      },
      {
        'course': 'Flutter 开发',
        'q': '什么是 Widget Tree？',
        'a': 'Widget Tree 是 Flutter 应用的核心，由嵌套的 Widget 组成，描述了应用的 UI 结构。',
        'hint': 'Flutter 的 UI 框架基础',
      },
      {
        'course': '算法与数据结构',
        'q': '什么是递归？',
        'a': '递归是一种函数调用自身的编程技巧，需要定义基本情况和递归情况来避免无限循环。',
        'hint': '函数自己调用自己',
      },
      {
        'course': 'Python 数据分析',
        'q': '如何处理 DataFrame 中的缺失值？',
        'a': '可以使用 dropna() 删除缺失值，使用 fillna() 填充缺失值，或使用 interpolate() 插值。',
        'hint': '数据清洗的重要步骤',
      },
    ];

    // 每日生成 5-15 条随机闪卡
    final cardsPerDay = 5 + (random % 11); // 5 到 15 之间
    final now = DateTime.now();

    for (int day = 0; day < 30; day++) {
      final dayCards = <AiFlashCard>[];
      final dayStart = now.subtract(Duration(days: 30 - day));

      // 从所有卡片数据中随机选择
      for (int i = 0; i < cardsPerDay; i++) {
        final cardIdx = (random + day * 17 + i * 31) % allCardData.length;
        final data = allCardData[cardIdx];

        dayCards.add(
          AiFlashCard(
            id: _generateId('flashcard'),
            question: data['q']!,
            answer: data['a']!,
            courseName: data['course']!,
            hint: data['hint']!,
            isStarred: (random + day + i) % 3 == 0,
            groupName: 'AI 生成闪卡',
            createdAt: dayStart.add(Duration(minutes: i * 90)),
          ),
        );
      }

      cards.addAll(dayCards);
    }

    return cards;
  }

  static Set<String> _getUniqueCourses(List<StudyLogItem> logs) {
    return logs.map((l) => l.courseName).toSet();
  }
}

class SampleData {
  final List<StudyTaskItem> tasks;
  final List<StudyLogItem> logs;
  final List<WeeklyReportItem> reports;
  final List<AiFlashCard> flashCards;

  SampleData({
    required this.tasks,
    required this.logs,
    required this.reports,
    required this.flashCards,
  });
}
