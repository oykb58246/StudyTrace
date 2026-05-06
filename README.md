# StudyTrace 学迹

> 面向大学生的学习任务管理、AI 学习助手与学习数据看板 App

StudyTrace 是一款 Flutter 跨平台学习管理应用，围绕「记录 → 执行 → 分析 → 复盘」构建个人学习闭环。App 支持课程任务、学习日志、日历、番茄钟、知识闪卡、学习笔记、AI 周报、风险提醒、云端同步、学习小组和排行榜 UI；同时已加入自建 NestJS 后端骨架，用于上线后的账号、同步、AI 代理、小组和排行数据能力。

- **Web 版**：https://studytraceweb26042901.z23.web.core.windows.net/
- **当前状态**：离线优先 App 已可本地使用；云端同步、学习小组、排行榜 UI 已加入；后端能力已搭建，下一步是进行真实接口联调和数据打通。

---

## 功能概览

### 学习闭环
- **课程任务管理**：创建、编辑、删除任务，支持状态/类型筛选、搜索、截止时间、提醒时间和子任务。
- **学习日志**：记录学习内容、问题、思考和下一步计划，支持课程归类和搜索筛选。
- **学习日历**：月历标记学习记录和截止任务，点击日期查看当天任务与记录，默认展示当天信息。
- **课程归档**：按课程汇总任务、日志和历史周报，支持课程管理。
- **学习数据看板**：整合原「学习统计」内容，集中展示总记录、总任务、完成率、课程分布饼图、近 7 天学习记录柱状图、近 4 周趋势、子任务进度、AI 周报、笔记等数据。
- **专注计时**：番茄钟计时，支持多种时长，计时结束可生成 AI 学习记录。
- **云端同步 UI**：展示同步入口、同步状态和多端数据同步相关操作，为接入后端同步接口预留交互。
- **学习小组 UI**：提供小组入口、邀请制小组、成员、动态等多人学习场景界面。
- **排行榜 UI**：提供个人榜、小组周榜/月榜等学习积分排行展示入口。

### AI 能力
- **AI 学习助手**：生成学习日志、拆解任务、分析周报、风险提醒。
- **AI 流式对话**：支持 Markdown 渲染、历史会话、多会话切换和深度思考模式。
- **AI 图片理解 / OCR / 语音输入**：支持拍照、选图、OCR 和语音创建任务。
- **AI 知识闪卡**：从学习记录生成问答卡片，支持列表横向滑动、层叠小卡、放大浏览、翻转、收藏和标签。
- **AI 设置**：蓝心大模型为主，DeepSeek 可选自定义接入，支持模型、Key、推理参数、连接测试。

### 设置与导航
- **侧边栏结构**：
  - 总览：作品总览
  - AI 管理：AI 学习助手、AI 设置
  - 学习应用：学习笔记、专注计时、知识闪卡，支持点击展开/收起
  - 数据与编排：数据看板、任务编排
  - 系统：系统设置
- **系统设置**：通知提醒、皮肤主题和其他系统偏好集中管理。
- **深色模式**：侧边栏底部小方形按钮切换日间/夜间。

### 后端上线能力
- **技术路线**：Node/NestJS + PostgreSQL + Prisma + JWT。
- **已具备骨架**：认证、用户、同步、AI 代理、学习小组、动态、排行榜、备份导出。
- **主要目录**：`backend/`
- **注意**：云端同步、学习小组、排行榜 UI 已加入；仍需要与后端接口联调，打通真实账号、同步、小组动态和排行数据。

---

## 技术栈

| 模块 | 内容 |
|------|------|
| App 框架 | Flutter 3.x / Material Design 3 |
| App 架构 | MVVM / ChangeNotifier |
| App 存储 | SharedPreferences 本地 JSON + flutter_secure_storage 凭据存储 |
| AI 服务 | 蓝心大模型为主，DeepSeek 可选自定义接入 |
| 图表与交互 | `fl_chart`、`table_calendar`、`rive`、`flutter_markdown` |
| 输入能力 | `image_picker`、`google_mlkit_text_recognition`、`speech_to_text` |
| 后端 | NestJS、PostgreSQL、Prisma、JWT、Docker |
| 平台 | Android / Windows / Web |

---

## 项目结构

```text
lib/
├── main.dart
└── src/
    ├── controllers/
    │   └── app_data_controller.dart
    ├── models/
    │   ├── study_task_item.dart
    │   ├── study_sub_task_item.dart
    │   ├── study_log_item.dart
    │   ├── weekly_report_item.dart
    │   ├── study_note.dart
    │   ├── note_block.dart
    │   ├── ai_config.dart
    │   ├── ai_chat_message.dart
    │   └── ai_flash_card.dart
    ├── services/
    │   ├── local_storage_service.dart
    │   ├── ai_study_service.dart
    │   ├── blueheart_model_client.dart
    │   ├── deepseek_client.dart
    │   ├── ai_credential_service.dart
    │   └── report_export_service.dart
    ├── theme/
    │   └── app_theme.dart
    └── ui/
        ├── shell/
        │   ├── app_shell.dart
        │   ├── navigation_models.dart
        │   ├── admin_section_page.dart
        │   ├── create_page.dart
        │   ├── extension_page.dart
        │   └── user_page.dart
        └── study/
            ├── ai_assistant_page.dart
            ├── ai_chat_page.dart
            ├── ai_settings_page.dart
            ├── calendar_page.dart
            ├── learning_dashboard_page.dart
            ├── study_notes_page.dart
            ├── timer_page.dart
            └── flash_card_page.dart

backend/
├── src/
├── prisma/
├── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## 后端 API 概览

后端位于 `backend/`，第一版接口包括：

- 账号：`POST /auth/register`、`POST /auth/login`、`POST /auth/refresh`
- 用户：`GET /me`、`PATCH /me/profile`
- 同步：`POST /sync/push`、`GET /sync/pull?cursor=...`、`GET /sync/export`
- 小组：`POST /groups`、`POST /groups/join`、`GET /groups/:id/members`
- 动态：`POST /activities`、`GET /groups/:id/activities`
- 排行榜：`GET /leaderboards/me`、`GET /leaderboards/groups/:id?range=week|month`
- AI 代理：`POST /ai/study-log`、`POST /ai/task-plan`、`POST /ai/weekly-analysis`、`POST /ai/risk-warnings`、`POST /ai/flash-cards`、`POST /ai/chat`

---

## 快速开始

### App

```bash
git clone https://github.com/oykb58246/StudyTrace.git
cd StudyTrace
flutter pub get
flutter run
```

### 后端

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run start:dev
```

Docker：

```bash
cd backend
docker compose up --build
```

---

## AI 配置

蓝心大模型已内置 AppKey，开箱即用。DeepSeek 为可选自定义接入：

1. 打开 App → 侧边栏 → AI 管理 → AI 设置
2. 蓝心面板选择模型或保留默认配置
3. DeepSeek 面板填写 API Key，测试连接后启用

通知提醒、皮肤主题和其他系统偏好位于：侧边栏 → 系统 → 系统设置。

---

## 版本

- **v1.2 当前版**：侧边栏二次重构；AI 设置与系统设置分离；学习统计并入数据看板；云端同步、学习小组、排行榜 UI 加入；知识闪卡浏览与层叠交互增强；学习日历与任务编辑问题修复；自建 NestJS 后端骨架加入。
- **v1.1**：蓝心大模型完整集成、流式对话、Vision 图片理解、皮肤系统和 UI 重构。
- **v1.0**：基础学习闭环、任务、日志、周报、统计和 AI 接入。

---

## 待接入

- Flutter 前端接入自建后端登录/注册。
- 云端同步 UI 与后端同步接口联调。
- 学习小组、学习动态、排行榜 UI 与真实后端数据打通。
- AI 请求改为后端代理，隐藏客户端内置模型 Key。

---

## 许可证

MIT License
