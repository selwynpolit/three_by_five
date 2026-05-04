
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';
import '../../domain/enums/app_view.dart';
import '../providers/canvas_providers.dart';
import '../providers/card_providers.dart';
import '../providers/task_providers.dart';
import '../providers/ui_state_providers.dart';

// ── Search overlay ────────────────────────────────────────────────────────────

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  int _selectedIndex = 0;
  int _totalResults = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyHandler);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() =>
      ref.read(searchOverlayVisibleProvider.notifier).hide();

  bool _keyHandler(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_totalResults > 0) {
        setState(
            () => _selectedIndex = (_selectedIndex + 1) % _totalResults);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_totalResults > 0) {
        setState(() => _selectedIndex =
            (_selectedIndex - 1 + _totalResults) % _totalResults);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.enter) {
      _activateIndex(_selectedIndex);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return true;
    }
    return false;
  }

  void _activateIndex(int index) {
    if (_totalResults == 0) return;
    final tasks = _matchedTasks();
    final cards = _matchedCards();
    if (index < tasks.length) {
      _openTask(tasks[index].id);
    } else {
      final cardIndex = index - tasks.length;
      if (cardIndex < cards.length) _openCard(cards[cardIndex].id);
    }
  }

  void _openTask(String id) {
    ref.read(selectedTaskIdProvider.notifier).select(id);
    _close();
  }

  void _openCard(String id) {
    ref.read(activeViewProvider.notifier).set(AppView.cardView);
    ref.read(selectedCardIdsProvider.notifier).selectOnly(id);
    _close();
  }

  // ── Compute results ──────────────────────────────────────────────────────

  List<AppTask> _matchedTasks() {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final tasks =
        ref.read(allVisibleTasksProvider).valueOrNull ?? [];
    final cardMap = <String, AppCard>{
      for (final c
          in ref.read(allCardsIncludingHiddenProvider).valueOrNull ?? [])
        c.id: c,
    };
    return tasks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            (cardMap[t.cardId]?.projectTitle
                    ?.toLowerCase()
                    .contains(q) ??
                false))
        .take(12)
        .toList();
  }

  List<AppCard> _matchedCards() {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final cards =
        ref.read(allCardsIncludingHiddenProvider).valueOrNull ?? [];
    return cards
        .where((c) =>
            (c.projectTitle?.toLowerCase().contains(q) ?? false) ||
            intl.DateFormat('d MMM yyyy')
                .format(c.date)
                .toLowerCase()
                .contains(q))
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _matchedTasks();
    final cards = _matchedCards();
    _totalResults = tasks.length + cards.length;
    if (_selectedIndex >= _totalResults && _totalResults > 0) {
      _selectedIndex = _totalResults - 1;
    }

    return GestureDetector(
      onTap: _close,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: GestureDetector(
            // Prevent taps inside the panel from closing.
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 580,
                constraints:
                    const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchInput(
                      ctrl: _ctrl,
                      focus: _focus,
                      onChanged: (v) => setState(() {
                        _query = v;
                        _selectedIndex = 0;
                      }),
                      onClose: _close,
                    ),
                    if (_query.isNotEmpty) ...[
                      const Divider(height: 1),
                      Flexible(
                        child: _query.isEmpty ||
                                _totalResults == 0
                            ? _NoResults(query: _query)
                            : _ResultsList(
                                tasks: tasks,
                                cards: cards,
                                selectedIndex: _selectedIndex,
                                query: _query,
                                onTaskTap: _openTask,
                                onCardTap: _openCard,
                              ),
                      ),
                    ] else
                      _EmptyPrompt(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search input ──────────────────────────────────────────────────────────────

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.ctrl,
    required this.focus,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.search,
                size: 20, color: AppColors.textTertiary),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: onChanged,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search tasks and cards…',
                hintStyle: TextStyle(
                    fontSize: 15, color: AppColors.textDisabled),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close,
                size: 16, color: AppColors.textTertiary),
            tooltip: 'Close (Esc)',
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.tasks,
    required this.cards,
    required this.selectedIndex,
    required this.query,
    required this.onTaskTap,
    required this.onCardTap,
  });

  final List<AppTask> tasks;
  final List<AppCard> cards;
  final int selectedIndex;
  final String query;
  final void Function(String) onTaskTap;
  final void Function(String) onCardTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      children: [
        if (tasks.isNotEmpty) ...[
          _SectionLabel('Tasks  ·  ${tasks.length}'),
          for (var i = 0; i < tasks.length; i++)
            _TaskResult(
              task: tasks[i],
              selected: selectedIndex == i,
              query: query,
              onTap: () => onTaskTap(tasks[i].id),
            ),
        ],
        if (cards.isNotEmpty) ...[
          _SectionLabel('Cards  ·  ${cards.length}'),
          for (var i = 0; i < cards.length; i++)
            _CardResult(
              card: cards[i],
              selected: selectedIndex == tasks.length + i,
              query: query,
              onTap: () => onCardTap(cards[i].id),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textDisabled,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TaskResult extends StatefulWidget {
  const _TaskResult({
    required this.task,
    required this.selected,
    required this.query,
    required this.onTap,
  });
  final AppTask task;
  final bool selected;
  final String query;
  final VoidCallback onTap;

  @override
  State<_TaskResult> createState() => _TaskResultState();
}

class _TaskResultState extends State<_TaskResult> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: highlighted
              ? AppColors.accentLight
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(
                Icons.check_box_outline_blank_rounded,
                size: 15,
                color: widget.task.isCompleted
                    ? AppColors.textDisabled
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: _highlightSpan(
                    widget.task.title,
                    widget.query,
                    base: TextStyle(
                      fontSize: 13,
                      color: widget.task.isCompleted
                          ? AppColors.textCompleted
                          : AppColors.textPrimary,
                      decoration: widget.task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textCompleted,
                    ),
                  ),
                ),
              ),
              if (widget.task.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    intl.DateFormat('d MMM')
                        .format(widget.task.dueDate!),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary),
                  ),
                ),
              if (widget.selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.keyboard_return,
                      size: 13, color: AppColors.accentMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardResult extends StatefulWidget {
  const _CardResult({
    required this.card,
    required this.selected,
    required this.query,
    required this.onTap,
  });
  final AppCard card;
  final bool selected;
  final String query;
  final VoidCallback onTap;

  @override
  State<_CardResult> createState() => _CardResultState();
}

class _CardResultState extends State<_CardResult> {
  bool _hovered = false;
  static final _dateFmt = intl.DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered;
    final label = widget.card.projectTitle ??
        _dateFmt.format(widget.card.date);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: highlighted
              ? AppColors.accentLight
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.style_outlined,
                  size: 15, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: _highlightSpan(
                    label,
                    widget.query,
                    base: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary),
                  ),
                ),
              ),
              Text(
                _dateFmt.format(widget.card.date),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary),
              ),
              if (widget.selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.keyboard_return,
                      size: 13, color: AppColors.accentMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / no-results ────────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
      child: Row(
        children: const [
          _Hint('↑↓', 'navigate'),
          SizedBox(width: 16),
          _Hint('↵', 'open'),
          SizedBox(width: 16),
          _Hint('Esc', 'close'),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.key_, this.label);
  final String key_;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(key_,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No results for "$query"',
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDisabled,
              fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

// ── Text highlight helper ─────────────────────────────────────────────────────

TextSpan _highlightSpan(String text, String query,
    {required TextStyle base}) {
  if (query.isEmpty) return TextSpan(text: text, style: base);
  final lower = text.toLowerCase();
  final q = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final idx = lower.indexOf(q, start);
    if (idx == -1) {
      spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx), style: base));
    }
    spans.add(TextSpan(
      text: text.substring(idx, idx + query.length),
      style: base.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          decoration: TextDecoration.none),
    ));
    start = idx + query.length;
  }
  return TextSpan(children: spans);
}

