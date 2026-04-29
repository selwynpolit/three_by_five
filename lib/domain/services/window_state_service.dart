import 'dart:ui';
import 'package:window_manager/window_manager.dart';
import '../../data/daos/settings_dao.dart';

/// Persists and restores window size and position via SettingsDao.
class WindowStateService {
  WindowStateService(this._settings);
  final SettingsDao _settings;

  static const _keyX = 'windowX';
  static const _keyY = 'windowY';
  static const _keyW = 'windowWidth';
  static const _keyH = 'windowHeight';

  static const _defaultWidth = 1280.0;
  static const _defaultHeight = 800.0;

  Future<void> saveState() async {
    final bounds = await windowManager.getBounds();
    await Future.wait([
      _settings.set(_keyX, bounds.left.toString()),
      _settings.set(_keyY, bounds.top.toString()),
      _settings.set(_keyW, bounds.width.toString()),
      _settings.set(_keyH, bounds.height.toString()),
    ]);
  }

  Future<void> restoreState() async {
    final values = await Future.wait([
      _settings.get(_keyX),
      _settings.get(_keyY),
      _settings.get(_keyW),
      _settings.get(_keyH),
    ]);

    final x = double.tryParse(values[0] ?? '');
    final y = double.tryParse(values[1] ?? '');
    final w = double.tryParse(values[2] ?? '') ?? _defaultWidth;
    final h = double.tryParse(values[3] ?? '') ?? _defaultHeight;

    await windowManager.setSize(Size(w, h));
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    } else {
      await windowManager.center();
    }
  }

  Future<void> ensureMinimumSize() =>
      windowManager.setMinimumSize(const Size(900, 600));
}
