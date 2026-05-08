// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cardRepositoryHash() => r'a0f73f659580fb24d8cb26750313f67348f86560';

/// See also [cardRepository].
@ProviderFor(cardRepository)
final cardRepositoryProvider = Provider<CardRepository>.internal(
  cardRepository,
  name: r'cardRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cardRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CardRepositoryRef = ProviderRef<CardRepository>;
String _$cardsHash() => r'bdc142dd85fb8f5a3ea40063fdf45f6fa3057e02';

/// Cards to display, filtered only by [hiddenStackIdsProvider].
/// [activeStackIdProvider] controls where new cards are created, not what is shown.
///
/// Copied from [cards].
@ProviderFor(cards)
final cardsProvider = AutoDisposeStreamProvider<List<AppCard>>.internal(
  cards,
  name: r'cardsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CardsRef = AutoDisposeStreamProviderRef<List<AppCard>>;
String _$archivedCardsHash() => r'b3db6b635d88d30c1f500789f5dfb618bd32d6fc';

/// Archived cards across all stacks.
///
/// Copied from [archivedCards].
@ProviderFor(archivedCards)
final archivedCardsProvider = AutoDisposeStreamProvider<List<AppCard>>.internal(
  archivedCards,
  name: r'archivedCardsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$archivedCardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ArchivedCardsRef = AutoDisposeStreamProviderRef<List<AppCard>>;
String _$showHiddenCardsHash() => r'e6b6a3851ab3215989fcd2103775b510e002be6e';

/// Toggles whether hidden/snoozed cards are shown in the current view.
///
/// Copied from [ShowHiddenCards].
@ProviderFor(ShowHiddenCards)
final showHiddenCardsProvider =
    NotifierProvider<ShowHiddenCards, bool>.internal(
      ShowHiddenCards.new,
      name: r'showHiddenCardsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$showHiddenCardsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ShowHiddenCards = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
