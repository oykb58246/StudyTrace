import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/achievement.dart';
import '../../models/user_profile.dart';
import '../../services/picked_image_store.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenAchievements,
    this.onOpenCourseArchive,
    this.showAppBar = true,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenCourseArchive;
  final bool showAppBar;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _imagePicker = ImagePicker();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _avatarEmoji;
  String? _avatarImagePath;
  Timer? _autoSaveTimer;
  String? _lastSavedProfileKey;
  bool _isSaving = false;
  bool _saveAgainAfterCurrent = false;
  bool _isLoggingOut = false;
  bool _isLoadingBackend = false;
  String? _backendUsername;
  String? _backendEmail;

  static const _emojiOptions = [
    '🎓',
    '📚',
    '✏️',
    '💻',
    '🔬',
    '📐',
    '🎨',
    '🌍',
    '🧠',
    '⭐',
    '🚀',
    '💡',
    '🎯',
    '🏆',
    '🔥',
    '💪',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.userProfile;
    _nicknameController = TextEditingController(text: profile.nickname);
    _bioController = TextEditingController(text: profile.bio);
    _avatarEmoji = profile.avatarEmoji;
    _avatarImagePath = profile.avatarImagePath;
    _lastSavedProfileKey = _profileKey(profile);
    _nicknameController.addListener(_scheduleAutoSave);
    _bioController.addListener(_scheduleAutoSave);
    if (widget.controller.isLoggedIn) {
      unawaited(_loadBackendProfile());
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nicknameController.removeListener(_scheduleAutoSave);
    _bioController.removeListener(_scheduleAutoSave);
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadBackendProfile() async {
    setState(() => _isLoadingBackend = true);
    try {
      final me = await widget.controller.authService.getProfile();
      if (!mounted) return;
      setState(() {
        _backendUsername = me['username'] as String?;
        _backendEmail = me['email'] as String?;
      });
    } catch (_) {
      // 拉取失败不阻断页面
    } finally {
      if (mounted) {
        setState(() => _isLoadingBackend = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.userProfile;
    final textColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final unlockedTypes =
        widget.controller.unlockedAchievements.map((e) => e.type).toSet();
    final unlockedCount = unlockedTypes.length;
    final totalAchievements = Achievement.all.length;
    final progress = totalAchievements == 0
        ? 0.0
        : (unlockedCount / totalAchievements).clamp(0.0, 1.0).toDouble();
    final level = _levelFor(widget.controller.totalPoints);
    final nextLevelPoints = _nextLevelPoints(widget.controller.totalPoints);
    final currentLevelStart = _levelStart(level);
    final levelProgress = nextLevelPoints == null
        ? 1.0
        : ((widget.controller.totalPoints - currentLevelStart) /
                (nextLevelPoints - currentLevelStart))
            .clamp(0.0, 1.0)
            .toDouble();
    final recentAchievements = widget.controller.unlockedAchievements
        .map((record) => Achievement.findByType(record.type))
        .whereType<Achievement>()
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: textColor,
              title: const Text(
                '我的学迹',
                style: TextStyle(fontWeight: AppTypography.title),
              ),
            )
          : null,
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathViolet,
        child: ListView(
          key: const Key('page_user_profile'),
          padding:
              EdgeInsets.fromLTRB(22, widget.showAppBar ? 14 : 16, 22, 124),
          children: [
            _profileHero(
              profile: profile,
              level: level,
              levelProgress: levelProgress,
              nextLevelPoints: nextLevelPoints,
              bodyColor: bodyColor,
            ),
            if (widget.onOpenCourseArchive != null) ...[
              const SizedBox(height: 14),
              _courseArchiveEntry(),
            ],
            const SizedBox(height: 14),
            _achievementCard(
              unlockedCount: unlockedCount,
              totalAchievements: totalAchievements,
              progress: progress,
              recentAchievements: recentAchievements,
            ),
            const SizedBox(height: 22),
            _buildField(
              label: '资料',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileFieldLabel('名字'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
                    decoration: _inputDeco('输入你的昵称'),
                  ),
                  const SizedBox(height: 14),
                  _profileFieldLabel('签名'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLines: 2,
                    style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
                    decoration: _inputDeco('一句话介绍自己'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (widget.controller.isLoggedIn) ...[
              _buildField(
                label: '账号信息',
                child: StudyCard(
                  padding: const EdgeInsets.all(16),
                  child: _isLoadingBackend
                      ? const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '用户名：${_backendUsername ?? '暂未同步'}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: AppTypography.title,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '邮箱：${_backendEmail ?? '暂未绑定邮箱'}',
                              style: TextStyle(color: bodyColor, fontSize: 13),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _buildField(
                label: '账号操作',
                child: _buildLogoutButton(textColor, bodyColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileHero({
    required UserProfile profile,
    required int level,
    required double levelProgress,
    required int? nextLevelPoints,
    required Color bodyColor,
  }) {
    final nextLevelText = nextLevelPoints == null
        ? '已达到当前最高阶段'
        : '距离阶段 ${level + 1} 还差 ${nextLevelPoints - widget.controller.totalPoints} 成长点';
    return StudyPathHero(
      isDarkMode: widget.isDarkMode,
      accent: StudyUi.pathViolet,
      badge: '学习档案',
      title: '我的学迹',
      subtitle: profile.bio.trim().isEmpty
          ? '${profile.nickname} · 每一步学习，都是成长的轨迹。'
          : '${profile.nickname} · ${profile.bio}',
      icon: Icons.person_rounded,
      steps: const ['连续学习', '成长阶段', '课程归档'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatarPreview(82),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BadgePill(
                          label: '阶段 $level',
                          background: StudyUi.pathViolet.withValues(
                            alpha: widget.isDarkMode ? 0.22 : 0.14,
                          ),
                          foreground: StudyUi.pathViolet,
                        ),
                        BadgePill(
                          label: '${widget.controller.totalPoints} 成长点',
                          background: StudyUi.pathBlue.withValues(
                            alpha: widget.isDarkMode ? 0.20 : 0.12,
                          ),
                          foreground: StudyUi.pathBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: levelProgress,
                        minHeight: 7,
                        backgroundColor: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0xFFE7ECFF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          StudyUi.pathMint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      nextLevelText,
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniMetric('连续学习', '${widget.controller.studyStreak} 天'),
              const SizedBox(width: 10),
              _miniMetric('成长阶段', '阶段 $level'),
              const SizedBox(width: 10),
              _miniMetric('成长点数', '${widget.controller.totalPoints}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _avatarImagePath != null ? '点击头像更换照片' : '点击头像设置头像',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _avatarPreview(double size) {
    return GestureDetector(
      onTap: _showAvatarPicker,
      child: StudyUserAvatar(
        avatarImagePath: _avatarImagePath,
        avatarEmoji: _avatarEmoji,
        size: size,
        accent: StudyUi.pathViolet,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  Widget _courseArchiveEntry() {
    final courseCount = widget.controller.courseNames.length;
    final reportCount = widget.controller.weeklyReports.length;
    return StudyCard(
      onTap: widget.onOpenCourseArchive,
      padding: const EdgeInsets.all(18),
      borderColor: StudyUi.pathBlue.withValues(
        alpha: widget.isDarkMode ? 0.22 : 0.16,
      ),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: Icons.inventory_2_rounded,
            accent: StudyUi.pathBlue,
            size: 48,
            iconSize: 21,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '课程归档',
                  style: TextStyle(
                    color: StudyUi.title(widget.isDarkMode),
                    fontSize: 17,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$courseCount 门课程 · $reportCount 份周报，回看期末复盘资料。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(widget.isDarkMode),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: StudyUi.muted(widget.isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _achievementCard({
    required int unlockedCount,
    required int totalAchievements,
    required double progress,
    required List<Achievement> recentAchievements,
  }) {
    return StudyCard(
      onTap: widget.onOpenAchievements,
      padding: const EdgeInsets.all(18),
      borderColor: StudyUi.pathWarm.withValues(
        alpha: widget.isDarkMode ? 0.24 : 0.18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.workspace_premium_rounded,
                accent: StudyUi.pathWarm,
                size: 48,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '成长记录',
                      style: TextStyle(
                        color: StudyUi.title(widget.isDarkMode),
                        fontSize: 17,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '已记录 $unlockedCount/$totalAchievements · 下一条记录正在积累',
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFFFE8CB),
              valueColor: const AlwaysStoppedAnimation<Color>(StudyUi.pathWarm),
            ),
          ),
          const SizedBox(height: 14),
          if (recentAchievements.isEmpty)
            Text(
              '完成任务、记录复盘或整理闪卡后，这里会出现你的成长记录。',
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                height: 1.45,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentAchievements
                  .map((achievement) =>
                      _badgePreview(achievement, StudyUi.pathWarm))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    final color = switch (label) {
      '连续学习' => StudyUi.pathMint,
      '成长点数' => StudyUi.pathBlue,
      _ => StudyUi.pathViolet,
    };
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.isDarkMode ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: StudyUi.muted(widget.isDarkMode),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
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

  Widget _badgePreview(Achievement achievement, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(
        _iconForAchievement(achievement.iconName),
        color: color,
        size: 21,
      ),
    );
  }

  Widget _buildLogoutButton(Color textColor, Color bodyColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? StudyUi.surfaceAlt(widget.isDarkMode).withValues(alpha: 0.72)
            : StudyUi.surfaceAlt(widget.isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyUi.border(widget.isDarkMode)),
      ),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: Icons.logout_rounded,
            accent: StudyUi.danger,
            size: 42,
            iconSize: 20,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '退出当前账号',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '退出后会回到登录页，本机资料仍保留。',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ProfileActionPill(
            icon: Icons.logout_rounded,
            label: _isLoggingOut ? '退出中' : '退出登录',
            accent: StudyUi.danger,
            isDarkMode: widget.isDarkMode,
            isFilled: true,
            onPressed: _isLoggingOut ? null : _confirmLogout,
          ),
        ],
      ),
    );
  }

  int _levelFor(int points) {
    if (points >= 1000) return 5;
    if (points >= 500) return 4;
    if (points >= 200) return 3;
    if (points >= 80) return 2;
    return 1;
  }

  int _levelStart(int level) {
    switch (level) {
      case 5:
        return 1000;
      case 4:
        return 500;
      case 3:
        return 200;
      case 2:
        return 80;
      default:
        return 0;
    }
  }

  int? _nextLevelPoints(int points) {
    if (points < 80) return 80;
    if (points < 200) return 200;
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    return null;
  }

  IconData _iconForAchievement(String name) {
    switch (name) {
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'task_alt':
        return Icons.task_alt_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'local_fire_department':
      case 'whatshot':
        return Icons.local_fire_department_rounded;
      case 'stars':
        return Icons.stars_rounded;
      case 'summarize':
        return Icons.summarize_rounded;
      case 'style':
        return Icons.style_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'toll':
        return Icons.toll_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'smart_toy':
        return Icons.smart_toy_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _profileFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: StudyUi.muted(widget.isDarkMode),
        fontSize: 12,
        fontWeight: AppTypography.title,
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: StudyUi.surfaceAlt(widget.isDarkMode),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: widget.controller.primaryColor.withValues(alpha: 0.42),
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileSheetSurface(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathViolet,
        icon: Icons.account_circle_rounded,
        title: '设置头像',
        subtitle: '头像会同步到主页、学迹和学习对话。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _avatarAction(Icons.photo_library_rounded, '相册', () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _avatarAction(Icons.camera_alt_rounded, '拍照', () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _avatarAction(Icons.emoji_emotions_rounded, '表情', () {
                    Navigator.of(ctx).pop();
                    _showEmojiPicker();
                  }),
                ),
              ],
            ),
            if (_avatarImagePath != null) ...[
              const SizedBox(height: 14),
              _ProfileActionPill(
                icon: Icons.hide_image_rounded,
                label: '移除照片',
                accent: StudyUi.danger,
                isDarkMode: widget.isDarkMode,
                onPressed: () {
                  setState(() => _avatarImagePath = null);
                  _scheduleAutoSave(immediate: true);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatarAction(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: StudyUi.surfaceAlt(widget.isDarkMode),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: StudyUi.border(widget.isDarkMode)),
          ),
          child: Column(
            children: [
              StudyGlassIconNode(
                icon: icon,
                accent: StudyUi.pathViolet,
                size: 42,
                iconSize: 20,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: StudyUi.title(widget.isDarkMode),
                  fontSize: 12,
                  fontWeight: AppTypography.emphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final path = await persistPickedImage(picked, prefix: 'avatar');
      setState(() => _avatarImagePath = path);
      _scheduleAutoSave(immediate: true);
    } catch (e) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '获取图片失败',
          message: '这次没有读取到图片，可以换一张或稍后再试。',
        );
      }
    }
  }

  void _showEmojiPicker() {
    final accent = widget.controller.primaryColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileSheetSurface(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        icon: Icons.emoji_emotions_rounded,
        title: '选择头像表情',
        subtitle: '也可以回到上一步选择照片头像。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojiOptions.map((emoji) {
                final selected = _avatarEmoji == emoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _avatarEmoji = emoji);
                    _scheduleAutoSave(immediate: true);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.2)
                          : (widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : StudyUi.surfaceAlt(widget.isDarkMode)),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          selected ? Border.all(color: accent, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleAutoSave({bool immediate = false}) {
    _autoSaveTimer?.cancel();
    if (immediate) {
      unawaited(_saveProfile());
      return;
    }
    _autoSaveTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_saveProfile()),
    );
  }

  UserProfile _draftProfile() {
    return UserProfile(
      nickname: _nicknameController.text.trim().isEmpty
          ? '学习者'
          : _nicknameController.text.trim(),
      avatarEmoji: _avatarEmoji,
      avatarImagePath: _avatarImagePath,
      bio: _bioController.text.trim().isEmpty
          ? '记录今天的一小步'
          : _bioController.text.trim(),
    );
  }

  String _profileKey(UserProfile profile) {
    return [
      profile.nickname,
      profile.avatarEmoji,
      profile.avatarImagePath ?? '',
      profile.bio,
    ].join('|');
  }

  Future<void> _saveProfile() async {
    final profile = _draftProfile();
    final profileKey = _profileKey(profile);
    if (profileKey == _lastSavedProfileKey) return;
    if (_isSaving) {
      _saveAgainAfterCurrent = true;
      return;
    }
    if (mounted) setState(() => _isSaving = true);
    try {
      await widget.controller.updateUserProfile(profile);
      _lastSavedProfileKey = profileKey;
    } catch (_) {
      if (mounted) {
        StudyToast.show(context, '资料自动保存失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (_saveAgainAfterCurrent) {
          _saveAgainAfterCurrent = false;
          _scheduleAutoSave(immediate: true);
        }
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _showProfileConfirmDialog(
      title: '退出登录',
      message: '确定要退出当前账号吗？退出后需要重新登录才能继续使用同步、小组和学习助手。',
      icon: Icons.logout_rounded,
      accent: StudyUi.danger,
      confirmText: '确认退出',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await widget.controller.logout();
      if (!mounted) return;
      StudyToast.show(context, '已退出登录');
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      await StudyToast.dialog(
        context,
        title: '退出失败',
        message: '这次没有退出成功，请稍后再试。',
      );
    }
  }

  Future<bool> _showProfileConfirmDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    required String confirmText,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ProfileDialogSurface(
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
                _ProfileActionPill(
                  icon: Icons.close_rounded,
                  label: '取消',
                  accent: StudyUi.muted(widget.isDarkMode),
                  isDarkMode: widget.isDarkMode,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                const Spacer(),
                _ProfileActionPill(
                  icon: Icons.check_rounded,
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
}

class _ProfileSheetSurface extends StatelessWidget {
  const _ProfileSheetSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: StudyUi.title(isDarkMode),
                            fontSize: 18,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: StudyUi.body(isDarkMode),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
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
    );
  }
}

class _ProfileDialogSurface extends StatelessWidget {
  const _ProfileDialogSurface({
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

class _ProfileActionPill extends StatelessWidget {
  const _ProfileActionPill({
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
            mainAxisAlignment: MainAxisAlignment.center,
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
