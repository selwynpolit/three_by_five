import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the help panel is currently open.
final helpPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// The section ID the user last viewed; persists for the app session.
final helpPanelSectionProvider =
    StateProvider<String>((ref) => 'getting-started');
