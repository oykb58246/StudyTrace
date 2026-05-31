import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/achievement.dart';
import '../../models/user_profile.dart';
import '../../services/picked_image_store.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';
import '../shared/local_image.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenAchievements,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenAchievements;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _imagePicker = ImagePicker();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _avatarEmoji;
  String? _avatarImagePath;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isLoadingBackend = false;
  String? _backendUsername;
  String? _backendEmail;

  static const _emojiOptions = [
    '🎓', '📚', '✏️', '💻', '🔬', '📐', '🎨', '🌍',
    '🧠', '⭐', '🚀', '💡', '🎯', '🏆', '🔥', '💪',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.userProfile;
    _nicknameController = TextEditingController(text: profile.nickname);
    _bioController = TextEditingController(text: profile.bio);
    _avatarEmoji = profile.avatarEmoji;
    _avatarImagePath = profile.avatarImagePath;
    if (widget.controller.isLoggedIn) {
      unawaited(_loadBackendProfile());
    }
  }

  @override
  void dispose() {
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
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final unlockedTypes =
        widget.controller.unlockedAchievements.map((e) => e.type).toSet();
    final unlockedCount = unlockedTypes.length;
    final totalAchievements = Achievement.all.length;
    final progress = totalAchievements == 0
        ? 0.0
        : (unlockedCount / totalAchievements).clamp(0.0, 1.0);
    final level = _levelFor(widget.controller.totalPoints);
    final nextLevelPoints = _nextLevelPoints(widget.controller.totalPoints);
    final currentLevelStart = _levelStart(level);
    final levelProgress = nextLevelPoints == null
        ? 1.0
        : ((widget.controller.totalPoints - currentLevelStart) /
                (nextLevelPoints - currentLevelStart))
            .clamp(0.0, 1.0);
    final recentAchievements = widget.controller.unlockedAchievements
        .map((record) => Achievement.findByType(record.type))
        .whereType<Achievement>()
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('个人资料',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isSaving ? '保存中...' : '保存',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : accent,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        children: [
          // Avatar selector
          Center(
            child: GestureDetector(
              onTap: _showAvatarPicker,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _avatarImagePath == null
                      ? StudyUi.chipBackground(accent, widget.isDarkMode)
                      : (widget.isDarkMode
                          ? const Color(0xFF242B37)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: StudyUi.border(widget.isDarkMode)),
                  boxShadow: [
                    if (!widget.isDarkMode)
                      BoxShadow(
                        color: accent.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarImagePath != null
                    ? localImageFromPath(
                        _avatarImagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(_avatarEmoji,
                              style: const TextStyle(fontSize: 44)),
                        ),
                      )
                    : Center(
                        child: Text(_avatarEmoji,
                            style: const TextStyle(fontSize: 44)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _avatarImagePath != null ? '点击更换头像' : '点击设置头像',
              style: TextStyle(color: bodyColor, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),

          // Nickname
          _buildField(
            label: '昵称',
            child: TextField(
              controller: _nicknameController,
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink),
              decoration: _inputDeco('输入你的昵称'),
            ),
          ),
          const SizedBox(height: 18),

          // Bio
          _buildField(
            label: '个人签名',
            child: TextField(
              controller: _bioController,
              maxLines: 2,
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : AppColors.ink),
              decoration: _inputDeco('一句话介绍自己'),
            ),
          ),
          const SizedBox(height: 18),

          if (widget.controller.isLoggedIn) ...[
            _buildField(
              label: '账号信息',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF2F5FC),
                  borderRadius: BorderRadius.circular(14),
                ),
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
                            '用户名：${_backendUsername ?? '未知'}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '邮箱：${_backendEmail ?? '未绑定'}',
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
            const SizedBox(height: 18),
          ],

          // Stats
          _buildField(
            label: '学习统计',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF2F5FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _statItem('任务', widget.controller.studyTasks.length, bodyColor, textColor),
                  _statItem('记录', widget.controller.studyLogs.length, bodyColor, textColor),
                  _statItem('连续', widget.controller.studyStreak, bodyColor, textColor),
                  _statItem('周报', widget.controller.weeklyReports.length, bodyColor, textColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 积分与成就
          _buildField(
            label: '积分与成就',
            child: StudyCard(
              onTap: widget.onOpenAchievements,
              color: StudyUi.primary,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.toll_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.controller.totalPoints} 积分 · Lv.$level',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已解锁 $unlockedCount/$totalAchievements 个成就',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.72),
                          size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: levelProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4BC4A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextLevelPoints == null
                        ? '已达到当前最高等级'
                        : '距离下一等级还差 ${nextLevelPoints - widget.controller.totalPoints} 积分',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _miniMetric('连续', '${widget.controller.studyStreak} 天'),
                      const SizedBox(width: 10),
                      _miniMetric('成就', '${(progress * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (recentAchievements.isEmpty)
                    Text(
                      '完成任务、记录日志或生成闪卡后，这里会出现你的徽章。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        height: 1.45,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recentAchievements
                          .map((achievement) =>
                              _badgePreview(achievement, Colors.white))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color bodyColor, Color textColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F5FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudyUi.border(widget.isDarkMode)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: StudyUi.danger.withValues(
                alpha: widget.isDarkMode ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: StudyUi.danger,
              size: 22,
            ),
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
                    fontWeight: FontWeight.w800,
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
          FilledButton(
            onPressed: _isLoggingOut ? null : _confirmLogout,
            style: FilledButton.styleFrom(
              backgroundColor: StudyUi.danger,
              foregroundColor: Colors.white,
              disabledBackgroundColor: StudyUi.danger.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(_isLoggingOut ? '退出中' : '退出登录'),
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

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF2F5FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF1A1F2E)
              : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text('设置头像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _avatarAction(Icons.photo_library_rounded, '相册', () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                }),
                _avatarAction(Icons.camera_alt_rounded, '拍照', () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                }),
                _avatarAction(Icons.emoji_emotions_rounded, '表情', () {
                  Navigator.of(ctx).pop();
                  _showEmojiPicker();
                }),
              ],
            ),
            if (_avatarImagePath != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _avatarImagePath = null);
                  Navigator.of(ctx).pop();
                },
                child: const Text('移除照片，使用表情头像',
                    style: TextStyle(color: Color(0xFFEF6850))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatarAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF2F5FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26,
                color: widget.isDarkMode ? Colors.white70 : AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : AppColors.ink,
                  fontSize: 12)),
        ],
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
    } catch (e) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '获取图片失败',
          message: '$e',
        );
      }
    }
  }

  void _showEmojiPicker() {
    final accent = widget.controller.primaryColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF1A1F2E)
              : const Color(0xFFF5F7FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '选择头像表情',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojiOptions.map((emoji) {
                final selected = _avatarEmoji == emoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _avatarEmoji = emoji);
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
                              : const Color(0xFFF2F5FC)),
                      borderRadius: BorderRadius.circular(16),
                      border: selected
                          ? Border.all(
                              color: accent, width: 2)
                          : null,
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

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    await widget.controller.updateUserProfile(
      UserProfile(
        nickname: _nicknameController.text.trim().isEmpty
            ? '学习者'
            : _nicknameController.text.trim(),
        avatarEmoji: _avatarEmoji,
        avatarImagePath: _avatarImagePath,
        bio: _bioController.text.trim().isEmpty
            ? '好好学习，天天向上'
            : _bioController.text.trim(),
      ),
    );
    if (mounted) {
      StudyToast.show(context, '个人资料已保存');
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？退出后需要重新登录才能继续使用云同步、小组和AI功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StudyUi.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
        message: '$error',
      );
    }
  }
}
