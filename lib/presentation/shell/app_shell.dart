import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/daos/settings_dao.dart';
import '../../domain/enums/app_view.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStackId != null) {
        ref
            .read(activeStackIdProvider.notifier)
            .set(widget.initialStackId);
      }
    });
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

    final activeView = ref.watch(activeViewProvider);
    final activeStackId = ref.watch(activeStackIdProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    return Row(
      children: [
        const Sidebar(),
        Expanded(
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

              // ── Backdrop ─────────────────────────────────────────
              AnimatedOpacity(
                opacity: selectedTaskId != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: selectedTaskId == null,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(selectedTaskIdProvider.notifier)
                        .select(null),
                    child: const ColoredBox(
                        color: Color(0x22000000),
                        child: SizedBox.expand()),
                  ),
                ),
              ),

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
      ],
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
