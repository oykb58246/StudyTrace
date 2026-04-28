# 灵析 AI 助手 - 项目开发指令

## 项目背景

一个基于 Flutter 的 AI 助手应用，采用 MVVM 架构（ChangeNotifier），包含 AI 分析、待办管理、场景展示、管理后台等功能。当前 AI 服务为模拟层，需要逐步接入真实 API 并完善各模块功能。

---

## 强制流程：每次会话必须遵循

### 第 1 步：初始化环境

```bash
flutter pub get
```

确保所有依赖安装完毕。

### 第 2 步：选择下一个任务

读取 `task.json`，选择 **一个** `passes: false` 的任务。

选择优先级：
1. 优先选择 `passes: false` 的任务
2. 考虑依赖关系 —— 基础功能应该先做
3. 选择优先级最高的未完成任务

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

### 第 5 步：测试验证

**强制测试要求：**

1. **代码检查**：
   ```bash
   flutter analyze
   ```
   必须无错误通过。

2. **页面修改测试**：
   - 涉及 UI/页面修改时，尝试启动模拟器进行测试
   - 如果无法启动模拟器，必须在 `progress.txt` 中说明原因
   - 原因可包括：没有安装模拟器、没有可用设备、环境限制等

3. **构建验证**（涉及大幅修改时）：
   ```bash
   flutter build apk --debug
   ```
   确保可以成功构建。

**测试清单：**
- [ ] `flutter analyze` 无错误
- [ ] 页面修改已在模拟器测试，或在 progress.txt 中说明无法测试的原因
- [ ] 构建成功（如适用）

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

### 第 7 步：汇报修改，等待确认

**不要直接提交 git commit。** 必须先向用户汇报：

1. 列出所有修改的文件
2. 简要描述每个文件的改动
3. 汇报测试结果
4. 询问用户是否需要提交

---

## 阻塞处理

**以下情况需要停止任务并请求人工帮助：**

1. **缺少环境配置**：
   - API 密钥未配置
   - 外部服务需要开通

2. **外部依赖不可用**：
   - 第三方 API 不可用
   - 需要人工授权的流程

3. **测试无法进行**：
   - 模拟器不可用且需要 UI 测试
   - 需要特定硬件环境

**阻塞时的正确做法：**
- 在 `progress.txt` 中记录当前进度和阻塞原因
- 输出清晰的阻塞信息
- 不要标记任务为完成

---

## 项目结构

```
lib/
├── main.dart                           # 应用入口
├── app/app.dart                        # MaterialApp 定义
└── src/
    ├── controllers/
    │   └── app_data_controller.dart     # 状态管理 (ChangeNotifier)
    ├── models/
    │   ├── analysis_item.dart           # AI 分析结果模型
    │   ├── history_item.dart            # 历史记录模型
    │   └── todo_item.dart               # 待办事项模型
    ├── services/
    │   ├── ai_service.dart              # AI 分析服务（当前为模拟层）
    │   └── local_storage_service.dart   # SharedPreferences 持久化
    ├── theme/
    │   └── app_theme.dart               # Material 主题定义
    └── ui/
        ├── analysis/
        │   └── analysis_result_page.dart # AI 分析结果详情页
        ├── login/
        │   └── login_screen.dart         # 欢迎/登录页
        ├── shared/
        │   ├── app_assets.dart           # 资源路径常量
        │   ├── common_widgets.dart        # 共享 UI 组件
        │   └── rive_safe_widget.dart      # Rive 安全封装
        └── shell/
            ├── admin_section_page.dart    # 管理后台页面
            ├── app_shell.dart             # 主应用外壳
            ├── create_page.dart           # 创建/待办页
            ├── extension_page.dart        # 场景页
            ├── navigation_models.dart     # 导航枚举
            ├── tool_home_page.dart        # 助手/AI 分析页
            └── user_page.dart             # 个人资料页
```

## 常用命令

```bash
flutter pub get          # 安装依赖
flutter analyze          # 代码检查
flutter run              # 启动应用
flutter build apk --debug  # 构建 APK
flutter test             # 运行测试
```

## 代码约定

- MVVM 架构：View → ViewModel (ChangeNotifier) → Model/Service
- 手动构造函数注入（不使用 Provider/Riverpod）
- 命令式导航（MaterialPageRoute）
- 页面内的私有组件使用 `_` 前缀
- 使用 Tailwind 风格的间距和圆角
- 支持暗黑/亮色双模式

---

## 核心规则

1. **一次一个任务** —— 每个会话只完成一个任务
2. **先测试再标记完成** —— 所有步骤必须验证通过
3. **`flutter analyze` 必须通过** —— 每次任务完成后运行
4. **页面修改需要 UI 测试** —— 启动模拟器或说明无法测试的原因
5. **记录到 progress.txt** —— 帮助后续任务理解上下文
6. **不自动提交 git** —— 先汇报修改内容，等待用户确认
7. **不删除已有代码** —— 只在现有基础上增量完善
8. **遇到阻塞及时停止** —— 不要假装任务完成
