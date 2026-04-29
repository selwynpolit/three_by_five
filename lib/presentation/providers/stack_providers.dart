import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/stacks_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/stack_repository.dart';
import 'database_provider.dart';

part 'stack_providers.g.dart';

@Riverpod(keepAlive: true)
StackRepository stackRepository(StackRepositoryRef ref) =>
    StackRepository(StacksDao(ref.watch(appDatabaseProvider)));

@riverpod
Stream<List<AppStack>> stacks(StacksRef ref) =>
    ref.watch(stackRepositoryProvider).watchAll();

/// The currently active stack. null = All Cards view.
@Riverpod(keepAlive: true)
class ActiveStackId extends _$ActiveStackId {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}
