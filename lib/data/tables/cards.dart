import 'package:drift/drift.dart';
import 'stacks.dart';

@DataClassName('AppCard')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get stackId => text().references(Stacks, #id)();

  /// The date this card represents (shown as the card's header date).
  DateTimeColumn get date => dateTime()();

  /// Optional project/context title shown at top of the card.
  TextColumn get projectTitle => text().nullable()();

  /// active | archived | expanded (expanded = this card is a Board).
  /// Use CardStatus enum via fromString() at the repository layer.
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// True when manually hidden with no resurfacing date.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// Non-null = snoozed until this date; null = not snoozed.
  DateTimeColumn get hiddenUntil => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
