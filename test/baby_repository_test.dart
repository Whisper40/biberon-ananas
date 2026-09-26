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
}
