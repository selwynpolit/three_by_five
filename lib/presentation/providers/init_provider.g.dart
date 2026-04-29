// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'init_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appInitHash() => r'3fd424cb1453e137ab412e07f75fb87de2849b09';

/// Ensures the database has at least one stack (provisions demo data on first
/// launch). Returns the stack ID that should be set as the initial active stack,
/// or null to show All Cards.
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
