// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskRepositoryHash() => r'71428a34a2e465c850f0762781167fabf45c707d';

/// See also [taskRepository].
@ProviderFor(taskRepository)
final taskRepositoryProvider = Provider<TaskRepository>.internal(
  taskRepository,
  name: r'taskRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$taskRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaskRepositoryRef = ProviderRef<TaskRepository>;
String _$boardColumnsDaoHash() => r'4311e711e09bbf9128a46b759e8f8cfc9c1c067c';

/// See also [boardColumnsDao].
@ProviderFor(boardColumnsDao)
final boardColumnsDaoProvider = Provider<BoardColumnsDao>.internal(
  boardColumnsDao,
  name: r'boardColumnsDaoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$boardColumnsDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BoardColumnsDaoRef = ProviderRef<BoardColumnsDao>;
String _$tasksForCardHash() => r'adc2a31d704a33109200c30b5584d4e3bde22c79';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// All tasks for a given card, ordered by sort_order then created_at.
///
/// Copied from [tasksForCard].
@ProviderFor(tasksForCard)
const tasksForCardProvider = TasksForCardFamily();

/// All tasks for a given card, ordered by sort_order then created_at.
///
/// Copied from [tasksForCard].
class TasksForCardFamily extends Family<AsyncValue<List<AppTask>>> {
  /// All tasks for a given card, ordered by sort_order then created_at.
  ///
  /// Copied from [tasksForCard].
  const TasksForCardFamily();

  /// All tasks for a given card, ordered by sort_order then created_at.
  ///
  /// Copied from [tasksForCard].
  TasksForCardProvider call(String cardId) {
    return TasksForCardProvider(cardId);
  }

  @override
  TasksForCardProvider getProviderOverride(
    covariant TasksForCardProvider provider,
  ) {
    return call(provider.cardId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tasksForCardProvider';
}

/// All tasks for a given card, ordered by sort_order then created_at.
///
/// Copied from [tasksForCard].
class TasksForCardProvider extends AutoDisposeStreamProvider<List<AppTask>> {
  /// All tasks for a given card, ordered by sort_order then created_at.
  ///
  /// Copied from [tasksForCard].
  TasksForCardProvider(String cardId)
    : this._internal(
        (ref) => tasksForCard(ref as TasksForCardRef, cardId),
        from: tasksForCardProvider,
        name: r'tasksForCardProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tasksForCardHash,
        dependencies: TasksForCardFamily._dependencies,
        allTransitiveDependencies:
            TasksForCardFamily._allTransitiveDependencies,
        cardId: cardId,
      );

  TasksForCardProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.cardId,
  }) : super.internal();

  final String cardId;

  @override
  Override overrideWith(
    Stream<List<AppTask>> Function(TasksForCardRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TasksForCardProvider._internal(
        (ref) => create(ref as TasksForCardRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        cardId: cardId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppTask>> createElement() {
    return _TasksForCardProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksForCardProvider && other.cardId == cardId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, cardId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TasksForCardRef on AutoDisposeStreamProviderRef<List<AppTask>> {
  /// The parameter `cardId` of this provider.
  String get cardId;
}

class _TasksForCardProviderElement
    extends AutoDisposeStreamProviderElement<List<AppTask>>
    with TasksForCardRef {
  _TasksForCardProviderElement(super.provider);

  @override
  String get cardId => (origin as TasksForCardProvider).cardId;
}

String _$tasksForCardColumnHash() =>
    r'45973fadc8c23ff37b06dab09b409f58c3c9dbde';

/// Tasks in a specific column (now/later) for a card.
///
/// Copied from [tasksForCardColumn].
@ProviderFor(tasksForCardColumn)
const tasksForCardColumnProvider = TasksForCardColumnFamily();

/// Tasks in a specific column (now/later) for a card.
///
/// Copied from [tasksForCardColumn].
class TasksForCardColumnFamily extends Family<AsyncValue<List<AppTask>>> {
  /// Tasks in a specific column (now/later) for a card.
  ///
  /// Copied from [tasksForCardColumn].
  const TasksForCardColumnFamily();

  /// Tasks in a specific column (now/later) for a card.
  ///
  /// Copied from [tasksForCardColumn].
  TasksForCardColumnProvider call(String cardId, String column) {
    return TasksForCardColumnProvider(cardId, column);
  }

  @override
  TasksForCardColumnProvider getProviderOverride(
    covariant TasksForCardColumnProvider provider,
  ) {
    return call(provider.cardId, provider.column);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tasksForCardColumnProvider';
}

/// Tasks in a specific column (now/later) for a card.
///
/// Copied from [tasksForCardColumn].
class TasksForCardColumnProvider
    extends AutoDisposeStreamProvider<List<AppTask>> {
  /// Tasks in a specific column (now/later) for a card.
  ///
  /// Copied from [tasksForCardColumn].
  TasksForCardColumnProvider(String cardId, String column)
    : this._internal(
        (ref) =>
            tasksForCardColumn(ref as TasksForCardColumnRef, cardId, column),
        from: tasksForCardColumnProvider,
        name: r'tasksForCardColumnProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tasksForCardColumnHash,
        dependencies: TasksForCardColumnFamily._dependencies,
        allTransitiveDependencies:
            TasksForCardColumnFamily._allTransitiveDependencies,
        cardId: cardId,
        column: column,
      );

  TasksForCardColumnProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.cardId,
    required this.column,
  }) : super.internal();

  final String cardId;
  final String column;

  @override
  Override overrideWith(
    Stream<List<AppTask>> Function(TasksForCardColumnRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TasksForCardColumnProvider._internal(
        (ref) => create(ref as TasksForCardColumnRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        cardId: cardId,
        column: column,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppTask>> createElement() {
    return _TasksForCardColumnProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksForCardColumnProvider &&
        other.cardId == cardId &&
        other.column == column;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, cardId.hashCode);
    hash = _SystemHash.combine(hash, column.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TasksForCardColumnRef on AutoDisposeStreamProviderRef<List<AppTask>> {
  /// The parameter `cardId` of this provider.
  String get cardId;

  /// The parameter `column` of this provider.
  String get column;
}

class _TasksForCardColumnProviderElement
    extends AutoDisposeStreamProviderElement<List<AppTask>>
    with TasksForCardColumnRef {
  _TasksForCardColumnProviderElement(super.provider);

  @override
  String get cardId => (origin as TasksForCardColumnProvider).cardId;
  @override
  String get column => (origin as TasksForCardColumnProvider).column;
}

String _$tasksDueTodayHash() => r'e26a81dc7853e0e40eecf57f72414d8773f8195d';

/// Tasks due today across all cards.
///
/// Copied from [tasksDueToday].
@ProviderFor(tasksDueToday)
final tasksDueTodayProvider = AutoDisposeStreamProvider<List<AppTask>>.internal(
  tasksDueToday,
  name: r'tasksDueTodayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tasksDueTodayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TasksDueTodayRef = AutoDisposeStreamProviderRef<List<AppTask>>;
String _$overdueTasksHash() => r'a8d2722aef5707c71b1be141274e54c964cb7955';

/// Overdue incomplete tasks.
///
/// Copied from [overdueTasks].
@ProviderFor(overdueTasks)
final overdueTasksProvider = AutoDisposeStreamProvider<List<AppTask>>.internal(
  overdueTasks,
  name: r'overdueTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$overdueTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverdueTasksRef = AutoDisposeStreamProviderRef<List<AppTask>>;
String _$tasksInDateRangeHash() => r'4898d62a1c3ce8722a7c8e1884454ce40cacb3e3';

/// Tasks with due dates in a calendar date range.
///
/// Copied from [tasksInDateRange].
@ProviderFor(tasksInDateRange)
const tasksInDateRangeProvider = TasksInDateRangeFamily();

/// Tasks with due dates in a calendar date range.
///
/// Copied from [tasksInDateRange].
class TasksInDateRangeFamily extends Family<AsyncValue<List<AppTask>>> {
  /// Tasks with due dates in a calendar date range.
  ///
  /// Copied from [tasksInDateRange].
  const TasksInDateRangeFamily();

  /// Tasks with due dates in a calendar date range.
  ///
  /// Copied from [tasksInDateRange].
  TasksInDateRangeProvider call(DateTime start, DateTime end) {
    return TasksInDateRangeProvider(start, end);
  }

  @override
  TasksInDateRangeProvider getProviderOverride(
    covariant TasksInDateRangeProvider provider,
  ) {
    return call(provider.start, provider.end);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tasksInDateRangeProvider';
}

/// Tasks with due dates in a calendar date range.
///
/// Copied from [tasksInDateRange].
class TasksInDateRangeProvider
    extends AutoDisposeStreamProvider<List<AppTask>> {
  /// Tasks with due dates in a calendar date range.
  ///
  /// Copied from [tasksInDateRange].
  TasksInDateRangeProvider(DateTime start, DateTime end)
    : this._internal(
        (ref) => tasksInDateRange(ref as TasksInDateRangeRef, start, end),
        from: tasksInDateRangeProvider,
        name: r'tasksInDateRangeProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tasksInDateRangeHash,
        dependencies: TasksInDateRangeFamily._dependencies,
        allTransitiveDependencies:
            TasksInDateRangeFamily._allTransitiveDependencies,
        start: start,
        end: end,
      );

  TasksInDateRangeProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.start,
    required this.end,
  }) : super.internal();

  final DateTime start;
  final DateTime end;

  @override
  Override overrideWith(
    Stream<List<AppTask>> Function(TasksInDateRangeRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TasksInDateRangeProvider._internal(
        (ref) => create(ref as TasksInDateRangeRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        start: start,
        end: end,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppTask>> createElement() {
    return _TasksInDateRangeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksInDateRangeProvider &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, start.hashCode);
    hash = _SystemHash.combine(hash, end.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TasksInDateRangeRef on AutoDisposeStreamProviderRef<List<AppTask>> {
  /// The parameter `start` of this provider.
  DateTime get start;

  /// The parameter `end` of this provider.
  DateTime get end;
}

class _TasksInDateRangeProviderElement
    extends AutoDisposeStreamProviderElement<List<AppTask>>
    with TasksInDateRangeRef {
  _TasksInDateRangeProviderElement(super.provider);

  @override
  DateTime get start => (origin as TasksInDateRangeProvider).start;
  @override
  DateTime get end => (origin as TasksInDateRangeProvider).end;
}

String _$boardColumnsHash() => r'01ee0b9062407b41c03f065dc8fb963d4e15c0ed';

/// Board columns ordered by sort_order.
///
/// Copied from [boardColumns].
@ProviderFor(boardColumns)
final boardColumnsProvider =
    AutoDisposeStreamProvider<List<AppBoardColumn>>.internal(
      boardColumns,
      name: r'boardColumnsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$boardColumnsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BoardColumnsRef = AutoDisposeStreamProviderRef<List<AppBoardColumn>>;
String _$taskByIdHash() => r'2825bfe66bd7e3c17671a7afc86c24109042c876';

/// Live stream for a single task (used by the detail panel).
///
/// Copied from [taskById].
@ProviderFor(taskById)
const taskByIdProvider = TaskByIdFamily();

/// Live stream for a single task (used by the detail panel).
///
/// Copied from [taskById].
class TaskByIdFamily extends Family<AsyncValue<AppTask?>> {
  /// Live stream for a single task (used by the detail panel).
  ///
  /// Copied from [taskById].
  const TaskByIdFamily();

  /// Live stream for a single task (used by the detail panel).
  ///
  /// Copied from [taskById].
  TaskByIdProvider call(String id) {
    return TaskByIdProvider(id);
  }

  @override
  TaskByIdProvider getProviderOverride(covariant TaskByIdProvider provider) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskByIdProvider';
}

/// Live stream for a single task (used by the detail panel).
///
/// Copied from [taskById].
class TaskByIdProvider extends AutoDisposeStreamProvider<AppTask?> {
  /// Live stream for a single task (used by the detail panel).
  ///
  /// Copied from [taskById].
  TaskByIdProvider(String id)
    : this._internal(
        (ref) => taskById(ref as TaskByIdRef, id),
        from: taskByIdProvider,
        name: r'taskByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$taskByIdHash,
        dependencies: TaskByIdFamily._dependencies,
        allTransitiveDependencies: TaskByIdFamily._allTransitiveDependencies,
        id: id,
      );

  TaskByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    Stream<AppTask?> Function(TaskByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TaskByIdProvider._internal(
        (ref) => create(ref as TaskByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<AppTask?> createElement() {
    return _TaskByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaskByIdRef on AutoDisposeStreamProviderRef<AppTask?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskByIdProviderElement
    extends AutoDisposeStreamProviderElement<AppTask?>
    with TaskByIdRef {
  _TaskByIdProviderElement(super.provider);

  @override
  String get id => (origin as TaskByIdProvider).id;
}

String _$notesForTaskHash() => r'37ec4fe3737c19a8f298cd11de861ffad71a79c1';

/// Notes for a task, oldest first.
///
/// Copied from [notesForTask].
@ProviderFor(notesForTask)
const notesForTaskProvider = NotesForTaskFamily();

/// Notes for a task, oldest first.
///
/// Copied from [notesForTask].
class NotesForTaskFamily extends Family<AsyncValue<List<AppNote>>> {
  /// Notes for a task, oldest first.
  ///
  /// Copied from [notesForTask].
  const NotesForTaskFamily();

  /// Notes for a task, oldest first.
  ///
  /// Copied from [notesForTask].
  NotesForTaskProvider call(String taskId) {
    return NotesForTaskProvider(taskId);
  }

  @override
  NotesForTaskProvider getProviderOverride(
    covariant NotesForTaskProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'notesForTaskProvider';
}

/// Notes for a task, oldest first.
///
/// Copied from [notesForTask].
class NotesForTaskProvider extends AutoDisposeStreamProvider<List<AppNote>> {
  /// Notes for a task, oldest first.
  ///
  /// Copied from [notesForTask].
  NotesForTaskProvider(String taskId)
    : this._internal(
        (ref) => notesForTask(ref as NotesForTaskRef, taskId),
        from: notesForTaskProvider,
        name: r'notesForTaskProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$notesForTaskHash,
        dependencies: NotesForTaskFamily._dependencies,
        allTransitiveDependencies:
            NotesForTaskFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  NotesForTaskProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  Override overrideWith(
    Stream<List<AppNote>> Function(NotesForTaskRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NotesForTaskProvider._internal(
        (ref) => create(ref as NotesForTaskRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppNote>> createElement() {
    return _NotesForTaskProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NotesForTaskProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NotesForTaskRef on AutoDisposeStreamProviderRef<List<AppNote>> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _NotesForTaskProviderElement
    extends AutoDisposeStreamProviderElement<List<AppNote>>
    with NotesForTaskRef {
  _NotesForTaskProviderElement(super.provider);

  @override
  String get taskId => (origin as NotesForTaskProvider).taskId;
}

String _$attachmentsForTaskHash() =>
    r'abe5fd1c342700ecb89022d02b8a0397e789d7d5';

/// Attachments for a task.
///
/// Copied from [attachmentsForTask].
@ProviderFor(attachmentsForTask)
const attachmentsForTaskProvider = AttachmentsForTaskFamily();

/// Attachments for a task.
///
/// Copied from [attachmentsForTask].
class AttachmentsForTaskFamily extends Family<AsyncValue<List<AppAttachment>>> {
  /// Attachments for a task.
  ///
  /// Copied from [attachmentsForTask].
  const AttachmentsForTaskFamily();

  /// Attachments for a task.
  ///
  /// Copied from [attachmentsForTask].
  AttachmentsForTaskProvider call(String taskId) {
    return AttachmentsForTaskProvider(taskId);
  }

  @override
  AttachmentsForTaskProvider getProviderOverride(
    covariant AttachmentsForTaskProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'attachmentsForTaskProvider';
}

/// Attachments for a task.
///
/// Copied from [attachmentsForTask].
class AttachmentsForTaskProvider
    extends AutoDisposeStreamProvider<List<AppAttachment>> {
  /// Attachments for a task.
  ///
  /// Copied from [attachmentsForTask].
  AttachmentsForTaskProvider(String taskId)
    : this._internal(
        (ref) => attachmentsForTask(ref as AttachmentsForTaskRef, taskId),
        from: attachmentsForTaskProvider,
        name: r'attachmentsForTaskProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$attachmentsForTaskHash,
        dependencies: AttachmentsForTaskFamily._dependencies,
        allTransitiveDependencies:
            AttachmentsForTaskFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  AttachmentsForTaskProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  Override overrideWith(
    Stream<List<AppAttachment>> Function(AttachmentsForTaskRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AttachmentsForTaskProvider._internal(
        (ref) => create(ref as AttachmentsForTaskRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppAttachment>> createElement() {
    return _AttachmentsForTaskProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentsForTaskProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AttachmentsForTaskRef
    on AutoDisposeStreamProviderRef<List<AppAttachment>> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _AttachmentsForTaskProviderElement
    extends AutoDisposeStreamProviderElement<List<AppAttachment>>
    with AttachmentsForTaskRef {
  _AttachmentsForTaskProviderElement(super.provider);

  @override
  String get taskId => (origin as AttachmentsForTaskProvider).taskId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
