import 'package:biberon_ananas/models/baby_event.dart';
import 'package:biberon_ananas/screens/journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche les 30 derniers jours et les écarts entre événements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final recent = now.subtract(const Duration(minutes: 5));
    final previous = recent.subtract(const Duration(hours: 3));
    final justInsideThirtyDays = now
        .subtract(const Duration(days: 30))
        .add(const Duration(seconds: 1));
    final olderThanThirtyDays = now.subtract(const Duration(days: 31));
    final events = [
      _event('feed', BabyEventType.breastfeeding, recent),
      _event('pump', BabyEventType.pumping, previous),
      _event(
        'bottle',
        BabyEventType.bottle,
        previous.subtract(const Duration(hours: 1)),
      ),
      _event('within-window', BabyEventType.height, justInsideThirtyDays),
      _event('old', BabyEventType.weight, olderThanThirtyDays),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalPage(events: events, onEdit: (_) {}, onDelete: (_) {}),
        ),
      ),
    );

    expect(find.text('30 derniers jours'), findsOneWidget);
    expect(find.byTooltip('Jour précédent'), findsNothing);
    expect(find.byTooltip('Jour suivant'), findsNothing);
    expect(find.byKey(const ValueKey('journal-event-feed')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-event-pump')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-event-bottle')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journal-event-within-window')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('journal-event-old')), findsNothing);
    expect(find.byIcon(Icons.child_care_rounded), findsOneWidget);
    expect(find.textContaining('3 h 00 min depuis'), findsOneWidget);
    expect(find.textContaining('1 h 00 min depuis'), findsOneWidget);
    expect(
      find.textContaining(
        '${previous.day.toString().padLeft(2, '0')}/${previous.month.toString().padLeft(2, '0')}/${previous.year} · ${previous.hour.toString().padLeft(2, '0')}:${previous.minute.toString().padLeft(2, '0')}',
      ),
      findsNWidgets(2),
    );
  });
}

BabyEvent _event(String id, BabyEventType type, DateTime startedAt) =>
    BabyEvent(
      id: id,
      babyId: 'baby',
      type: type,
      startedAt: startedAt,
      createdAt: startedAt,
      durationSeconds:
          type == BabyEventType.breastfeeding || type == BabyEventType.pumping
          ? 600
          : null,
    );
