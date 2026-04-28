import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_config.dart';
import '../../services/deepseek_client.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late String _model;
  late bool _isEnabled;
  late bool _thinkingMode;
  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.aiConfig;
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _model = config.model;
    _isEnabled = config.isEnabled;
    _thinkingMode = config.thinkingMode;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDarkMode ? Colors.white : Colors.black;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ListView(
          key: const Key('page_ai_settings'),
          padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
          children: [
            Text(
              '系统设置',
              style: TextStyle(
                color: titleColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '配置 DeepSeek API 与智能输入能力',
              style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 18),
            _statusCard(),
            const SizedBox(height: 14),
            GlassCard(
              color: widget.isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.9)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF7040F2),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'DeepSeek API',
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white
                                : AppColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF7040F2),
                        onChanged: (value) =>
                            setState(() => _isEnabled = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _apiKeyController,
                    label: widget.controller.hasDeepSeekApiKey
                        ? 'API Key（已保存，可留空）'
                        : 'API Key',
                    hintText: 'sk-...',
                    obscureText: _obscureKey,
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? '显示' : '隐藏',
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _model,
                    decoration: _inputDecoration('模型'),
                    dropdownColor: widget.isDarkMode
                        ? const Color(0xFF242B37)
                        : Colors.white,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'deepseek-v4-flash',
                        child: Text('deepseek-v4-flash'),
                      ),
                      DropdownMenuItem(
                        value: 'deepseek-v4-pro',
                        child: Text('deepseek-v4-pro'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _model = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _baseUrlController,
                    label: 'Base URL',
                    hintText: AiConfig.defaultBaseUrl,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _thinkingMode,
                    onChanged: (value) => setState(() => _thinkingMode = value),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF7040F2),
                    title: Text(
                      '深度分析模式',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '用于周报和风险提醒时给模型更审慎的分析要求',
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white54
                            : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7040F2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: const Text(
                              '保存',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: '测试连接',
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: '删除 API Key',
                        onPressed: widget.controller.hasDeepSeekApiKey
                            ? _deleteKey
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              color: widget.isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.9)
                  : null,
              child: Row(
                children: [
                  const Icon(
                    Icons.image_search_rounded,
                    color: Color(0xFF7394F9),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '图片 OCR 与语音输入会先转成文字，再交给当前 AI 模式整理。',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusCard() {
    final usingRealAi = widget.controller.isUsingRealAi;
    final color =
        usingRealAi ? const Color(0xFF4BC4A1) : const Color(0xFFF8AA5B);
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color.withValues(alpha: widget.isDarkMode ? 0.16 : 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            usingRealAi ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
            color: color,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usingRealAi ? '真实 AI 模式' : '演示模式',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  usingRealAi
                      ? '${widget.controller.aiConfig.model} 已启用'
                      : '未启用 DeepSeek 时会继续使用本地模拟结果',
                  style: TextStyle(color: bodyColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        color: widget.isDarkMode ? Colors.white : AppColors.ink,
        fontSize: 14,
      ),
      decoration: _inputDecoration(label).copyWith(
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: widget.isDarkMode ? Colors.white70 : AppColors.muted,
      ),
      filled: true,
      fillColor: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF2F5FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  AiConfig _formConfig() {
    final baseUrl = _baseUrlController.text.trim().isEmpty
        ? AiConfig.defaultBaseUrl
        : _baseUrlController.text.trim();
    return AiConfig(
      baseUrl: baseUrl,
      model: _model,
      thinkingMode: _thinkingMode,
      isEnabled: _isEnabled,
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveAiSettings(
        config: _formConfig(),
        deepSeekApiKey: _apiKeyController.text,
      );
      _apiKeyController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 设置已保存'),
          backgroundColor: Color(0xFF4BC4A1),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final ok = await widget.controller.testDeepSeekConnection(
        candidateApiKey: _apiKeyController.text,
        config: _formConfig(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'DeepSeek 连接成功' : 'DeepSeek 连接失败'),
          backgroundColor:
              ok ? const Color(0xFF4BC4A1) : const Color(0xFFF77D8E),
        ),
      );
    } on AiServiceException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('DeepSeek 连接失败：$error');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _deleteKey() async {
    await widget.controller.deleteDeepSeekApiKey();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DeepSeek API Key 已删除')),
    );
    setState(() => _isEnabled = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFF77D8E)),
    );
  }
}
