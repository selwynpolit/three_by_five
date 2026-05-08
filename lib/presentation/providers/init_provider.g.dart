// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'init_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appInitHash() => r'6e68748d78682c999c5ae2df5920a47295400407';

/// Ensures the database has at least one stack (provisions demo data on first
/// launch) then restores the last-used view state.  Returns the stack ID to
/// use as the initial active stack (non-null once the database is ready).
///
/// Copied from [appInit].
@ProviderFor(appInit)
final appInitProvider = FutureProvider<String?>.internal(
  appInit,
  name: r'appInitProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appInitHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppInitRef = FutureProviderRef<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
