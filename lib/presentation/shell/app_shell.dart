import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/daos/settings_dao.dart';
import '../../domain/enums/app_view.dart';
import '../providers/canvas_providers.dart';
import '../providers/card_providers.dart';
import '../providers/database_provider.dart';
import '../providers/init_provider.dart';
import '../providers/stack_providers.dart';
import '../providers/ui_state_providers.dart';
import '../views/archive_view/archive_view.dart';
import '../views/calendar_view/calendar_view.dart';
import '../views/card_view/card_view.dart';
import '../views/kanban_view/kanban_view.dart';
import '../views/task_detail/task_detail_panel.dart';
import '../views/today_view/today_view.dart';
import '../widgets/search_overlay.dart';
import '../widgets/undo_toast.dart';
import 'sidebar.dart';

const _kPanelWidth = 440.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);

    return init.when(
      loading: () => const _SplashScreen(),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Failed to load: $e')),
      ),
      data: (initialStackId) =>
          _ShellReady(initialStackId: initialStackId),
    );
  }
}

// ── Shell ready ────────────────────────────────────────────────────────────────

class _ShellReady extends ConsumerStatefulWidget {
  const _ShellReady({required this.initialStackId});
  final String? initialStackId;

  @override
  ConsumerState<_ShellReady> createState() => _ShellReadyState();
}

class _ShellReadyState extends ConsumerState<_ShellReady> {
  Timer? _resurfaceTimer;

  @override
  void initState() {
    super.initState();
    // Active stack and hidden stacks are restored by appInitProvider via
    // Future.microtask — no widget lifecycle callback needed here.
    _resurfaceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) ref.invalidate(cardsProvider);
    });
    // Global ESC handler — fires before any widget's onKeyEvent so it
    // works even when a Quill editor or nested CallbackShortcuts would
    // otherwise consume the key.
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
  }

  @override
  void dispose() {
    _resurfaceTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    super.dispose();
  }

  bool _globalKeyHandler(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      // Search overlay has its own handler (added later, fires first).
      // Here we only handle closing the task detail panel.
      if (mounted && ref.read(selectedTaskIdProvider) != null) {
        ref.read(selectedTaskIdProvider.notifier).select(null);
        return true;
      }
    }
    return false;
  }

  Future<void> _createCard() async {
    final stackId = ref.read(effectiveCreateStackProvider);
    if (stackId == null) return;
    await ref
        .read(cardRepositoryProvider)
        .create(stackId: stackId, date: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeStackIdProvider, (_, next) {
      final dao = SettingsDao(ref.read(appDatabaseProvider));
      if (next != null) {
        dao.set(AppConstants.kActiveStackId, next);
      } else {
        dao.remove(AppConstants.kActiveStackId);
      }
    });

    ref.listen(hiddenStackIdsProvider, (_, next) {
      final dao = SettingsDao(ref.read(appDatabaseProvider));
      if (next.isEmpty) {
        dao.remove('hiddenStackIds');
      } else {
        dao.set('hiddenStackIds', jsonEncode(next.toList()));
      }
    });

    // Persist card layout so it survives app restarts.
    ref.listen(lastCardLayoutModeProvider, (_, next) {
      final dao = SettingsDao(ref.read(appDatabaseProvider));
      dao.set('cardLayoutMode', next.index.toString());
    });

    // When navigating back to card view, restore the last card layout
    // (so task-list mode doesn't persist across sidebar navigation).
    ref.listen(activeViewProvider, (prev, next) {
      const cardViews = {AppView.cardView, AppView.allCardsView};
      if (cardViews.contains(next) && !cardViews.contains(prev)) {
        ref.read(cardLayoutModeProvider.notifier).state =
            ref.read(lastCardLayoutModeProvider);
      }
    });

    final activeView = ref.watch(activeViewProvider);
    final activeStackId = ref.watch(activeStackIdProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final searchVisible = ref.watch(searchOverlayVisibleProvider);

    void switchView(AppView view) =>
        ref.read(activeViewProvider.notifier).set(view);
    void toggleSearch() =>
        ref.read(searchOverlayVisibleProvider.notifier).toggle();

    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              _createCard,
          // ⌘K — global search
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              toggleSearch,
          // ⌘1–5 — switch views
          const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
              () => switchView(AppView.cardView),
          const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
              () => switchView(AppView.kanbanView),
          const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
              () => switchView(AppView.calendarView),
          const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
              () => switchView(AppView.todayView),
          const SingleActivator(LogicalKeyboardKey.digit5, meta: true):
              () => switchView(AppView.archiveView),
          // ESC is handled exclusively by HardwareKeyboard.addHandler in
          // app_shell + task_detail_panel — removing it from CallbackShortcuts
          // prevents it from bypassing the panel's save-dialog interception.
        },
        child: Focus(
          autofocus: true,
          child: Row(
      children: [
        const Sidebar(),
        Expanded(
          child: ColoredBox(
            color: AppColors.appBackground,
            child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Main view ────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: CurvedAnimation(
                      parent: anim, curve: Curves.easeOut),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('$activeView|$activeStackId'),
                  child: _viewFor(activeView),
                ),
              ),

              // ── Backdrop — visual depth cue only. ────────────────
              // IgnorePointer so card interactions remain available
              // while the panel is open. Close via ESC or the ✕ button.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: selectedTaskId != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const ColoredBox(
                      color: Color(0x18000000),
                      child: SizedBox.expand()),
                ),
              ),

              // ── Undo toast (above backdrop so it stays tappable) ─
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: UndoToast(),
                ),
              ),

              // ── Global search overlay ────────────────────────────
              if (searchVisible) const SearchOverlay(),

              // ── Detail panel (slides from right) ─────────────────
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: _kPanelWidth,
                child: AnimatedSlide(
                  offset: selectedTaskId != null
                      ? Offset.zero
                      : const Offset(1.0, 0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: selectedTaskId != null
                      ? TaskDetailPanel(
                          key: ValueKey(selectedTaskId),
                          taskId: selectedTaskId,
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ],
            ),
          ),
        ),
      ],
          ),
        ),
      ),
    );
  }

  Widget _viewFor(AppView view) => switch (view) {
        AppView.cardView || AppView.allCardsView => const CardView(),
        AppView.kanbanView => const KanbanView(),
        AppView.calendarView => const CalendarView(),
        AppView.todayView => const TodayView(),
        AppView.archiveView => const ArchiveView(),
      };
}

// ── Splash ────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Text(
          '3by5',
          style: GoogleFonts.caveat(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
