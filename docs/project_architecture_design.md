# StudyTrace 系统架构与设计文档

本项目是一个面向备考、日常课程学习与自主专业技能训练的 AI 辅助学习复盘与防遗忘闭环系统。系统由客户端（Flutter）与服务端（NestJS）组成，采用离线优先架构，并集成了基于大语言模型的 AI Agent 操作层与基于可审计证据链的共学社区。

---

## 一、 系统架构概述

StudyTrace 采用分层的云端/客户端协同架构。客户端负责本地交互、状态更新、传感器/媒体输入以及离线数据持久化；服务端负责多端数据同步、AI 代理编排、用户身份鉴权与学习小组证据链社区的管理。

```
+-----------------------------------------------------------------------------------+
|                                 StudyTrace 客户端 (Flutter)                       |
|  +--------------------+  +-----------------------+  +--------------------------+  |
|  |     UI 视图层      |  | AppDataController      |  | 本地服务层               |  |
|  |  (Pages / Widgets) |  | (ChangeNotifier 状态) |  | (Local Storage / Notify) |  |
|  +---------+----------+  +-----------+-----------+  +------------+-------------+  |
+------------|-------------------------|---------------------------|----------------+
             |                         |                           |
             | HTTP / SSE              | 数据同步 (JSON Payloads)   | 本地持久化 (SharedPreferences)
             v                         v                           v
+-----------------------------------------------------------------------------------+
|                                 StudyTrace 服务端 (NestJS)                        |
|  +-----------------------------------------------------------------------------+  |
|  |                           业务控制器 (Controllers)                           |  |
|  |            (Auth / Users / Sync / Groups / Leaderboards / Ai / Moments)     |  |
|  +-------------------------------------+---------------------------------------+  |
|  |                             业务服务层 (Services)                           |  |
|  |            (Prisma / Sync / Activities / Leaderboards / VivoGateway)        |  |
|  +-------------------------------------+---------------------------------------+  |
+----------------------------------------|------------------------------------------+
                                         v
                            +------------+------------+
                            |         MySQL           |
                            +-------------------------+
```

### 1. 前端技术栈与 MVVM 模式
* **开发框架**：Flutter 3.x，使用 Dart 语言进行全平台编译。
* **状态管理**：采用经典的 **ChangeNotifier 控制器模式**，通过单一全局控制器 `AppDataController` 封装所有核心领域实体（如任务、日志、笔记、闪卡、游戏化状态等），并统一向上游 UI 视图派发更新通知。
* **动效与交互**：集成 `Rive` 矢量动画库与 `fl_chart` 数据图表库，实现高品质的微交互和数据统计渲染。

### 2. 后端技术栈与数据库
* **核心框架**：NestJS (Node.js) 提供的模块化 IOC 容器架构，遵循 RESTful API 设计规范。
* **ORM 引擎**：Prisma，通过结构化的 `schema.prisma` 定义关系模型，并提供强类型的 TypeScript 客户端接口。
* **数据存储**：当前使用 MySQL，主要用于存储账户信息、云同步实体、AI 审计日志、排行榜数据及共学小组证据链。

---

## 二、 核心设计理念：六位一体闭环

系统在工程上彻底落地了 **「感知 — 理解 — 规划 — 执行 — 复盘 — 留痕」** 的行为闭环：

```
                    +-------------------+
                    |   1. 感知 (Perceive) | <-----------------------------+
                    |  (手记/语音/照片)  |                               |
                    +---------+---------+                               |
                              |                                         |
                              v                                         |
                    +-------------------+                               |
                    | 2. 理解 (Understand) |                             |
                    | (大模型结构化诊断) |                               |
                    +---------+---------+                               |
                              |                                         |
                              v                                         |
                    +-------------------+                               |
                    |   3. 规划 (Plan)  |                               |
                    | (AI任务拆解与闪卡) |                               |
                    +---------+---------+                               |
                              |                                         |
                              v                                         |
                    +-------------------+                               |
                    | 4. 执行 (Execute) |                               |
                    | (番茄专注/任务打卡) |                               |
                    +---------+---------+                               |
                              |                                         |
                              v                                         |
                    +-------------------+                               |
                    |  5. 复盘 (Review)  |                               |
                    | (富文本笔记/图谱)  |                               |
                    +---------+---------+                               |
                              |                                         |
                              v                                         |
                    +-------------------+                               |
                    |   6. 留痕 (Trace)  | -----------------------------+
                    |  (证据包/打卡地图)  |
                    +-------------------+
```

1. **感知**：用户利用课后零碎时间以文字手记、录音文件转写或拍摄讲义课件（云端 OCR / 本地 MLKit 识别）的方式进行行为录入。
2. **理解**：后台 AI 服务根据用户录入的学习记录，实时抽取核心概念并生成结构化诊断卡，给出阻碍因子和情绪标记。
3. **规划**：在**AI学习驾驶舱**中自动完成复杂学习目标的任务拆解，一键注入日程并生成对应的遗忘复习闪卡（Flashcards）。
4. **执行**：提供**专注计时器 (番茄钟)** 和智能日程提醒，学习执行状态（专注时长、子任务完成度）会在计时结束后自动写入系统数据库。
5. **复盘**：在**学习笔记**模块，基于 Notion 风格的块编辑器，利用 AI 续写/改写指令深化概念；同时，使用 `KnowledgeGraphService` 将学习资产抽取并生成力导向布局的关系网络。
6. **留痕**：本周生成的学迹事件会被自动打包为**作品证据包**，并自动沉淀在**校园学习地图**中，提供从本地私密备份到小组显式公开审计的留痕路径。

---

## 三、 离线优先与多端同步设计

为了在无网环境下保障学习行为的无缝记录，StudyTrace 实现了坚韧的**离线优先机制**与**通用数据云同步协议**。

### 1. 联网状态监听与静默重试
系统使用 `ConnectivityService` 对网络连接状态进行持续广播监听。
* **无网状态**：所有的增删改操作均直接在客户端 `LocalStorageService`（底层基于 SharedPreferences）完成，不阻断核心操作，相应实体会被打上本地更新时间戳 `updatedAt`，并在本地垃圾箱 `TrashItem` 进行软删除标记。
* **网络恢复**：一旦监听到网络上线，系统会启动后台静默同步线程，调用 `syncToCloud()` 完成未决数据的上报与云端对齐。

### 2. 通用数据同步协议规范
为了避免对每一个数据模型设计一套单独的 API 端点，系统通过 NestJS 和 Flutter 设计了一个基于**实体封装**的通用 Pull/Push 协议。

#### (1) 数据传输载体：`SyncItemPayload`
客户端所有核心实体（Task, Log, Note, Flashcard, Report 等）全部继承/封装为 `SyncItemPayload` 实体进行上报：
* `entityType` (String)：实体类型，如 `study_task`, `study_log`, `study_note`, `flash_card`, `weekly_report` 等。
* `entityId` (String)：客户端生成的唯一唯一标识 UUID (或特定的 CUID)。
* `payloadJson` (Map)：序列化为标准 JSON 的实体属性字段。
* `updatedAt` (DateTime)：最新的修改或创建时间戳。
* `deletedAt` (DateTime?)：如果该实体在本地被软删除，则带有此时间戳；否则为 null。

#### (2) 双向同步流
* **Push 阶段**：客户端提取自上一次同步以来被修改或创建的本地 payload 数组，向服务端发送 `POST /sync/push`。
* **Pull 阶段**：客户端发送 `GET /sync/pull?cursor=...`，传入上一次同步的游标时间戳。服务端提取数据库中在该时间戳之后被更新的 `SyncItem` 增量数据返回，并返回最新的游标 `nextCursor`。

#### (3) 冲突解决策略：后写胜出 (Last-Write-Wins, LWW)
对于在多端并发修改同一实体的情况，客户端与服务端统一实施基于**时间戳对齐**的冲突合并逻辑：
1. 当云端推送与本地数据发生冲突时，系统分别对比云端与本地的 `updatedAt`。
2. 若 `remote.updatedAt.isAfter(local.updatedAt)`，则将本地数据覆盖为云端 JSON；反之，将本地修改保留，并在下一次 push 周期推送至服务器。
3. 若存在 `deletedAt` 且其时间戳新于另一端，则直接执行逻辑软删除，进入本地/云端的回收站。

---

## 四、 AI Agent 交互与操作层设计

StudyTrace 不仅提供传统的对话式 AI，还设计了**可控制本地界面的 AI Agent 系统**。

### 1. 工具注册表与执行联动
系统由 `AiToolRegistry`（提供工具声明与 System Prompt 生成）和 `AiActionExecutor`（提供动作分发与状态回写）构成执行环路。

```
+---------------+     发送提问/文件     +------------------+
|    用户 UI    | --------------------> | NestJS 后端 AI    |
+---------------+                       | (蓝心 API 代理)  |
        ^                               +--------+---------+
        |                                        |
        | 执行 results 并渲染 UI 状态              | 返回 Markdown Reply + JSON Actions
        |                                        v
+-------+---------------+               +------------------+
|   AiActionExecutor    | <------------ | AiAssistantTurn  |
|  (客户端 Action 解析)  |               |  (Actions 队列)  |
+-----------------------+               +------------------+
```

* **大模型适配与 Prompt 路由**：后端将当前应用的可用工具列表（基于 `AiToolRegistry` 转换的 JSON Schema 描述）动态注入 System Prompt，要求大模型在返回文本回答的同时，按规则在 JSON 响应的 `actions` 字段中返回对应的 App 调用动作。
* **动作解析与队列执行**：客户端接收到大模型流式或同步返回的 `AiAssistantTurn` 结构后，将 Actions 提取出来。`AiActionExecutor` 依次执行队列中的前 4 个动作，例如：
  * `switchTab`：自动驱动底栏 Tab 切换到指定的业务页。
  * `addTask` / `addTaskDirect`：提取 AI 智能拆解的任务标题与时间段，在本地添加任务。
  * `saveNote`：提取大模型为用户总结的笔记大纲或扩写文本，自动新建并保存到笔记列表。
  * `startFocusWithTask`：根据 AI 任务，自动打开番茄钟并关联对应的任务 ID。
  * `noteFromOcr` / `createFlashcardBatch`：触发批量处理机制。

### 2. 风险等级控制与动作审计
为了保证系统的安全性，所有的 Agent 动作均经过了风险评级管理：
* **风险级别定义 (`AiRiskLevel`)**：
  * `safe`：只读或只导航的动作（如 `switchTab`），无阻碍执行。
  * `stateChanging`：可逆的状态变更（如 `addTask`、`setDarkMode`），自动执行并通过 SnackBar 提示用户。
  * `destructive`：破坏性的删除或覆写动作（如 `deleteTask`、`overwriteNote`、`emptyTrash`），系统会强制在客户端弹出模态确认对话框，只有在用户手动点击确认后方可执行。
* **动作审计追踪 (`AiActionRecord`)**：
  * 每一个下发的 Action 在执行前，都会通过 `AppDataController.appendActionRecord()` 在本地和云端持久化一条 `AiActionRecord`，记录其 `toolId`、`sessionId`、具体 `params` 以及初始的 `pending` 状态。
  * 执行完成后，系统会更新该审计项的状态为 `executed` 或 `failed`，并记录错误日志。这构成了系统“可审计 AI 能力轨迹”的数据基础。

---

## 五、 学迹可追溯证据链设计

StudyTrace 提供了一套严密的学迹留痕与反作弊共享机制。

### 1. 数据模型与证据包装 (Evidence Package)
* **学迹事件记录**：用户的日常学习活动（例如：新建任务、任务完成、番茄钟专注完毕、保存笔记、复习闪卡、打卡签到）在 `LearningTraceService` 中会被转化为可证明的学迹轨迹点。
* **作品证据包 (`EvidencePackage`)**：用户可以自主将本周或某个时间段内的所有轨迹点、对应的笔记链接、闪卡复习明细和总时长打包，由客户端生成包含元数据描述的只读证据包。

### 2. 社交共享与安全原则
* **安全隔离域 (Private by Default)**：为了保护学生隐私，用户的日历打点、瞬间相册、地理打卡记录（POI 地址及经纬度）默认均为**个人私密数据**，保存在云端和本地的个人隔离域中，不会泄漏给任何第三方。
* **共享触发链 (Explicit Share)**：只有当用户明确点击“加入小组”或“提交挑战证据”时，该实体才会被克隆/发布到指定的 `Group` 共享视图中。此时，小组内成员均可看到该学习动作的详细证明（如番茄钟的真实开始与结束时间、笔记链接等），以此杜绝作弊。

### 3. 多维度证据排行榜 (Evidence Leaderboard)
不同于传统的仅通过“手动填写时长”进行排名的打卡应用，StudyTrace 的排行榜是基于多维度客观指标 (Metrics) 构成的：
* `Points`：基础积分，由真实的系统交互行为（打卡成功、闪卡完成）自动累加计算。
* `Loops`：闭环转化率（如：输入日志并完成 AI 拆解任务的比率）。
* `Review`：闪卡自测的主动复习率及 AI 判定次数。
* `EvidencePackages`：生成并导出的审计证据包数。
* `ChallengeEvidence`：向小组公开提交并审核过关的真实挑战凭证数量。
* `Streak`：连续复盘和专注执行的连击天数。

---

## 六、 后端 API 设计与数据库 Contract

### 1. 核心 Prisma 实体定义
服务端通过 Prisma 对数据库进行建模，其主要实体关系如下：

```prisma
model User {
  id              String         @id @default(cuid())
  username        String         @unique
  passwordHash    String
  profile         UserProfile?
  syncItems       SyncItem[]     // 云同步实体表
  memberships     GroupMember[]  // 小组关系
  scoreEvents     ScoreEvent[]   // 积分变化事件
  aiUsageLogs     AiUsageLog[]   // AI 调用额度与审计日志
  learningMoments LearningMoment[] // 学习瞬间
  evidencePackages EvidencePackage[] // 证据包
  locationCheckIns LocationCheckIn[] // 地理位置打卡
  memoryChunks    MemoryChunk[]  // 个人学习记忆切片（用于可选向量索引与语义召回）
}

model SyncItem {
  id              String    @id @default(cuid())
  userId          String
  entityType      String
  entityId        String
  payloadJson     Json
  updatedAt       DateTime
  deletedAt       DateTime?
  serverUpdatedAt DateTime  @updatedAt

  @@unique([userId, entityType, entityId])
}

model GroupChallenge {
  id            String   @id @default(cuid())
  groupId       String
  createdById   String
  title         String
  planJson      Json     // 挑战阶段计划
  coverImageUrl String?
  status        String   @default("active")
  evidences     ChallengeEvidence[]
}

model MemoryChunk {
  id            String   @id @default(cuid())
  userId        String
  sourceType    String   // 'note', 'log', 'task' 等
  sourceId      String
  title         String
  content       String
  embeddingJson Json?    // 向量数据 (通过大模型适配器生成)
}
```

### 2. 核心服务端模块与 API 端点清单

| 模块名称 | API 路由端点 | HTTP 方法 | 功能描述 |
| :--- | :--- | :--- | :--- |
| **AuthModule** | `/auth/register` | `POST` | 注册系统新账户 |
| | `/auth/login` | `POST` | 获取 Access Token 与 Refresh Token |
| | `/auth/refresh` | `POST` | 凭 Refresh Token 刷新双 token 会话 |
| **SyncModule** | `/sync/push` | `POST` | 客户端批量推送本地增删改 payload 数组 |
| | `/sync/pull` | `GET` | 增量拉取最新 cursor 之后的云端更新数据 |
| | `/sync/export` | `GET` | 导出用户所有 entity 备份为标准 JSON |
| **GroupModule** | `/groups` | `POST` | 创建带有随机唯一邀请码的学习小组 |
| | `/groups/join` | `POST` | 通过 6 位邀请码加入小组 |
| | `/groups/:id` | `GET` | 查询小组详情、动态和排行榜 |
| **AiModule** | `/ai/study-log` | `POST` | 分析手记，流式/结构化返回诊断结果与任务计划 |
| | `/ai/learning-loop`| `POST` | 核心多模态闭环：课件/讲义解析与多资产一键规划 |
| | `/ai/chat/stream` | `POST` | 长会话流式问答与本地 Actions 下发路由 |
| | `/ai/memory/index` | `POST` | 解析笔记/日志并建立可选 Embedding 索引 |
| | `/ai/memory/search`| `POST` | 基于个人学习资料进行语义召回并显示证据来源 |
| | `/ai/poi-search` | `POST` | 检索校园周边的学习地点 (如图书馆、自习室) |
| | `/ai/capability-badges` | `GET` | 读取云端授予用户的 AI 能力透明轨迹与审计等级 |
