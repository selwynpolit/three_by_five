import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/help_providers.dart';

// ── Section registry ──────────────────────────────────────────────────────────

class _Section {
  const _Section({
    required this.id,
    required this.label,
    required this.file,
    required this.icon,
  });
  final String id;
  final String label;
  final String file;
  final IconData icon;
}

const _kSections = [
  _Section(
    id: 'getting-started',
    label: 'Getting Started',
    file: 'docs/getting-started.md',
    icon: Icons.rocket_launch_outlined,
  ),
  _Section(
    id: 'cards-and-stacks',
    label: 'Cards & Stacks',
    file: 'docs/cards-and-stacks.md',
    icon: Icons.style_outlined,
  ),
  _Section(
    id: 'tasks',
    label: 'Tasks',
    file: 'docs/tasks.md',
    icon: Icons.checklist_rounded,
  ),
  _Section(
    id: 'views',
    label: 'Views',
    file: 'docs/views.md',
    icon: Icons.view_quilt_outlined,
  ),
  _Section(
    id: 'search-and-filtering',
    label: 'Search & Filtering',
    file: 'docs/search-and-filtering.md',
    icon: Icons.search,
  ),
  _Section(
    id: 'snooze-and-hide',
    label: 'Snooze & Hide',
    file: 'docs/snooze-and-hide.md',
    icon: Icons.bedtime_outlined,
  ),
  _Section(
    id: 'keyboard-shortcuts',
    label: 'Keyboard Shortcuts',
    file: 'docs/keyboard-shortcuts.md',
    icon: Icons.keyboard_outlined,
  ),
  _Section(
    id: 'backup-and-restore',
    label: 'Backup & Restore',
    file: 'docs/backup-and-restore.md',
    icon: Icons.backup_outlined,
  ),
  _Section(
    id: 'export',
    label: 'Export to CSV',
    file: 'docs/export.md',
    icon: Icons.table_chart_outlined,
  ),
  _Section(
    id: 'voice-input',
    label: 'Voice Input',
    file: 'docs/voice-input.md',
    icon: Icons.mic_outlined,
  ),
  _Section(
    id: 'tips-and-workflows',
    label: 'Tips & Workflows',
    file: 'docs/tips-and-workflows.md',
    icon: Icons.lightbulb_outlined,
  ),
];

// ── Quick-reference shortcuts shown at the bottom of the sidebar ──────────────

const _kShortcuts = [
  ('⌘N', 'New card'),
  ('⌘K', 'Search'),
  ('⌘⇧B', 'Backup'),
  ('⌘⇧E', 'Export'),
  ('⌘?', 'Help'),
  ('ESC', 'Close'),
  ('⌘1', 'Cards'),
  ('⌘2', 'Kanban'),
  ('⌘3', 'Calendar'),
  ('⌘4', 'Today'),
];

// ── Public entry-point ────────────────────────────────────────────────────────

/// Full-screen backdrop + centred help modal.
class HelpPanelOverlay extends ConsumerWidget {
  const HelpPanelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(helpPanelVisibleProvider.notifier).state = false,
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          // Tap the dark backdrop → close.
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(helpPanelVisibleProvider.notifier).state = false,
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: GestureDetector(
                // Swallow taps inside the panel so they don't close it.
                onTap: () {},
                child: const _HelpPanel(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Panel shell ───────────────────────────────────────────────────────────────

class _HelpPanel extends ConsumerStatefulWidget {
  const _HelpPanel();

  @override
  ConsumerState<_HelpPanel> createState() => _HelpPanelState();
}

class _HelpPanelState extends ConsumerState<_HelpPanel> {
  final _searchCtrl = TextEditingController();
  final _contentScrollCtrl = ScrollController();
  final _searchFocus = FocusNode();

  String _query = '';
  // sectionId → markdown text
  final Map<String, String> _content = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _contentScrollCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait(
      _kSections.map((s) => rootBundle.loadString(s.file)),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _kSections.length; i++) {
        _content[_kSections[i].id] = results[i];
      }
      _loading = false;
    });
  }

  void _selectSection(String id) {
    ref.read(helpPanelSectionProvider.notifier).state = id;
    _contentScrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// Sections that contain the search query (in their title or content).
  List<_Section> get _filteredSections {
    if (_query.isEmpty) return _kSections;
    return _kSections.where((s) {
      if (s.label.toLowerCase().contains(_query)) return true;
      final body = _content[s.id] ?? '';
      return body.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelW = (size.width * 0.85).clamp(640.0, 940.0);
    final panelH = (size.height * 0.85).clamp(480.0, 700.0);
    final activeSectionId = ref.watch(helpPanelSectionProvider);
    final filtered = _filteredSections;

    // If the active section is no longer in the filtered list, auto-select first.
    final displayId =
        filtered.any((s) => s.id == activeSectionId) && _query.isEmpty
            ? activeSectionId
            : (filtered.isNotEmpty ? filtered.first.id : activeSectionId);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: panelW,
        height: panelH,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(context, filtered, displayId),
                    const VerticalDivider(width: 1, thickness: 0.5),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : _buildContent(context, displayId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      color: AppColors.sidebarBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '3by5 Help',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search help…',
                  hintStyle: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textDisabled),
                  prefixIcon: const Icon(Icons.search,
                      size: 15, color: AppColors.textTertiary),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _searchFocus.unfocus();
                          },
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.textTertiary),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.cardBorder, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.cardBorder, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Close button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => ref
                  .read(helpPanelVisibleProvider.notifier)
                  .state = false,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  Widget _buildSidebar(
    BuildContext context,
    List<_Section> sections,
    String activeId,
  ) {
    return SizedBox(
      width: 200,
      child: Container(
        color: AppColors.sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No results',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textDisabled,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    )
                  else
                    ...sections.map((s) => _SidebarItem(
                          section: s,
                          isActive: s.id == activeId,
                          onTap: () => _selectSection(s.id),
                        )),
                ],
              ),
            ),
            // Keyboard shortcuts card
            const Divider(height: 1, thickness: 0.5),
            _ShortcutsCard(),
          ],
        ),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, String sectionId) {
    final markdown = _content[sectionId] ?? '';
    final query = _query;

    // If searching and sectionId is from filtered list, highlight query.
    final displayMarkdown = query.isNotEmpty && markdown.isNotEmpty
        ? markdown
        : markdown;

    return Scrollbar(
      controller: _contentScrollCtrl,
      child: SingleChildScrollView(
        controller: _contentScrollCtrl,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: MarkdownBody(
          data: displayMarkdown,
          selectable: true,
          styleSheet: _markdownStyle(context),
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return MarkdownStyleSheet(
      h1: base.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ) ??
          const TextStyle(),
      h2: base.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ) ??
          const TextStyle(),
      h3: base.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ) ??
          const TextStyle(),
      p: base.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ) ??
          const TextStyle(),
      strong: base.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ) ??
          const TextStyle(),
      code: base.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: AppColors.accent,
            backgroundColor: AppColors.divider,
          ) ??
          const TextStyle(),
      codeblockDecoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.accent.withValues(alpha: 0.5), width: 3),
        ),
        color: AppColors.accent.withValues(alpha: 0.05),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      blockquote: base.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ) ??
          const TextStyle(),
      listBullet: base.bodyMedium?.copyWith(color: AppColors.textSecondary) ??
          const TextStyle(),
      tableHead: base.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ) ??
          const TextStyle(),
      tableBody: base.bodySmall?.copyWith(color: AppColors.textSecondary) ??
          const TextStyle(),
      tableBorder: TableBorder.all(
        color: AppColors.divider,
        width: 0.5,
      ),
      tableHeadAlign: TextAlign.left,
      h1Padding: const EdgeInsets.only(bottom: 8, top: 4),
      h2Padding: const EdgeInsets.only(bottom: 6, top: 20),
      h3Padding: const EdgeInsets.only(bottom: 4, top: 14),
      pPadding: const EdgeInsets.only(bottom: 10),
    );
  }
}

// ── Sidebar item ──────────────────────────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.section,
    required this.isActive,
    required this.onTap,
  });
  final _Section section;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.sidebarViewSelected
                : _hovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.section.icon,
                size: 14,
                color: widget.isActive
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.section.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.isActive
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Keyboard shortcuts card ───────────────────────────────────────────────────

class _ShortcutsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHORTCUTS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 0,
            runSpacing: 2,
            children: _kShortcuts
                .map((s) => _ShortcutRow(shortcut: s.$1, label: s.$2))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.shortcut, required this.label});
  final String shortcut;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
