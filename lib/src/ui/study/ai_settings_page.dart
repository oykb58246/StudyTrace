import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_config.dart';
import '../../models/daily_reminder_settings.dart';
import '../../models/learning_alert.dart';
import '../../services/local_storage_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import 'package:http/http.dart' as http;

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
  late bool _isEnabled;
  late bool _thinkingEnabled;
  late bool _voiceMode;
  late double _voiceRate;
  bool _isSaving = false;
  bool _isTestingBackend = false;
  DailyReminderSettings _dailyReminderSettings =
      DailyReminderSettings.defaults;
  LearningAlertSettings _learningAlertSettings =
      LearningAlertSettings.defaults;
  bool _isLoadingReminder = true;
  bool _isSavingReminder = false;
  int _todayUsage = 0;
  int? _todayUsageLimit;
  int? _todayUsageRemaining;
  bool _isExportingData = false;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.aiConfig;
    _isEnabled = config.isEnabled;
    _thinkingEnabled = config.thinkingEnabled;
    _voiceMode = config.voiceMode;
    _voiceRate = config.voiceRate;
    _loadDailyReminderSettings();
    _learningAlertSettings = widget.controller.learningAlertSettings;
    _loadTodayUsage();
  }

  Future<void> _loadTodayUsage() async {
    try {
      if (widget.controller.isLoggedIn) {
        final usage = await widget.controller.aiStudyService.todayUsage();
        if (!mounted) return;
        setState(() {
          _todayUsage = usage.used;
          _todayUsageLimit = usage.limit;
          _todayUsageRemaining = usage.remaining;
        });
        return;
      }
      final count = await LocalStorageService().getTodayAiUsageCount();
      if (mounted) {
        setState(() {
          _todayUsage = count;
          _todayUsageLimit = null;
          _todayUsageRemaining = null;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AiSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = widget.controller.learningAlertSettings;
    if (latest != _learningAlertSettings) {
      _learningAlertSettings = latest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        const accent = StudyUi.primary;
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
              'AI设置',
              style: TextStyle(
                color: titleColor,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI学习助手已就绪，可用于对话、学习记录、任务拆解与周报复盘。',
              style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 18),
            _statusCard(),
            const SizedBox(height: 8),
            _usageCard(bodyColor, titleColor),
            const SizedBox(height: 14),

            _buildSectionCard(
              icon: Icons.cloud_rounded,
              iconColor: StudyUi.warning,
              title: '云端服务',
              subtitle: '连接AI学习助手与云同步服务',
              badge: '推荐',
              children: [
                _buildBuiltInEndpointTile(),
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
                        foregroundColor: StudyUi.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            StudyCard(
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
                          '启用AI学习助手',
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '关闭后将停用云端整理、改写和语义搜索能力',
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
            const SizedBox(height: 8),
            StudyCard(
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
                          '思考深度',
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '开启深度后，AI聊天以外的生成、整理和分析能力会使用更强推理；AI聊天仍使用右上角单独开关',
                          style: TextStyle(color: bodyColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _thinkingEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: accent,
                    onChanged: (value) =>
                        setState(() => _thinkingEnabled = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            StudyCard(
              color: widget.isDarkMode
                  ? const Color(0xFF242B37).withValues(alpha: 0.9)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '语音对话模式',
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '启用后学习对话可用语音连续交流（半双工，先听后说）',
                              style:
                                  TextStyle(color: bodyColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _voiceMode,
                        activeThumbColor: Colors.white,
                        activeTrackColor: accent,
                        onChanged: (v) =>
                            setState(() => _voiceMode = v),
                      ),
                    ],
                  ),
                  if (_voiceMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('朗读语速',
                            style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : AppColors.ink,
                                fontSize: 14)),
                        Expanded(
                          child: Slider(
                            value: _voiceRate.clamp(0.2, 1.0).toDouble(),
                            min: 0.2,
                            max: 1.0,
                            divisions: 8,
                            activeColor: accent,
                            label: _voiceRate.toStringAsFixed(1),
                            onChanged: (v) =>
                                setState(() => _voiceRate = v),
                          ),
                        ),
                      ],
                    ),
                  ],
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
        _buildPrivacyDataSection(bodyColor: bodyColor),
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

    return StudyCard(
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

  Widget _buildBuiltInEndpointTile() {
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE6E9F2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFF8AA5B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '内置云服务',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '由 StudyTrace 安全托管，登录后自动连接',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerApiSection() {
    return _buildSectionCard(
      icon: Icons.dns_rounded,
      iconColor: const Color(0xFFF8AA5B),
      title: '云端服务',
      subtitle: '云同步、学习小组与AI学习助手使用内置服务',
      children: [
        _buildBuiltInEndpointTile(),
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
                isLoggedIn ? '已登录\n可以进行云同步任务。' : '尚未登录\n请先登录账号',
                style: TextStyle(
                  color: widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                if (isLoggedIn) {
                  await widget.controller.logout();
                } else {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
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
        if (isLoggedIn) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.person_remove_rounded),
            label: const Text('注销账号并删除云端数据'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isExportingData ? null : _exportAllData,
          icon: _isExportingData
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_isExportingData ? '正在导出...' : '导出全部本地数据'),
        ),
      ],
    );
  }

  Widget _buildPrivacyDataSection({required Color bodyColor}) {
    return _buildSectionCard(
      icon: Icons.verified_user_rounded,
      iconColor: StudyUi.secondary,
      title: '数据与隐私',
      subtitle: '公开运营所需的合规说明和数据控制',
      children: [
        _legalTile(
          icon: Icons.privacy_tip_rounded,
          title: '隐私政策',
          onTap: () => _showLegalSheet('隐私政策', _privacyPolicyText),
        ),
        _legalTile(
          icon: Icons.description_rounded,
          title: '用户协议',
          onTap: () => _showLegalSheet('用户协议', _termsText),
        ),
        _legalTile(
          icon: Icons.privacy_tip_rounded,
          title: 'AI学习助手数据使用说明',
          onTap: () => _showLegalSheet('AI学习助手数据使用说明', _aiDataText),
        ),
        _legalTile(
          icon: Icons.security_rounded,
          title: '权限用途说明',
          onTap: () => _showLegalSheet('权限用途说明', _permissionText),
        ),
        const SizedBox(height: 8),
        Text(
          '导出数据只在当前设备生成文件；注销账号会请求云端删除账号与关联数据，并清空本地学习数据。',
          style: TextStyle(color: bodyColor, fontSize: 12, height: 1.45),
        ),
      ],
    );
  }

  Widget _legalTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: widget.controller.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: bodyColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    final accent = widget.controller.primaryColor;
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final timeLabel = _dailyReminderSettings.time.format(context);
    final alertDigestLabel = _learningAlertSettings.digestTime.format(context);
    final alerts = widget.controller.learningAlerts;

    return _buildSectionCard(
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFF4BC4A1),
      title: '通知与学习预警',
      subtitle: '任务提醒、每日提醒和学习风险摘要',
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
        const SizedBox(height: 18),
        Divider(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8EBF5),
          height: 1,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _learningAlertSettings.enabled,
          onChanged: _isSavingReminder
              ? null
              : (value) => _saveLearningAlertSettings(
                    _learningAlertSettings.copyWith(enabled: value),
                  ),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: accent,
          title: Text(
            '学习预警中心',
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '根据截止时间、学习断档、闪卡复习和子任务进度生成风险预警',
            style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
          ),
        ),
        if (_learningAlertSettings.enabled) ...[
          const SizedBox(height: 6),
          _LearningAlertSettingChips(
            settings: _learningAlertSettings,
            isDarkMode: widget.isDarkMode,
            accent: accent,
            onChanged: _isSavingReminder ? null : _saveLearningAlertSettings,
          ),
          const SizedBox(height: 10),
          _LearningAlertThresholds(
            settings: _learningAlertSettings,
            isDarkMode: widget.isDarkMode,
            accent: accent,
            onChanged: _isSavingReminder ? null : _saveLearningAlertSettings,
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _learningAlertSettings.dailyDigestEnabled,
            onChanged: _isSavingReminder
                ? null
                : (value) => _saveLearningAlertSettings(
                      _learningAlertSettings.copyWith(
                        dailyDigestEnabled: value,
                      ),
                    ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            title: Text(
              '每日预警摘要',
              style: TextStyle(
                color: titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              alerts.isEmpty ? '当前没有需要推送的学习风险' : '每天推送最高优先级的学习风险',
              style: TextStyle(color: bodyColor, fontSize: 12),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '摘要时间',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isSavingReminder
                    ? null
                    : _pickLearningAlertDigestTime,
                icon: const Icon(Icons.alarm_on_rounded, size: 18),
                label: Text(alertDigestLabel),
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
          _LearningAlertPreview(
            alerts: alerts,
            isDarkMode: widget.isDarkMode,
            accent: accent,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed:
                  _isSavingReminder || alerts.isEmpty ? null : _pushTopLearningAlert,
              icon: const Icon(Icons.notification_important_rounded, size: 18),
              label: const Text('立即推送最高风险'),
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
          ),
        ],
        if (_isSavingReminder) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(color: accent, minHeight: 2),
        ],
      ],
    );
  }

  Widget _skinSelector() {
    final accent = widget.controller.primaryColor;
    return StudyCard(
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
              ButtonSegment(value: true, label: Text('云端', style: TextStyle(fontSize: 12))),
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
    final isBackendReachable = widget.controller.isLoggedIn;

    final (String label, String detail, Color color) = isBackendReachable
        ? (
            'AI学习助手已连接',
            '云端AI学习助手已就绪',
            const Color(0xFF4BC4A1),
          )
        : (
            'AI学习助手未连接',
            '请登录后使用内置云端服务',
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
            isBackendReachable
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

  Widget _usageCard(Color bodyColor, Color titleColor) {
    final accent = widget.controller.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8EBF5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.query_stats_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日助手调用',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _todayUsageLimit == null
                      ? '统计当前设备的助手调用次数'
                      : '上限 $_todayUsageLimit 次，剩余 $_todayUsageRemaining 次',
                  style: TextStyle(color: bodyColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$_todayUsage',
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '次',
            style: TextStyle(color: bodyColor, fontSize: 11),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _loadTodayUsage,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded, size: 16, color: bodyColor),
            ),
          ),
        ],
      ),
    );
  }

  AiConfig _formConfig() {
    final current = widget.controller.aiConfig;
    return AiConfig(
      temperature: 0.7,
      maxTokens: 1200,
      topP: 0.7,
      thinkingMode: _thinkingEnabled,
      thinkingEnabled: _thinkingEnabled,
      frequencyPenalty: 0.0,
      presencePenalty: 0.0,
      reasoningEffort: '',
      isEnabled: _isEnabled,
      voiceMode: _voiceMode,
      voiceLanguage: current.voiceLanguage,
      voiceRate: _voiceRate,
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
      StudyToast.show(context, settings.enabled ? '每日学习提醒已开启' : '每日学习提醒已关闭');
    } catch (error) {
      _showError('通知设置保存失败：$error');
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  Future<void> _pickLearningAlertDigestTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _learningAlertSettings.digestTime,
    );
    if (!mounted || picked == null) return;
    await _saveLearningAlertSettings(
      _learningAlertSettings.copyWith(
        dailyDigestEnabled: true,
        digestTime: picked,
      ),
    );
  }

  Future<void> _saveLearningAlertSettings(
    LearningAlertSettings settings,
  ) async {
    setState(() => _isSavingReminder = true);
    try {
      await widget.controller.saveLearningAlertSettings(settings);
      if (!mounted) return;
      setState(() => _learningAlertSettings = settings);
      StudyToast.show(context, settings.enabled ? '学习预警设置已更新' : '学习预警已关闭');
    } catch (error) {
      _showError('学习预警设置保存失败：$error');
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  Future<void> _pushTopLearningAlert() async {
    final alerts = widget.controller.learningAlerts;
    if (alerts.isEmpty) {
      _showError('当前没有需要推送的学习预警');
      return;
    }
    setState(() => _isSavingReminder = true);
    try {
      await widget.controller.pushTopLearningAlertNow();
      if (!mounted) return;
      StudyToast.show(context, '已推送最高风险学习预警');
    } catch (error) {
      _showError('学习预警推送失败：$error');
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveAiSettings(
        config: _formConfig(),
      );
      if (!mounted) return;
      StudyToast.show(context, 'AI设置已保存');
    } catch (error) {
      _showError('AI设置保存失败：$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testBackendConnection() async {
    setState(() => _isTestingBackend = true);
    final urlStr = widget.controller.apiBaseUrl.trim();
    try {
      final uri =
          Uri.parse('${urlStr.replaceAll(RegExp(r'/+$'), '')}/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        StudyToast.show(context, '连接成功 (状态码: ${resp.statusCode})');
      } else {
        _showError('云服务暂无正常响应，状态码: ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('连接失败：$e');
    } finally {
      if (mounted) setState(() => _isTestingBackend = false);
    }
  }

  Future<void> _exportAllData() async {
    setState(() => _isExportingData = true);
    try {
      final file = await widget.controller.exportAllUserData();
      if (!mounted) return;
      StudyToast.show(context, '数据已导出：${file.path}');
    } catch (error) {
      _showError('导出失败：$error');
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '注销后会删除云端账号与关联数据，并清空本机学习数据。此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.controller.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      _showError('注销失败：$error');
    }
  }

  void _showLegalSheet(String title, String content) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bodyColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                content,
                style: TextStyle(color: bodyColor, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    StudyToast.dialog(context, title: '操作失败', message: message);
  }

  static const _privacyPolicyText = '''
StudyTrace 会保存你主动创建的学习任务、学习记录、笔记、闪卡、课程、小组和积分数据。

登录后，数据会同步到 StudyTrace 云端，用于多端同步、学习小组、排行榜和账号恢复。未登录时，数据主要保存在当前设备。

我们不会在客户端内置模型供应商密钥，也不会把你的数据出售给第三方。你可以在系统设置中导出本地数据，或注销账号并请求删除云端数据。
''';

  static const _termsText = '''
StudyTrace 是免费的学习管理工具，提供任务管理、学习记录、AI学习助手、小组和排行榜功能。

你需要对自己发布在小组中的内容负责，不得上传违法、侵权、骚扰或恶意内容。助手生成内容仅作学习辅助，不构成专业建议。

服务可能因维护、网络或第三方能力波动而短暂不可用，我们会尽力保持稳定并持续改进。
''';

  static const _aiDataText = '''
AI学习助手由 StudyTrace 后端统一代理云端能力。App 不保存、不输入、不内置模型供应商 Key。

当你使用学习对话、拍照识别、任务拆解、周计划、笔记改写或语义搜索时，请求内容可能会发送到云端处理。后端会记录必要的调用日志用于限额、排障和成本控制。

请避免输入身份证号、银行卡号、密码等敏感信息。助手结果可能不准确，重要事项请自行核对。
''';

  static const _permissionText = '''
网络：用于登录、云同步、小组、排行榜和AI学习助手。

相机与相册：用于拍照创建学习记录、拍照成笔记、头像选择和 OCR 识别。

麦克风与语音识别：用于语音创建任务和语音输入。

通知与闹钟：用于任务截止提醒、每日学习提醒和番茄钟体验。

这些权限会在相关功能使用前请求；拒绝权限不会影响其他基础功能。
''';
}

class _LearningAlertPreview extends StatelessWidget {
  const _LearningAlertPreview({
    required this.alerts,
    required this.isDarkMode,
    required this.accent,
  });

  final List<LearningAlert> alerts;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final visibleAlerts = alerts.take(3).toList(growable: false);

    if (visibleAlerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF4F8F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE1EFE8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前没有明显学习风险。完成任务、生成闪卡或记录学习后，预警会自动刷新。',
                style: TextStyle(color: bodyColor, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '当前风险预览',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${alerts.length} 条',
              style: TextStyle(color: bodyColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final alert in visibleAlerts) ...[
          _LearningAlertTile(
            alert: alert,
            isDarkMode: isDarkMode,
          ),
          if (alert != visibleAlerts.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LearningAlertSettingChips extends StatelessWidget {
  const _LearningAlertSettingChips({
    required this.settings,
    required this.isDarkMode,
    required this.accent,
    required this.onChanged,
  });

  final LearningAlertSettings settings;
  final bool isDarkMode;
  final Color accent;
  final ValueChanged<LearningAlertSettings>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          label: '截止/逾期',
          icon: Icons.event_busy_rounded,
          selected: settings.deadlineWarningEnabled,
          onSelected: (value) => onChanged?.call(
            settings.copyWith(deadlineWarningEnabled: value),
          ),
        ),
        _chip(
          label: '学习断档',
          icon: Icons.timeline_rounded,
          selected: settings.studyGapWarningEnabled,
          onSelected: (value) => onChanged?.call(
            settings.copyWith(studyGapWarningEnabled: value),
          ),
        ),
        _chip(
          label: '闪卡复习',
          icon: Icons.style_rounded,
          selected: settings.flashcardReviewEnabled,
          onSelected: (value) => onChanged?.call(
            settings.copyWith(flashcardReviewEnabled: value),
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    final disabled = onChanged == null;
    final selectedColor = disabled ? Colors.grey : accent;
    final textColor = isDarkMode ? Colors.white : AppColors.ink;
    return FilterChip(
      selected: selected,
      onSelected: disabled ? null : onSelected,
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : selectedColor,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : textColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: selectedColor,
      checkmarkColor: Colors.white,
      backgroundColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF2F5FC),
      side: BorderSide(
        color: selected
            ? selectedColor
            : (isDarkMode ? Colors.white24 : const Color(0xFFE2E6F0)),
      ),
    );
  }
}

class _LearningAlertThresholds extends StatelessWidget {
  const _LearningAlertThresholds({
    required this.settings,
    required this.isDarkMode,
    required this.accent,
    required this.onChanged,
  });

  final LearningAlertSettings settings;
  final bool isDarkMode;
  final Color accent;
  final ValueChanged<LearningAlertSettings>? onChanged;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return Column(
      children: [
        _stepperRow(
          title: '截止提前提醒',
          value: '${settings.deadlineLeadHours} 小时',
          enabled: settings.deadlineWarningEnabled,
          titleColor: titleColor,
          bodyColor: bodyColor,
          onMinus: () => _updateDeadline(-6),
          onPlus: () => _updateDeadline(6),
        ),
        const SizedBox(height: 8),
        _stepperRow(
          title: '学习断档阈值',
          value: '${settings.studyGapDays} 天',
          enabled: settings.studyGapWarningEnabled,
          titleColor: titleColor,
          bodyColor: bodyColor,
          onMinus: () => _updateGap(-1),
          onPlus: () => _updateGap(1),
        ),
      ],
    );
  }

  Widget _stepperRow({
    required String title,
    required String value,
    required bool enabled,
    required Color titleColor,
    required Color bodyColor,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    final canEdit = enabled && onChanged != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: canEdit ? titleColor : bodyColor.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _iconButton(Icons.remove_rounded, canEdit ? onMinus : null),
        SizedBox(
          width: 68,
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: canEdit ? titleColor : bodyColor.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _iconButton(Icons.add_rounded, canEdit ? onPlus : null),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: accent,
        disabledColor: isDarkMode ? Colors.white24 : const Color(0xFFB7BECC),
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF2F5FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _updateDeadline(int delta) {
    if (onChanged == null) return;
    final next = (settings.deadlineLeadHours + delta).clamp(1, 168).toInt();
    onChanged!(settings.copyWith(deadlineLeadHours: next));
  }

  void _updateGap(int delta) {
    if (onChanged == null) return;
    final next = (settings.studyGapDays + delta).clamp(1, 14).toInt();
    onChanged!(settings.copyWith(studyGapDays: next));
  }
}

class _LearningAlertTile extends StatelessWidget {
  const _LearningAlertTile({
    required this.alert,
    required this.isDarkMode,
  });

  final LearningAlert alert;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor = isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final levelColor = _levelColor(alert.level);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: levelColor.withValues(alpha: isDarkMode ? 0.28 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(alert.icon, size: 18, color: levelColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.levelLabel,
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LearningAlertLevel level) {
    switch (level) {
      case LearningAlertLevel.low:
        return const Color(0xFF4CB9FF);
      case LearningAlertLevel.medium:
        return const Color(0xFFF8AA5B);
      case LearningAlertLevel.high:
        return const Color(0xFFF77D8E);
    }
  }
}
