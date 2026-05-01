import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
  final _imagePicker = ImagePicker();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _avatarEmoji;
  String? _avatarImagePath;
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
    _avatarImagePath = profile.avatarImagePath;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
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
                  gradient: _avatarImagePath == null
                      ? LinearGradient(
                          colors: [accent, Color(0xFF8D5EFF)],
                        )
                      : null,
                  color: _avatarImagePath != null
                      ? (widget.isDarkMode
                          ? const Color(0xFF242B37)
                          : Colors.white)
                      : null,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: _avatarImagePath == null ? 0.3 : 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarImagePath != null
                    ? Image.file(
                        File(_avatarImagePath!),
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
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final copied = await File(picked.path).copy(targetPath);
      setState(() => _avatarImagePath = copied.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取图片失败：$e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('个人资料已保存')),
      );
      Navigator.of(context).pop();
    }
  }
}
