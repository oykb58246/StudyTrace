import 'dart:ui';

import 'package:flutter/material.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_flash_card.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class FlashCardPage extends StatefulWidget {
  const FlashCardPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.autoGenerate = true,
    this.startReviewOnOpen = false,
    this.initialReviewCardIds = const [],
    this.debugAutoOpenNewGroupDialog = false,
    this.debugAutoOpenGradeResultDialog = false,
    this.onOpenNotes,
    this.showAppBar = true,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final bool autoGenerate;
  final bool startReviewOnOpen;
  final List<String> initialReviewCardIds;
  final bool debugAutoOpenNewGroupDialog;
  final bool debugAutoOpenGradeResultDialog;
  final VoidCallback? onOpenNotes;
  final bool showAppBar;

  @override
  State<FlashCardPage> createState() => _FlashCardPageState();
}

class _FlashCardPageState extends State<FlashCardPage> {
  String? _filterGroup;
  bool _showStarredOnly = false;
  bool _showBrowse = false;
  int _browseIndex = 0;
  List<String> _browseCardIds = const [];
  bool _didOpenDebugDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.autoGenerate) {
        await _autoGenerateIfNeeded();
      }
      if (mounted && widget.startReviewOnOpen) {
        _startReviewSession(preferredIds: widget.initialReviewCardIds);
      }
      if (mounted) {
        await _scheduleDebugDialog();
      }
    });
  }

  Future<void> _scheduleDebugDialog() async {
    if (_didOpenDebugDialog ||
        (!widget.debugAutoOpenNewGroupDialog &&
            !widget.debugAutoOpenGradeResultDialog)) {
      return;
    }
    _didOpenDebugDialog = true;
    await Future<void>.delayed(const Duration(milliseconds: 460));
    if (!mounted) return;
    if (widget.debugAutoOpenGradeResultDialog) {
      final reviewCard = _debugFlashCard();
      setState(() {
        _browseCardIds = [reviewCard.id];
        _browseIndex = 0;
        _showBrowse = true;
      });
      return;
    }
    if (widget.debugAutoOpenNewGroupDialog) {
      await _askNewGroupName();
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

    final existingKeys = _flashCardKeys(widget.controller.flashCards);
    final generatedForYesterday = widget.controller.flashCards
        .any((card) => card.id.startsWith('fc_auto_${_dateKey(yesterday)}_'));
    if (generatedForYesterday) return;

    try {
      final cards = await widget.controller.aiStudyService
          .generateFlashCards(logs: yLogs, count: 5);
      final now = DateTime.now();
      final newCards = cards
          .where((card) => !existingKeys.contains(_flashCardKey(card)))
          .toList()
          .asMap()
          .entries
          .map(
            (e) => AiFlashCard(
              id: 'fc_auto_${_dateKey(yesterday)}_${now.microsecondsSinceEpoch}_${e.key}',
              question: e.value.question,
              answer: e.value.answer,
              courseName: e.value.courseName,
              hint: e.value.hint,
              createdAt: yesterday,
            ),
          )
          .toList();
      if (newCards.isEmpty) return;
      if (mounted) await widget.controller.addFlashCards(newCards);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.controller.load,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          const accent = StudyUi.primary;
          final all = _cardsForUiReview(widget.controller.flashCards);
          final list = _filteredCards(all);
          final browseList = _browseCardsFrom(list);
          final textColor = StudyUi.title(widget.isDarkMode);
          final bodyColor = StudyUi.body(widget.isDarkMode);

          return Scaffold(
            backgroundColor: StudyUi.background(widget.isDarkMode),
            appBar: widget.showAppBar
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    foregroundColor: textColor,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const StudyGlassIconNode(
                          icon: Icons.style_rounded,
                          size: 30,
                          iconSize: 15,
                          accent: accent,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _showBrowse ? '闪卡浏览' : '知识闪卡',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: AppTypography.title),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      if (widget.onOpenNotes != null)
                        _FlashCardIconButton(
                          icon: Icons.edit_note_rounded,
                          accent: StudyUi.pathMint,
                          isDarkMode: widget.isDarkMode,
                          tooltip: '学习笔记',
                          onPressed: widget.onOpenNotes,
                        ),
                      if (!_showBrowse)
                        _FlashCardIconButton(
                          icon: Icons.school_rounded,
                          accent: StudyUi.pathViolet,
                          isDarkMode: widget.isDarkMode,
                          tooltip: '今日复习',
                          onPressed: _startReviewSession,
                        ),
                      if (!_showBrowse)
                        _FlashCardIconButton(
                          icon: Icons.refresh_rounded,
                          accent: StudyUi.pathCyan,
                          isDarkMode: widget.isDarkMode,
                          tooltip: '刷新今日闪卡',
                          onPressed: _refreshTodayCards,
                        ),
                      if (all.isNotEmpty && !_showBrowse) _filterMenu(),
                    ],
                  )
                : null,
            body: StudyScreenBackground(
              isDarkMode: widget.isDarkMode,
              accent: accent,
              showPath: !_showBrowse,
              child: _showBrowse && browseList.isNotEmpty
                  ? _browseView(browseList, textColor, bodyColor)
                  : _listView(list, textColor, bodyColor),
            ),
            floatingActionButton: _showBrowse
                ? _FlashCardActionButton(
                    icon: Icons.view_agenda_rounded,
                    label: '列表',
                    accent: accent,
                    isDarkMode: widget.isDarkMode,
                    filled: true,
                    onPressed: () => setState(() => _showBrowse = false),
                  )
                : null,
            bottomNavigationBar: const SizedBox(height: 80),
          );
        },
      ),
    );
  }

  List<AiFlashCard> _cardsForUiReview(List<AiFlashCard> all) {
    if (!widget.debugAutoOpenNewGroupDialog &&
        !widget.debugAutoOpenGradeResultDialog) {
      return all;
    }
    final reviewCard = _debugFlashCard();
    if (all.any((card) => card.id == reviewCard.id)) return all;
    return [reviewCard, ...all];
  }

  AiFlashCard _debugFlashCard() {
    final now = DateTime.now();
    return AiFlashCard(
      id: 'ui_review_flashcard_dialog',
      question: '洛必达法则使用前要先检查什么？',
      answer: '先确认极限属于 0/0 或无穷/无穷型，再检查函数在邻域内可导，最后再考虑求导后的极限是否存在。',
      courseName: '高等数学',
      hint: '从极限类型、可导条件和求导后极限三个角度回答。',
      groupName: '高数错题复盘',
      createdAt: DateTime(now.year, now.month, now.day, 9),
      isStarred: true,
      reviewCount: 1,
      lastReviewScore: 4,
      lastReviewedAt: now.subtract(const Duration(days: 1)),
      nextReviewDate: now.add(const Duration(days: 2)),
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

  Widget _filterMenu() {
    final groups = widget.controller.flashCardGroups;
    return StudyPopupMenuButton<String>(
      icon: const Icon(Icons.filter_list_rounded, color: StudyUi.pathBlue),
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
        ...groups.map(
          (g) => PopupMenuItem(
            value: g,
            child: Text(
              g,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _flashCardHero(List<AiFlashCard> list) {
    final dueCount = list.where((card) => card.isDueForReview).length;
    final reviewedCount = list.where((card) => card.reviewCount > 0).length;
    final masteredCount =
        list.where((card) => card.masteryPercent >= 80).length;
    final newCount = list.where((card) => card.reviewCount == 0).length;
    final accent = widget.controller.primaryColor;
    final reviewTarget = dueCount > 0
        ? dueCount
        : newCount > 0
            ? newCount
            : list.length;
    final focusTitle = dueCount > 0
        ? '今天先复习 $dueCount 张'
        : newCount > 0
            ? '先看 $newCount 张新卡'
            : '今天轻松回看一组';
    final focusSubtitle = list.isEmpty
        ? '记录学习后，可以整理成闪卡。'
        : '共 ${list.length} 张 · 已复习 $reviewedCount 张 · 掌握 $masteredCount 张';
    return StudyPathHero(
      isDarkMode: widget.isDarkMode,
      accent: accent,
      badge: '知识闪卡',
      title: '先复习今天这组',
      subtitle: '先把今天需要再看的卡片过一遍，其他卡片放到列表里慢慢整理。',
      icon: Icons.style_rounded,
      steps: const ['复习', '回想', '掌握'],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StudyUi.surfaceAlt(widget.isDarkMode).withValues(
                alpha: widget.isDarkMode ? 0.72 : 0.86,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: StudyUi.border(widget.isDarkMode)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    StudyGlassIconNode(
                      icon: Icons.school_rounded,
                      accent:
                          dueCount > 0 ? StudyUi.pathViolet : StudyUi.pathBlue,
                      size: 52,
                      isDarkMode: widget.isDarkMode,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            focusTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: StudyUi.title(widget.isDarkMode),
                              fontSize: 17,
                              fontWeight: AppTypography.hero,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            focusSubtitle,
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
                    const SizedBox(width: 10),
                    BadgePill(
                      label: '$reviewTarget 张',
                      background: StudyUi.chipBackground(
                        accent,
                        widget.isDarkMode,
                      ),
                      foreground: accent,
                    ),
                  ],
                ),
                if (dueCount == 0 && list.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '今天没有必须复习的卡片，可以选一组熟悉一下。',
                    style: TextStyle(
                      color: StudyUi.muted(widget.isDarkMode),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FlashCardActionButton(
                  icon: Icons.school_rounded,
                  label: '复习',
                  accent: accent,
                  isDarkMode: widget.isDarkMode,
                  filled: true,
                  expand: true,
                  onPressed: _startReviewSession,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FlashCardActionButton(
                  icon: Icons.auto_awesome_rounded,
                  label: '整理',
                  accent: StudyUi.pathCyan,
                  isDarkMode: widget.isDarkMode,
                  expand: true,
                  onPressed: _refreshTodayCards,
                ),
              ),
              if (widget.onOpenNotes != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _FlashCardActionButton(
                    icon: Icons.edit_note_rounded,
                    label: '笔记',
                    accent: StudyUi.pathMint,
                    isDarkMode: widget.isDarkMode,
                    expand: true,
                    onPressed: widget.onOpenNotes,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _listView(List<AiFlashCard> list, Color textColor, Color bodyColor) {
    if (list.isEmpty) {
      return ListView(
        key: const Key('page_flash_cards'),
        padding: EdgeInsets.fromLTRB(22, widget.showAppBar ? 8 : 16, 22, 100),
        children: [
          _flashCardHero(list),
          const SizedBox(height: 18),
          const StudyEmptyState.flashcards(
            title: '还没有知识闪卡',
            message: '记录学习日志后，可以整理成问答卡片，集中复习关键知识点。',
          ),
        ],
      );
    }

    final grouped = _groupCardsByDate(list);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      key: const Key('page_flash_cards'),
      padding: EdgeInsets.fromLTRB(22, widget.showAppBar ? 8 : 16, 22, 100),
      itemCount: dates.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                _flashCardHero(list),
                if (!widget.showAppBar) ...[
                  const SizedBox(height: 12),
                  _inlineToolbar(list),
                ],
              ],
            ),
          );
        }
        final date = dates[index - 1];
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
                  fontWeight: AppTypography.title,
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

  Widget _inlineToolbar(List<AiFlashCard> allCards) {
    if (allCards.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _filterMenu(),
      ],
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
    const cardWidth = 220.0;
    const overlap = 24.0;
    return SizedBox(
      key: Key('flash_card_shelf_${date}_$shelfIndex'),
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(right: 48),
        itemCount: cards.length,
        itemBuilder: (_, index) {
          final isLast = index == cards.length - 1;
          return SizedBox(
            width: isLast ? cardWidth : cardWidth - overlap,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: cardWidth,
              maxWidth: cardWidth,
              child: _miniCard(
                card: cards[index],
                scopeCards: cards,
                scopeIndex: index,
                stackIndex: index,
                textColor: textColor,
                bodyColor: bodyColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniCard({
    required AiFlashCard card,
    required List<AiFlashCard> scopeCards,
    required int scopeIndex,
    required int stackIndex,
    required Color textColor,
    required Color bodyColor,
  }) {
    const accent = StudyUi.primary;
    final isOdd = stackIndex.isOdd;
    final cardColor = isOdd
        ? StudyUi.surfaceAlt(widget.isDarkMode)
        : StudyUi.surface(widget.isDarkMode);
    final shadowColor = widget.isDarkMode
        ? Colors.black.withValues(alpha: 0.30)
        : accent.withValues(alpha: 0.14);
    final verticalOffset = stackIndex.isEven ? 0.0 : 7.0;
    final scale = stackIndex.isEven ? 1.0 : 0.985;

    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Transform.scale(
        scale: scale,
        child: Container(
          key: Key('flash_card_mini_${card.id}'),
          width: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(-8, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openBrowse(scopeCards, scopeIndex),
              child: StudyCard(
                color: cardColor,
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
                            if (card.reviewCount > 0)
                              _miniTag(
                                '${card.masteryLabel} ${card.masteryPercent}%',
                                card.masteryPercent >= 80
                                    ? const Color(0xFF4BC4A1)
                                    : const Color(0xFFF8AA5B),
                              ),
                            if (card.isDueForReview)
                              _miniTag('今日复习', const Color(0xFFEF6850)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 124),
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
      ),
    );
  }

  Widget _starButton(AiFlashCard card, Color bodyColor) {
    return _FlashCardIconButton(
      key: Key('flash_card_star_${card.id}'),
      tooltip: card.isStarred ? '取消收藏' : '收藏',
      icon: card.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
      accent: card.isStarred ? const Color(0xFFF8AA5B) : bodyColor,
      isDarkMode: widget.isDarkMode,
      size: 36,
      onPressed: () => widget.controller
          .updateFlashCard(card.id, isStarred: !card.isStarred),
    );
  }

  Widget _groupButton(AiFlashCard card, Color bodyColor) {
    final groups = widget.controller.flashCardGroups;
    return StudyPopupMenuButton<String>(
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
        useRootNavigator: true,
        builder: (ctx) => _FlashCardDialogSurface(
          isDarkMode: widget.isDarkMode,
          icon: Icons.create_new_folder_rounded,
          accent: accent,
          title: '添加到新的分组',
          subtitle: '把这张闪卡放进一条更清晰的复习路径。',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('flash_card_new_group_field'),
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
                decoration: _flashCardInputDecoration(
                  isDarkMode: widget.isDarkMode,
                  hintText: '分组名称',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FlashCardActionButton(
                      icon: Icons.close_rounded,
                      label: '取消',
                      accent: StudyUi.muted(widget.isDarkMode),
                      isDarkMode: widget.isDarkMode,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FlashCardActionButton(
                      key: const Key('flash_card_create_group_button'),
                      icon: Icons.check_rounded,
                      label: '创建',
                      accent: accent,
                      isDarkMode: widget.isDarkMode,
                      filled: true,
                      expand: true,
                      onPressed: () {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.of(ctx).pop(name);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  void _startReviewSession({List<String> preferredIds = const []}) {
    final all = _cardsForUiReview(widget.controller.flashCards);
    final preferred = <AiFlashCard>[];
    if (preferredIds.isNotEmpty) {
      final byId = {for (final card in all) card.id: card};
      for (final id in preferredIds) {
        final card = byId[id];
        if (card != null) preferred.add(card);
      }
    }
    if (preferred.isNotEmpty) {
      setState(() {
        _browseCardIds =
            preferred.map((card) => card.id).toList(growable: false);
        _browseIndex = 0;
        _showBrowse = true;
      });
      StudyToast.show(context, '开始复习 ${preferred.length} 张闪卡');
      return;
    }
    // 筛选到期复习的卡片：从未复习 + 已到期 + 收藏
    final reviewCards =
        all.where((c) => c.isDueForReview || c.isStarred).toList();
    if (reviewCards.isEmpty) {
      StudyToast.show(context, '暂无需要复习的闪卡，继续保持！');
      return;
    }
    // 按 nextReviewDate 排序（null 排最前）
    reviewCards.sort((a, b) {
      final aDate = a.nextReviewDate ?? DateTime(2000);
      final bDate = b.nextReviewDate ?? DateTime(2000);
      return aDate.compareTo(bDate);
    });
    final ids = reviewCards.take(20).map((c) => c.id).toList();
    setState(() {
      _browseCardIds = ids;
      _browseIndex = 0;
      _showBrowse = true;
    });
    StudyToast.show(context, '今日复习 ${ids.length} 张闪卡');
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
      StudyToast.show(context, '今天还没有学习记录，请先记录学习内容');
      return;
    }

    try {
      StudyToast.show(context, '正在整理闪卡...');

      final cards = await widget.controller.aiStudyService
          .generateFlashCards(logs: todayLogs, count: 8);

      final existingKeys = _flashCardKeys(widget.controller.flashCards);
      final now = DateTime.now();
      final newCards = cards
          .where((card) => !existingKeys.contains(_flashCardKey(card)))
          .toList()
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

      if (newCards.isEmpty) {
        if (mounted) {
          StudyToast.show(context, '今日闪卡已存在，没有新增重复卡片');
        }
        return;
      }

      if (mounted) {
        await widget.controller.addFlashCards(newCards);
        if (mounted) {
          StudyToast.show(context, '已整理 ${newCards.length} 张闪卡');
        }
      }
    } catch (_) {
      if (mounted) {
        await StudyToast.dialog(
          context,
          title: '这次没能整理闪卡',
          message: '这次没有整理成功，请稍后重试。',
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

  Set<String> _flashCardKeys(Iterable<AiFlashCard> cards) {
    return cards.map(_flashCardKey).toSet();
  }

  String _flashCardKey(AiFlashCard card) {
    return '${card.courseName.trim().toLowerCase()}|'
        '${card.question.trim().toLowerCase()}|'
        '${card.answer.trim().toLowerCase()}';
  }

  String _dateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _browseView(List<AiFlashCard> list, Color textColor, Color bodyColor) {
    final accent = widget.controller.primaryColor;
    if (_browseIndex >= list.length) _browseIndex = 0;
    final card = list[_browseIndex];
    void showPrevious() {
      if (_browseIndex > 0) setState(() => _browseIndex--);
    }

    void showNext() {
      if (_browseIndex < list.length - 1) setState(() => _browseIndex++);
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: StudyCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            StudyGlassIconNode(
              icon: Icons.style_rounded,
              size: 34,
              iconSize: 16,
              accent: accent,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 ${_browseIndex + 1}/${list.length} 张',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '翻转后作答，安排下次复习',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bodyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            _starButton(card, bodyColor),
            _groupButton(card, bodyColor),
            if (widget.onOpenNotes != null)
              _FlashCardIconButton(
                icon: Icons.edit_note_rounded,
                accent: StudyUi.pathMint,
                isDarkMode: widget.isDarkMode,
                tooltip: '学习笔记',
                onPressed: widget.onOpenNotes,
              ),
          ]),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -220) {
                showNext();
              } else if (velocity > 220) {
                showPrevious();
              }
            },
            child: _FlashCardView(
              key: ValueKey(card.id),
              isDarkMode: widget.isDarkMode,
              controller: widget.controller,
              card: card,
              titleColor: textColor,
              bodyColor: bodyColor,
              accentColor: accent,
              autoOpenGradeResultOnOpen:
                  widget.debugAutoOpenGradeResultDialog &&
                      card.id == 'ui_review_flashcard_dialog',
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _FlashCardIconButton(
            icon: Icons.chevron_left_rounded,
            accent: accent,
            isDarkMode: widget.isDarkMode,
            onPressed: _browseIndex > 0 ? showPrevious : null,
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              '点击卡片翻转',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: bodyColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 18),
          _FlashCardIconButton(
            icon: Icons.chevron_right_rounded,
            accent: accent,
            isDarkMode: widget.isDarkMode,
            onPressed: _browseIndex < list.length - 1 ? showNext : null,
          ),
        ]),
      ),
    ]);
  }
}

class _FlashCardActionButton extends StatelessWidget {
  const _FlashCardActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = false,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? Colors.white : accent;
    final background =
        filled ? accent : StudyUi.chipBackground(accent, isDarkMode);
    final disabledForeground =
        StudyUi.muted(isDarkMode).withValues(alpha: 0.62);
    final child = Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: expand ? 10 : 16,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: enabled
            ? background
            : StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: filled ? 0.18 : 0.28)
              : StudyUi.border(isDarkMode),
        ),
        boxShadow: [
          if (enabled && filled && !isDarkMode)
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: expand ? 15 : 16,
            color: enabled ? foreground : disabledForeground,
          ),
          SizedBox(width: expand ? 5 : 7),
          if (expand)
            Flexible(
                child: _buttonLabel(enabled, foreground, disabledForeground))
          else
            _buttonLabel(enabled, foreground, disabledForeground),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: child,
      ),
    );
  }

  Widget _buttonLabel(
      bool enabled, Color foreground, Color disabledForeground) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: enabled ? foreground : disabledForeground,
        fontSize: expand ? 12 : 13,
        fontWeight: AppTypography.title,
      ),
    );
  }
}

class _FlashCardIconButton extends StatelessWidget {
  const _FlashCardIconButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.46,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StudyUi.chipBackground(accent, isDarkMode),
              border: Border.all(
                color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.24),
              ),
              boxShadow: [
                if (enabled && !isDarkMode)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.13),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Icon(icon, color: accent, size: size * 0.52),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _FlashCardDialogSurface extends StatelessWidget {
  const _FlashCardDialogSurface({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width =
        (MediaQuery.sizeOf(context).width - 40).clamp(280.0, 390.0).toDouble();
    return SizedBox.expand(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: StudyFontScope(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDarkMode
                              ? const [
                                  Color(0xEE17222C),
                                  Color(0xEE1D2A35),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.94),
                                  const Color(0xFFF5F8FF)
                                      .withValues(alpha: 0.90),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isDarkMode ? 0.12 : 0.84),
                        ),
                        boxShadow: [
                          if (!isDarkMode)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.15),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
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
                                isDarkMode: isDarkMode,
                                size: 46,
                                iconSize: 21,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: StudyUi.title(isDarkMode),
                                        fontSize: 21,
                                        fontWeight: AppTypography.hero,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
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
                          const SizedBox(height: 18),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashCardSheetSurface extends StatelessWidget {
  const _FlashCardSheetSurface({
    required this.isDarkMode,
    required this.child,
  });

  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? const [
                      Color(0xF017222C),
                      Color(0xF01D2A35),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.95),
                      const Color(0xFFF3FAFF).withValues(alpha: 0.92),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.86),
              ),
            ),
          ),
          child: StudyFontScope(child: child),
        ),
      ),
    );
  }
}

InputDecoration _flashCardInputDecoration({
  required bool isDarkMode,
  required String hintText,
  EdgeInsetsGeometry contentPadding =
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: StudyUi.muted(isDarkMode),
      fontSize: 13,
    ),
    filled: true,
    fillColor: StudyUi.surfaceAlt(isDarkMode).withValues(alpha: 0.86),
    contentPadding: contentPadding,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: StudyUi.border(isDarkMode)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: StudyUi.primary, width: 1.3),
    ),
  );
}

class _FlashCardView extends StatefulWidget {
  const _FlashCardView({
    super.key,
    required this.isDarkMode,
    required this.controller,
    required this.card,
    required this.titleColor,
    required this.bodyColor,
    required this.accentColor,
    this.autoOpenGradeResultOnOpen = false,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final AiFlashCard card;
  final Color titleColor;
  final Color bodyColor;
  final Color accentColor;
  final bool autoOpenGradeResultOnOpen;

  @override
  State<_FlashCardView> createState() => _FlashCardViewState();
}

class _FlashCardViewState extends State<_FlashCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _isFlipped = false;
  bool _didAutoOpenGradeResult = false;

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
    if (widget.autoOpenGradeResultOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await _openDebugGradeResult();
      });
    }
  }

  Future<void> _openDebugGradeResult() async {
    if (_didAutoOpenGradeResult || !mounted) return;
    _didAutoOpenGradeResult = true;
    final grade = FlashCardGrade(
      score: 4,
      feedback:
          '回答已经抓住了 Widget 不可变和 State 保存变化这两个重点。下次可以补一句：setState 会标记状态所在子树重新构建，而不是直接修改 Widget。',
    );
    final reviewed = widget.card.recordReview(grade.score);
    await _showGradeResultDialog(
      grade,
      'State 用来保存页面变化的数据，Widget 只是配置。调用 setState 后，Flutter 会重新构建这一部分界面。',
      reviewed,
    );
    if (!_isFlipped && mounted) {
      _toggle();
    }
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

  Future<void> _openAnswerSheet() async {
    final inputCtrl = TextEditingController();
    final submitted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FlashCardSheetSurface(
          isDarkMode: widget.isDarkMode,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            widget.isDarkMode ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '输入你的答案',
                    style: TextStyle(
                      color: widget.titleColor,
                      fontSize: 18,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.card.question,
                    style: TextStyle(color: widget.bodyColor, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: inputCtrl,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 6,
                    style: TextStyle(
                        color: widget.titleColor, fontSize: 14, height: 1.5),
                    decoration: _flashCardInputDecoration(
                      isDarkMode: widget.isDarkMode,
                      hintText: '把你知道的写下来，稍后会给出复习反馈',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _FlashCardActionButton(
                          icon: Icons.close_rounded,
                          label: '取消',
                          accent: widget.accentColor,
                          isDarkMode: widget.isDarkMode,
                          expand: true,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FlashCardActionButton(
                          icon: Icons.check_rounded,
                          label: '查看反馈',
                          accent: widget.accentColor,
                          isDarkMode: widget.isDarkMode,
                          filled: true,
                          expand: true,
                          onPressed: () {
                            final t = inputCtrl.text.trim();
                            if (t.isEmpty) {
                              StudyToast.show(ctx, '请先输入你的答案');
                              return;
                            }
                            Navigator.of(ctx).pop(t);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    inputCtrl.dispose();
    if (submitted == null || submitted.isEmpty || !mounted) return;
    await _gradeUserAnswer(submitted);
  }

  Future<void> _gradeUserAnswer(String userAnswer) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StudyCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: widget.accentColor,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '正在整理反馈...',
                  style: TextStyle(
                    color: widget.titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    FlashCardGrade? grade;
    try {
      grade = await widget.controller.aiStudyService.gradeFlashcard(
        question: widget.card.question,
        correctAnswer: widget.card.answer,
        userAnswer: userAnswer,
        courseName: widget.card.courseName,
      );
    } catch (_) {
      grade = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (grade == null) {
      await StudyToast.dialog(
        context,
        title: '反馈生成失败',
        message: '这次没能生成复习反馈，请稍后再试。',
      );
      return;
    }
    final reviewed = await widget.controller
        .recordFlashCardReview(widget.card.id, grade.score);
    await _showGradeResultDialog(grade, userAnswer, reviewed);
    if (!_isFlipped && mounted) {
      _toggle();
    }
  }

  Future<void> _showGradeResultDialog(
    FlashCardGrade grade,
    String userAnswer,
    AiFlashCard? reviewed,
  ) async {
    final color = switch (grade.score) {
      5 => const Color(0xFF4BC4A1),
      4 => const Color(0xFF7394F9),
      3 => const Color(0xFFF8AA5B),
      2 => const Color(0xFFF77D8E),
      _ => const Color(0xFFEF6850),
    };
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _FlashCardDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.check_rounded,
        accent: color,
        title: grade.label,
        subtitle: '复习反馈与下次安排',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.56,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('复习反馈',
                        style: TextStyle(
                            color: widget.bodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(grade.feedback,
                        style: TextStyle(
                            color: widget.titleColor,
                            fontSize: 14,
                            height: 1.5)),
                    const SizedBox(height: 14),
                    Text('你的回答',
                        style: TextStyle(
                            color: widget.bodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(userAnswer,
                        style: TextStyle(
                            color: widget.titleColor,
                            fontSize: 13,
                            height: 1.5)),
                    const SizedBox(height: 14),
                    Text('参考答案',
                        style: TextStyle(
                            color: widget.bodyColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(widget.card.answer,
                        style: TextStyle(
                            color: widget.titleColor,
                            fontSize: 13,
                            height: 1.5)),
                    if (reviewed != null) ...[
                      const SizedBox(height: 14),
                      Text('防遗忘计划',
                          style: TextStyle(
                              color: widget.bodyColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '已复习 ${reviewed.reviewCount} 次，掌握度 ${reviewed.masteryPercent}%，下次复习 ${_formatReviewDate(reviewed.nextReviewDate)}。',
                        style: TextStyle(
                            color: widget.titleColor,
                            fontSize: 13,
                            height: 1.5),
                      ),
                      if (reviewed.weakTags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '薄弱标签：${reviewed.weakTags.join('、')}',
                          style: TextStyle(
                              color: widget.bodyColor,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 118,
                child: _FlashCardActionButton(
                  icon: Icons.check_rounded,
                  label: '好的',
                  accent: color,
                  isDarkMode: widget.isDarkMode,
                  filled: true,
                  expand: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReviewDate(DateTime? value) {
    if (value == null) return '待安排';
    return '${value.month}/${value.day}';
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
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: StudyUi.surface(widget.isDarkMode),
                border: Border.all(color: StudyUi.border(widget.isDarkMode)),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode
                        ? Colors.black.withValues(alpha: 0.26)
                        : widget.accentColor.withValues(alpha: 0.12),
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

  Widget _front() => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 260;
          return Column(children: [
            Row(children: [
              if (widget.card.courseName.isNotEmpty)
                Flexible(
                  child: BadgePill(
                    label: widget.card.courseName,
                    background: widget.accentColor.withValues(alpha: 0.1),
                    foreground: widget.accentColor,
                  ),
                ),
              const SizedBox(width: 8),
              const Spacer(),
              Text(
                '点击翻转',
                style: TextStyle(
                  color: StudyUi.muted(widget.isDarkMode),
                  fontSize: 12,
                ),
              ),
            ]),
            Divider(height: compact ? 18 : 32),
            if (!compact) ...[
              Text(
                _reviewStatusText(widget.card),
                style: TextStyle(
                  color: widget.bodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.card.reviewCount > 0 ||
                  widget.card.weakTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BadgePill(
                      label:
                          '${widget.card.masteryLabel} ${widget.card.masteryPercent}%',
                      background: widget.accentColor.withValues(alpha: 0.1),
                      foreground: widget.accentColor,
                    ),
                    for (final tag in widget.card.weakTags.take(2))
                      BadgePill(
                        label: tag,
                        background:
                            const Color(0xFFEF6850).withValues(alpha: 0.1),
                        foreground: const Color(0xFFEF6850),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              StudyGlassIconNode(
                icon: Icons.help_outline_rounded,
                asset: AppAssets.featureFlashcardIcon,
                accent: widget.accentColor,
                isDarkMode: widget.isDarkMode,
                preserveColor: false,
                size: 52,
                iconSize: 24,
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.card.question,
                  style: TextStyle(
                    color: widget.titleColor,
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Center(
              child: _FlashCardActionButton(
                icon: Icons.edit_rounded,
                label: '我来答',
                accent: widget.accentColor,
                isDarkMode: widget.isDarkMode,
                onPressed: _openAnswerSheet,
              ),
            ),
          ]);
        },
      );

  String _reviewStatusText(AiFlashCard card) {
    if (card.reviewCount == 0) return '还未复习，回答后会安排下次复习时间';
    if (card.nextReviewDate == null) return '已复习 ${card.reviewCount} 次';
    final due = card.isDueForReview
        ? '今天可复习'
        : '下次 ${_formatReviewDate(card.nextReviewDate)}';
    return '已复习 ${card.reviewCount} 次 · $due';
  }

  Widget _back() => Column(children: [
        Row(children: [
          if (widget.card.courseName.isNotEmpty)
            Flexible(
              child: BadgePill(
                label: widget.card.courseName,
                background: const Color(0x194BC4A1),
                foreground: const Color(0xFF4BC4A1),
              ),
            ),
          const SizedBox(width: 8),
          const Spacer(),
          Text(
            '答案',
            style: TextStyle(
              color: StudyUi.muted(widget.isDarkMode),
              fontSize: 12,
            ),
          ),
        ]),
        const Divider(height: 32),
        StudyGlassIconNode(
          icon: Icons.lightbulb_rounded,
          asset: AppAssets.aiSuggestionIcon,
          preserveColor: true,
          accent: StudyUi.pathWarm,
          isDarkMode: widget.isDarkMode,
          size: 52,
          iconSize: 24,
        ),
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
