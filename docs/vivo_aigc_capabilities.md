# StudyTrace vivo AIGC 能力本地清单

> 来源: https://aigc.vivo.com.cn/#/document/index?id=1746
> 抽取日期: 2026-06-20
> 官方使用指引更新时间: 2026-06-05 02:58:10

本文用于本地记录 vivo AIGC / 蓝心能力在 StudyTrace 中的接入状态，方便后续开发直接查找能力、端点、配置项和本地调用入口。

## 2026-06-20 更新摘要

- 1746 是能力总目录，当前新增/更新重点是图片生成和视频生成。
- 图片生成 1732 最新接口为同步 `POST /api/v1/image_generation`，返回 `data.images[].url`；`data.image` 标记为即将废弃。
- 图片生成新增 `Doubao-Seedream-5.0-lite`，限制说明更新为每个模型每天提交 50 次，总共 500 次。
- 视频生成 2201 使用 `POST /api/v1/submit_task` 和 `GET /api/v1/query_task`；公共 URL 参数必须带 `request_id`、`system_time`、`module=aigc`，查询时额外带 `task_id`。
- 视频生成新增 `Doubao-Seedance-2.0`、`Doubao-Seedance-2.0-fast`，限制说明更新为每个模型每天提交 10 次，总共生成 200 个视频。
- 通用 HTTP JSON 能力使用 `Authorization: Bearer AppKey`；`VivoGatewayService` 已按最新文档改为 Bearer 鉴权。
- 文本向量 1734 使用 `POST /embedding-model-api/predict/batch`，请求体为 `model_name + sentences`；记忆检索默认使用官方路径。
- 地理编码/POI 搜索 1736 使用 `GET /search/geo`，请求参数为 `keywords/city/page_num/page_size/requestId`。
- 长语音转写 1739 使用 `/lasr/create → /lasr/upload → /lasr/run → /lasr/progress → /lasr/result`，`/ai/speech/transcribe` 已默认接入该官方录音文件转写流程。
- StudyTrace 后端仍保留 `/ai/images/tasks` 这类 task-shaped 业务接口，但图片生成内部已改为同步返回图片；聊天、笔记、学习动态封面和小组挑战封面会优先直接使用 `imagesUrl`。

## 当前 StudyTrace AI 调用边界

- Flutter 客户端不保存 vivo/蓝心 AppKey 或模型密钥。
- Flutter 只调用 StudyTrace 后端 `/ai/*` 业务接口，并携带用户登录 JWT。
- NestJS 后端统一托管 vivo/蓝心能力，使用 `BLUEHEART_*`、`VIVO_*` 环境变量。
- `AiController` 已挂 `JwtAuthGuard` 和 `RateLimitGuard`。
- 通用后端调用层在 `backend/src/modules/ai/vivo-gateway.service.ts`，默认使用官方 Bearer AppKey。
- 业务编排在 `backend/src/modules/ai/ai.service.ts`。
- 前端通用 vivo 能力封装在 `lib/src/services/vivo_capability_service.dart`。

## 已有 AI 功能汇总

| 功能 | 前端入口 | 后端入口 | 状态 |
| --- | --- | --- | --- |
| 学习日志生成 | `AiStudyService.generateStudyLog` | `POST /ai/study-log` | 已接入 |
| 任务拆解 | `AiStudyService.generateTaskPlan` | `POST /ai/task-plan` | 已接入 |
| 周学习计划 | `AiStudyService.generateWeeklyPlan` | `POST /ai/weekly-plan` | 已接入 |
| 学习整理 | `AiStudyService.generateLearningLoop` | `POST /ai/learning-loop` | 已接入 |
| 周报分析 | `AiStudyService.generateWeeklyAnalysis` | `POST /ai/weekly-analysis` | 已接入 |
| 风险提醒 | `AiStudyService.generateRiskWarnings` | `POST /ai/risk-warnings` | 已接入 |
| 闪卡生成 | `AiStudyService.generateFlashCards` | `POST /ai/flash-cards` | 已接入 |
| 闪卡评分 | `AiStudyService.gradeFlashcard` | `POST /ai/grade-flashcard` | 已接入 |
| AI 对话 | `AiStudyService.generateAssistantTurn` | `POST /ai/chat` | 已接入 |
| AI 流式对话 | `AiStudyService.generateAssistantReplyStream` | `POST /ai/chat/stream` | 后端已接入，聊天页主流程未完全切换 |
| OCR | `OcrService` | `POST /ai/ocr` | 已接入，前端可回退 MLKit |
| 翻译 | `VivoCapabilityService.translate` | `POST /ai/translate` | 已接入 |
| 图片生成 | `VivoCapabilityService.createCover` | `POST /ai/images/tasks` | 已接入；后端同步调用官方 `image_generation` 并返回 `imagesUrl` |
| 图片任务查询 | `VivoCapabilityService.refreshImageTask` | `POST /ai/images/tasks/status` | 兼容旧任务式封装；新同步图片通常无需查询 |
| 视频生成 | `VivoCapabilityService.createVideo` | `POST /ai/videos/tasks` | 已按 2201 任务协议接入 |
| 视频任务查询 | `VivoCapabilityService.refreshVideoTask` | `POST /ai/videos/tasks/status` | 已按 2201 查询协议接入 |
| 查询改写 | `AiSemanticSearchService` | `POST /ai/query-rewrite` | 已接入，失败回退本地搜索 |
| 文本相似度 | `AiSemanticSearchService` | `POST /ai/rerank` | 已接入，失败回退本地搜索 |
| 文本向量/记忆索引 | `VivoCapabilityService.indexMemory` | `POST /ai/memory/index` | 已接入后端能力 |
| 记忆检索 | `VivoCapabilityService.searchMemory` | `POST /ai/memory/search` | 已接入后端能力 |
| 语音转写 | `VivoCapabilityService.transcribeAudio` | `POST /ai/speech/transcribe` | 已接入官方 LASR 录音文件转写流程 |
| POI 搜索 | `VivoCapabilityService.searchPoi` | `POST /ai/poi-search` | 已接入后端能力 |
| 逆地理编码 | `VivoCapabilityService.reverseGeocode` | `POST /ai/reverse-geocode` | 已接入后端能力 |
| 能力徽章 | `VivoCapabilityService.capabilityBadges` | `GET /ai/capability-badges` | 已接入 |

## vivo 官方能力清单

| docId | 分组 | 能力 | 官方端点/协议 | 方法 | 鉴权 | 默认模型/引擎 | StudyTrace 映射 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1745 | 文本生成 | 大模型 | `https://api-ai.vivo.com.cn/v1/chat/completions` | POST | Bearer AppKey | `Volc-DeepSeek-V3.2`, `Doubao-Seed-2.0-mini`, `Doubao-Seed-2.0-lite`, `Doubao-Seed-2.0-pro`, `qwen3.5-plus` | `/ai/chat`, `/ai/chat/stream`, 学习生成类接口 |
| 1805 | 文本生成 | Function calling | 消息/提示词协议 | n/a | n/a | n/a | `ai_tool_registry.dart` + `/ai/chat` JSON actions |
| 1732 | 图片生成 | 图片生成 | `https://api-ai.vivo.com.cn/api/v1/image_generation` | POST | Bearer AppKey | `Doubao-Seedream-4.5`, `Doubao-Seedream-5.0-lite` | `/ai/images/tasks`, `/ai/images/tasks/status` |
| 2201 | 视频生成 | 视频生成 | `/api/v1/submit_task`, `/api/v1/query_task` | POST, GET | Bearer AppKey | `Doubao-Seedance-1.0-pro`, `Doubao-Seedance-2.0`, `Doubao-Seedance-2.0-fast` | `/ai/videos/tasks`, `/ai/videos/tasks/status` |
| 1737 | 视觉技术 | 通用 OCR | `/ocr/general_recognition` | POST form | Bearer AppKey | n/a | `/ai/ocr` |
| 1733 | 自然语言处理 | 文本翻译 | `/translation/query/self` | POST | Bearer AppKey | n/a | `/ai/translate` |
| 1734 | 自然语言处理 | 文本向量 | `/embedding-model-api/predict/batch` | POST | Bearer AppKey | `m3e-base`, `bge-base-zh-v1.5` | `/ai/embeddings`, `/ai/memory/index`, `/ai/memory/search` |
| 2060 | 自然语言处理 | 文本相似度 | `/rerank` | POST | Bearer AppKey | `bge-reranker-large` | `/ai/rerank` |
| 2061 | 自然语言处理 | 查询改写 | `/query_rewrite_base` | POST | Bearer AppKey | n/a | `/ai/query-rewrite` |
| 1738 | ASR | 实时短语音识别 | `ws://api-ai.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | `shortasrinput` | 仅登记，实时流式识别待后续专项 |
| 1740 | ASR | 长语音听写 | `ws://asr-test-v2.vivo.com.cn/asr/v2` | WebSocket | Bearer AppKey | n/a | 仅登记，待接入 |
| 1739 | ASR | 长语音转写 | `/lasr/create`, `/lasr/upload`, `/lasr/run`, `/lasr/progress`, `/lasr/result` | HTTP 多步 | Bearer AppKey | `fileasrrecorder` | `/ai/speech/transcribe` |
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
- `partial`: 已有相近业务能力或配置登记，但未完整覆盖官方协议。
- `planned`: 已登记官方能力和配置占位，后续可按需接入。
- `manual`: 需要 native SDK、超大文件上传、或人工下载官方包，不适合在本任务直接接入。

## 配置原则

- 密钥只放后端环境变量，不进入 Flutter。
- `BLUEHEART_API_KEY` 用于 OpenAI 兼容 Bearer 调用和 1746 云端 HTTP API Bearer 鉴权。
- `BLUEHEART_APP_ID` 用于需要 AppId 或签名的能力。
- 图片生成默认模型由 `VIVO_IMAGE_MODEL` 控制，默认 `Doubao-Seedream-5.0-lite`。
- 视频生成默认模型由 `VIVO_VIDEO_MODEL` 控制，默认 `Doubao-Seedance-1.0-pro`。
- 官方路径优先登记在 `backend/src/modules/ai/vivo-capabilities.ts`。
- `.env.example` 只提供占位和默认官方路径，不写真实值。

## 后续接入建议

1. 优先接入文本/JSON 能力，因为它们和现有 `AiService` / `VivoGatewayService` 最贴合。
2. WebSocket ASR/TTS 需要单独设计服务端转发、断线、音频分帧和移动端权限，不建议和普通 HTTP 能力混改。
3. 长音频转写已接入基础录音文件流程；更长课堂录音、后台上传和文件管理可单独扩展。
4. 端侧 3B 与端侧审核涉及 Android AAR/native SDK，应作为 Android 专项任务处理。
5. 每新增一个 live 能力，应同步更新本文件、`vivo-capabilities.ts`、`.env.example` 和前端 `VivoCapabilityService`。

## 适合学迹继续深化的 API 用法

| 能力 | 学迹场景 | 当前状态 | 下一步建议 |
| --- | --- | --- | --- |
| 通用 OCR | 拍照整理题目、板书、课件，生成笔记/任务/闪卡 | 已接入 `/ai/ocr`，桌面端已避免 MLKit 插件崩溃 | 保留云端优先；可把 OCR 结果直接送入学习小结和闪卡生成 |
| 大模型图片理解 | 题目截图讲解、课堂图片归纳、学习材料问答 | `/ai/chat` 已支持 `imageBase64` | 在拍照整理里增加“提取文字 + 理解内容”的双通道提示 |
| 图片生成 | 笔记配图、动态封面、小组挑战封面 | 已按最新同步接口更新后端，相关前端入口优先直接展示返回图 | 后续可增加尺寸/风格选择 |
| 视频生成 | 把学习报告/知识点做成 5 秒复盘短片 | 后端已按 2201 任务接口更新；AI action 已有 `media.generate_video` | 增加“生成学习复盘视频”入口，默认使用学习报告摘要做 prompt |
| 文本向量 | 个人学习记忆检索、按语义找历史笔记/任务 | 已按 1734 官方 `model_name + sentences` 更新 | 继续积累学习资料索引，提升助手回答的个人化程度 |
| 实时短语音识别 | 语音复盘、口述学习记录 | 端侧 SAPI/本机识别已可用；官方实时 WebSocket 未完整接入 | 实时流式对话作为后续专项 |
| 长语音转写 | 语音复盘、课堂录音/讲座录音转笔记 | `/ai/speech/transcribe` 已接入官方 LASR 多步流程，现有录音复盘可直接使用 | 后续可增加“课堂录音整理”文件上传入口 |
| 音频生成/TTS | AI 学习报告朗读、每日鼓励播报 | 当前主要用本机 TTS | 官方 TTS 为 WebSocket，适合后续服务端转发，不建议混入本次 HTTP 更新 |
