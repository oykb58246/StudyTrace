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
    this.autoGenerate = true,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final bool autoGenerate;

  @override
  State<FlashCardPage> createState() => _FlashCardPageState();
}

class _FlashCardPageState extends State<FlashCardPage> {
  String? _filterGroup;
  bool _showStarredOnly = false;
  bool _showBrowse = false;
  int _browseIndex = 0;
  List<String> _browseCardIds = const [];

  @override
  void initState() {
    super.initState();
    if (widget.autoGenerate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoGenerateIfNeeded();
      });
    }
  }

  Future<void> _autoGenerateIfNeeded() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yLogs = widget.controller.studyLogs
        .where(
          (l) =>
              l.date.year == yesterday.year &&
              l.date.month == yesterday.month &&
              l.date.day == yesterday.day,
        )
        .toList();
    if (yLogs.isEmpty) return;

    final existing = widget.controller.flashCards.where(
      (c) =>
          c.createdAt.year == yesterday.year &&
          c.createdAt.month == yesterday.month &&
          c.createdAt.day == yesterday.day,
    );
    if (existing.isNotEmpty) return;

    try {
      final cards =
          await AiStudyService().generateFlashCards(logs: yLogs, count: 5);
      final now = DateTime.now();
      final newCards = cards
          .asMap()
          .entries
          .map(
            (e) => AiFlashCard(
              id: 'fc_${now.microsecondsSinceEpoch}_${e.key}',
              question: e.value.question,
              answer: e.value.answer,
              courseName: e.value.courseName,
              hint: e.value.hint,
              createdAt: yesterday,
            ),
          )
          .toList();
      if (mounted) widget.controller.addFlashCards(newCards);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final accent = widget.controller.primaryColor;
        final all = widget.controller.flashCards;
        final list = _filteredCards(all);
        final browseList = _browseCardsFrom(list);
        final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return Scaffold(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF141923)
              : const Color(0xFFF5F7FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: textColor,
            title: Text(
              _showBrowse ? '闪卡浏览' : '知识闪卡',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              if (!_showBrowse)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '刷新今日闪卡',
                  onPressed: _refreshTodayCards,
                ),
              if (all.isNotEmpty && !_showBrowse) _filterMenu(),
            ],
          ),
          body: _showBrowse && browseList.isNotEmpty
              ? _browseView(browseList, textColor, bodyColor)
              : _listView(list, textColor, bodyColor),
          floatingActionButton: _showBrowse
              ? FloatingActionButton.extended(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.view_agenda_rounded),
                  label: const Text('列表',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => setState(() => _showBrowse = false),
                )
              : null,
          bottomNavigationBar: const SizedBox(height: 80),
        );
      },
    );
  }

  List<AiFlashCard> _filteredCards(List<AiFlashCard> all) {
    var list = all;
    if (_showStarredOnly) {
      list = list.where((c) => c.isStarred).toList();
    }
    if (_filterGroup != null) {
      list = list.where((c) => c.groupName == _filterGroup).toList();
    }
    return list;
  }

  PopupMenuButton<String> _filterMenu() {
    final groups = widget.controller.flashCardGroups;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list_rounded),
      tooltip: '筛选分组',
      onSelected: (v) => setState(() {
        _showBrowse = false;
        if (v == '__all') {
          _filterGroup = null;
          _showStarredOnly = false;
        } else if (v == '__starred') {
          _showStarredOnly = !_showStarredOnly;
          _filterGroup = null;
        } else {
          _filterGroup = v;
          _showStarredOnly = false;
        }
      }),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '__all', child: Text('全部')),
        PopupMenuItem(
          value: '__starred',
          child: Row(children: [
            Icon(
              _showStarredOnly ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18,
              color: _showStarredOnly ? const Color(0xFFF8AA5B) : null,
            ),
            const SizedBox(width: 8),
            const Text('收藏'),
          ]),
        ),
        if (groups.isNotEmpty) const PopupMenuDivider(),
        ...groups.map((g) => PopupMenuItem(value: g, child: Text(g))),
      ],
    );
  }

  Widget _listView(List<AiFlashCard> list, Color textColor, Color bodyColor) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.style_rounded,
            size: 56,
            color: widget.isDarkMode ? Colors.white24 : const Color(0xFFC2C8D6),
          ),
          const SizedBox(height: 12),
          Text('还没有知识闪卡', style: TextStyle(color: bodyColor, fontSize: 16)),
          const SizedBox(height: 4),
          Text('记录学习日志后，AI 会自动生成',
              style: TextStyle(color: bodyColor, fontSize: 13)),
        ]),
      );
    }

    final grouped = _groupCardsByDate(list);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 100),
      itemCount: dates.length,
      itemBuilder: (_, index) {
        final date = dates[index];
        final cards = grouped[date]!;
        final shelves = _splitIntoShelves(cards);
        return Padding(
          key: Key('flash_card_date_group_$date'),
          padding: const EdgeInsets.only(bottom: 22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                date,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cards.length} 张',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 10),
            for (var shelfIndex = 0;
                shelfIndex < shelves.length;
                shelfIndex++) ...[
              _cardShelf(
                date: date,
                shelfIndex: shelfIndex,
                cards: shelves[shelfIndex],
                textColor: textColor,
                bodyColor: bodyColor,
              ),
              if (shelfIndex != shelves.length - 1)
                Divider(
                  height: 20,
                  thickness: 0.5,
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
            ],
          ]),
        );
      },
    );
  }

  Map<String, List<AiFlashCard>> _groupCardsByDate(List<AiFlashCard> cards) {
    final grouped = <String, List<AiFlashCard>>{};
    for (final card in cards) {
      final key = _dateKey(card.createdAt);
      grouped.putIfAbsent(key, () => []).add(card);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return grouped;
  }

  List<List<AiFlashCard>> _splitIntoShelves(List<AiFlashCard> cards) {
    final shelves = <List<AiFlashCard>>[];
    for (var i = 0; i < cards.length; i += 8) {
      shelves.add(cards.sublist(i, (i + 8).clamp(0, cards.length)));
    }
    if (shelves.length > 1 && shelves.last.length < 3) {
      shelves[shelves.length - 2] = [
        ...shelves[shelves.length - 2],
        ...shelves.last,
      ];
      shelves.removeLast();
    }
    return shelves;
  }

  Widget _cardShelf({
    required String date,
    required int shelfIndex,
    required List<AiFlashCard> cards,
    required Color textColor,
    required Color bodyColor,
  }) {
    return SizedBox(
      key: Key('flash_card_shelf_${date}_$shelfIndex'),
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => Transform.translate(
          offset: const Offset(-8, 0),
          child: _miniCard(
          card: cards[index],
          scopeCards: cards,
          scopeIndex: index,
          textColor: textColor,
          bodyColor: bodyColor,
        ),
      ),
      ),
    );
  }

  Widget _miniCard({
    required AiFlashCard card,
    required List<AiFlashCard> scopeCards,
    required int scopeIndex,
    required Color textColor,
    required Color bodyColor,
  }) {
    final accent = widget.controller.primaryColor;
    return SizedBox(
      key: Key('flash_card_mini_${card.id}'),
      width: 220,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openBrowse(scopeCards, scopeIndex),
          child: GlassCard(
            color: widget.isDarkMode
                ? const Color(0xFF242B37).withValues(alpha: 0.9)
                : null,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Stack(fit: StackFit.expand, children: [
              Positioned(
                right: 0,
                top: 0,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _starButton(card, bodyColor),
                  _groupButton(card, bodyColor),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: const Color(0xFFF8AA5B).withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        card.question,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (card.courseName.isNotEmpty)
                          _miniTag(card.courseName, accent),
                        if (card.groupName.isNotEmpty)
                          _miniTag(card.groupName, const Color(0xFF7394F9)),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _starButton(AiFlashCard card, Color bodyColor) {
    return IconButton(
      key: Key('flash_card_star_${card.id}'),
      tooltip: card.isStarred ? '取消收藏' : '收藏',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        card.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
        size: 22,
        color: card.isStarred ? const Color(0xFFF8AA5B) : bodyColor,
      ),
      onPressed: () => widget.controller
          .updateFlashCard(card.id, isStarred: !card.isStarred),
    );
  }

  Widget _groupButton(AiFlashCard card, Color bodyColor) {
    final groups = widget.controller.flashCardGroups;
    return PopupMenuButton<String>(
      key: Key('flash_card_group_menu_${card.id}'),
      tooltip: card.groupName.isNotEmpty ? card.groupName : '选择分组',
      icon: Icon(
        Icons.label_outline_rounded,
        size: 20,
        color: card.groupName.isNotEmpty ? const Color(0xFF7394F9) : bodyColor,
      ),
      onSelected: (value) => _handleGroupAction(card, value),
      itemBuilder: (_) => [
        if (groups.isNotEmpty)
          ...groups.map(
            (g) => PopupMenuItem(
              key: Key('flash_card_group_option_$g'),
              value: 'group:$g',
              child: Text(g),
            ),
          )
        else
          const PopupMenuItem(
            enabled: false,
            child: Text('暂无已有分组'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: Key('flash_card_group_option_new'),
          value: '__new',
          child: Text('添加到新的分组'),
        ),
        if (card.groupName.isNotEmpty)
          const PopupMenuItem(
            key: Key('flash_card_group_option_remove'),
            value: '__remove',
            child: Text('移出分组', style: TextStyle(color: Color(0xFFEF6850))),
          ),
      ],
    );
  }

  Future<void> _handleGroupAction(AiFlashCard card, String value) async {
    if (value == '__new') {
      final name = await _askNewGroupName();
      if (name == null || name.isEmpty) return;
      await widget.controller.updateFlashCard(card.id, groupName: name);
      return;
    }
    if (value == '__remove') {
      await widget.controller.updateFlashCard(card.id, groupName: '');
      return;
    }
    if (value.startsWith('group:')) {
      await widget.controller.updateFlashCard(
        card.id,
        groupName: value.substring('group:'.length),
      );
    }
  }

  Future<String?> _askNewGroupName() async {
    final accent = widget.controller.primaryColor;
    final ctrl = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('添加到新的分组'),
          content: TextField(
            key: const Key('flash_card_new_group_field'),
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '分组名称',
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F5FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              key: const Key('flash_card_create_group_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop(name);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      );
      return result;
    } finally {
      ctrl.dispose();
    }
  }

  void _openBrowse(List<AiFlashCard> cards, int index) {
    setState(() {
      _browseCardIds = cards.map((c) => c.id).toList(growable: false);
      _browseIndex = index;
      _showBrowse = true;
    });
  }

  Future<void> _refreshTodayCards() async {
    final today = DateTime.now();
    final todayLogs = widget.controller.studyLogs
        .where((l) =>
            l.date.year == today.year &&
            l.date.month == today.month &&
            l.date.day == today.day)
        .toList();

    if (todayLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天还没有学习记录，请先记录学习内容')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在生成闪卡...')),
      );

      final cards =
          await AiStudyService().generateFlashCards(logs: todayLogs, count: 8);

      final now = DateTime.now();
      final newCards = cards
          .asMap()
          .entries
          .map(
            (e) => AiFlashCard(
              id: 'fc_${now.microsecondsSinceEpoch}_${e.key}',
              question: e.value.question,
              answer: e.value.answer,
              courseName: e.value.courseName,
              hint: e.value.hint,
              createdAt: today,
            ),
          )
          .toList();

      if (mounted) {
        await widget.controller.addFlashCards(newCards);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已生成 ${newCards.length} 张闪卡')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成闪卡失败，请重试')),
        );
      }
    }
  }

  List<AiFlashCard> _browseCardsFrom(List<AiFlashCard> filteredList) {
    if (_browseCardIds.isEmpty) return const [];
    final byId = {for (final card in filteredList) card.id: card};
    return _browseCardIds
        .map((id) => byId[id])
        .whereType<AiFlashCard>()
        .toList();
  }

  Widget _browseView(List<AiFlashCard> list, Color textColor, Color bodyColor) {
    final accent = widget.controller.primaryColor;
    if (_browseIndex >= list.length) _browseIndex = 0;
    final card = list[_browseIndex];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            '${_browseIndex + 1} / ${list.length}',
            style: TextStyle(
              color: bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _FlashCardView(
            key: ValueKey(card.id),
            isDarkMode: widget.isDarkMode,
            card: card,
            titleColor: textColor,
            bodyColor: bodyColor,
            accentColor: accent,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.14),
              foregroundColor: accent,
            ),
            onPressed:
                _browseIndex > 0 ? () => setState(() => _browseIndex--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 18),
          Text('点击卡片翻转', style: TextStyle(color: bodyColor, fontSize: 13)),
          const SizedBox(width: 18),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.14),
              foregroundColor: accent,
            ),
            onPressed: _browseIndex < list.length - 1
                ? () => setState(() => _browseIndex++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ),
    ]);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _FlashCardView extends StatefulWidget {
  const _FlashCardView({
    super.key,
    required this.isDarkMode,
    required this.card,
    required this.titleColor,
    required this.bodyColor,
    required this.accentColor,
  });

  final bool isDarkMode;
  final AiFlashCard card;
  final Color titleColor;
  final Color bodyColor;
  final Color accentColor;

  @override
  State<_FlashCardView> createState() => _FlashCardViewState();
}

class _FlashCardViewState extends State<_FlashCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
      reverseDuration: const Duration(milliseconds: 1050),
      animationBehavior: AnimationBehavior.preserve,
    );
    _anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FlashCardView old) {
    super.didUpdateWidget(old);
    if (old.card.id != widget.card.id) {
      _isFlipped = false;
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_ctrl.isAnimating) return;
    if (_isFlipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * 3.14159;
          final isFront = angle < 3.14159 / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              width: double.infinity,
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
              padding: const EdgeInsets.all(24),
              child: isFront
                  ? _front()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _back(),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _front() => Column(children: [
        Row(children: [
          if (widget.card.courseName.isNotEmpty)
            BadgePill(
              label: widget.card.courseName,
              background: widget.accentColor.withValues(alpha: 0.1),
              foreground: widget.accentColor,
            ),
          const Spacer(),
          Text(
            '点击翻转',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white38 : AppColors.muted,
              fontSize: 12,
            ),
          ),
        ]),
        const Divider(height: 32),
        Icon(Icons.help_outline_rounded,
            color: widget.accentColor, size: 36),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              widget.card.question,
              style: TextStyle(
                color: widget.titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ]);

  Widget _back() => Column(children: [
        Row(children: [
          if (widget.card.courseName.isNotEmpty)
            BadgePill(
              label: widget.card.courseName,
              background: const Color(0x194BC4A1),
              foreground: const Color(0xFF4BC4A1),
            ),
          const Spacer(),
          Text(
            '答案',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white38 : AppColors.muted,
              fontSize: 12,
            ),
          ),
        ]),
        const Divider(height: 32),
        const Icon(Icons.lightbulb_rounded, color: Color(0xFF4BC4A1), size: 36),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                widget.card.answer,
                style: TextStyle(
                  color: widget.titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.card.hint.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7394F9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '💡 ${widget.card.hint}',
                    style: TextStyle(color: widget.bodyColor, fontSize: 13),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]);
}
