import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/analysis_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class AnalysisResultPage extends StatefulWidget {
  const AnalysisResultPage({
    super.key,
    required this.analysis,
    required this.controller,
    required this.isDarkMode,
  });

  final AnalysisItem analysis;
  final AppDataController controller;
  final bool isDarkMode;

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends State<AnalysisResultPage> {
  bool _isSaving = false;
  bool _isAddingTodo = false;
  bool _isGeneratingPlan = false;

  Future<void> _saveHistory() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    await widget.controller.saveAnalysis(widget.analysis);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    _showMessage(
      widget.controller.hasHistory(widget.analysis.id)
          ? '分析记录已保存'
          : '分析记录保存失败，请稍后再试',
    );
  }

  Future<void> _addTodo() async {
    if (_isAddingTodo) {
      return;
    }
    setState(() => _isAddingTodo = true);
    final todo = await widget.controller.addTodoFromAnalysis(widget.analysis);
    if (!mounted) {
      return;
    }
    setState(() => _isAddingTodo = false);
    _showMessage('已加入待办：${todo.title}');
  }

  Future<void> _generatePlan() async {
    if (_isGeneratingPlan) {
      return;
    }
    setState(() => _isGeneratingPlan = true);
    final todos = await widget.controller.generatePlanFromAnalysis(
      widget.analysis,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isGeneratingPlan = false);
    _showMessage('已生成 ${todos.length} 个计划待办');
  }

  void _showMessage(String message) {
    StudyToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    const accent = StudyUi.pathBlue;
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return Scaffold(
      key: const Key('analysis_result_page'),
      backgroundColor: StudyUi.background(widget.isDarkMode),
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            children: [
              _AnalysisTopBar(
                isDarkMode: widget.isDarkMode,
                accent: accent,
              ),
              const SizedBox(height: 14),
              StudyPathHero(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                badge: widget.analysis.contentType,
                title: widget.analysis.summary,
                subtitle: '把材料整理成关键点、下一步和计划入口，方便继续推进学习。',
                icon: Icons.auto_awesome_rounded,
                steps: const ['整理', '行动', '计划', '保存'],
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StudyPathMetricPill(
                            label: '关键点',
                            value: '${widget.analysis.keyPoints.length}',
                            icon: Icons.tips_and_updates_rounded,
                            color: StudyUi.secondary,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StudyPathMetricPill(
                            label: '下一步',
                            value: '${widget.analysis.suggestedActions.length}',
                            icon: Icons.check_circle_outline_rounded,
                            color: StudyUi.success,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StudyPathMetricPill(
                      label: '整理时间',
                      value: _dateLabel(widget.analysis.createdAt),
                      icon: Icons.schedule_rounded,
                      color: StudyUi.pathCyan,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AnalysisInsightStrip(
                isDarkMode: widget.isDarkMode,
                goodText: _firstOr(
                  widget.analysis.keyPoints,
                  '已经整理出本次学习中最值得保留的内容。',
                ),
                adjustText: _firstOr(
                  widget.analysis.suggestedActions,
                  '先把下一步拆成一个今天能完成的小动作。',
                ),
                nextText: _firstOr(
                  widget.analysis.suggestedActions.skip(1).toList(),
                  '保存分析结果，接着生成计划或加入待办。',
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                isDarkMode: widget.isDarkMode,
                title: '做得好的',
                subtitle: '继续保留这些学习优势。',
                icon: Icons.tips_and_updates_rounded,
                accent: StudyUi.secondary,
                children: [
                  for (var i = 0; i < widget.analysis.keyPoints.length; i++)
                    _PathLine(
                      index: i + 1,
                      text: widget.analysis.keyPoints[i],
                      color: bodyColor,
                      accent: StudyUi.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                isDarkMode: widget.isDarkMode,
                title: '下一步建议',
                subtitle: '把分析结果变成今天能推进的小动作。',
                icon: Icons.route_rounded,
                accent: StudyUi.success,
                children: [
                  for (var i = 0;
                      i < widget.analysis.suggestedActions.length;
                      i++)
                    _PathLine(
                      index: i + 1,
                      text: widget.analysis.suggestedActions[i],
                      color: bodyColor,
                      accent: StudyUi.success,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                isDarkMode: widget.isDarkMode,
                title: '原始内容',
                subtitle: '保留上下文，方便回看分析来源。',
                icon: Icons.subject_rounded,
                accent: StudyUi.pathWarm,
                children: [
                  Text(
                    widget.analysis.rawContent,
                    style: TextStyle(
                      color: bodyColor,
                      height: 1.58,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _ActionButton(
                key: const Key('save_history_button'),
                label: _isSaving ? '保存中...' : '保存到历史',
                icon: Icons.history_rounded,
                color: accent,
                isDarkMode: widget.isDarkMode,
                onTap: _saveHistory,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                key: const Key('add_todo_button'),
                label: _isAddingTodo ? '加入中...' : '加入待办',
                icon: Icons.check_circle_outline_rounded,
                color: StudyUi.secondary,
                isDarkMode: widget.isDarkMode,
                onTap: _addTodo,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                key: const Key('generate_plan_button'),
                label: _isGeneratingPlan ? '生成中...' : '生成计划',
                icon: Icons.insights_rounded,
                color: StudyUi.pathWarm,
                isDarkMode: widget.isDarkMode,
                onTap: _generatePlan,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _firstOr(Iterable<String> values, String fallback) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }
}

class _AnalysisTopBar extends StatelessWidget {
  const _AnalysisTopBar({
    required this.isDarkMode,
    required this.accent,
  });

  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      color: StudyUi.surface(isDarkMode).withValues(alpha: isDarkMode ? 0.78 : 0.86),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.72),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudyUi.chipBackground(accent, isDarkMode),
                border: Border.all(
                  color: accent.withValues(alpha: isDarkMode ? 0.28 : 0.18),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: StudyUi.title(isDarkMode),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          StudyGlassIconNode(
            icon: Icons.analytics_rounded,
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
                  '分析结果',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 18,
                    fontWeight: AppTypography.title,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '整理关键点，接到下一步。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisInsightStrip extends StatelessWidget {
  const _AnalysisInsightStrip({
    required this.isDarkMode,
    required this.goodText,
    required this.adjustText,
    required this.nextText,
  });

  final bool isDarkMode;
  final String goodText;
  final String adjustText;
  final String nextText;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      color: StudyUi.surface(isDarkMode)
          .withValues(alpha: isDarkMode ? 0.82 : 0.90),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.72),
      child: Column(
        children: [
          _AnalysisInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.thumb_up_alt_rounded,
            accent: StudyUi.pathMint,
            title: '做得好的',
            text: goodText,
          ),
          const SizedBox(height: 10),
          _AnalysisInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.tune_rounded,
            accent: StudyUi.pathWarm,
            title: '需要调整',
            text: adjustText,
          ),
          const SizedBox(height: 10),
          _AnalysisInsightTile(
            isDarkMode: isDarkMode,
            icon: Icons.near_me_rounded,
            accent: StudyUi.secondary,
            title: '下一步建议',
            text: nextText,
          ),
        ],
      ),
    );
  }
}

class _AnalysisInsightTile extends StatelessWidget {
  const _AnalysisInsightTile({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.text,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(accent, isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: 36,
            iconSize: 17,
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
                    fontSize: 14,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.isDarkMode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final bool isDarkMode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      color: StudyUi.surface(isDarkMode).withValues(alpha: isDarkMode ? 0.82 : 0.88),
      borderColor: Colors.white.withValues(alpha: isDarkMode ? 0.10 : 0.70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        fontSize: 16,
                        fontWeight: AppTypography.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
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
}

class _PathLine extends StatelessWidget {
  const _PathLine({
    required this.index,
    required this.text,
    required this.color,
    required this.accent,
  });

  final int index;
  final String text;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.13),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: AppTypography.title,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color,
              Color.alphaBlend(
                Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.16),
                color,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDarkMode ? 0.16 : 0.50),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDarkMode ? 0.18 : 0.22),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: AppTypography.title,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
