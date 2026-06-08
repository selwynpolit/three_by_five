import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

/// Whether the "Generate test cards" button is shown in the card view header.
/// Persisted via SettingsDao key 'showGenerateButton'. Default: true.
final showGenerateButtonProvider =
    NotifierProvider<_ShowGenBtn, bool>(_ShowGenBtn.new);

class _ShowGenBtn extends Notifier<bool> {
  @override
  bool build() {
    if (kReleaseMode) return false;
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final stored =
        await ref.read(settingsDaoProvider).get('showGenerateButton');
    if (stored != null) state = stored != 'false';
  }

  void toggle() {
    state = !state;
    ref.read(settingsDaoProvider).set('showGenerateButton', state.toString());
  }
}
