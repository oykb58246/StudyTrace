# StudyTrace CLI 开发指令

## 项目概要

StudyTrace — Flutter 大学生学习管理 App。MVVM 架构，SharedPreferences 本地存储，DeepSeek AI 集成。详细结构见 `项目当前总结.md`。

---

## 每次会话流程

### 1. 理解需求 → 进入计划模式 → 并行探索 → 写计划

- 用户给出需求后，**先进入计划模式**（`EnterPlanMode`）
- **并行启动 2~3 个 Explore Agent** 探索相关代码，各自聚焦不同模块/文件
- Agent 返回后综合所有发现，在计划文件中写出完整方案（问题分析 + 修改方案 + 涉及文件 + 实现顺序）
- **退出计划模式**（`ExitPlanMode`）等待用户审批
- 用户审批通过后，**建立任务列表**（`TaskCreate`）将各步骤拆为独立任务
- **计划通过后直接执行，无需再次确认**

### 2. 按任务顺序逐项编码 → 编码结束后不做命令行检查

- 任务有依赖关系的按依赖顺序执行，独立任务可并行
- 每次完成一个任务标记 `completed`，再取下一个
- **编码结束后不再进行命令行检查**：不执行 `dart ...`、`flutter ...`、`git diff --check`、analyze/test 或其他检查命令
- 如用户明确要求检查，再按用户指定范围执行

### 3. 简要汇报

只列出：修改了哪些文件、做什么、未进行命令行检查。不加冗长总结。

---

## 关键规则

- **中文思考与交流**：思考过程（thinking）和对 sub-agent 的 prompt 一律用中文，方便用户阅读和理解
- **计划通过后直接执行**，无需等用户说"开始"或"继续"
- **不自动 git commit**，等用户确认
- **编码结束后不再进行命令行检查**：不执行 `dart ...`、`flutter ...`、`git diff --check`、analyze/test 或其他检查命令，除非用户明确要求
- 不引入 pubspec.yaml 没有的新依赖，除非必要
- 遇到真机才能验证的功能（通知、语音），加 try-catch 兜底，不让测试崩溃
- 多个需求按计划列表顺序处理，不混在一起跳着改
- 项目结构以 `项目当前总结.md` 为准，本文档不重复

---

## 常用命令

以下命令仅供用户人工参考；Agent 默认不执行 `dart` / `flutter` 命令。

```bash
flutter pub get              # 安装依赖
flutter analyze              # 静态检查
flutter test                 # 单元/Widget 测试
flutter run                  # 启动到设备
flutter build apk --debug    # 构建 debug APK
```
