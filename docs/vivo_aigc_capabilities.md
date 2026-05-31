# StudyTrace vivo AIGC 能力本地清单

> 来源: https://aigc.vivo.com.cn/#/document/index?id=1746
> 抽取日期: 2026-05-29
> 官方使用指引更新时间: 2026-04-13 15:16:04 UTC

本文用于本地记录 vivo AIGC / 蓝心能力在 StudyTrace 中的接入状态，方便后续开发直接查找能力、端点、配置项和本地调用入口。

## 当前 StudyTrace AI 调用边界

- Flutter 客户端不保存 vivo/蓝心 AppKey 或模型密钥。
- Flutter 只调用 StudyTrace 后端 `/ai/*` 业务接口，并携带用户登录 JWT。
- NestJS 后端统一托管 vivo/蓝心能力，使用 `BLUEHEART_*`、`VIVO_*` 环境变量。
- `AiController` 已挂 `JwtAuthGuard` 和 `RateLimitGuard`。
- 通用后端调用层在 `backend/src/modules/ai/vivo-gateway.service.ts`。
- 业务编排在 `backend/src/modules/ai/ai.service.ts`。
- 前端通用 vivo 能力封装在 `lib/src/services/vivo_capability_service.dart`。

## 已有 AI 功能汇总

| 功能 | 前端入口 | 后端入口 | 状态 |
| --- | --- | --- | --- |
| 学习日志生成 | `AiStudyService.generateStudyLog` | `POST /ai/study-log` | 已接入 |
| 任务拆解 | `AiStudyService.generateTaskPlan` | `POST /ai/task-plan` | 已接入 |
| 周学习计划 | `AiStudyService.generateWeeklyPlan` | `POST /ai/weekly-plan` | 已接入 |
| 学习闭环 | `AiStudyService.generateLearningLoop` | `POST /ai/learning-loop` | 已接入 |
| 周报分析 | `AiStudyService.generateWeeklyAnalysis` | `POST /ai/weekly-analysis` | 已接入 |
| 风险提醒 | `AiStudyService.generateRiskWarnings` | `POST /ai/risk-warnings` | 已接入 |
| 闪卡生成 | `AiStudyService.generateFlashCards` | `POST /ai/flash-cards` | 已接入 |
| 闪卡评分 | `AiStudyService.gradeFlashcard` | `POST /ai/grade-flashcard` | 已接入 |
| AI 对话 | `AiStudyService.generateAssistantTurn` | `POST /ai/chat` | 已接入 |
| AI 流式对话 | `AiStudyService.generateAssistantReplyStream` | `POST /ai/chat/stream` | 后端已接入，聊天页主流程未完全切换 |
| OCR | `OcrService` | `POST /ai/ocr` | 已接入，前端可回退 MLKit |
| 翻译 | `VivoCapabilityService.translate` | `POST /ai/translate` | 已接入 |
| 图片生成 | `VivoCapabilityService.createCover` | `POST /ai/images/tasks` | 已接入任务式封装 |
| 图片任务查询 | `VivoCapabilityService.refreshImageTask` | `POST /ai/images/tasks/status` | 已接入任务式封装 |
| 视频生成 | `VivoCapabilityService.createVideo` | `POST /ai/videos/tasks` | 已接入任务式封装 |
| 视频任务查询 | `VivoCapabilityService.refreshVideoTask` | `POST /ai/videos/tasks/status` | 已接入任务式封装 |
| 查询改写 | `AiSemanticSearchService` | `POST /ai/query-rewrite` | 已接入，失败回退本地搜索 |
| 文本相似度 | `AiSemanticSearchService` | `POST /ai/rerank` | 已接入，失败回退本地搜索 |
| 文本向量/记忆索引 | `VivoCapabilityService.indexMemory` | `POST /ai/memory/index` | 已接入后端能力 |
| 记忆检索 | `VivoCapabilityService.searchMemory` | `POST /ai/memory/search` | 已接入后端能力 |
| 语音转写 | `VivoCapabilityService.transcribeAudio` | `POST /ai/speech/transcribe` | 已有可选 endpoint 适配 |
| POI 搜索 | `VivoCapabilityService.searchPoi` | `POST /ai/poi-search` | 已接入后端能力 |
| 逆地理编码 | `VivoCapabilityService.reverseGeocode` | `POST /ai/reverse-geocode` | 已接入后端能力 |
| 能力徽章 | `VivoCapabilityService.capabilityBadges` | `GET /ai/capability-badges` | 已接入 |

## vivo 官方能力清单

| docId | 分组 | 能力 | 官方端点/协议 | 方法 | 鉴权 | 默认模型/引擎 | StudyTrace 映射 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1745 | 文本生成 | 大模型 | `https://api-ai.vivo.com.cn/v1/chat/completions` | POST | Bearer AppKey | `Volc-DeepSeek-V3.2`, `Doubao-Seed-2.0-mini`, `Doubao-Seed-2.0-lite`, `Doubao-Seed-2.0-pro`, `qwen3.5-plus` | `/ai/chat`, `/ai/chat/stream`, 学习生成类接口 |
| 1805 | 文本生成 | Function calling | 消息/提示词协议 | n/a | n/a | n/a | `ai_tool_registry.dart` + `/ai/chat` JSON actions |
| 1732 | 图片生成 | 图片生成 | `https://api-ai.vivo.com.cn/api/v1/image_generation` | POST | Bearer AppKey | `Doubao-Seedream-4.5` | `/ai/images/tasks`, `/ai/images/tasks/status` |
| 2201 | 视频生成 | 视频生成 | `/api/v1/submit_task`, `/api/v1/query_task` | POST, GET | Bearer AppKey | `Doubao-Seedance-1.0-pro` | `/ai/videos/tasks`, `/ai/videos/tasks/status` |
| 1737 | 视觉技术 | 通用 OCR | `/ocr/general_recognition` | POST form | Bearer AppKey | n/a | `/ai/ocr` |
| 1733 | 自然语言处理 | 文本翻译 | `/translation/query/self` | POST | Bearer AppKey | n/a | `/ai/translate` |
| 1734 | 自然语言处理 | 文本向量 | `/embedding-model-api/predict/batch` | POST | Bearer AppKey | `m3e-base`, `bge-base-zh-v1.5` | `/ai/embeddings`, `/ai/memory/index`, `/ai/memory/search` |
| 2060 | 自然语言处理 | 文本相似度 | `/rerank` | POST | Bearer AppKey | `bge-reranker-large` | `/ai/rerank` |
| 2061 | 自然语言处理 | 查询改写 | `/query_rewrite_base` | POST | Bearer AppKey | n/a | `/ai/query-rewrite` |
| 1738 | ASR | 实时短语音识别 | `ws://api-ai.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | `shortasrinput` | 部分登记，现有 `/ai/speech/transcribe` 走可选 HTTP 适配 |
| 1740 | ASR | 长语音听写 | `ws://asr-test-v2.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | n/a | 仅登记，待接入 |
| 1739 | ASR | 长语音转写 | `/lasr/create`, `/lasr/upload`, `/lasr/run`, `/lasr/progress`, `/lasr/result` | HTTP 多步 | Bearer AppKey | n/a | 仅登记，待接入 |
| 2065 | ASR | 方言自由说 | `ws://api-ai.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | `shortasrinput` | 仅登记，待接入 |
| 2068 | ASR | 同声传译 | `ws://api-ai.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | `longasrsubtitle` | 仅登记，待接入 |
| 1735 | TTS | 音频生成 | `wss://api-ai.vivo.com.cn/tts` | WebSocket | Bearer AppKey + 签名 | `short_audio_synthesis_jovi`, `long_audio_synthesis_screen`, `tts_humanoid_lam` | 仅登记，待接入；当前 App 主要用本机 TTS |
| 2062 | TTS | 声音复刻 | `/replica/create_vcn_task`, `/replica/get_vcn_task`, `/replica/get_vcn_task_list`, `/replica/del_task` | POST, GET, multipart | Bearer AppKey + 签名 | n/a | 仅登记，待接入 |
| 1736 | LBS | 地理编码/POI 搜索 | `/search/geo` | GET | Bearer AppKey | n/a | `/ai/poi-search`，逆地理为现有业务扩展 |
| 1802 | 端侧文本生成 | 端侧 3B 大模型 | Android AAR/native SDK | SDK | 本地 SDK | `BlueLM` | 仅登记，需 Android native 专项 |
| 1804 | 端侧文本生成 | 端侧文本审核 | Android AAR SDK | SDK | 本地 SDK | n/a | 仅登记，需 Android native 专项 |
| 1803 | 端侧文本生成 | 端侧能力相关文件 | 官方下载文件 | n/a | n/a | n/a | 仅登记 |

## 能力状态说明

- `live`: 已有 StudyTrace 后端业务接口，可被前端服务调用。
- `partial`: 已有相近业务接口或可选 endpoint 适配，但未完整覆盖官方协议。
- `planned`: 已登记官方能力和配置占位，后续可按需接入。
- `manual`: 需要 native SDK、超大文件上传、或人工下载官方包，不适合在本任务直接接入。

## 配置原则

- 密钥只放后端环境变量，不进入 Flutter。
- `BLUEHEART_API_KEY` 同时用于 OpenAI 兼容 Bearer 调用和部分 vivo 网关签名。
- `BLUEHEART_APP_ID` 用于需要 AppId 或签名的能力。
- 视频生成默认模型由 `VIVO_VIDEO_MODEL` 控制，默认 `Doubao-Seedance-1.0-pro`。
- 官方路径优先登记在 `backend/src/modules/ai/vivo-capabilities.ts`。
- `.env.example` 只提供占位和默认官方路径，不写真实值。

## 后续接入建议

1. 优先接入文本/JSON 能力，因为它们和现有 `AiService` / `VivoGatewayService` 最贴合。
2. WebSocket ASR/TTS 需要单独设计服务端转发、断线、音频分帧和移动端权限，不建议和普通 HTTP 能力混改。
3. 长音频转写涉及大文件和分片上传，建议单独做 multipart 或对象存储流程。
4. 端侧 3B 与端侧审核涉及 Android AAR/native SDK，应作为 Android 专项任务处理。
5. 每新增一个 live 能力，应同步更新本文件、`vivo-capabilities.ts`、`.env.example` 和前端 `VivoCapabilityService`。
