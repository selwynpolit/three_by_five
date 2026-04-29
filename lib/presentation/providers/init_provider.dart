import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/daos/stacks_dao.dart';
import '../../data/database/app_database.dart';
import 'database_provider.dart';

part 'init_provider.g.dart';

/// Ensures the database has at least one stack (provisions demo data on first
/// launch). Returns the stack ID that should be set as the initial active stack,
/// or null to show All Cards.
@Riverpod(keepAlive: true)
Future<String?> appInit(AppInitRef ref) async {
  final db = ref.watch(appDatabaseProvider);
  final stacksDao = StacksDao(db);
  final settingsDao = SettingsDao(db);

  final existing = await stacksDao.watchAll().first;
  if (existing.isEmpty) {
    await _provisionDefaults(db);
  }

  // Restore previously active stack (if it still exists).
  final saved = await settingsDao.get(AppConstants.kActiveStackId);
  if (saved != null) {
    final all = await stacksDao.watchAll().first;
    if (all.any((s) => s.id == saved)) return saved;
  }
  return null; // Default: All Cards
}

Future<void> _provisionDefaults(AppDatabase db) async {
  final now = DateTime.now();
  final stackColor = AppColors.stackPalette.first.toARGB32();

  // Default stack
  await db.into(db.stacks).insert(StacksCompanion.insert(
    id: AppConstants.kDefaultStackId,
    name: 'Personal',
    color: stackColor,
    sortOrder: const Value(0),
    createdAt: now,
  ));

  // Welcome card (today)
  await db.into(db.cards).insert(CardsCompanion.insert(
    id: AppConstants.kDefaultCardId,
    stackId: AppConstants.kDefaultStackId,
    date: now,
    projectTitle: const Value('Getting Started'),
    createdAt: now,
    updatedAt: now,
  ));

  // Now-column tasks
  final nowTasks = [
    'Welcome to 3by5 👋',
    'Press ⌘N to add a task',
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

  // Later-column tasks
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
