// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zoom_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$viewZoomHash() => r'2ce10d30d6b2b510c4234b48a2a2f20331df7a5d';

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

abstract class _$ViewZoom extends BuildlessNotifier<double> {
  late final AppView view;

  double build(AppView view);
}

/// See also [ViewZoom].
@ProviderFor(ViewZoom)
const viewZoomProvider = ViewZoomFamily();

/// See also [ViewZoom].
class ViewZoomFamily extends Family<double> {
  /// See also [ViewZoom].
  const ViewZoomFamily();

  /// See also [ViewZoom].
  ViewZoomProvider call(AppView view) {
    return ViewZoomProvider(view);
  }

  @override
  ViewZoomProvider getProviderOverride(covariant ViewZoomProvider provider) {
    return call(provider.view);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'viewZoomProvider';
}

/// See also [ViewZoom].
class ViewZoomProvider extends NotifierProviderImpl<ViewZoom, double> {
  /// See also [ViewZoom].
  ViewZoomProvider(AppView view)
    : this._internal(
        () => ViewZoom()..view = view,
        from: viewZoomProvider,
        name: r'viewZoomProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$viewZoomHash,
        dependencies: ViewZoomFamily._dependencies,
        allTransitiveDependencies: ViewZoomFamily._allTransitiveDependencies,
        view: view,
      );

  ViewZoomProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.view,
  }) : super.internal();

  final AppView view;

  @override
  double runNotifierBuild(covariant ViewZoom notifier) {
    return notifier.build(view);
  }

  @override
  Override overrideWith(ViewZoom Function() create) {
    return ProviderOverride(
      origin: this,
      override: ViewZoomProvider._internal(
        () => create()..view = view,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        view: view,
      ),
    );
  }

  @override
  NotifierProviderElement<ViewZoom, double> createElement() {
    return _ViewZoomProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ViewZoomProvider && other.view == view;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, view.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ViewZoomRef on NotifierProviderRef<double> {
  /// The parameter `view` of this provider.
  AppView get view;
}

class _ViewZoomProviderElement extends NotifierProviderElement<ViewZoom, double>
    with ViewZoomRef {
  _ViewZoomProviderElement(super.provider);

  @override
  AppView get view => (origin as ViewZoomProvider).view;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
