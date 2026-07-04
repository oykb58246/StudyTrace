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
    this.onOpenAssistantSettings,
    this.onOpenHistory,
    this.onOpenTrash,
    this.onOpenAbout,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final AiSettingsMode mode;
  final VoidCallback? onOpenAssistantSettings;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenTrash;
  final VoidCallback? onOpenAbout;

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
  bool _isLoadingDemoSeed = false;
  bool _isResettingDemoSeed = false;
  DailyReminderSettings _dailyReminderSettings = DailyReminderSettings.defaults;
  LearningAlertSettings _learningAlertSettings = LearningAlertSettings.defaults;
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
    final compactHeader = StudyCompactHeaderScope.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        const accent = StudyUi.pathViolet;
        if (widget.mode == AiSettingsMode.system) {
          return _buildSystemSettingsView(
            bodyColor: bodyColor,
          );
        }

        return ListView(
          key: const Key('page_ai_settings'),
          padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 66, 22, 124),
          children: [
            _assistantHero(bodyColor: bodyColor, titleColor: titleColor),
            const SizedBox(height: 12),
            _usageCard(bodyColor, titleColor),
            const SizedBox(height: 14),
            _buildSectionCard(
              icon: Icons.cloud_rounded,
              iconColor: StudyUi.warning,
              title: '账号备份',
              subtitle: '登录后备份学习资料，换设备也能接着学',
              badge: '推荐',
              children: [
                _buildBuiltInEndpointTile(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _settingsActionButton(
                    icon: Icons.wifi_protected_setup_rounded,
                    label: _isTestingBackend ? '检查中...' : '检查账号备份',
                    color: StudyUi.warning,
                    onPressed:
                        _isTestingBackend ? null : _testBackendConnection,
                    busyIcon: _isTestingBackend
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _preferenceCard(
              icon: Icons.auto_awesome_rounded,
              color: accent,
              title: '启用学习助手',
              subtitle: '开启后，复盘、整理笔记和生成下一步会保持可用。',
              trailing: Switch(
                value: _isEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: accent,
                onChanged: (value) => setState(() => _isEnabled = value),
              ),
            ),
            const SizedBox(height: 8),
            _preferenceCard(
              icon: Icons.psychology_alt_rounded,
              color: StudyUi.pathBlue,
              title: '思考深度',
              subtitle: '控制助手回答的细致程度，适合复盘和学习分析。',
              trailing: Switch(
                value: _thinkingEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: StudyUi.pathBlue,
                onChanged: (value) => setState(() => _thinkingEnabled = value),
              ),
            ),
            const SizedBox(height: 8),
            _preferenceCard(
              icon: Icons.graphic_eq_rounded,
              color: StudyUi.pathCyan,
              title: '语音偏好',
              subtitle: '学习对话可用语音连续交流，也可以只保留文字整理。',
              trailing: Switch(
                value: _voiceMode,
                activeThumbColor: Colors.white,
                activeTrackColor: StudyUi.pathCyan,
                onChanged: (v) => setState(() => _voiceMode = v),
              ),
              child: _voiceMode ? _voiceRateControl() : null,
            ),
            const SizedBox(height: 14),
            _saveSettingsButton(accent),
          ],
        );
      },
    );
  }

  Widget _preferenceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
    Widget? child,
  }) {
    return StudyCard(
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: widget.isDarkMode ? 0.20 : 0.15),
      child: Column(
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: icon,
                accent: color,
                size: 42,
                iconSize: 18,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: StudyUi.title(widget.isDarkMode),
                        fontSize: 16,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: StudyUi.body(widget.isDarkMode),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  Widget _voiceRateControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: StudyUi.pathCyan.withValues(
          alpha: widget.isDarkMode ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyUi.pathCyan.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Text(
            '朗读语速',
            style: TextStyle(
              color: StudyUi.title(widget.isDarkMode),
              fontSize: 13,
              fontWeight: AppTypography.title,
            ),
          ),
          Expanded(
            child: Slider(
              value: _voiceRate.clamp(0.2, 1.0).toDouble(),
              min: 0.2,
              max: 1.0,
              divisions: 8,
              activeColor: StudyUi.pathCyan,
              label: _voiceRate.toStringAsFixed(1),
              onChanged: (v) => setState(() => _voiceRate = v),
            ),
          ),
          Text(
            _voiceRate.toStringAsFixed(1),
            style: TextStyle(
              color: StudyUi.pathCyan,
              fontWeight: AppTypography.hero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveSettingsButton(Color accent) {
    final enabled = !_isSaving;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? _save : null,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: enabled
                  ? [
                      accent,
                      StudyUi.pathCyan,
                    ]
                  : [
                      StudyUi.muted(widget.isDarkMode),
                      StudyUi.muted(widget.isDarkMode).withValues(alpha: 0.72),
                    ],
            ),
            boxShadow: [
              if (enabled && !widget.isDarkMode)
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _isSaving ? '保存中...' : '保存设置',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: AppTypography.hero,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color color = StudyUi.pathBlue,
    bool filled = false,
    bool expand = false,
    Widget? busyIcon,
  }) {
    final disabled = onPressed == null;
    final foreground = filled
        ? Colors.white
        : (disabled ? StudyUi.muted(widget.isDarkMode) : color);
    final background = filled
        ? color.withValues(alpha: disabled ? 0.46 : 1)
        : color.withValues(alpha: widget.isDarkMode ? 0.12 : 0.08);
    final borderColor = filled
        ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
        : color.withValues(alpha: disabled ? 0.10 : 0.22);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        busyIcon ?? Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: AppTypography.title,
            ),
          ),
        ),
      ],
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onPressed,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (filled && !disabled && !widget.isDarkMode)
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: content,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _settingsSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Color color = StudyUi.pathBlue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.isDarkMode ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: color,
            size: 38,
            iconSize: 17,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: StudyUi.title(widget.isDarkMode),
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: StudyUi.body(widget.isDarkMode),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingsInlineActionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
          alpha: widget.isDarkMode ? 0.78 : 0.86,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudyUi.border(widget.isDarkMode)),
      ),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: color,
            size: 38,
            iconSize: 17,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: StudyUi.title(widget.isDarkMode),
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: StudyUi.body(widget.isDarkMode),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }

  Widget _assistantHero({
    required Color bodyColor,
    required Color titleColor,
  }) {
    final online = widget.controller.isLoggedIn;
    final statusColor = online ? StudyUi.pathMint : StudyUi.pathWarm;
    return StudyPathHero(
      isDarkMode: widget.isDarkMode,
      accent: StudyUi.pathViolet,
      badge: '助手设置',
      title: '助手设置',
      subtitle: online
          ? '个性化你的学习助手体验，资料备份后换设备也能接着学。'
          : '未登录不影响本机记录，登录后可以备份资料和使用学习助手。',
      icon: Icons.smart_toy_rounded,
      steps: const ['学习助手', '语音', '资料备份'],
      child: Column(
        children: [
          StudyCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: online
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  accent: statusColor,
                  size: 44,
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? '助手已准备好' : '本机资料可用',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        online ? '学习资料会备份到账号' : '登录后可继续备份和整理',
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                BadgePill(
                  label: online ? '已登录' : '本地',
                  background: statusColor.withValues(
                    alpha: widget.isDarkMode ? 0.20 : 0.12,
                  ),
                  foreground: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _settingsMiniMetric(
                label: '语音',
                value: _voiceMode ? '已开' : '关闭',
                color: StudyUi.pathBlue,
              ),
              const SizedBox(width: 8),
              _settingsMiniMetric(
                label: '思考深度',
                value: _thinkingEnabled ? '更细' : '轻量',
                color: StudyUi.pathViolet,
              ),
              const SizedBox(width: 8),
              _settingsMiniMetric(
                label: '今日整理',
                value: '$_todayUsage 次',
                color: StudyUi.pathMint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.isDarkMode ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
                fontSize: 11,
                fontWeight: AppTypography.title,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: AppTypography.hero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettingsView({
    required Color bodyColor,
  }) {
    final compactHeader = StudyCompactHeaderScope.of(context);
    final syncLabel = widget.controller.isLoggedIn ? '已开启' : '本地';
    final themeLabel = widget.controller.darkMode
        ? '深色'
        : (widget.controller.skinVivo ? '清爽' : '经典');
    return ListView(
      key: const Key('page_system_settings'),
      padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 66, 22, 124),
      children: [
        StudyPathHero(
          isDarkMode: widget.isDarkMode,
          accent: StudyUi.pathBlue,
          badge: '应用设置',
          title: '个性化你的学习体验',
          subtitle: '外观、提醒、隐私和资料备份放在一处，让 StudyTrace 更贴合你的节奏。',
          icon: Icons.settings_suggest_rounded,
          steps: const ['外观', '提醒', '隐私', '备份'],
          child: Row(
            children: [
              _settingsMiniMetric(
                label: '外观',
                value: themeLabel,
                color: StudyUi.pathViolet,
              ),
              const SizedBox(width: 8),
              _settingsMiniMetric(
                label: '通知',
                value: _dailyReminderSettings.enabled ? '已开' : '关闭',
                color: StudyUi.pathMint,
              ),
              const SizedBox(width: 8),
              _settingsMiniMetric(
                label: '备份',
                value: syncLabel,
                color: widget.controller.isLoggedIn
                    ? StudyUi.pathCyan
                    : StudyUi.pathWarm,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _skinSelector(),
        const SizedBox(height: 14),
        _buildNotificationSection(),
        const SizedBox(height: 14),
        _buildPrivacyPreferenceSection(),
        const SizedBox(height: 14),
        _buildMoreToolsSection(),
        const SizedBox(height: 14),
        _buildAccountSyncSection(),
        const SizedBox(height: 14),
        _buildDemoSeedSection(),
        const SizedBox(height: 14),
        _buildPrivacyDataSection(bodyColor: bodyColor),
        const SizedBox(height: 18),
        _systemSaveButton(),
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
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return StudyCard(
      color: StudyUi.surface(widget.isDarkMode),
      child: StudyFontScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: iconColor,
                  size: 40,
                  iconSize: 18,
                  isDarkMode: widget.isDarkMode,
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
                              fontWeight: AppTypography.hero,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            BadgePill(
                              label: badge,
                              background: StudyUi.chipBackground(
                                iconColor,
                                widget.isDarkMode,
                              ),
                              foreground: iconColor,
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
      ),
    );
  }

  Widget _buildBuiltInEndpointTile() {
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final titleColor = StudyUi.title(widget.isDarkMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : StudyUi.pathWarm.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : StudyUi.pathWarm.withValues(alpha: 0.14),
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
                  '学习助手',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '由 StudyTrace 安全连接，登录后自动可用',
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

  Widget _buildAccountSyncSection() {
    const accent = StudyUi.pathBlue;
    final isLoggedIn = widget.controller.isLoggedIn;
    final statusColor = isLoggedIn ? StudyUi.pathMint : StudyUi.pathWarm;

    return _buildSectionCard(
      icon: Icons.cloud_sync_rounded,
      iconColor: accent,
      title: '账号备份',
      subtitle: '备份学习数据，多端都能接着用',
      children: [
        _buildBuiltInEndpointTile(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(
              alpha: widget.isDarkMode ? 0.12 : 0.08,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              StudyGlassIconNode(
                icon: isLoggedIn
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                accent: statusColor,
                size: 38,
                iconSize: 17,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLoggedIn ? '已登录，学习资料会备份到账号。' : '尚未登录，本地学习资料可继续使用。',
                  style: TextStyle(
                    color: StudyUi.body(widget.isDarkMode),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              BadgePill(
                label: isLoggedIn ? '已备份' : '本地',
                background: statusColor.withValues(
                  alpha: widget.isDarkMode ? 0.18 : 0.12,
                ),
                foreground: statusColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _settingsActionButton(
                icon: isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                label: isLoggedIn ? '退出登录' : '去登录',
                color: isLoggedIn ? StudyUi.danger : accent,
                filled: true,
                expand: true,
                onPressed: () async {
                  if (isLoggedIn) {
                    await widget.controller.logout();
                  } else {
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ),
          ],
        ),
        if (isLoggedIn) ...[
          const SizedBox(height: 10),
          _settingsActionButton(
            icon: Icons.person_remove_rounded,
            label: '注销账号并删除账号备份',
            color: StudyUi.danger,
            expand: true,
            onPressed: _confirmDeleteAccount,
          ),
        ],
        const SizedBox(height: 10),
        _settingsActionButton(
          icon: Icons.wifi_protected_setup_rounded,
          label: _isTestingBackend ? '检查中...' : '检查账号备份',
          color: StudyUi.warning,
          expand: true,
          onPressed: _isTestingBackend ? null : _testBackendConnection,
          busyIcon: _isTestingBackend
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const SizedBox(height: 10),
        _settingsActionButton(
          icon: Icons.download_rounded,
          label: _isExportingData ? '正在准备...' : '保存本机学习数据',
          color: StudyUi.pathViolet,
          expand: true,
          onPressed: _isExportingData ? null : _exportAllData,
          busyIcon: _isExportingData
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildDemoSeedSection() {
    return _buildSectionCard(
      icon: Icons.rocket_launch_rounded,
      iconColor: StudyUi.warning,
      title: '高数复盘练习',
      subtitle: '放入一套可删除的高数复盘练习，快速熟悉记录、任务和闪卡',
      badge: '练习',
      children: [
        Text(
          '会重新放入高数复盘练习，不删除你手动创建的学习记录、任务、闪卡或学迹。',
          style: TextStyle(
            color: StudyUi.body(widget.isDarkMode),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        _settingsActionButton(
          icon: Icons.auto_fix_high_rounded,
          label: _isLoadingDemoSeed ? '正在添加...' : '添加高数复盘练习',
          color: StudyUi.warning,
          filled: true,
          expand: true,
          onPressed: _isLoadingDemoSeed ? null : _confirmLoadDemoSeed,
          busyIcon: _isLoadingDemoSeed
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        _settingsActionButton(
          icon: Icons.restore_rounded,
          label: _isResettingDemoSeed ? '正在清除...' : '清除高数复盘练习',
          color: StudyUi.warning,
          expand: true,
          onPressed: _isResettingDemoSeed ? null : _confirmResetDemoSeed,
          busyIcon: _isResettingDemoSeed
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildPrivacyDataSection({required Color bodyColor}) {
    return _buildSectionCard(
      icon: Icons.verified_user_rounded,
      iconColor: StudyUi.secondary,
      title: '隐私与数据',
      subtitle: '了解数据保存、账号备份和权限用途',
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
          title: '学习助手数据使用说明',
          onTap: () => _showLegalSheet('学习助手数据使用说明', _aiDataText),
        ),
        _legalTile(
          icon: Icons.security_rounded,
          title: '权限用途说明',
          onTap: () => _showLegalSheet('权限用途说明', _permissionText),
        ),
        const SizedBox(height: 8),
        Text(
          '保存数据只在当前设备生成文件；注销账号会请求删除账号与关联数据，并清空本机学习数据。',
          style: TextStyle(color: bodyColor, fontSize: 12, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildPrivacyPreferenceSection() {
    return _buildSectionCard(
      icon: Icons.shield_rounded,
      iconColor: StudyUi.pathMint,
      title: '隐私',
      subtitle: '管理数据权限与学习助手使用说明',
      children: [
        _settingsInlineActionRow(
          icon: Icons.folder_copy_rounded,
          color: StudyUi.pathMint,
          title: '本地学习资料',
          subtitle: '未登录时保存在当前设备，登录后可备份到账号',
          action: BadgePill(
            label: widget.controller.isLoggedIn ? '已备份' : '本地',
            background: StudyUi.chipBackground(
              widget.controller.isLoggedIn
                  ? StudyUi.pathCyan
                  : StudyUi.pathMint,
              widget.isDarkMode,
            ),
            foreground: widget.controller.isLoggedIn
                ? StudyUi.pathCyan
                : StudyUi.pathMint,
          ),
        ),
        const SizedBox(height: 10),
        _settingsInlineActionRow(
          icon: Icons.psychology_rounded,
          color: StudyUi.secondary,
          title: '学习助手数据使用',
          subtitle: '了解助手如何使用你的复盘、笔记和任务内容',
          action: _settingsActionButton(
            icon: Icons.chevron_right_rounded,
            label: '查看',
            color: StudyUi.secondary,
            onPressed: () => _showLegalSheet('学习助手数据使用说明', _aiDataText),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreToolsSection() {
    final tiles = <Widget>[];

    void addTile({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback? onTap,
    }) {
      if (onTap == null) return;
      if (tiles.isNotEmpty) {
        tiles.add(const SizedBox(height: 8));
      }
      tiles.add(_settingsNavigationTile(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ));
    }

    addTile(
      icon: Icons.tune_rounded,
      color: StudyUi.pathViolet,
      title: '助手设置',
      subtitle: '调整助手开关、语音和整理习惯',
      onTap: widget.onOpenAssistantSettings,
    );
    addTile(
      icon: Icons.history_rounded,
      color: StudyUi.pathBlue,
      title: '整理历史',
      subtitle: '查看最近整理过的内容和结果',
      onTap: widget.onOpenHistory,
    );
    addTile(
      icon: Icons.restore_from_trash_rounded,
      color: StudyUi.danger,
      title: '回收站',
      subtitle: '恢复误删内容，或清理不需要的资料',
      onTap: widget.onOpenTrash,
    );
    addTile(
      icon: Icons.auto_stories_rounded,
      color: StudyUi.pathCyan,
      title: '应用介绍',
      subtitle: '了解 StudyTrace 怎么串起记录、复盘和回顾',
      onTap: widget.onOpenAbout,
    );

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      icon: Icons.apps_rounded,
      iconColor: StudyUi.pathCyan,
      title: '更多工具',
      subtitle: '不常用的入口放在这里，需要时再打开',
      children: tiles,
    );
  }

  Widget _settingsNavigationTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
              alpha: widget.isDarkMode ? 0.72 : 0.86,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudyUi.border(widget.isDarkMode)),
          ),
          child: Row(
            children: [
              StudyGlassIconNode(
                icon: icon,
                accent: color,
                size: 36,
                iconSize: 17,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.title(widget.isDarkMode),
                        fontSize: 14,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(widget.isDarkMode),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: StudyUi.muted(widget.isDarkMode),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _systemSaveButton() {
    return _settingsActionButton(
      icon: Icons.check_circle_outline_rounded,
      label: '保存',
      color: StudyUi.pathBlue,
      filled: true,
      expand: true,
      onPressed: () => StudyToast.show(context, '应用设置已保存'),
    );
  }

  Widget _legalTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
                alpha: widget.isDarkMode ? 0.72 : 0.82,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StudyUi.border(widget.isDarkMode)),
            ),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: StudyUi.secondary,
                  size: 34,
                  iconSize: 16,
                  isDarkMode: widget.isDarkMode,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: StudyUi.title(widget.isDarkMode),
                      fontSize: 14,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: StudyUi.body(widget.isDarkMode),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    const accent = StudyUi.pathMint;
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final timeLabel = _dailyReminderSettings.time.format(context);
    final alertDigestLabel = _learningAlertSettings.digestTime.format(context);
    final alerts = widget.controller.learningAlerts;

    return _buildSectionCard(
      icon: Icons.notifications_active_rounded,
      iconColor: accent,
      title: '通知',
      subtitle: '学习提醒、每日提醒和学习难点摘要',
      children: [
        _settingsSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: '每日学习提醒',
          subtitle: '默认 20:00，可根据学习节奏调整',
          value: _dailyReminderSettings.enabled,
          color: accent,
          onChanged: _isLoadingReminder || _isSavingReminder
              ? null
              : (value) => _saveDailyReminder(
                    _dailyReminderSettings.copyWith(enabled: value),
                  ),
        ),
        const SizedBox(height: 10),
        _settingsInlineActionRow(
          icon: Icons.schedule_rounded,
          color: StudyUi.pathBlue,
          title: '提醒时间',
          subtitle: '每天固定时间轻提醒',
          action: _settingsActionButton(
            icon: Icons.schedule_rounded,
            label: timeLabel,
            color: StudyUi.pathBlue,
            onPressed: _isLoadingReminder || _isSavingReminder
                ? null
                : _pickDailyReminderTime,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '首次使用提醒时会请求通知权限；任务提醒会在任务完成、删除或修改时自动更新。',
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
        _settingsSwitchTile(
          icon: Icons.insights_rounded,
          title: '学习提醒',
          subtitle: '根据截止时间、几天没学、闪卡复习和任务进度提醒你',
          value: _learningAlertSettings.enabled,
          color: StudyUi.pathViolet,
          onChanged: _isSavingReminder
              ? null
              : (value) => _saveLearningAlertSettings(
                    _learningAlertSettings.copyWith(enabled: value),
                  ),
        ),
        if (_learningAlertSettings.enabled) ...[
          const SizedBox(height: 10),
          _LearningAlertSettingChips(
            settings: _learningAlertSettings,
            isDarkMode: widget.isDarkMode,
            accent: StudyUi.pathViolet,
            onChanged: _isSavingReminder ? null : _saveLearningAlertSettings,
          ),
          const SizedBox(height: 10),
          _LearningAlertThresholds(
            settings: _learningAlertSettings,
            isDarkMode: widget.isDarkMode,
            accent: StudyUi.pathViolet,
            onChanged: _isSavingReminder ? null : _saveLearningAlertSettings,
          ),
          const SizedBox(height: 10),
          _settingsSwitchTile(
            icon: Icons.mark_email_read_rounded,
            title: '每日提醒摘要',
            subtitle: alerts.isEmpty ? '当前没有需要推送的学习提醒' : '每天推送最需要关注的学习提醒',
            value: _learningAlertSettings.dailyDigestEnabled,
            color: StudyUi.pathCyan,
            onChanged: _isSavingReminder
                ? null
                : (value) => _saveLearningAlertSettings(
                      _learningAlertSettings.copyWith(
                        dailyDigestEnabled: value,
                      ),
                    ),
          ),
          const SizedBox(height: 10),
          _settingsInlineActionRow(
            icon: Icons.alarm_on_rounded,
            color: StudyUi.pathCyan,
            title: '摘要时间',
            subtitle: '只在摘要打开时推送',
            action: _settingsActionButton(
              icon: Icons.alarm_on_rounded,
              label: alertDigestLabel,
              color: StudyUi.pathCyan,
              onPressed:
                  _isSavingReminder ? null : _pickLearningAlertDigestTime,
            ),
          ),
          const SizedBox(height: 12),
          _LearningAlertPreview(
            alerts: alerts,
            isDarkMode: widget.isDarkMode,
            accent: StudyUi.pathViolet,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _settingsActionButton(
              icon: Icons.notification_important_rounded,
              label: '立即推送重点提醒',
              color: StudyUi.pathViolet,
              onPressed: _isSavingReminder || alerts.isEmpty
                  ? null
                  : _pushTopLearningAlert,
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
    return _buildSectionCard(
      icon: Icons.palette_rounded,
      iconColor: StudyUi.pathViolet,
      title: '外观',
      subtitle: '选择主题色，也可以跟随夜间学习切换深色模式',
      children: [
        Row(
          children: [
            Expanded(
              child: _skinChoice(
                value: true,
                title: '清透',
                subtitle: '清爽蓝绿',
                color: StudyUi.pathBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _skinChoice(
                value: false,
                title: '传统',
                subtitle: '经典主色',
                color: StudyUi.pathMint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _settingsSwitchTile(
          icon: Icons.dark_mode_rounded,
          title: '深色模式',
          subtitle: '晚上复盘时降低屏幕亮度刺激',
          value: widget.controller.darkMode,
          color: StudyUi.pathViolet,
          onChanged: (value) => widget.controller.setDarkMode(value),
        ),
      ],
    );
  }

  Widget _skinChoice({
    required bool value,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final selected = widget.controller.skinVivo == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.controller.setSkinVivo(value),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: widget.isDarkMode ? 0.18 : 0.12)
                : StudyUi.surfaceAlt(widget.isDarkMode),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.30)
                  : StudyUi.border(widget.isDarkMode),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: selected ? 1 : 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                    width: 1.2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.title(widget.isDarkMode),
                        fontSize: 14,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudyUi.body(widget.isDarkMode),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _usageCard(Color bodyColor, Color titleColor) {
    const accent = StudyUi.pathViolet;
    final online = widget.controller.isLoggedIn;
    final quotaText =
        _todayUsageLimit == null ? '本地' : '${_todayUsageRemaining ?? 0} 次';
    return StudyCard(
      padding: const EdgeInsets.all(16),
      borderColor: accent.withValues(alpha: widget.isDarkMode ? 0.22 : 0.16),
      child: Column(
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.health_and_safety_rounded,
                accent: online ? StudyUi.pathMint : StudyUi.pathWarm,
                size: 46,
                iconSize: 20,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学习助手',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      online ? '助手已准备好' : '本机资料可用，登录后备份',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              BadgePill(
                label: online ? '已连接' : '本地',
                background: StudyUi.chipBackground(
                  online ? StudyUi.pathMint : StudyUi.pathWarm,
                  widget.isDarkMode,
                ),
                foreground: online ? StudyUi.pathMint : StudyUi.pathWarm,
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _loadTodayUsage,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 17,
                    color: StudyUi.muted(widget.isDarkMode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _serviceMetricTile(
                label: '今日整理',
                value: '$_todayUsage 次',
                detail: '整理与对话',
                color: StudyUi.pathBlue,
              ),
              const SizedBox(width: 10),
              _serviceMetricTile(
                label: _todayUsageLimit == null ? '资料备份' : '今日还可用',
                value: quotaText,
                detail: online ? '学习资料备份' : '登录后开启',
                color: StudyUi.pathCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceMetricTile({
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.isDarkMode ? 0.15 : 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
                fontSize: 11,
                fontWeight: AppTypography.title,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: AppTypography.hero,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                fontSize: 11,
              ),
            ),
          ],
        ),
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
      _showError('通知设置暂时没有保存成功，请稍后再试');
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
      StudyToast.show(context, settings.enabled ? '学习提醒已更新' : '学习提醒已关闭');
    } catch (error) {
      _showError('学习提醒暂时没有保存成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  Future<void> _pushTopLearningAlert() async {
    final alerts = widget.controller.learningAlerts;
    if (alerts.isEmpty) {
      _showError('当前没有需要推送的学习提醒');
      return;
    }
    setState(() => _isSavingReminder = true);
    try {
      await widget.controller.pushTopLearningAlertNow();
      if (!mounted) return;
      StudyToast.show(context, '已推送重点学习提醒');
    } catch (error) {
      _showError('学习提醒暂时没有发出，请稍后再试');
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
      StudyToast.show(context, '助手设置已保存');
    } catch (error) {
      _showError('助手偏好暂时没有保存成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testBackendConnection() async {
    setState(() => _isTestingBackend = true);
    final urlStr = widget.controller.apiBaseUrl.trim();
    try {
      final uri = Uri.parse('${urlStr.replaceAll(RegExp(r'/+$'), '')}/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        StudyToast.show(context, '账号备份连接正常');
      } else {
        _showError('账号备份暂时不稳定，请稍后再试');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('账号备份暂时连不上，请稍后再试');
    } finally {
      if (mounted) setState(() => _isTestingBackend = false);
    }
  }

  Future<void> _exportAllData() async {
    setState(() => _isExportingData = true);
    try {
      await widget.controller.exportAllUserData();
      if (!mounted) return;
      StudyToast.show(context, '本机学习数据已保存，文件位置已准备好');
    } catch (error) {
      _showError('本机学习数据暂时没有保存成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  Future<void> _confirmLoadDemoSeed() async {
    final confirmed = await _showAiSettingsConfirmDialog(
      title: '添加高数复盘练习',
      message: '会重新放入高数复盘练习，包含学习记录、下一步、闪卡和学迹回看。你的手动数据不会被删除。',
      icon: Icons.auto_awesome_rounded,
      accent: StudyUi.pathViolet,
      confirmText: '添加',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoadingDemoSeed = true);
    try {
      final result = await widget.controller.loadFinalDemoSeed();
      if (!mounted) return;
      StudyToast.show(
        context,
        '已添加 ${result.totalItems} 项高数复盘练习：${result.logs} 条学习记录、${result.tasks} 个任务、${result.flashCards} 张闪卡',
      );
    } catch (error) {
      _showError('高数复盘练习暂时没有添加成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isLoadingDemoSeed = false);
    }
  }

  Future<void> _confirmResetDemoSeed() async {
    final confirmed = await _showAiSettingsConfirmDialog(
      title: '清除高数复盘练习',
      message: '只会删除这套高数复盘练习，不会删除你手动创建的学习记录、任务、闪卡或学迹。',
      icon: Icons.restart_alt_rounded,
      accent: StudyUi.pathCyan,
      confirmText: '清除',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isResettingDemoSeed = true);
    try {
      final removed = await widget.controller.resetFinalDemoSeed();
      if (!mounted) return;
      StudyToast.show(context, '已清除 $removed 项高数复盘练习');
    } catch (error) {
      _showError('高数复盘练习暂时没有清除成功，请稍后再试');
    } finally {
      if (mounted) setState(() => _isResettingDemoSeed = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _showAiSettingsConfirmDialog(
      title: '注销账号',
      message: '注销后会删除账号与账号备份数据，并清空本机学习数据。此操作不可恢复。',
      icon: Icons.warning_rounded,
      accent: StudyUi.danger,
      confirmText: '确认注销',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await widget.controller.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      _showError('账号暂时没有注销成功，请稍后再试');
    }
  }

  void _showLegalSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiSettingsSheetSurface(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathViolet,
        icon: Icons.policy_rounded,
        title: title,
        child: Text(
          content,
          style: TextStyle(
            color: StudyUi.body(widget.isDarkMode),
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Future<bool> _showAiSettingsConfirmDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    required String confirmText,
    bool danger = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AiSettingsDialogSurface(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        icon: icon,
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _AiSettingsActionPill(
                  icon: Icons.close_rounded,
                  label: '取消',
                  accent: StudyUi.muted(widget.isDarkMode),
                  isDarkMode: widget.isDarkMode,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                const Spacer(),
                _AiSettingsActionPill(
                  icon: danger
                      ? Icons.delete_forever_rounded
                      : Icons.check_rounded,
                  label: confirmText,
                  accent: accent,
                  isDarkMode: widget.isDarkMode,
                  isFilled: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  void _showError(String message) {
    if (!mounted) return;
    StudyToast.dialog(context, title: '操作失败', message: message);
  }

  static const _privacyPolicyText = '''
StudyTrace 会保存你主动创建的学习任务、学习记录、笔记、闪卡、课程、小组和成长点数据。

登录后，数据会备份到 StudyTrace 账号，用于换设备继续使用、学习小组、学习进度和账号恢复。未登录时，数据主要保存在当前设备。

我们不会让你在手机里保存额外的模型凭证，也不会把你的数据出售给第三方。你可以在设置中保存本机数据，或注销账号并请求删除账号备份数据。
''';

  static const _termsText = '''
StudyTrace 是免费的学习管理工具，提供任务管理、学习记录、学习助手、小组和学习进度功能。

你需要对自己发布在小组中的内容负责，不得上传违法、侵权、骚扰或恶意内容。助手整理的内容仅作学习参考，不构成专业建议。

服务可能因维护或网络波动而短暂不可用，我们会尽力保持稳定并持续改进。
''';

  static const _aiDataText = '''
学习助手由 StudyTrace 统一处理整理请求。App 不需要你保存或输入额外的模型凭证。

当你使用学习对话、拍照识别、任务拆解、周安排、笔记改写或搜索时，请求内容可能会用于完成这次学习整理。为保持账号安全和稳定体验，我们会记录必要的使用次数和安全记录。

请避免输入身份证号、银行卡号、密码等敏感信息。助手整理的内容可能不准确，重要事项请自行核对。
''';

  static const _permissionText = '''
网络：用于登录、资料备份、小组、学习进度和学习助手。

相机与相册：用于拍照创建学习记录、拍照成笔记、头像选择和 OCR 识别。

麦克风与语音识别：用于语音创建任务和语音输入。

通知与闹钟：用于任务截止提醒、每日学习提醒和番茄钟体验。

这些权限会在相关功能使用前请求；拒绝权限不会影响其他基础功能。
''';
}

class _AiSettingsDialogSurface extends StatelessWidget {
  const _AiSettingsDialogSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: StudyUi.surface(isDarkMode),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StudyUi.border(isDarkMode)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudyGlassIconNode(
                  icon: icon,
                  accent: accent,
                  size: 40,
                  iconSize: 18,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 17,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _AiSettingsSheetSurface extends StatelessWidget {
  const _AiSettingsSheetSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                StudyUi.surface(isDarkMode),
                StudyUi.surfaceAlt(isDarkMode),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: StudyUi.border(isDarkMode)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StudyUi.muted(isDarkMode).withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StudyGlassIconNode(
                      icon: icon,
                      accent: accent,
                      size: 42,
                      iconSize: 20,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: StudyUi.title(isDarkMode),
                          fontSize: 18,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSettingsActionPill extends StatelessWidget {
  const _AiSettingsActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.isFilled = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = isFilled ? Colors.white : accent;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color:
                isFilled ? accent : StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isFilled
                  ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.38)
                  : accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final visibleAlerts = alerts.take(3).toList(growable: false);

    if (visibleAlerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.58)
              : StudyUi.surfaceAlt(isDarkMode),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode
                ? StudyUi.border(isDarkMode)
                : StudyUi.pathMint.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前没有明显学习难点。完成任务、整理闪卡或记录学习后，提醒会自动刷新。',
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
                '当前提醒预览',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: AppTypography.title,
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
    final textColor = StudyUi.title(isDarkMode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: disabled ? null : () => onSelected(!selected),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor
                : (isDarkMode
                    ? StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.58)
                    : StudyUi.surfaceAlt(isDarkMode)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? selectedColor : StudyUi.border(isDarkMode),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : icon,
                size: 15,
                color: selected ? Colors.white : selectedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : textColor,
                  fontSize: 12,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
        ),
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
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
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
                fontWeight: AppTypography.title,
              ),
            ),
          ),
        ),
        _iconButton(Icons.add_rounded, canEdit ? onPlus : null),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SizedBox(
      width: 34,
      height: 34,
      child: Opacity(
        opacity: enabled ? 1 : 0.46,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: enabled
                  ? StudyUi.chipBackground(accent, isDarkMode)
                  : StudyUi.surfaceAlt(isDarkMode),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled
                    ? accent.withValues(alpha: isDarkMode ? 0.24 : 0.18)
                    : StudyUi.border(isDarkMode),
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? accent : StudyUi.muted(isDarkMode),
              size: 18,
            ),
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
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    final levelColor = _levelColor(alert.level);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: levelColor.withValues(alpha: isDarkMode ? 0.28 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: alert.icon,
            accent: levelColor,
            size: 36,
            iconSize: 18,
            isDarkMode: isDarkMode,
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
                          fontWeight: AppTypography.emphasis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.levelLabel,
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 11,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
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
