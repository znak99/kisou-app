import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late SqfliteTravelPlanRepository repository;
  final now = DateTime.utc(2026, 7, 31);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'kisou_travel_repository_',
    );
    databasePath = p.join(temporaryDirectory.path, 'plans.db');
    repository = SqfliteTravelPlanRepository(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
      now: () => now,
    );
  });

  tearDown(() async {
    await repository.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists and updates a plan with a stable notification id', () async {
    final created = await repository.create(_draft(DateTime.utc(2026, 8, 10)));
    final updated = await repository.update(
      created.id,
      _draft(
        DateTime.utc(2026, 8, 11),
        reminder: TravelReminder.threeHoursBefore,
      ),
    );

    expect(updated.notificationId, created.notificationId);
    expect(updated.syncState, TravelNotificationSyncState.pendingSchedule);
    expect(
      (await repository.listVisible()).single.departureAtUtc,
      DateTime.utc(2026, 8, 11),
    );
  });

  test('rejects duplicate city and departure instants', () async {
    final draft = _draft(DateTime.utc(2026, 8, 10));
    await repository.create(draft);

    await expectLater(
      repository.create(draft),
      throwsA(isA<DuplicateTravelPlanException>()),
    );
  });

  test('enforces the 20 visible plan limit transactionally', () async {
    for (var index = 0; index < maxTravelPlans; index++) {
      await repository.create(_draft(DateTime.utc(2026, 8, 10, index)));
    }

    await expectLater(
      repository.create(_draft(DateTime.utc(2026, 8, 11))),
      throwsA(isA<TravelPlanLimitException>()),
    );
    expect(await repository.listVisible(), hasLength(maxTravelPlans));
  });

  test('removes one malformed row while preserving valid plans', () async {
    final valid = await repository.create(_draft(DateTime.utc(2026, 8, 10)));
    final external = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await external.insert('travel_plans', {
      'destination_code': 'retired-city-code',
      'departure_at_utc_ms': DateTime.utc(2026, 8, 12).millisecondsSinceEpoch,
      'reminder_minutes': 0,
      'notification_id': travelNotificationIdMax,
      'sync_state': TravelNotificationSyncState.none.name,
      'created_at_utc_ms': now.millisecondsSinceEpoch,
      'updated_at_utc_ms': now.millisecondsSinceEpoch,
    });
    await external.close();

    final recovered = await repository.listAll();

    expect(recovered.map((plan) => plan.id), [valid.id]);
    final verification = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final countRows = await verification.rawQuery(
      'SELECT COUNT(*) AS count FROM travel_plans WHERE destination_code = ?',
      ['retired-city-code'],
    );
    final malformedCount = countRows.single['count'];
    await verification.close();
    expect(malformedCount, 0);
  });

  test('does not open a fallback database when directory protection fails', () {
    final failingRepository = SqfliteTravelPlanRepository(
      factory: databaseFactoryFfi,
      databaseDirectory: () async {
        throw StateError('storage protection failed');
      },
      now: () => now,
    );

    expect(failingRepository.listAll(), throwsStateError);
  });
}

TravelPlanDraft _draft(
  DateTime departureAtUtc, {
  TravelReminder reminder = TravelReminder.none,
}) {
  return TravelPlanDraft(
    cityCode: 'tokyo',
    departureAtUtc: departureAtUtc,
    reminder: reminder,
  );
}
