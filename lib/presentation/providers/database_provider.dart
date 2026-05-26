import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/database/app_database.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
SettingsDao settingsDao(SettingsDaoRef ref) =>
    SettingsDao(ref.watch(appDatabaseProvider));
