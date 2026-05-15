import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/tags_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/tag_repository.dart';
import 'database_provider.dart';

part 'tag_providers.g.dart';

@Riverpod(keepAlive: true)
TagRepository tagRepository(TagRepositoryRef ref) =>
    TagRepository(TagsDao(ref.watch(appDatabaseProvider)));

@riverpod
Stream<List<AppTag>> allTags(AllTagsRef ref) =>
    ref.watch(tagRepositoryProvider).watchAll();

@riverpod
Stream<List<AppTag>> tagsForTask(TagsForTaskRef ref, String taskId) =>
    TagsDao(ref.watch(appDatabaseProvider)).watchByTask(taskId);

/// Map of taskId → first tag name, used for sorting the task list by tag.
final taskTagNamesProvider = StreamProvider<Map<String, String>>((ref) =>
    TagsDao(ref.watch(appDatabaseProvider)).watchTaskTagNamesByTaskId());
