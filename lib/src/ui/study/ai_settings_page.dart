import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../controllers/app_data_controller.dart';
import '../../models/ai_config.dart';
import '../../models/daily_reminder_settings.dart';
import '../../services/blueheart_model_client.dart';
import '../../services/deepseek_client.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

enum AiSettingsMode { ai, system }

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.mode = AiSettingsMode.ai,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final AiSettingsMode mode;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _deepSeekApiKeyController;
  late final TextEditingController _blueHeartAppKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _serverBaseUrlController;
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
  bool _isTestingBackend = false;
  bool _showAdvanced = false;
  DailyReminderSettings _dailyReminderSettings =
      DailyReminderSettings.defaults;
  bool _isLoadingReminder = true;
  bool _isSavingReminder = false;

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
    _serverBaseUrlController = TextEditingController(text: widget.controller.apiBaseUrl);
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
    _loadDailyReminderSettings();
  }

  @override
  void dispose() {
    _deepSeekApiKeyController.dispose();
    _blueHeartAppKeyController.dispose();
    _baseUrlController.dispose();
    _serverBaseUrlController.dispose();
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
        if (widget.mode == AiSettingsMode.system) {
          return _buildSystemSettingsView(
            titleColor: titleColor,
            bodyColor: bodyColor,
          );
        }

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

  Widget _buildSystemSettingsView({
    required Color titleColor,
    required Color bodyColor,
  }) {
    return ListView(
      key: const Key('page_system_settings'),
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
          '账号同步、本地通知与应用偏好集中管理。',
          style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 18),
        _buildAccountSyncSection(),
        const SizedBox(height: 14),
        _buildServerApiSection(),
        const SizedBox(height: 14),
        _skinSelector(),
        const SizedBox(height: 14),
        _buildNotificationSection(),
        const SizedBox(height: 14),
        _buildSectionCard(
          icon: Icons.settings_suggest_rounded,
          iconColor: const Color(0xFF7D9BFF),
          title: '其他设置',
          subtitle: '通用偏好与后续系统选项',
          children: [
            Text(
              '深色模式可在侧边栏快捷切换；隐私、导出与备份偏好后续会统一收纳在这里。',
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ],
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

  Widget _buildServerApiSection() {
    return _buildSectionCard(
      icon: Icons.dns_rounded,
      iconColor: const Color(0xFFF8AA5B),
      title: '后端服务代理与 API',
      subtitle: '配置以链接云同步、学习小组与 AI 管理',
      children: [
        _buildTextField(
          controller: _serverBaseUrlController,
          label: 'NestJS 后端地址',
          hintText: '如: http://10.0.2.2:3000 等',
          onChanged: (val) {
            widget.controller.setApiBaseUrl(val.trim());
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isTestingBackend)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton.icon(
              onPressed: _isTestingBackend ? null : _testBackendConnection,
              icon: const Icon(Icons.wifi_protected_setup_rounded, size: 18),
              label: const Text('测试连接'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF8AA5B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSyncSection() {
    final accent = widget.controller.primaryColor;
    final isLoggedIn = widget.controller.isLoggedIn;
    
    return _buildSectionCard(
      icon: Icons.cloud_sync_rounded,
      iconColor: const Color(0xFF4CB9FF),
      title: '账号登录与云同步',
      subtitle: '备份学习数据到云端，多端共享',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isLoggedIn ? '已登录: 测试账号\n可以进行云同步任务。' : '尚未登录\n请配置后端服务后在此登录',
                style: TextStyle(
                  color: widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (isLoggedIn) {
                  widget.controller.logout();
                } else {
                  // Simulate Login for now
                  widget.controller.login('fake-jwt-token-12345');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLoggedIn ? Colors.redAccent : accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(isLoggedIn ? '退出登录' : '去登录'),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    final accent = widget.controller.primaryColor;
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final timeLabel = _dailyReminderSettings.time.format(context);

    return _buildSectionCard(
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFF4BC4A1),
      title: '本地通知',
      subtitle: '任务截止提醒和每日学习提醒',
      children: [
        SwitchListTile(
          value: _dailyReminderSettings.enabled,
          onChanged: _isLoadingReminder || _isSavingReminder
              ? null
              : (value) => _saveDailyReminder(
                    _dailyReminderSettings.copyWith(enabled: value),
                  ),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: accent,
          title: Text(
            '每日学习提醒',
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '默认 20:00，可根据学习节奏调整',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '提醒时间',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isLoadingReminder || _isSavingReminder
                  ? null
                  : _pickDailyReminderTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(timeLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.isDarkMode ? Colors.white : accent,
                side: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.white24
                      : accent.withValues(alpha: 0.22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Android 13 及以上会在初始化时请求通知权限；任务提醒会在任务完成、删除或修改时自动同步。',
          style: TextStyle(color: bodyColor, fontSize: 12, height: 1.45),
        ),
        if (_isSavingReminder) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(color: accent, minHeight: 2),
        ],
      ],
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
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
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

  Future<void> _loadDailyReminderSettings() async {
    try {
      final settings = await widget.controller.loadDailyReminderSettings();
      if (!mounted) return;
      setState(() {
        _dailyReminderSettings = settings;
        _isLoadingReminder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReminder = false);
    }
  }

  Future<void> _pickDailyReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyReminderSettings.time,
    );
    if (!mounted || picked == null) return;
    await _saveDailyReminder(
      _dailyReminderSettings.copyWith(enabled: true, time: picked),
    );
  }

  Future<void> _saveDailyReminder(DailyReminderSettings settings) async {
    setState(() => _isSavingReminder = true);
    try {
      await widget.controller.saveDailyReminderSettings(settings);
      if (!mounted) return;
      setState(() => _dailyReminderSettings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.enabled ? '每日学习提醒已开启' : '每日学习提醒已关闭'),
          backgroundColor: const Color(0xFF4BC4A1),
        ),
      );
    } catch (error) {
      _showError('通知设置保存失败：$error');
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
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

  Future<void> _testBackendConnection() async {
    setState(() => _isTestingBackend = true);
    final urlStr = _serverBaseUrlController.text.trim();
    try {
      if (urlStr.isEmpty) {
        _showError('NestJS 后端地址不能为空');
        return;
      }
      final uri = Uri.parse('$urlStr/api'); // try to ping some endpoint or just the root
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 404) {
        // Even 404 means the server exists and is reachable
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('测试成功！服务已连通 (Status状态码: ${resp.statusCode})'),
            backgroundColor: const Color(0xFF4BC4A1),
          ),
        );
      } else {
        _showError('后端服务暂无正常响应，状态码: ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('连接失败：$e');
    } finally {
      if (mounted) setState(() => _isTestingBackend = false);
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
