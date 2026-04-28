import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_flash_card.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class FlashCardPage extends StatefulWidget {
  const FlashCardPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<FlashCardPage> createState() => _FlashCardPageState();
}

class _FlashCardPageState extends State<FlashCardPage> {
  final _aiService = AiStudyService();
  List<AiFlashCard> _cards = [];
  var _currentIndex = 0;
  var _isFlipped = false;
  var _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateCards();
  }

  Future<void> _generateCards() async {
    setState(() {
      _isGenerating = true;
      _cards = [];
      _currentIndex = 0;
      _isFlipped = false;
    });
    try {
      final logs = widget.controller.studyLogs;
      if (logs.isEmpty) {
        setState(() => _isGenerating = false);
        return;
      }
      final cards = await _aiService.generateFlashCards(
        logs: logs.take(20).toList(),
        count: 8,
      );
      if (mounted) {
        setState(() {
          _cards = cards;
          _isGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return ListView(
      key: const Key('page_flash_card'),
      padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF8AA5B).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.style_rounded,
                color: Color(0xFFF8AA5B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '知识闪卡',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI 从学习记录自动生成，巩固知识点',
                    style: TextStyle(color: bodyColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: widget.isDarkMode ? Colors.white54 : AppColors.muted),
              onPressed: _isGenerating ? null : _generateCards,
              tooltip: '重新生成',
            ),
          ],
        ),
        const SizedBox(height: 22),

        if (_isGenerating)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF7040F2)),
                  SizedBox(height: 18),
                  Text('AI 正在生成闪卡...',
                      style: TextStyle(color: Color(0xFFC2C8D6))),
                ],
              ),
            ),
          )
        else if (_cards.isEmpty)
          GlassCard(
            color: widget.isDarkMode
                ? const Color(0xFF242B37).withValues(alpha: 0.9)
                : null,
            child: Column(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: Color(0xFFC2C8D6), size: 48),
                const SizedBox(height: 12),
                Text(
                  '还没有学习记录',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '先去记录学习日志，AI 会自动生成闪卡帮你复习',
                  style: TextStyle(color: bodyColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentIndex + 1} / ${_cards.length}',
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flash card
          GestureDetector(
            onTap: () => setState(() => _isFlipped = !_isFlipped),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.95)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0x1A121A36),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Card header
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Row(
                      children: [
                        BadgePill(
                          label: _cards[_currentIndex].courseName,
                          background: const Color(0x197040F2),
                          foreground: const Color(0xFF7040F2),
                        ),
                        const Spacer(),
                        Icon(
                          _isFlipped
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: widget.isDarkMode
                              ? Colors.white38
                              : AppColors.muted,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isFlipped ? '答案' : '点击翻转',
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white38
                                : AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFlipped
                                  ? Icons.lightbulb_rounded
                                  : Icons.help_outline_rounded,
                              color: _isFlipped
                                  ? const Color(0xFF4BC4A1)
                                  : const Color(0xFF7040F2),
                              size: 32,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isFlipped
                                  ? _cards[_currentIndex].answer
                                  : _cards[_currentIndex].question,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: _isFlipped ? 16 : 18,
                                fontWeight: _isFlipped
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_isFlipped &&
                                _cards[_currentIndex].hint.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7394F9)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '💡 ${_cards[_currentIndex].hint}',
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF7040F2).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF7040F2),
                  disabledBackgroundColor:
                      widget.isDarkMode ? Colors.white12 : const Color(0xFFE8EBF5),
                  disabledForegroundColor:
                      widget.isDarkMode ? Colors.white24 : AppColors.muted,
                ),
                onPressed: _currentIndex > 0 ? _prevCard : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 20),
              Text(
                '点击卡片翻转',
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF7040F2).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF7040F2),
                  disabledBackgroundColor:
                      widget.isDarkMode ? Colors.white12 : const Color(0xFFE8EBF5),
                  disabledForegroundColor:
                      widget.isDarkMode ? Colors.white24 : AppColors.muted,
                ),
                onPressed:
                    _currentIndex < _cards.length - 1 ? _nextCard : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
