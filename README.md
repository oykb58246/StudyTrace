# StudyTrace 学迹

> 大学生课程任务管理与 AI 学习助手 App

StudyTrace 是一款面向大学生的 Flutter 跨平台应用，支持课程任务管理、每日学习记录、番茄钟计时、学习数据统计，并深度集成**蓝心大模型**和 **DeepSeek** AI 能力——流式对话、图片理解、自动生成结构化学习日志、智能拆解复杂任务、AI 分析周报、风险提醒、知识闪卡等功能，形成"**记录 → 执行 → 分析 → 复盘**"的智能学习闭环。

- **Web 版**：https://studytraceweb26042901.z23.web.core.windows.net/

---

## 功能概览

### 核心功能
- **课程任务管理** — 创建/编辑/删除任务，按状态/类型筛选，自定义子任务，可点击切换完成状态，智能排序（未完成 → 截止期优先）
- **每日学习记录** — 记录学习内容、问题、思考、下一步计划，按课程分类
- **学习日历** — 月视图日历，标记每日学习记录和任务，点击查看当天详情
- **学习周报** — 基于一周学习数据自动生成结构化周报，支持保存和复制
- **课程归档** — 自动聚合课程的任务与记录，按课程浏览历史学习数据，支持手动添加/删除课程
- **学习统计** — 饼图（课程分布）+ 柱状图（7天趋势）+ 完成率统计卡片
- **连续打卡** — 跟踪连续学习天数，7 天以上显示火焰徽章
- **番茄钟计时** — 5/15/25/45/60 分钟预设，计时结束 AI 自动生成学习记录

### AI 智能能力（蓝心大模型 + DeepSeek 双引擎）

| 功能 | 说明 |
|------|------|
| **AI 流式对话** | 实时 token-by-token 响应，Markdown 渲染，会话历史持久化，多会话切换 |
| **AI 图片理解** | 拍照/选图 → AI 分析图片内容（蓝心 Vision） |
| **AI 生成学习日志** | 输入自然语言描述 → 结构化学习记录一键保存 |
| **AI 智能拆解任务** | 输入复杂任务 → 子任务列表 → 一键导入任务列表 |
| **AI 分析型周报** | 7 维度深度分析（主题/投入/问题/完成率/风险/评价/建议） |
| **AI 风险提醒** | 自动检测截止风险、进度偏低、课程断档，按级别预警 |
| **AI 知识闪卡** | 从学习记录自动生成问答闪卡，点击翻转查看答案 |
| **语音创建任务** | 语音输入描述 → AI 自动拆解并创建学习任务 |
| **Notion 风格笔记** | AI 生成笔记自动转为结构化块（标题/列表/待办/代码块） |

### 更多功能
- **皮肤主题** — vivo 蓝 / 传统紫双主题可切换，80+ 处 UI 动态颜色
- **深度思考模式** — 聊天内一键开启/关闭 AI 深度推理
- **深色模式** — 全局深色/浅色主题切换
- **个人信息** — 自定义头像表情、昵称、个人签名
- **API 配置** — 蓝心 AppKey（内置即用）+ DeepSeek API Key，模型选择，高级参数调节

---

## 技术栈

| 项目 | 内容 |
|------|------|
| 框架 | Flutter 3.x (Material Design 3) |
| 架构 | MVVM (ChangeNotifier) |
| 语言 | Dart |
| 存储 | SharedPreferences（本地 JSON）+ flutter_secure_storage（API Key） |
| AI 服务 | 蓝心大模型（Chat Completions + Vision + OCR）+ DeepSeek |
| Web 部署 | Azure Storage 静态网站 |
| 关键依赖 | `table_calendar` `fl_chart` `rive` `flutter_markdown` `speech_to_text` `google_mlkit_text_recognition` `image_picker` `http` |
| 平台 | Android / Windows / Web |

---

## 快速开始

### 前置要求
- Flutter SDK >= 3.0.0
- Android Studio 或 VS Code + Flutter 插件
- Android 模拟器或真机

### 运行

```bash
# 克隆项目
git clone https://github.com/oykb58246/StudyTrace.git
cd StudyTrace

# 安装依赖
flutter pub get

# 代码检查
flutter analyze

# 运行到设备
flutter run

# 构建 APK
flutter build apk --debug

# 构建 Web
flutter build web --release
```

### AI 配置

蓝心大模型已内置 AppKey，开箱即用。也可额外配置 DeepSeek 作为备选：
1. 打开 App → AI 设置
2. 蓝心面板：选择模型即可使用
3. DeepSeek 面板（可选）：填写 API Key → 测试连接 → 启用

---

## 项目结构

```
lib/
├── main.dart                                  # 应用入口
└── src/
    ├── controllers/
    │   └── app_data_controller.dart            # 全局状态管理 + 皮肤系统
    ├── models/
    │   ├── study_task_item.dart                # 学习任务（含子任务）
    │   ├── study_sub_task_item.dart            # 子任务
    │   ├── study_log_item.dart                 # 学习日志
    │   ├── weekly_report_item.dart             # 周报
    │   ├── study_note.dart                     # 学习笔记（Notion 风格块）
    │   ├── note_block.dart                     # 笔记块（标题/列表/待办/代码）
    │   ├── user_profile.dart                   # 用户资料
    │   ├── ai_generated_log.dart               # AI 生成日志
    │   ├── ai_task_plan.dart                   # AI 任务拆解
    │   ├── ai_study_analysis.dart              # AI 分析周报
    │   ├── ai_risk_warning.dart                # AI 风险提醒
    │   ├── ai_flash_card.dart                  # AI 知识闪卡
    │   ├── ai_chat_message.dart                # AI 聊天消息/会话
    │   └── ai_config.dart                      # AI 配置模型（双引擎+高级参数）
    ├── services/
    │   ├── local_storage_service.dart          # 本地持久化
    │   ├── weekly_report_service.dart          # 周报生成
    │   ├── ai_study_service.dart               # AIGC 核心服务（蓝心+DeepSeek）
    │   ├── blueheart_model_client.dart         # 蓝心大模型客户端（流式/Vision）
    │   ├── blueheart_ocr_client.dart           # 蓝心 OCR 客户端
    │   ├── deepseek_client.dart                # DeepSeek API 客户端
    │   ├── ai_credential_service.dart          # 凭据安全存储（含内置 AppKey）
    │   └── sample_data_service.dart            # 示例数据生成
    ├── theme/
    │   └── app_theme.dart                      # MD3 主题 + AppColors
    └── ui/
        ├── shared/
        │   └── common_widgets.dart             # 通用组件
        ├── login/
        │   └── login_screen.dart               # 登录/注册页
        ├── analysis/
        │   └── analysis_result_page.dart       # 分析结果页
        ├── shell/
        │   ├── app_shell.dart                  # 主壳（侧栏+底部导航）
        │   ├── navigation_models.dart          # 导航枚举
        │   ├── admin_section_page.dart         # 侧栏页面路由
        │   ├── tool_home_page.dart             # 首页 Dashboard
        │   ├── create_page.dart                # 任务管理（自定义子任务）
        │   ├── extension_page.dart             # 学习记录列表
        │   └── user_page.dart                  # 课程归档（含课程CRUD）
        └── study/
            ├── ai_chat_page.dart               # AI 流式对话（会话历史/Vision/深度思考）
            ├── ai_assistant_page.dart          # AI 学习助手（4大功能）
            ├── ai_settings_page.dart           # AI 设置（双引擎+皮肤+高级参数）
            ├── calendar_page.dart              # 学习日历（日志+任务）
            ├── statistics_page.dart            # 学习统计
            ├── timer_page.dart                 # 番茄钟
            ├── flash_card_page.dart            # 知识闪卡（层叠+翻转）
            ├── study_notes_page.dart           # 学习笔记（Notion 块编辑器）
            ├── learning_dashboard_page.dart    # 学习仪表盘
            ├── task_planning_page.dart         # 任务规划
            └── user_profile_page.dart          # 用户资料编辑
```

---

## 导航结构

```
底部导航
├── 首页   — 仪表盘、AI 入口、周报生成、任务进度
├── 记录   — 学习日志列表、搜索、筛选
├── 日历   — 月视图日历、日视图日志+任务
├── 任务   — 任务管理、搜索、状态/类型筛选、自定义子任务
└── 归档   — 课程汇总、历史周报、课程管理

侧边菜单
├── BROWSE
│   ├── 作品总览
│   ├── AI 学习助手
│   ├── AI 对话（流式聊天+历史会话）
│   ├── 学习笔记（Notion 编辑器）
│   ├── 学习统计
│   ├── 专注计时
│   └── 知识闪卡
└── 管理
    ├── 任务编排
    ├── 数据看板
    └── 系统设置（AI 配置 / 皮肤 / 深色模式）
```

---

## 版本

- **v1.1** — 蓝心大模型完整集成 + 流式对话 + Vision 图片理解 + 皮肤系统 + 全面 UI 重构
- v1.0 — 初始版本，DeepSeek AI 集成 + 学习闭环功能

---

## 许可证

MIT License
