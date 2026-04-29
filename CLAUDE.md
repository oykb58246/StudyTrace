# StudyTrace CLI 开发指令

## 项目概要

StudyTrace — Flutter 大学生学习管理 App。MVVM 架构，SharedPreferences 本地存储，DeepSeek AI 集成。详细结构见 `项目当前总结.md`。

---

## 每次会话流程

### 1. 环境初始化（一次性）
```bash
flutter pub get && flutter analyze
```

### 2. 理解需求 → 直接编码

- 先读相关文件（并行读取），理解后再动手
- 用户给多个需求时**一次性全部处理**，不要拆成多次会话
- 增量修改，不删除已有功能代码
- 新增模型/页面/服务遵循现有目录结构

### 3. 验证（所有修改完成后一次性运行）
```bash
flutter analyze && flutter test
```

有错误才逐一定位修复，不要改一行跑一次。

### 4. 简要汇报

只列出：修改了哪些文件、做什么、analyze/test 结果。不加冗长总结。

---

## 关键规则

- **不自动 git commit**，等用户确认
- `flutter analyze` 必须 0 错误
- 不引入 pubspec.yaml 没有的新依赖，除非必要
- 遇到真机才能验证的功能（通知、语音），加 try-catch 兜底，不让测试崩溃
- 项目结构以 `项目当前总结.md` 为准，本文档不重复

---

## 常用命令

```bash
flutter pub get              # 安装依赖
flutter analyze              # 静态检查
flutter test                 # 单元/Widget 测试
flutter run                  # 启动到设备
flutter build apk --debug    # 构建 debug APK
```
