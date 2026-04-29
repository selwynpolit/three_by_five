// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ui_state_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeViewHash() => r'1dc58c650c45c90280e14b69e64896a7f216a693';

/// Which top-level view is currently shown.
///
/// Copied from [ActiveView].
@ProviderFor(ActiveView)
final activeViewProvider = NotifierProvider<ActiveView, AppView>.internal(
  ActiveView.new,
  name: r'activeViewProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeViewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveView = Notifier<AppView>;
String _$selectedTaskIdHash() => r'35e2cbe14468e3491622771edef2d834cd70be03';

/// The task currently open in the detail panel. Null = panel closed.
///
/// Copied from [SelectedTaskId].
@ProviderFor(SelectedTaskId)
final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskId, String?>.internal(
      SelectedTaskId.new,
      name: r'selectedTaskIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedTaskIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedTaskId = Notifier<String?>;
String _$activeBoardCardIdHash() => r'8f6d995091a708994d585dd40e86381ce687461a';

/// The card open in Board view. Null = no board open.
///
/// Copied from [ActiveBoardCardId].
@ProviderFor(ActiveBoardCardId)
final activeBoardCardIdProvider =
    NotifierProvider<ActiveBoardCardId, String?>.internal(
      ActiveBoardCardId.new,
      name: r'activeBoardCardIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeBoardCardIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveBoardCardId = Notifier<String?>;
String _$lastUndoActionHash() => r'0f31e70fda99c1ae0aebfbc7d59e445d038de97a';

/// The last reversible action performed. Non-null = undo toast should be shown.
/// Use [record] after any undoable operation; [consume] to execute the undo and
/// clear state; [clear] to dismiss the toast without undoing.
///
/// Copied from [LastUndoAction].
@ProviderFor(LastUndoAction)
final lastUndoActionProvider =
    NotifierProvider<LastUndoAction, UndoAction?>.internal(
      LastUndoAction.new,
      name: r'lastUndoActionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lastUndoActionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LastUndoAction = Notifier<UndoAction?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
