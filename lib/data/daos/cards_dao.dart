import 'package:drift/drift.dart';
import '../database/app_database.dart';

class CardsDao {
  CardsDao(this._db);
  final AppDatabase _db;

  Stream<List<AppCard>> watchByStack(
    String stackId, {
    bool showHidden = false,
  }) {
    return (_db.select(_db.cards)
          ..where((c) {
            final base = c.deletedAt.isNull() &
                c.stackId.equals(stackId) &
                c.status.equals('archived').not();
            // SQL only filters the boolean flag; hiddenUntil is checked in
            // the Dart map below so DateTime.now() re-evaluates each emission.
            if (showHidden) return base;
            return base & c.isHidden.equals(false);
          })
          ..orderBy([(c) => OrderingTerm.desc(c.date)]))
        .watch()
        .map((cards) {
          if (showHidden) return cards;
          final now = DateTime.now();
          return cards
              .where((c) =>
                  c.hiddenUntil == null || !c.hiddenUntil!.isAfter(now))
              .toList();
        });
  }

  Stream<List<AppCard>> watchAll({bool showHidden = false}) {
    return (_db.select(_db.cards)
          ..where((c) {
            final base =
                c.deletedAt.isNull() & c.status.equals('archived').not();
            if (showHidden) return base;
            return base & c.isHidden.equals(false);
          })
          ..orderBy([(c) => OrderingTerm.desc(c.date)]))
        .watch()
        .map((cards) {
          if (showHidden) return cards;
          final now = DateTime.now();
          return cards
              .where((c) =>
                  c.hiddenUntil == null || !c.hiddenUntil!.isAfter(now))
              .toList();
        });
  }

  Stream<List<AppCard>> watchArchived({String? stackId}) {
    return (_db.select(_db.cards)
          ..where((c) {
            final base =
                c.deletedAt.isNull() & c.status.equals('archived');
            if (stackId != null) return base & c.stackId.equals(stackId);
            return base;
          })
          ..orderBy([(c) => OrderingTerm.desc(c.date)]))
        .watch();
  }

  Future<AppCard?> getById(String id) =>
      (_db.select(_db.cards)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<void> insert(CardsCompanion entry) =>
      _db.into(_db.cards).insert(entry);

  Future<void> update(CardsCompanion entry) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(entry.id.value)))
          .write(entry);

  Future<void> softDelete(String id) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> archive(String id) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          status: const Value('archived'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> restore(String id) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          status: const Value('active'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> hideIndefinitely(String id) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          isHidden: const Value(true),
          hiddenUntil: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> snoozeUntil(String id, DateTime date) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          isHidden: const Value(false),
          hiddenUntil: Value(date),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> unhide(String id) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          isHidden: const Value(false),
          hiddenUntil: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> moveToStack(String id, String stackId) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          stackId: Value(stackId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setStatus(String id, String status) =>
      (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<List<AppCard>> getActiveByStack(String stackId) =>
      (_db.select(_db.cards)
            ..where((c) =>
                c.stackId.equals(stackId) &
                c.deletedAt.isNull() &
                c.status.equals('archived').not()))
          .get();

  Future<void> moveAllActiveToStack(String fromStackId, String toStackId) =>
      (_db.update(_db.cards)
            ..where((c) =>
                c.stackId.equals(fromStackId) &
                c.deletedAt.isNull() &
                c.status.equals('archived').not()))
          .write(CardsCompanion(
            stackId: Value(toStackId),
            updatedAt: Value(DateTime.now()),
          ));

  Future<void> deleteAllByStack(String stackId) =>
      (_db.update(_db.cards)
            ..where((c) => c.stackId.equals(stackId) & c.deletedAt.isNull()))
          .write(CardsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
}
