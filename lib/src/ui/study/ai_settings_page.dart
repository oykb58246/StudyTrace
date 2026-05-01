import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_config.dart';
import '../../services/blueheart_model_client.dart';
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
  late final TextEditingController _deepSeekApiKeyController;
  late final TextEditingController _blueHeartAppKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _appIdController;
  late final TextEditingController _maxTokensController;
  late String _deepSeekModel;
  late String _blueHeartModel;
  late double _temperature;
  late double _topP;
  late bool _thinkingEnabled;
  late double _frequencyPenalty;
  late double _presencePenalty;
  late String _reasoningEffort;
  late bool _isEnabled;
  bool _obscureDeepSeekKey = true;
  bool _obscureBlueHeartKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _showAdvanced = false;

  static const _deepSeekModels = [
    'deepseek-v4-flash',
    'deepseek-v4-pro',
  ];

  @override
  void initState() {
    super.initState();
    final config = widget.controller.aiConfig;
    _deepSeekApiKeyController = TextEditingController();
    _blueHeartAppKeyController = TextEditingController();
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _appIdController = TextEditingController(text: config.appId);
    _maxTokensController =
        TextEditingController(text: config.maxTokens.toString());
    _deepSeekModel = config.model;
    _blueHeartModel = config.blueHeartModel;
    _temperature = config.temperature;
    _topP = config.topP;
    _thinkingEnabled = config.thinkingEnabled;
    _frequencyPenalty = config.frequencyPenalty;
    _presencePenalty = config.presencePenalty;
    _reasoningEffort = config.reasoningEffort;
    _isEnabled = config.isEnabled;
  }

  @override
  void dispose() {
    _deepSeekApiKeyController.dispose();
    _blueHeartAppKeyController.dispose();
    _baseUrlController.dispose();
    _appIdController.dispose();
    _maxTokensController.dispose();
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
        final accent = widget.controller.primaryColor;
        return ListView(
          key: const Key('page_ai_settings'),
          padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
          children: [
            Text(
              'AI 设置',
              style: TextStyle(
                color: titleColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '蓝心大模型已内置，开箱即用；也可配置 DeepSeek 作为备选',
              style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 18),
            _skinSelector(),
            const SizedBox(height: 14),
            _statusCard(),
            const SizedBox(height: 14),

            _buildSectionCard(
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF4470E8),
              title: '蓝心大模型',
              subtitle: '内置 AppKey，支持聊天、OCR 和语音识别',
              badge: '内置',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _blueHeartAppKeyController,
                        label: widget.controller.hasBlueHeartAppKey
                            ? 'AppKey（已内置，可覆盖）'
                            : 'AppKey',
                        hintText: '留空使用内置 AppKey',
                        obscureText: _obscureBlueHeartKey,
                        suffixIcon: IconButton(
                          tooltip: _obscureBlueHeartKey ? '显示' : '隐藏',
                          onPressed: () => setState(
                              () => _obscureBlueHeartKey = !_obscureBlueHeartKey),
                          icon: Icon(
                            _obscureBlueHeartKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '删除蓝心 AppKey',
                      onPressed: widget.controller.hasBlueHeartAppKey
                          ? _deleteBlueHeartKey
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _appIdController,
                  label: 'AppId（OCR / ASR 需要）',
                  hintText: '用于 businessid = aigc + AppId',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _blueHeartModel,
                  decoration: _inputDecoration('聊天模型'),
                  dropdownColor: widget.isDarkMode
                      ? const Color(0xFF242B37)
                      : Colors.white,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  items: BlueHeartModelClient.supportedModels.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _blueHeartModel = value);
                  },
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: bodyColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '高级参数',
                        style: TextStyle(color: bodyColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temperature: ${_temperature.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Slider(
                              value: _temperature,
                              min: 0,
                              max: 2.0,
                              divisions: 20,
                              activeColor: accent,
                              inactiveColor: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE0E4EE),
                              onChanged: (v) =>
                                  setState(() => _temperature = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _maxTokensController,
                    label: 'Max Tokens',
                    hintText: '1200',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top P: ${_topP.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Slider(
                              value: _topP,
                              min: 0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: accent,
                              inactiveColor: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE0E4EE),
                              onChanged: (v) => setState(() => _topP = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: _thinkingEnabled,
                    onChanged: (v) =>
                        setState(() => _thinkingEnabled = v),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: accent,
                    title: Text(
                      '深度思考模式',
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white
                            : AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '模型先思考再回答，适合复杂分析',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '频率惩罚: ${_frequencyPenalty.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Slider(
                              value: _frequencyPenalty,
                              min: -2.0,
                              max: 2.0,
                              divisions: 40,
                              activeColor: accent,
                              inactiveColor: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE0E4EE),
                              onChanged: (v) =>
                                  setState(() => _frequencyPenalty = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '存在惩罚: ${_presencePenalty.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Slider(
                              value: _presencePenalty,
                              min: -2.0,
                              max: 2.0,
                              divisions: 40,
                              activeColor: accent,
                              inactiveColor: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE0E4EE),
                              onChanged: (v) =>
                                  setState(() => _presencePenalty = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _reasoningEffort,
                    decoration: _inputDecoration('思考深度'),
                    dropdownColor: widget.isDarkMode
                        ? const Color(0xFF242B37)
                        : Colors.white,
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('默认')),
                      DropdownMenuItem(value: 'minimal', child: Text('Minimal — 最快')),
                      DropdownMenuItem(value: 'low', child: Text('Low — 快速')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium — 均衡')),
                      DropdownMenuItem(value: 'high', child: Text('High — 深度')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _reasoningEffort = v);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '蓝心大模型同时为聊天、学习日志生成等 AI 功能提供支持。'
                  'OCR 和语音识别依赖 AppKey + AppId 组合。',
                  style: TextStyle(color: bodyColor, fontSize: 13, height: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSectionCard(
              icon: Icons.tungsten_rounded,
              iconColor: const Color(0xFF7394F9),
              title: 'DeepSeek（备选）',
              subtitle: '可选配置，蓝心不可用时自动切换',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _deepSeekApiKeyController,
                        label: widget.controller.hasDeepSeekApiKey
                            ? 'API Key（已保存，可留空）'
                            : 'API Key',
                        hintText: 'sk-...',
                        obscureText: _obscureDeepSeekKey,
                        suffixIcon: IconButton(
                          tooltip: _obscureDeepSeekKey ? '显示' : '隐藏',
                          onPressed: () => setState(
                              () => _obscureDeepSeekKey = !_obscureDeepSeekKey),
                          icon: Icon(
                            _obscureDeepSeekKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '删除 DeepSeek Key',
                      onPressed: widget.controller.hasDeepSeekApiKey
                          ? _deleteKey
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _deepSeekModel,
                  decoration: _inputDecoration('聊天模型'),
                  dropdownColor: widget.isDarkMode
                      ? const Color(0xFF242B37)
                      : Colors.white,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  items: _deepSeekModels.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _deepSeekModel = value);
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _baseUrlController,
                  label: 'Base URL',
                  hintText: AiConfig.defaultBaseUrl,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: '测试连接',
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            GlassCard(
              color: widget.isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.9)
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '启用 AI 功能',
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '关闭后所有 AI 功能使用本地模拟结果',
                          style: TextStyle(color: bodyColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: accent,
                    onChanged: (value) => setState(() => _isEnabled = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
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
                  '保存设置',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
    String? badge,
  }) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return GlassCard(
      color: widget.isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.9)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4BC4A1)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFF4BC4A1),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _skinSelector() {
    final accent = widget.controller.primaryColor;
    return GlassCard(
      color: widget.isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.9)
          : null,
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.palette_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('皮肤主题',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text('切换 app 主色调',
                    style: TextStyle(
                        color: widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                        fontSize: 12)),
              ],
            ),
          ),
          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: accent,
              selectedForegroundColor: Colors.white,
            ),
            segments: const [
              ButtonSegment(value: true, label: Text('vivo蓝', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: false, label: Text('传统', style: TextStyle(fontSize: 12))),
            ],
            selected: {widget.controller.skinVivo},
            onSelectionChanged: (v) => widget.controller.setSkinVivo(v.first),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final hasBlueHeart = widget.controller.hasBlueHeartAppKey;
    final hasDeepSeek = widget.controller.hasDeepSeekApiKey;
    final usingRealAi = widget.controller.isUsingRealAi;

    final (String label, String detail, Color color) = hasBlueHeart
        ? (
            '蓝心大模型已就绪',
            '内置 AppKey，聊天 + OCR 可用',
            const Color(0xFF4470E8),
          )
        : hasDeepSeek && _isEnabled
            ? (
                'DeepSeek 已就绪',
                _deepSeekModel,
                const Color(0xFF7394F9),
              )
            : usingRealAi
                ? (
                    'AI 已就绪',
                    '已配置 AI 服务',
                    const Color(0xFF4BC4A1),
                  )
                : (
                    '未配置 AI',
                    '请添加蓝心或 DeepSeek 密钥',
                    const Color(0xFFF77D8E),
                  );

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
            hasBlueHeart || hasDeepSeek
                ? Icons.cloud_done_rounded
                : Icons.offline_bolt_rounded,
            color: color,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
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
        ? widget.controller.aiConfig.baseUrl
        : _baseUrlController.text.trim();
    final maxTokens = int.tryParse(_maxTokensController.text.trim()) ?? 1200;
    return AiConfig(
      baseUrl: baseUrl,
      model: _deepSeekModel,
      appId: _appIdController.text.trim(),
      blueHeartModel: _blueHeartModel,
      temperature: _temperature,
      maxTokens: maxTokens.clamp(1, 65536),
      topP: _topP,
      thinkingEnabled: _thinkingEnabled,
      frequencyPenalty: _frequencyPenalty,
      presencePenalty: _presencePenalty,
      reasoningEffort: _reasoningEffort,
      isEnabled: _isEnabled,
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveAiSettings(
        config: _formConfig(),
        deepSeekApiKey: _deepSeekApiKeyController.text,
        blueHeartAppKey: _blueHeartAppKeyController.text,
      );
      _deepSeekApiKeyController.clear();
      _blueHeartAppKeyController.clear();
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
        candidateApiKey: _deepSeekApiKeyController.text,
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
      _showError('连接失败：$error');
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

  Future<void> _deleteBlueHeartKey() async {
    await widget.controller.deleteBlueHeartAppKey();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('蓝心 AppKey 已删除')),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFF77D8E)),
    );
  }
}
