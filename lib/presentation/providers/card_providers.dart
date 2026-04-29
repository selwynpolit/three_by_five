import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/cards_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/card_repository.dart';
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

/// Active, visible cards for the active stack (or all stacks if stackId is null).
@riverpod
Stream<List<AppCard>> cards(CardsRef ref) {
  final repo = ref.watch(cardRepositoryProvider);
  final stackId = ref.watch(activeStackIdProvider);
  final showHidden = ref.watch(showHiddenCardsProvider);

  if (stackId == null) {
    return repo.watchAll(showHidden: showHidden);
  }
  return repo.watchByStack(stackId, showHidden: showHidden);
}

/// Archived cards, optionally filtered to the active stack.
@riverpod
Stream<List<AppCard>> archivedCards(ArchivedCardsRef ref) {
  final repo = ref.watch(cardRepositoryProvider);
  final stackId = ref.watch(activeStackIdProvider);
  return repo.watchArchived(stackId: stackId);
}
