import 'package:biberon_ananas/models/baby.dart';
import 'package:biberon_ananas/models/baby_event.dart';
import 'package:biberon_ananas/services/baby_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persiste plusieurs enfants, enfant actif et événements CRUD', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = BabyRepository(preferences: preferences);
    await repository.init();
    final first = Baby(
      id: 'first',
      name: 'Léa',
      gender: BabyGender.girl,
      birthDate: DateTime(2026, 1, 10),
    );
    final second = Baby(
      id: 'second',
      name: 'Noé',
      gender: BabyGender.boy,
      birthDate: DateTime(2025, 12, 2),
    );
    await repository.addBaby(first);
    await repository.addBaby(second);
    await repository.setActiveBaby(second.id);

    final event = BabyEvent(
      id: 'feed',
      babyId: second.id,
      type: BabyEventType.breastfeeding,
      startedAt: DateTime(2026, 9, 26, 8),
      createdAt: DateTime(2026, 9, 26, 8, 24),
      durationSeconds: 24 * 60,
      breastSide: BreastSide.right,
    );
    await repository.saveEvent(event);

    final restored = BabyRepository(preferences: preferences);
    await restored.init();
    expect(restored.babies, hasLength(2));
    expect(restored.activeBaby?.name, 'Noé');
    expect(
      restored.eventsForBaby('second').single.breastSide,
      BreastSide.right,
    );

    await restored.saveEvent(
      BabyEvent(
        id: 'feed',
        babyId: second.id,
        type: BabyEventType.bottle,
        startedAt: event.startedAt,
        createdAt: event.createdAt,
        amountMl: 120,
      ),
    );
    expect(restored.events, hasLength(1));
    expect(restored.events.single.amountMl, 120);
    await restored.deleteEvent('feed');
    expect(restored.events, isEmpty);
  });

  test('refuse un événement associé à un enfant inexistant', () async {
    final repository = BabyRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await repository.init();
    expect(
      () => repository.saveEvent(
        BabyEvent(
          id: 'orphan',
          babyId: 'missing',
          type: BabyEventType.bottle,
          startedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'exporte puis restaure tous les profils, événements et enfant actif',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final source = BabyRepository(preferences: preferences);
      await source.init();
      final first = Baby(
        id: 'first',
        name: 'Lina',
        gender: BabyGender.girl,
        birthDate: DateTime(2025, 3, 4),
      );
      final second = Baby(
        id: 'second',
        name: 'Adam',
        gender: BabyGender.boy,
        birthDate: DateTime(2024, 11, 12),
      );
      await source.addBaby(first);
      await source.addBaby(second);
      await source.setActiveBaby(second.id);
      await source.saveEvent(
        BabyEvent(
          id: 'bottle-1',
          babyId: second.id,
          type: BabyEventType.bottle,
          startedAt: DateTime(2026, 9, 26, 9, 30),
          createdAt: DateTime(2026, 9, 26, 9, 31),
          amountMl: 150,
        ),
      );
      await source.saveEvent(
        BabyEvent(
          id: 'weight-1',
          babyId: first.id,
          type: BabyEventType.weight,
          startedAt: DateTime(2026, 9, 25, 11),
          createdAt: DateTime(2026, 9, 25, 11),
          measurement: 4.25,
        ),
      );

      final backup = source.parseBackupData(source.exportJson());
      final destination = BabyRepository(preferences: preferences);
      await destination.init();
      await destination.addBaby(
        Baby(
          id: 'old',
          name: 'Ancien profil',
          gender: BabyGender.girl,
          birthDate: DateTime(2020),
        ),
      );
      await destination.restoreBackup(backup);

      final reloaded = BabyRepository(preferences: preferences);
      await reloaded.init();
      expect(reloaded.babies.map((baby) => baby.id), ['first', 'second']);
      expect(reloaded.activeBaby?.id, 'second');
      expect(reloaded.events, hasLength(2));
      expect(reloaded.eventsForBaby('second').single.amountMl, 150);
      expect(reloaded.eventsForBaby('first').single.measurement, 4.25);
    },
  );

  test(
    'refuse une sauvegarde incohérente sans toucher aux données courantes',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = BabyRepository(preferences: preferences);
      await repository.init();
      final baby = Baby(
        id: 'current',
        name: 'Mia',
        gender: BabyGender.girl,
        birthDate: DateTime(2026),
      );
      await repository.addBaby(baby);
      final invalid = '''
{
  "format": "biberon_ananas_backup",
  "version": 1,
  "activeBabyId": "current",
  "babies": [{"id":"current","name":"Mia","gender":"girl","birthDate":"2026-01-01T00:00:00.000"}],
  "events": [{"id":"orphan","babyId":"absent","type":"bottle","startedAt":"2026-01-01T00:00:00.000","createdAt":"2026-01-01T00:00:00.000"}]
}
''';

      expect(() => repository.parseBackupData(invalid), throwsFormatException);
      expect(repository.babies.single.id, 'current');
      expect(repository.events, isEmpty);
    },
  );
}
