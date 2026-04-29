// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stack_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stackRepositoryHash() => r'98229438b1a82ff7d7628ca1a5c8a4d3e9cb4dc5';

/// See also [stackRepository].
@ProviderFor(stackRepository)
final stackRepositoryProvider = Provider<StackRepository>.internal(
  stackRepository,
  name: r'stackRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stackRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StackRepositoryRef = ProviderRef<StackRepository>;
String _$stacksHash() => r'76dd5ee49092d437da3bd3601c8b95925c0836e4';

/// See also [stacks].
@ProviderFor(stacks)
final stacksProvider = AutoDisposeStreamProvider<List<AppStack>>.internal(
  stacks,
  name: r'stacksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stacksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StacksRef = AutoDisposeStreamProviderRef<List<AppStack>>;
String _$activeStackIdHash() => r'df8503b71cbdc64c77f0a7e94a3bf45d6c7d510f';

/// The currently active stack. null = All Cards view.
///
/// Copied from [ActiveStackId].
@ProviderFor(ActiveStackId)
final activeStackIdProvider = NotifierProvider<ActiveStackId, String?>.internal(
  ActiveStackId.new,
  name: r'activeStackIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeStackIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveStackId = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
