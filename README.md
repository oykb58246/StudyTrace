# StudyTrace 学迹

> 面向大学生的 AI 学习操作层与学习证据链社区

StudyTrace 不是通用 AI 导学、错题题库或笔记助手，而是把大学生真实学习过程沉淀成「可执行、可复盘、可追溯」证据链的 Flutter 跨平台学习管理应用。App 通过 vivo AIGC/蓝心能力把相机、语音、OCR、图片理解、查询改写、文本相似度排序和 AI actions 串成“拍一下 / 说一句 → 自动安排学习 → 留下证据”的操作层体验。用户可以从课件、课堂笔记、题目或课程通知一键生成学习记录、任务拆解、笔记、闪卡和复习路径，并通过学迹动态、作品证据包、小组共学挑战和证据型排行把学习行为沉淀为可追溯、可分享的长期成果。

- **Web 版**：https://studytrace.oykb.cn
- **API**：https://api.studytrace.oykb.cn
- **当前状态**：离线优先 App、真实账号、云端同步、AI 后端代理、小组动态和排行榜已接入；比赛版已补齐 AI 学习驾驶舱、学习闭环计划、学迹证据包、AI 动态草稿、能力徽章、小组共学挑战、证据型排行、校园学习地图、能力透明轨迹，以及 vivo 翻译、图片生成、云端语音、文本向量、POI/地理编码适配入口。

---

## 功能概览

### 学习闭环
- **课程任务管理**：创建、编辑、删除任务，支持状态/类型筛选、搜索、截止时间、提醒时间和子任务。
- **学习日志**：记录学习内容、问题、思考和下一步计划，支持课程归类和搜索筛选。
- **学习日历**：月历标记学习记录和截止任务，点击日期查看当天任务与记录，默认展示当天信息。
- **课程归档**：按课程汇总任务、日志和历史周报，支持课程管理。
- **学习数据看板**：整合原「学习统计」内容，集中展示总记录、总任务、完成率、课程分布饼图、近 7 天学习记录柱状图、近 4 周趋势、子任务进度、AI 周报、笔记等数据。
- **专注计时**：番茄钟计时，支持多种时长，计时结束可生成 AI 学习记录。
- **AI 学习预警中心**：基于任务截止、逾期、子任务进度、学习记录断档和闪卡复习生成本地风险预警，支持每日摘要通知和最高风险即时推送。
- **云端同步 UI**：展示同步入口、同步状态和多端数据同步相关操作，为接入后端同步接口预留交互。
- **学习小组 UI**：提供小组入口、邀请制小组、成员、动态和 AI 共学挑战等多人学习场景界面。
- **排行榜 UI**：提供个人榜、小组周榜/月榜等学习积分排行展示入口，并补充证据轨迹、AI 闭环、证据包和复盘沉淀等证据型维度。
- **学迹动态**：默认作为私密学习证据链，支持显式发布到小组；可像朋友圈一样发布学习图文，并自动汇聚日志、任务、笔记、闪卡和 AI 操作记录，形成个人学习时间线。
- **作品证据包 / 精选成果墙**：按课程聚合学习日志、任务完成、笔记、闪卡、AI 操作和图文动态，生成可展示的学习成果证据包。
- **校园学习地图**：地点打卡默认私密保存，可选择城市、坐标或 POI 检索，并在用户显式选择后分享到小组证据链。

### AI 能力
- **AI 学习驾驶舱**：首屏提供“一拍成学习闭环”“今日最优学习路径”“问我的学习记忆”三条比赛演示链路；拍照链路优先使用图片多模态理解，并保留 vivo OCR 兜底。
- **学习闭环计划**：`POST /ai/learning-loop` 将材料转成结构化 JSON，生成学习摘要、课程归属、知识点、任务草稿、笔记草稿、闪卡和复习计划。
- **学习记忆检索**：对任务、日志、笔记、闪卡和 AI 操作记录进行本地预筛，再用 vivo 查询改写与文本相似度排序召回个人学习资料，并展示证据来源卡片。
- **AI 操作层**：AI 对话可输出结构化 actions，直接创建任务、保存笔记、生成闪卡、启动专注或触发学习闭环。
- **AI 计划自检**：学习闭环一键落地前可检查截止冲突、任务密度和课程分布，降低 AI 草稿直接落地的误操作风险。
- **AI 学迹动态卡片**：可根据学习轨迹、课程和图片生成可发布的学习证据动态文案。
- **vivo 能力透明卡**：AI 结果页展示本次使用的大模型、OCR、图片理解、查询改写、文本相似度/重排等能力。
- **AI 学习助手**：生成学习日志、拆解任务、分析周报、风险提醒。
- **AI 流式对话**：支持 Markdown 渲染、历史会话、多会话切换和深度思考模式。
- **AI 图片理解 / OCR / 语音输入**：支持拍照、选图、OCR 和语音创建任务。
- **AI 知识闪卡**：从学习记录生成问答卡片，支持列表横向滑动、层叠小卡、放大浏览、翻转、收藏和标签。
- **AI 设置**：云端 AI 后端代理，支持服务地址、推理参数和连接测试；客户端不保存模型 Key。

### 设置与导航
- **侧边栏结构**：
  - 总览：作品总览
  - AI 管理：AI 学习助手、AI 设置
  - 学习应用：学习笔记、专注计时、知识闪卡，支持点击展开/收起
  - 数据与编排：数据看板、任务编排
  - 系统：系统设置
- **系统设置**：通知提醒、AI 学习预警中心、皮肤主题和其他系统偏好集中管理。
- **深色模式**：侧边栏底部小方形按钮切换日间/夜间。

### 后端上线能力
- **技术路线**：Node/NestJS + PostgreSQL + Prisma + JWT。
- **已具备骨架**：认证、用户、同步、AI 代理、学习小组、动态、排行榜、挑战、证据包、地点打卡、记忆索引、备份导出。
- **主要目录**：`backend/`
- **注意**：学迹动态默认写入个人私密证据链；只有显式选择小组、挑战提交证据或证据包分享到小组时，才进入组内动态和组榜。

---

## 技术栈

| 模块 | 内容 |
|------|------|
| App 框架 | Flutter 3.x / Material Design 3 |
| App 架构 | MVVM / ChangeNotifier |
| App 存储 | SharedPreferences 本地 JSON + flutter_secure_storage 凭据存储 |
| AI 服务 | 后端托管 vivo AIGC/蓝心能力，客户端不保存模型 Key |
| 图表与交互 | `fl_chart`、`table_calendar`、`rive`、`flutter_markdown` |
| 输入能力 | `image_picker`、`google_mlkit_text_recognition`、`speech_to_text`、`record` |
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
    │   ├── ai_semantic_search_service.dart
    │   ├── ocr_service.dart
    │   ├── api_client.dart
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
- 排行榜：`GET /leaderboards/me`、`GET /leaderboards/groups/:id?range=week|month&metric=points|loops|review|evidencePackages|challengeEvidence|streak`
- 挑战与证据：`POST /groups/:id/challenges/ai-draft`、`POST /groups/:id/challenges`、`GET /groups/:id/challenges`、`POST /groups/:id/challenges/:challengeId/join`、`POST /groups/:id/challenges/:challengeId/evidence`、`GET /groups/:id/challenges/:challengeId/leaderboard`
- 证据包与地点：`POST /evidence-packages`、`GET /evidence-packages/mine`、`GET /groups/:id/evidence-packages`、`PATCH /evidence-packages/:id`、`POST /locations/check-ins`、`GET /locations/check-ins/mine`
- AI 代理：`POST /ai/study-log`、`POST /ai/task-plan`、`POST /ai/learning-loop`、`POST /ai/weekly-analysis`、`POST /ai/risk-warnings`、`POST /ai/flash-cards`、`POST /ai/ocr`、`POST /ai/query-rewrite`、`POST /ai/rerank`、`POST /ai/chat`
- vivo 能力：`GET /ai/capability-badges`、`POST /ai/translate`、`POST /ai/images/tasks`、`POST /ai/images/tasks/status`、`POST /ai/speech/transcribe`、`POST /ai/memory/index`、`POST /ai/memory/search`、`POST /ai/poi-search`、`POST /ai/reverse-geocode`

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

AI 能力统一通过后端代理调用，生产密钥只配置在服务器环境变量：

1. 打开 App → 侧边栏 → AI 管理 → AI 设置
2. 确认云服务地址为 `https://api.studytrace.oykb.cn`
3. 后端 `.env` 配置 `BLUEHEART_API_KEY`、`BLUEHEART_APP_ID` 后重启服务；翻译、图片、语音、向量、POI 能力按需补充 `VIVO_*` 环境变量，未配置时前端保留原文/文字输入/本地证据兜底，不伪装成功

### 移动端构建边界

- Android、iOS、macOS 已包含录音相关权限配置；云端语音失败时保留文字输入或本机语音兜底。
- 当前线上同步只重建并上传 Web 版；APK/IPA 需要在目标真机或签名环境重新构建后分发。

通知提醒、皮肤主题和其他系统偏好位于：侧边栏 → 系统 → 系统设置。

---

## 版本

- **v1.5 可审计证据链社区版**：补齐默认私密边界、后端挑战/证据包/地点/记忆索引实体、真实证据型排行、AI 操作留痕、能力透明轨迹，以及 vivo 翻译、绘画任务、云端语音、文本向量和 POI/地理编码适配入口。
- **v1.4 证据链增强版**：围绕“AI 学习操作层 + 学习证据链社区”升级；新增 AI 学迹动态草稿、作品证据包、精选成果墙、能力徽章、图片多模态闭环、学习记忆证据来源、落地前自检、AI 共学挑战和证据型排行展示。
- **v1.3**：vivo AIGC 比赛版 AI 学习操作层；新增 AI 学习驾驶舱、学习闭环计划、今日最优路径、学习记忆检索、高价值 actions 和学迹动态时间线。
- **v1.2**：侧边栏二次重构；AI 设置与系统设置分离；学习统计并入数据看板；云端同步、学习小组、排行榜 UI 加入；知识闪卡浏览与层叠交互增强；学习日历与任务编辑问题修复；自建 NestJS 后端骨架加入。
- **v1.1**：vivo AIGC/蓝心能力集成、流式对话、Vision 图片理解、皮肤系统和 UI 重构。
- **v1.0**：基础学习闭环、任务、日志、周报、统计和 AI 接入。

---

## 比赛演示建议

1. 拍一页课程 PPT 或课堂笔记，展示图片多模态理解 + vivo OCR 兜底 → 蓝心学习闭环 → 一键落地任务、笔记、闪卡。
2. 在闭环预览中展示 vivo 能力透明卡和“落地前自检”，说明 AI 结果会先经过冲突、密度和课程分布检查。
3. 询问“上次数据库索引问题”，展示查询改写 + 语义排序召回个人学习记忆，并展示任务/日志/笔记/闪卡/AI 操作证据来源。
4. 打开学迹动态，展示 AI 动态草稿、私密证据链、小组发布、作品证据包和精选成果墙。
5. 打开学习小组生成 AI 共学挑战，提交任务/日志/动态/证据包作为挑战证据，再打开排行榜展示积分之外的 AI 闭环、复盘、证据包、挑战证据和连续学习维度。
6. 展示学迹动态或证据包的一键翻译、封面生成、语音复盘和地点打卡入口；失败时保留原文或文字模式，强调不伪造能力结果。
7. 结尾强调 StudyTrace 从“AI 生成内容”升级为“AI 驱动学习行为、沉淀过程证据、连接同伴共学”的学习证据链社区。

---

## 许可证

MIT License
