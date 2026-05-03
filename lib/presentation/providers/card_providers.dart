import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/cards_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/card_repository.dart';
import 'canvas_providers.dart';
import 'database_provider.dart';
import 'stack_providers.dart';

part 'card_providers.g.dart';

@Riverpod(keepAlive: true)
CardRepository cardRepository(CardRepositoryRef ref) =>
    CardRepository(CardsDao(ref.watch(appDatabaseProvider)));

/// Toggles whether hidden/snoozed cards are shown in the current view.
@Riverpod(keepAlive: true)
class ShowHiddenCards extends _$ShowHiddenCards {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

/// Cards to display, filtered only by [hiddenStackIdsProvider].
/// [activeStackIdProvider] controls where new cards are created, not what is shown.
@riverpod
Stream<List<AppCard>> cards(CardsRef ref) {
  final repo = ref.watch(cardRepositoryProvider);
  final hiddenStackIds = ref.watch(hiddenStackIdsProvider);
  final showHidden = ref.watch(showHiddenCardsProvider);

  final base = repo.watchAll(showHidden: showHidden);
  if (hiddenStackIds.isEmpty) return base;
  return base.map((list) =>
      list.where((c) => !hiddenStackIds.contains(c.stackId)).toList());
}

/// Archived cards across all stacks.
@riverpod
Stream<List<AppCard>> archivedCards(ArchivedCardsRef ref) {
  final repo = ref.watch(cardRepositoryProvider);
  return repo.watchArchived();
}
