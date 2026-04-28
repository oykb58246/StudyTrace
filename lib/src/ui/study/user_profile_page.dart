import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _avatarEmoji;
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

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
                color: widget.isDarkMode ? Colors.white : const Color(0xFF7040F2),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        children: [
          // Avatar emoji selector
          Center(
            child: GestureDetector(
              onTap: _showEmojiPicker,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7040F2), Color(0xFF8D5EFF)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7040F2).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _avatarEmoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '点击更换头像表情',
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

  void _showEmojiPicker() {
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
                          ? const Color(0xFF7040F2).withValues(alpha: 0.2)
                          : (widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF2F5FC)),
                      borderRadius: BorderRadius.circular(16),
                      border: selected
                          ? Border.all(
                              color: const Color(0xFF7040F2), width: 2)
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
        bio: _bioController.text.trim().isEmpty
            ? '好好学习，天天向上'
            : _bioController.text.trim(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('个人资料已保存')),
      );
      Navigator.of(context).pop();
    }
  }
}
