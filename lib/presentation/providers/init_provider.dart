import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/daos/stacks_dao.dart';
import '../../data/database/app_database.dart';
import 'canvas_providers.dart';
import 'database_provider.dart';
import 'stack_providers.dart';

part 'init_provider.g.dart';

/// Ensures the database has at least one stack (provisions demo data on first
/// launch) then restores the last-used view state.  Returns the stack ID to
/// use as the initial active stack (non-null once the database is ready).
@Riverpod(keepAlive: true)
Future<String?> appInit(AppInitRef ref) async {
  final db = ref.watch(appDatabaseProvider);
  final stacksDao = StacksDao(db);
  final settingsDao = SettingsDao(db);

  final existing = await stacksDao.watchAll().first;
  if (existing.isEmpty) {
    await _provisionDefaults(db);
    return AppConstants.kDefaultStackId;
  }

  // Restore previously active stack (falls back to first stack).
  final saved = await settingsDao.get(AppConstants.kActiveStackId);
  final stackId = (saved != null && existing.any((s) => s.id == saved))
      ? saved
      : existing.first.id;

  // Read hidden-stacks setting before leaving async context.
  final hiddenJson = await settingsDao.get('hiddenStackIds');

  // Apply both state values via microtask — avoids mutating providers
  // during a widget build phase (which Riverpod forbids).
  Future.microtask(() {
    ref.read(activeStackIdProvider.notifier).set(stackId);

    if (hiddenJson != null && hiddenJson.isNotEmpty) {
      try {
        final ids = (jsonDecode(hiddenJson) as List).cast<String>();
        if (ids.isNotEmpty) {
          ref.read(hiddenStackIdsProvider.notifier).hideAll(ids);
        }
      } catch (_) {}
    }
  });

  return stackId;
}

Future<void> _provisionDefaults(AppDatabase db) async {
  final now = DateTime.now();
  final stackColor = AppColors.stackPalette.first.toARGB32();

  await db.into(db.stacks).insert(StacksCompanion.insert(
    id: AppConstants.kDefaultStackId,
    name: 'Personal',
    color: stackColor,
    sortOrder: const Value(0),
    createdAt: now,
  ));

  await db.into(db.cards).insert(CardsCompanion.insert(
    id: AppConstants.kDefaultCardId,
    stackId: AppConstants.kDefaultStackId,
    date: now,
    projectTitle: const Value('Getting Started'),
    createdAt: now,
    updatedAt: now,
  ));

  final nowTasks = [
    'Welcome to 3by5 👋',
    'Press ⌘N to add a card',
    'Drag tasks between Now and Later',
  ];
  for (var i = 0; i < nowTasks.length; i++) {
    await db.into(db.tasks).insert(TasksCompanion.insert(
      id: 'task_demo_now_$i',
      cardId: AppConstants.kDefaultCardId,
      title: nowTasks[i],
      columnName: const Value('now'),
      sortOrder: Value(i),
      createdAt: now,
      updatedAt: now,
    ));
  }

  final laterTasks = [
    'Explore the Kanban view (⌘2)',
    'Try setting a due date on a task',
    'Right-click a card to see more options',
  ];
  for (var i = 0; i < laterTasks.length; i++) {
    await db.into(db.tasks).insert(TasksCompanion.insert(
      id: 'task_demo_later_$i',
      cardId: AppConstants.kDefaultCardId,
      title: laterTasks[i],
      columnName: const Value('later'),
      sortOrder: Value(i),
      createdAt: now,
      updatedAt: now,
    ));
  }
}
