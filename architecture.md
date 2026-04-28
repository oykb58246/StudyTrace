# StudyTrace 架构设计文档

## 1. 项目概述

StudyTrace 是一个面向大学生的课程任务管理与学习周报生成 App。

核心功能：

1. 课程管理
2. 学习任务管理
3. 学习日志记录
4. 周报自动生成
5. 历史周报归档

第一版采用 Flutter + 本地存储，不依赖后端。

---

## 2. 技术栈

| 层级 | 技术 |
|---|---|
| 前端 | Flutter |
| 语言 | Dart |
| UI | Material Design 3 |
| 本地存储 | shared_preferences |
| 状态管理 | ChangeNotifier，第一版保持简单 |
| AI 功能 | 第一版使用本地模板生成，后续可接 DeepSeek / OpenAI / 通义千问 |

---

## 3. 核心业务流程

```
用户打开 App
    ↓
进入首页 Dashboard
    ↓
查看近期任务、今日学习记录入口、本周周报入口
    ↓
添加课程任务
    ↓
添加学习日志
    ↓
选择最近 7 天日志
    ↓
生成结构化周报
    ↓
保存周报历史
```

---

## 4. 页面结构

```
/lib
  /models
    study_task.dart
    study_log.dart
    weekly_report.dart

  /services
    storage_service.dart
    report_generator.dart

  /pages
    home_page.dart
    task_list_page.dart
    task_edit_page.dart
    study_log_page.dart
    study_log_edit_page.dart
    weekly_report_page.dart
    report_history_page.dart
    course_archive_page.dart

  /widgets
    task_card.dart
    log_card.dart
    report_section.dart
```

---

## 5. 数据模型

### StudyTask

```dart
class StudyTask {
  final String id;
  String title;
  String type;
  String course;
  DateTime? deadline;
  String status;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
}
```

任务类型：课程视频、论文阅读、编程作业、实验报告、项目开发、考试复习、其他

任务状态：未开始、进行中、已完成

### StudyLog

```dart
class StudyLog {
  final String id;
  DateTime date;
  String course;
  String content;
  String problem;
  String reflection;
  String nextPlan;
  DateTime createdAt;
}
```

### WeeklyReport

```dart
class WeeklyReport {
  final String id;
  DateTime startDate;
  DateTime endDate;
  String content;
  DateTime createdAt;
}
```

---

## 6. 周报生成结构

```
一、本周学习内容
二、本周完成进度
三、遇到的问题
四、思考与收获
五、下周学习计划
```

第一版通过本地模板生成，不调用 AI API。

---

## 7. 开发阶段

### V1 本地 MVP

- 可以添加任务
- 可以添加学习日志
- 可以生成周报
- 可以保存历史周报

### V2 体验优化

- 首页统计
- 课程归档
- 搜索筛选
- 截止时间提醒样式

### V3 AI 增强

- 接入 AI 润色周报
- 支持正式版、简洁版、汇报版
- 支持根据任务生成下周计划
