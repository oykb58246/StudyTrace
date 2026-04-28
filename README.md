# StudyTrace 学迹

> 大学生课程任务管理与 AI 学习周报生成 App

StudyTrace 是一款面向大学生的 Flutter 移动端应用，支持课程任务管理、每日学习记录、番茄钟计时、学习数据统计，并深度集成 AI 能力——自动生成结构化学习日志、智能拆解复杂任务、AI 分析周报、风险提醒、知识闪卡等功能，形成"**记录 → 执行 → 分析 → 复盘**"的智能学习闭环。

---

## 功能概览

### 核心功能
- **课程任务管理** — 创建/编辑/删除任务，按状态/类型筛选，支持子任务拆解
- **每日学习记录** — 记录学习内容、问题、思考、下一步计划，按课程分类
- **学习日历** — 月视图日历，标记每日学习记录，点击查看详情
- **学习周报** — 基于一周学习数据自动生成结构化周报，支持保存和复制
- **课程归档** — 自动聚合课程的任务与记录，按课程浏览历史学习数据
- **学习统计** — 饼图（课程分布）+ 柱状图（7天趋势）+ 完成率统计卡片
- **连续打卡** — 跟踪连续学习天数，7 天以上显示火焰徽章
- **番茄钟计时** — 5/15/25/45/60 分钟预设，计时结束 AI 自动生成学习记录

### AI 智能能力
- **AI 生成学习日志** — 输入自然语言描述，AI 自动生成结构化学习记录
- **AI 智能拆解任务** — 输入复杂任务，AI 拆解为子任务列表并自动创建
- **AI 分析型周报** — 基于近期数据生成 7 维度深度分析（主题/投入/问题/完成率/风险/评价/建议）
- **AI 风险提醒** — 自动检测截止风险、进度偏低、课程断档等问题，按级别预警
- **AI 知识闪卡** — 从学习记录自动生成问答闪卡，点击翻转查看答案
- **语音创建任务** — 语音输入描述，AI 自动拆解并创建学习任务
- **图片 OCR 输入** — 拍照/选图识别文字，直接用于 AI 学习记录生成

### 更多功能
- **深色模式** — 全局深色/浅色主题切换
- **个人信息** — 自定义头像表情、昵称、个人签名
- **学习笔记** — 自由书写笔记，支持标题/内容/关联课程/搜索
- **API 配置** — 支持配置 DeepSeek API Key，切换模型，测试连接

---

## 技术栈

| 项目 | 内容 |
|------|------|
| 框架 | Flutter 3.x (Material Design 3) |
| 架构 | MVVM (ChangeNotifier) |
| 语言 | Dart |
| 存储 | SharedPreferences（本地 JSON）+ flutter_secure_storage（API Key）|
| AI 服务 | DeepSeek Chat Completions API（支持 mock 演示模式）|
| 关键依赖 | `table_calendar` `fl_chart` `rive` `speech_to_text` `google_mlkit_text_recognition` `image_picker` `http` |
| 平台 | Android |

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
```

### 配置 AI 能力

1. 打开 App → 侧栏 → 系统设置
2. 填写 DeepSeek API Key
3. 选择模型（deepseek-v4-flash / deepseek-v4-pro）
4. 点击「测试连接」验证
5. 未配置 API Key 时自动使用 Mock 演示模式

---

## 项目结构

```
lib/
├── main.dart                             # 应用入口
└── src/
    ├── controllers/
    │   └── app_data_controller.dart       # 全局状态管理
    ├── models/
    │   ├── study_task_item.dart           # 学习任务
    │   ├── study_log_item.dart            # 学习日志
    │   ├── weekly_report_item.dart        # 周报
    │   ├── study_note.dart                # 学习笔记
    │   ├── user_profile.dart              # 用户资料
    │   ├── ai_generated_log.dart          # AI 生成日志
    │   ├── ai_task_plan.dart              # AI 任务拆解
    │   ├── ai_study_analysis.dart         # AI 分析周报
    │   ├── ai_risk_warning.dart           # AI 风险提醒
    │   ├── ai_flash_card.dart             # AI 知识闪卡
    │   └── ai_config.dart                 # AI 配置模型
    ├── services/
    │   ├── local_storage_service.dart     # 本地持久化
    │   ├── weekly_report_service.dart     # 周报生成
    │   ├── ai_study_service.dart          # AIGC 核心服务
    │   ├── deepseek_client.dart           # DeepSeek API 客户端
    │   ├── ai_credential_service.dart     # 凭据安全存储
    │   └── ai_report_service.dart         # 旧版 AI 润色预留
    ├── theme/
    │   └── app_theme.dart                 # MD3 主题配置
    └── ui/
        ├── shared/
        │   └── common_widgets.dart        # 通用组件
        ├── login/
        │   └── login_screen.dart          # 登录/注册页
        ├── shell/
        │   ├── app_shell.dart             # 主壳（侧栏+底部导航）
        │   ├── navigation_models.dart     # 导航枚举
        │   ├── admin_section_page.dart    # 侧栏页面路由
        │   ├── tool_home_page.dart        # 首页 Dashboard
        │   ├── create_page.dart           # 任务列表
        │   ├── extension_page.dart        # 学习记录列表
        │   └── user_page.dart             # 课程归档
        └── study/
            ├── calendar_page.dart         # 学习日历
            ├── statistics_page.dart       # 学习统计
            ├── timer_page.dart            # 番茄钟
            ├── ai_assistant_page.dart     # AI 学习助手
            ├── ai_settings_page.dart      # AI API 设置
            ├── flash_card_page.dart       # AI 知识闪卡
            ├── study_notes_page.dart      # 学习笔记
            └── user_profile_page.dart     # 用户资料编辑
```

---

## 导航结构

```
底部导航
├── 首页   — 仪表盘、AI 入口、周报生成、任务进度
├── 记录   — 学习日志列表、搜索、筛选
├── 日历   — 月视图日历、日视图记录
├── 任务   — 任务管理、搜索、状态/类型筛选
└── 归档   — 课程汇总、历史周报

侧边菜单
├── BROWSE
│   ├── 作品总览
│   ├── AI 学习助手
│   ├── 学习笔记
│   ├── 学习统计
│   ├── 专注计时
│   └── 知识闪卡
└── 管理
    ├── 任务编排
    ├── 数据看板
    └── 系统设置（API Key / 深色模式）
```

---

## 演示流程

```
1. 打开 App → 登录 → 进入首页 Dashboard
2. 查看连续打卡天数、任务进度、最近学习记录
3. 点击「语音创建任务」→ 说话 → AI 自动拆解并创建
4. 侧栏 → AI 学习助手 → 输入学习描述 → AI 生成结构化日志
5. AI 学习助手 → AI 拆解任务 → 一键加入任务列表
6. 首页 → 生成学习周报 → 保存到历史
7. AI 学习助手 → AI 风险提醒 → 查看预警
8. 侧栏 → 知识闪卡 → 翻转浏览 AI 生成的复习卡片
```

---

## 许可证

MIT License
