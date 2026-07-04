# StudyTrace 学迹

> 面向大学生与自主学习者的 AI 学习复盘、行动规划与学迹回看应用

StudyTrace 将日常学习中的任务、日志、笔记、闪卡、专注计时和 AI 整理过程沉淀为可复盘、可追溯的成长轨迹。它不是单一的笔记工具或聊天助手，而是围绕「感知 - 理解 - 规划 - 执行 - 复盘 - 回看」构建的学习操作层。

应用采用 Flutter 客户端与 NestJS 后端协同架构：客户端负责离线优先的学习记录与交互体验，后端负责账号、资料备份、AI 能力代理、学习小组、学迹回顾和学习进度等服务。AI 能力由后端统一托管，客户端不保存模型密钥。

---

## 核心能力

### 学习路径

* **首页工作台**：聚合今日学习路径、AI 建议、学习轨迹、任务进度和常用入口。
* **计划管理**：管理课程安排、截止任务、子任务、提醒时间和学习标记。
* **专注执行**：提供番茄钟专注计时，完成后可回写学习记录。
* **复习巩固**：通过知识闪卡、AI 判分、熟练度更新和复习节奏提醒巩固知识点。
* **个人档案**：汇总课程归档、成就、偏好、个人资料和学习状态。
* **学迹记录**：以私密优先的方式记录图文学习瞬间，并可按用户选择进入学习小组。
* **学习回顾**：汇总任务、日志、笔记、闪卡和学习助手整理结果，形成阶段性学迹回顾。
* **数据看板**：展示学习趋势、课程分布、任务完成、闪卡复习和 AI 整理结果。
* **知识图谱**：根据任务、笔记和闪卡提取知识节点与关联关系，帮助用户看清知识结构。

### AI 能力

* **AI 学习座舱**：围绕拍照整理、今日学习路径和个人学习记忆提供高频入口。
* **学习材料整理**：将课件、笔记、题目或课程通知整理为学习摘要、任务草稿、笔记草稿、闪卡和复习建议。
* **AI 对话与操作层**：支持流式回复、Markdown 渲染、多会话管理，并可在用户确认边界内生成任务、保存笔记、创建闪卡或启动专注。
* **笔记辅助写作**：支持续写、扩写、改写、总结等笔记编辑辅助能力。
* **语义检索**：结合本地候选召回、查询改写和相似度排序，帮助用户找回相关任务、日志、笔记和闪卡。
* **多模态入口**：支持 OCR、图片理解、录音文件转写、翻译、图片生成、视频生成、POI 检索和逆地理编码等后端托管能力。
* **整理历史**：记录学习助手整理过的内容、结果和可重试状态，便于用户回看与继续处理。

### 同伴学习与成长回顾

* **学习小组**：支持邀请制小组、成员列表、组内近况和小组回顾。
* **学习回顾**：可将阶段性学习成果整理为包含任务、日志、笔记、闪卡和学迹的结构化回顾。
* **地点记录**：地点记录默认私密保存，可按用户选择进入小组回顾。
* **学习进度**：进度指标覆盖任务推进、复习、学习回顾、小组记录和连续学习等维度。

---

## 当前导航

```text
底部导航
├── 首页   — 今日学习路径、AI 建议、学习轨迹和常用入口
├── 计划   — 课程安排、截止任务、学习记录和日历视图
├── 专注   — 番茄钟计时、专注记录和任务关联
├── 复习   — 知识闪卡、AI 判分和复习节奏
└── 我的   — 个人资料、课程归档、成就和偏好

侧边栏入口
├── 学习助手
├── 助手设置
├── 学习笔记
├── 学迹
├── 学习回顾
├── 数据看板
├── 系统设置
├── 成长记录
├── 知识图谱
├── 整理历史
├── 回收站
└── 应用介绍
```

部分深层能力也会通过首页卡片、学习助手整理结果或业务页面入口进入，例如学习小组、同伴近况、学习流程和学习回顾详情。

---

## 技术栈

| 模块 | 内容 |
|------|------|
| 客户端 | Flutter / Dart / Material Design 3 |
| 架构 | MVVM / ChangeNotifier / 单一 AppDataController 协调核心状态 |
| 本地存储 | SharedPreferences JSON + flutter_secure_storage |
| 图表与日历 | fl_chart / table_calendar |
| 多模态输入 | image_picker / google_mlkit_text_recognition / speech_to_text / record |
| AI 服务 | NestJS 后端统一代理 vivo AIGC/蓝心能力，客户端不保存模型 Key |
| 后端 | NestJS / Prisma / MySQL / JWT / Docker |
| 同步策略 | 离线优先，本地更新时间戳与后写胜出冲突策略 |

---

## 项目结构

```text
lib/
├── main.dart
├── app/
│   └── app.dart
└── src/
    ├── controllers/
    │   └── app_data_controller.dart
    ├── models/
    ├── services/
    ├── theme/
    └── ui/
        ├── login/
        ├── shared/
        ├── shell/
        │   ├── app_shell.dart
        │   ├── navigation_models.dart
        │   ├── tool_home_page.dart
        │   ├── create_page.dart
        │   ├── extension_page.dart
        │   └── user_page.dart
        └── study/
            ├── ai_learning_cockpit_page.dart
            ├── ai_chat_page.dart
            ├── ai_settings_page.dart
            ├── learning_moments_page.dart
            ├── evidence_package_page.dart
            ├── learning_dashboard_page.dart
            ├── study_group_page.dart
            ├── leaderboard_page.dart
            ├── achievements_page.dart
            ├── knowledge_graph_page.dart
            ├── study_notes_page.dart
            ├── task_planning_page.dart
            ├── timer_page.dart
            └── flash_card_page.dart

backend/
├── src/
│   ├── modules/
│   └── prisma/
├── prisma/
├── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## 后端能力

后端位于 `backend/`，采用模块化 NestJS 架构：

* **HealthModule**：服务健康状态。
* **AuthModule**：注册、登录、刷新、退出和账号删除。
* **UsersModule**：用户资料、偏好和个人账号管理。
* **SyncModule**：通用实体同步、增量拉取、导出、软删除和冲突处理。
* **GroupsModule**：邀请制学习小组、成员列表、加入和退出。
* **MomentsModule**：学迹记录、可见性、点赞和评论。
* **ActivitiesModule**：学习活动与积分事件。
* **LeaderboardsModule**：个人排行、小组排行和多维指标。
* **CommunityEvidenceModule**：共学挑战、小组回顾、学习回顾和地点记录。
* **AiModule**：学习生成、对话、OCR、翻译、图片/视频生成、语音转写、语义检索、记忆索引、POI 和能力记录。

常用 API：

* 账号：`POST /auth/register`、`POST /auth/login`、`POST /auth/refresh`、`POST /auth/logout`、`POST /auth/delete-account`
* 用户：`GET /me`、`PATCH /me/profile`、`DELETE /me`
* 同步：`POST /sync/push`、`GET /sync/pull?cursor=...`、`GET /sync/export`
* 小组：`POST /groups`、`POST /groups/join`、`GET /groups`、`GET /groups/:id`、`GET /groups/:id/members`、`DELETE /groups/:id/membership`
* 学迹：`POST /moments`、`GET /moments/feed`、`PATCH /moments/:id/visibility`、`DELETE /moments/:id`
* 互动：`POST /moments/:id/likes/me`、`DELETE /moments/:id/likes/me`、`POST /moments/:id/comments`、`DELETE /moments/:id/comments/:commentId`
* 活动：`POST /activities`、`GET /activities/mine`、`GET /groups/:id/activities`
* 排行：`GET /leaderboards/me`、`GET /leaderboards/groups/:id?range=week|month&metric=...`
* 挑战：`POST /groups/:id/challenges/ai-draft`、`POST /groups/:id/challenges`、`GET /groups/:id/challenges`、`POST /groups/:id/challenges/:challengeId/join`、`POST /groups/:id/challenges/:challengeId/evidence`
* 学习回顾与地点：`POST /evidence-packages`、`GET /evidence-packages/mine`、`GET /groups/:id/evidence-packages`、`PATCH /evidence-packages/:id`、`POST /locations/check-ins`、`GET /locations/check-ins/mine`
* AI：`POST /ai/study-log`、`POST /ai/task-plan`、`POST /ai/weekly-plan`、`POST /ai/learning-loop`、`POST /ai/weekly-analysis`、`POST /ai/risk-warnings`、`POST /ai/flash-cards`、`POST /ai/grade-flashcard`、`POST /ai/chat`、`POST /ai/chat/stream`
* 扩展 AI 能力：`POST /ai/ocr`、`POST /ai/rewrite`、`POST /ai/query-rewrite`、`POST /ai/rerank`、`POST /ai/translate`、`POST /ai/images/tasks`、`POST /ai/images/tasks/status`、`POST /ai/videos/tasks`、`POST /ai/videos/tasks/status`、`POST /ai/speech/transcribe`、`POST /ai/memory/index`、`POST /ai/memory/search`、`POST /ai/poi-search`、`POST /ai/reverse-geocode`、`GET /ai/capability-badges`、`GET /ai/usage/today`

---

## 快速开始

### 客户端

```bash
git clone https://github.com/oykb58246/StudyTrace.git
cd StudyTrace
flutter pub get
flutter run
```

默认情况下客户端指向线上或预设 API 地址。连接本地后端时，可在 `lib/src/controllers/app_data_controller.dart` 的 `_defaultBaseUrl()` 中改为当前运行环境可访问的地址：

```dart
static String _defaultBaseUrl() {
  return 'http://localhost:3000';
}
```

Android 模拟器通常使用 `http://10.0.2.2:3000`，真机需要使用局域网地址。

### 后端

后端需要 Node.js 18+ 与 MySQL。环境变量以 `backend/.env.example` 为模板。

数据库结构以 `backend/prisma/schema.prisma` 和 `backend/prisma/migrations/`
为准，后端代码通过 `PrismaService` 访问数据库。`backend/sql/schema.mysql.sql`
是早期整理的手写 SQL 参考，保留为数据库设计草案和后续演进方向，不会被当前后端、
Docker 或 Prisma 自动执行。

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
docker compose up --build -d
```

---

## AI 配置边界

* 客户端只保存后端服务地址、用户登录凭据和基础偏好，不保存 vivo/蓝心模型密钥。
* 后端通过环境变量管理 `BLUEHEART_*`、`VIVO_*` 等配置。
* 当云端能力不可用时，客户端优先保留本地记录、文字输入、本地 OCR 或普通检索结果，不把失败结果包装为成功。
* 语音能力当前以录音文件转写和本机朗读为主；实时流式语音和官方 TTS 可作为后续专项继续扩展。
* 学习记忆当前结合本地候选召回、查询改写、相似度排序和可选记忆索引，不把所有历史资料默认上传为全量云端记忆库。

---

## 版本概览

* **v1.5 当前版本**：完成学迹记录、学习回顾、学习进度、知识图谱、成长记录、整理历史、学习小组和多类 AI 能力接入。
* **v1.4 学习回顾增强版**：补齐私密优先边界、学习回顾、成长记录、地点记录和本地学习提醒中心。
* **v1.3 AI 学习座舱版**：加入拍照整理、今日学习路径、学习记忆检索和 AI actions。
* **v1.2 后端与导航重构版**：引入 NestJS 后端、云同步、小组、排行和侧边栏导航。
* **v1.1 AI 集成版**：接入流式对话、Markdown 渲染、多会话和主题切换。
* **v1.0 本地学习路径版**：提供课程、任务、学习日志、周报和基础统计。

---

## 许可证

当前项目按 MIT License 口径维护。
