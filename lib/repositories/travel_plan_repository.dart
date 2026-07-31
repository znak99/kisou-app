import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/travel_plan.dart';
import '../services/travel_database_directory.dart';

abstract interface class TravelPlanRepository {
  Future<List<TravelPlan>> listVisible();

  Future<List<TravelPlan>> listAll();

  Future<TravelPlan> create(TravelPlanDraft draft);

  Future<TravelPlan> update(int id, TravelPlanDraft draft);

  Future<void> setSyncState(int id, TravelNotificationSyncState syncState);

  Future<void> markPendingDelete(int id);

  Future<void> deletePermanently(int id);

  Future<void> clearAll();

  Future<void> close();
}

class SqfliteTravelPlanRepository implements TravelPlanRepository {
  SqfliteTravelPlanRepository({
    DatabaseFactory? factory,
    String? databasePath,
    DateTime Function()? now,
    Future<String> Function()? databaseDirectory,
  }) : _factory = factory ?? databaseFactory,
       _databasePath = databasePath,
       _now = now ?? DateTime.now,
       _databaseDirectory = databaseDirectory ?? prepareTravelDatabaseDirectory;

  static const _databaseName = 'kisou_travel_plans.db';
  static const _table = 'travel_plans';

  final DatabaseFactory _factory;
  final String? _databasePath;
  final DateTime Function() _now;
  final Future<String> Function() _databaseDirectory;
  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path =
        _databasePath ?? p.join(await _databaseDirectory(), _databaseName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE $_table (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              destination_code TEXT NOT NULL,
              departure_at_utc_ms INTEGER NOT NULL,
              reminder_minutes INTEGER NOT NULL
                CHECK (reminder_minutes IN (0, 180, 1440)),
              notification_id INTEGER UNIQUE,
              sync_state TEXT NOT NULL
                CHECK (sync_state IN (
                  'none',
                  'pendingSchedule',
                  'scheduled',
                  'blockedPermission',
                  'pendingDelete'
                )),
              created_at_utc_ms INTEGER NOT NULL,
              updated_at_utc_ms INTEGER NOT NULL,
              UNIQUE (destination_code, departure_at_utc_ms)
            )
          ''');
          await database.execute('''
            CREATE INDEX idx_travel_plans_departure
            ON $_table (departure_at_utc_ms, id)
          ''');
          await database.execute('''
            CREATE INDEX idx_travel_plans_sync
            ON $_table (sync_state)
          ''');
        },
      ),
    );
  }

  @override
  Future<List<TravelPlan>> listVisible() async {
    final database = await _database;
    return database.transaction(
      (transaction) => _readRecoveringCorruptRows(
        transaction,
        where: 'sync_state != ?',
        whereArgs: [TravelNotificationSyncState.pendingDelete.name],
      ),
    );
  }

  @override
  Future<List<TravelPlan>> listAll() async {
    final database = await _database;
    return database.transaction(
      (transaction) => _readRecoveringCorruptRows(transaction),
    );
  }

  /// A single malformed local row must not make every travel plan unusable.
  ///
  /// SQLite's schema constraints prevent most malformed values, but an older
  /// app build, a partial migration, or manual device restore can still leave
  /// an unknown destination code. Such rows cannot be shown or scheduled
  /// safely, so they are removed in the same transaction. Reconciliation then
  /// treats any notification that belonged to the removed row as an orphan and
  /// cancels it.
  Future<List<TravelPlan>> _readRecoveringCorruptRows(
    DatabaseExecutor executor, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = await executor.query(
      _table,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'departure_at_utc_ms ASC, id ASC',
    );
    final plans = <TravelPlan>[];
    final corruptIds = <int>[];
    for (final row in rows) {
      try {
        plans.add(TravelPlan.fromStorage(row));
      } on Object {
        final id = row['id'];
        if (id is int) {
          corruptIds.add(id);
        }
      }
    }
    for (final id in corruptIds) {
      await executor.delete(_table, where: 'id = ?', whereArgs: [id]);
    }
    return List.unmodifiable(plans);
  }

  @override
  Future<TravelPlan> create(TravelPlanDraft draft) async {
    final now = _now().toUtc();
    draft.validate(nowUtc: now);
    final database = await _database;
    try {
      return await database.transaction((transaction) async {
        final countResult = await transaction.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM $_table
          WHERE sync_state != ?
          ''',
          [TravelNotificationSyncState.pendingDelete.name],
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        if (count >= maxTravelPlans) {
          throw const TravelPlanLimitException();
        }

        final id = await transaction.insert(_table, {
          'destination_code': draft.cityCode,
          'departure_at_utc_ms': draft.departureAtUtc
              .toUtc()
              .millisecondsSinceEpoch,
          'reminder_minutes': draft.reminder.minutes,
          'notification_id': null,
          'sync_state': _initialSyncState(draft.reminder).name,
          'created_at_utc_ms': now.millisecondsSinceEpoch,
          'updated_at_utc_ms': now.millisecondsSinceEpoch,
        });
        final notificationId = travelNotificationIdMin + id;
        if (notificationId > travelNotificationIdMax) {
          throw const TravelPlanLimitException();
        }
        await transaction.update(
          _table,
          {'notification_id': notificationId},
          where: 'id = ?',
          whereArgs: [id],
        );
        return _getById(transaction, id);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateTravelPlanException();
      }
      rethrow;
    }
  }

  @override
  Future<TravelPlan> update(int id, TravelPlanDraft draft) async {
    final now = _now().toUtc();
    draft.validate(nowUtc: now);
    final database = await _database;
    try {
      return await database.transaction((transaction) async {
        final updated = await transaction.update(
          _table,
          {
            'destination_code': draft.cityCode,
            'departure_at_utc_ms': draft.departureAtUtc
                .toUtc()
                .millisecondsSinceEpoch,
            'reminder_minutes': draft.reminder.minutes,
            'sync_state': _initialSyncState(draft.reminder).name,
            'updated_at_utc_ms': now.millisecondsSinceEpoch,
          },
          where: 'id = ? AND sync_state != ?',
          whereArgs: [id, TravelNotificationSyncState.pendingDelete.name],
        );
        if (updated != 1) {
          throw StateError('Travel plan does not exist.');
        }
        return _getById(transaction, id);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const DuplicateTravelPlanException();
      }
      rethrow;
    }
  }

  TravelNotificationSyncState _initialSyncState(TravelReminder reminder) {
    return reminder == TravelReminder.none
        ? TravelNotificationSyncState.none
        : TravelNotificationSyncState.pendingSchedule;
  }

  Future<TravelPlan> _getById(DatabaseExecutor executor, int id) async {
    final rows = await executor.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Travel plan does not exist.');
    }
    return TravelPlan.fromStorage(rows.single);
  }

  @override
  Future<void> setSyncState(
    int id,
    TravelNotificationSyncState syncState,
  ) async {
    final database = await _database;
    final updated = await database.update(
      _table,
      {
        'sync_state': syncState.name,
        'updated_at_utc_ms': _now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated != 1) {
      throw StateError('Travel plan does not exist.');
    }
  }

  @override
  Future<void> markPendingDelete(int id) {
    return setSyncState(id, TravelNotificationSyncState.pendingDelete);
  }

  @override
  Future<void> deletePermanently(int id) async {
    final database = await _database;
    await database.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    final database = await _database;
    await database.delete(_table);
  }

  @override
  Future<void> close() async {
    final database = _databaseFuture;
    if (database != null) {
      await (await database).close();
    }
  }
}

/// Non-mobile fallback keeps widget tests and unsupported desktop previews
/// independent from platform SQLite channels. Android and iOS always use the
/// durable repository above.
class MemoryTravelPlanRepository implements TravelPlanRepository {
  MemoryTravelPlanRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<int, TravelPlan> _plans = {};
  int _nextId = 1;

  @override
  Future<List<TravelPlan>> listVisible() async {
    return _sorted(
      _plans.values.where(
        (plan) => plan.syncState != TravelNotificationSyncState.pendingDelete,
      ),
    );
  }

  @override
  Future<List<TravelPlan>> listAll() async => _sorted(_plans.values);

  List<TravelPlan> _sorted(Iterable<TravelPlan> plans) {
    final result = plans.toList();
    result.sort((left, right) {
      final departure = left.departureAtUtc.compareTo(right.departureAtUtc);
      return departure != 0 ? departure : left.id.compareTo(right.id);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<TravelPlan> create(TravelPlanDraft draft) async {
    final now = _now().toUtc();
    draft.validate(nowUtc: now);
    if (_plans.values
            .where(
              (plan) =>
                  plan.syncState != TravelNotificationSyncState.pendingDelete,
            )
            .length >=
        maxTravelPlans) {
      throw const TravelPlanLimitException();
    }
    _ensureUnique(draft);
    final id = _nextId++;
    final plan = TravelPlan(
      id: id,
      cityCode: draft.cityCode,
      departureAtUtc: draft.departureAtUtc,
      reminder: draft.reminder,
      notificationId: travelNotificationIdMin + id,
      syncState: draft.reminder == TravelReminder.none
          ? TravelNotificationSyncState.none
          : TravelNotificationSyncState.pendingSchedule,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    _plans[id] = plan;
    return plan;
  }

  @override
  Future<TravelPlan> update(int id, TravelPlanDraft draft) async {
    final existing = _plans[id];
    if (existing == null ||
        existing.syncState == TravelNotificationSyncState.pendingDelete) {
      throw StateError('Travel plan does not exist.');
    }
    final now = _now().toUtc();
    draft.validate(nowUtc: now);
    _ensureUnique(draft, excludingId: id);
    final updated = existing.copyWith(
      cityCode: draft.cityCode,
      departureAtUtc: draft.departureAtUtc,
      reminder: draft.reminder,
      syncState: draft.reminder == TravelReminder.none
          ? TravelNotificationSyncState.none
          : TravelNotificationSyncState.pendingSchedule,
      updatedAtUtc: now,
    );
    _plans[id] = updated;
    return updated;
  }

  void _ensureUnique(TravelPlanDraft draft, {int? excludingId}) {
    final duplicate = _plans.values.any(
      (plan) =>
          plan.id != excludingId &&
          plan.syncState != TravelNotificationSyncState.pendingDelete &&
          plan.cityCode == draft.cityCode &&
          plan.departureAtUtc == draft.departureAtUtc,
    );
    if (duplicate) {
      throw const DuplicateTravelPlanException();
    }
  }

  @override
  Future<void> setSyncState(
    int id,
    TravelNotificationSyncState syncState,
  ) async {
    final existing = _plans[id];
    if (existing == null) {
      throw StateError('Travel plan does not exist.');
    }
    _plans[id] = existing.copyWith(
      syncState: syncState,
      updatedAtUtc: _now().toUtc(),
    );
  }

  @override
  Future<void> markPendingDelete(int id) {
    return setSyncState(id, TravelNotificationSyncState.pendingDelete);
  }

  @override
  Future<void> deletePermanently(int id) async {
    _plans.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _plans.clear();
  }

  @override
  Future<void> close() async {}
}
