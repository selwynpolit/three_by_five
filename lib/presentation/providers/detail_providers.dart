import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/daos/attachments_dao.dart';
import '../../data/daos/notes_dao.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';
import 'database_provider.dart';

part 'detail_providers.g.dart';

@Riverpod(keepAlive: true)
NoteRepository noteRepository(NoteRepositoryRef ref) =>
    NoteRepository(NotesDao(ref.watch(appDatabaseProvider)));

@Riverpod(keepAlive: true)
AttachmentRepository attachmentRepository(AttachmentRepositoryRef ref) =>
    AttachmentRepository(AttachmentsDao(ref.watch(appDatabaseProvider)));
