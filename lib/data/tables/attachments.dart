import 'package:drift/drift.dart';
import 'tasks.dart';

@DataClassName('AppAttachment')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();

  /// image | link | emailClip — use AttachmentType.fromString() at repo layer.
  TextColumn get type => text()();

  // --- Image fields ---
  TextColumn get filePath => text().nullable()();

  // --- Link fields ---
  TextColumn get url => text().nullable()();
  TextColumn get linkTitle => text().nullable()();
  TextColumn get faviconUrl => text().nullable()();

  // --- Email clip fields ---
  TextColumn get emailSubject => text().nullable()();
  TextColumn get emailSender => text().nullable()();
  TextColumn get emailBodySnippet => text().nullable()();
  TextColumn get emailSourceClient => text().nullable()();
  DateTimeColumn get emailOriginalDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
