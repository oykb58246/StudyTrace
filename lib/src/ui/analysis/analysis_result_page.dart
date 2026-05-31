import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/analysis_item.dart';
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
    const accent = StudyUi.primary;
    final textColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);

    return Scaffold(
      key: const Key('analysis_result_page'),
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text(
          '分析结果',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: StudyUi.surface(widget.isDarkMode),
              border: Border.all(color: StudyUi.border(widget.isDarkMode)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgePill(
                  label: widget.analysis.contentType,
                  background: StudyUi.chipBackground(accent, widget.isDarkMode),
                  foreground: accent,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.analysis.summary,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            isDarkMode: widget.isDarkMode,
            title: '关键点',
            children: [
              for (final point in widget.analysis.keyPoints)
                _BulletLine(text: point, color: bodyColor),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            isDarkMode: widget.isDarkMode,
            title: '建议行动',
            children: [
              for (final action in widget.analysis.suggestedActions)
                _BulletLine(text: action, color: bodyColor),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            isDarkMode: widget.isDarkMode,
            title: '原始内容',
            children: [
              Text(
                widget.analysis.rawContent,
                style: TextStyle(color: bodyColor, height: 1.55),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ActionButton(
            key: const Key('save_history_button'),
            label: _isSaving ? '保存中...' : '保存到历史',
            icon: Icons.history_rounded,
            color: const Color(0xFF182146),
            onTap: _saveHistory,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            key: const Key('add_todo_button'),
            label: _isAddingTodo ? '加入中...' : '加入待办',
            icon: Icons.check_circle_outline_rounded,
            color: StudyUi.secondary,
            onTap: _addTodo,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            key: const Key('generate_plan_button'),
            label: _isGeneratingPlan ? '生成中...' : '生成计划',
            icon: Icons.insights_rounded,
            color: StudyUi.danger,
            onTap: _generatePlan,
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
    required this.children,
  });

  final bool isDarkMode;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 7,
              color: Color(0xFF7394F9),
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
