# StudyTrace - AI Agent 开发说明

## 项目背景

StudyTrace 是一个面向大学生的 Flutter 移动端应用，功能定位：

- 课程任务管理
- 学习过程记录
- 按周汇总学习记录
- 生成学习周报
- 保存历史周报

第一版采用 Flutter + 本地存储，不依赖后端。

---

## 强制流程：每次会话必须遵循

### 第 1 步：初始化环境

```bash
flutter pub get
flutter analyze
```

确保所有依赖安装完毕。

### 第 2 步：选择下一个任务

读取 `task.json`，选择一个 `passes: false` 的任务。

选择优先级：
1. 优先选择 id 最小的未完成任务
2. 先完成基础架构，再完成页面，再完成复杂功能
3. 一次只做一个任务

### 第 3 步：理解现有代码

在动手之前：
- 阅读任务涉及的现有文件
- 理解现有的代码模式和约定
- 确认修改范围，不破坏已有功能

### 第 4 步：实现任务

- 仔细阅读任务描述和步骤
- 增量修改，不删除已有代码
- 在现有 UI 基础上完善，保持风格一致
- 遵循项目现有的 MVVM 架构和代码约定
- 不要加入 task.json 以外的新功能

### 第 5 步：测试验证

每完成一个任务后，必须运行：

```bash
flutter analyze
```

如果任务涉及页面或交互，尽量运行：

```bash
flutter run
```

必要时运行：

```bash
flutter test
```

测试清单：
- [ ] `flutter analyze` 无错误
- [ ] App 可以正常启动
- [ ] 新页面可以正常进入
- [ ] 表单输入、保存、删除等交互正常
- [ ] 本地数据保存后重新进入仍存在
- [ ] 页面修改已在模拟器测试，或在 progress.txt 中说明无法测试的原因

### 第 6 步：更新进度

将工作记录到 `progress.txt`：

```
## [日期] - 任务: [任务标题]

### 做了什么:
- [具体的修改内容]

### 测试情况:
- flutter analyze: [通过/未通过]
- UI 测试: [已测试/无法测试及原因]

### 备注:
- [给后续任务的备注]
```

### 第 7 步：更新 task.json

只有当任务完整实现并测试通过后，才能将对应任务的 `"passes": false` 改为 `"passes": true`。

不要删除任务，不要重写已完成的任务描述。

### 第 8 步：汇报修改，等待确认

**不要直接提交 git commit。** 必须先向用户汇报：

1. 列出所有修改的文件
2. 简要描述每个文件的改动
3. 汇报测试结果
4. 询问用户是否需要提交

---

## 阻塞处理

以下情况视为阻塞：

1. 当前代码结构缺失，无法判断入口文件
2. 依赖安装失败
3. 本地存储库无法正常初始化
4. AI 接口需要真实 API Key
5. Flutter 项目无法启动

阻塞时不要修改 `passes` 为 true，而是在 `progress.txt` 记录阻塞原因。

阻塞信息格式：

```md
🚫 任务阻塞 - 需要人工介入

当前任务：[任务标题]
已完成：
- ...
阻塞原因：
- ...
需要人工操作：
1. ...
2. ...
```

---

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   ├── study_task.dart          # 学习任务模型
│   ├── study_log.dart           # 学习日志模型
│   └── weekly_report.dart       # 周报模型
├── services/
│   ├── storage_service.dart     # 本地持久化
│   └── report_generator.dart    # 周报生成
├── pages/
│   ├── home_page.dart           # 首页 Dashboard
│   ├── task_list_page.dart      # 任务列表
│   ├── task_edit_page.dart      # 新增/编辑任务
│   ├── study_log_page.dart      # 学习日志列表
│   ├── study_log_edit_page.dart # 新增学习日志
│   ├── weekly_report_page.dart  # 周报生成
│   ├── report_history_page.dart # 历史周报
│   └── course_archive_page.dart # 课程归档
└── widgets/
    ├── task_card.dart
    ├── log_card.dart
    └── report_section.dart
```

## 常用命令

```bash
flutter pub get          # 安装依赖
flutter analyze          # 代码检查
flutter run              # 启动应用
flutter build apk        # 构建 APK
flutter test             # 运行测试
```

## 核心规则

1. **一次一个任务** —— 每个会话只完成一个任务
2. **先测试再标记完成** —— 所有步骤必须验证通过
3. **`flutter analyze` 必须通过** —— 每次任务完成后运行
4. **页面修改需要 UI 测试** —— 启动模拟器或说明无法测试的原因
5. **记录到 progress.txt** —— 帮助后续任务理解上下文
6. **更新 task.json passes** —— 完成后标记为 true
7. **不自动提交 git** —— 先汇报修改内容，等待用户确认
8. **不删除已有代码** —— 只在现有基础上增量完善
9. **遇到阻塞及时停止** —— 不要假装任务完成
10. **AI 周报功能第一版先用本地模板生成** —— 不接真实 AI API
