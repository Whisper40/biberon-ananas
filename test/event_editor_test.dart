import 'package:biberon_ananas/models/baby_event.dart';
import 'package:biberon_ananas/screens/event_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('minuteur demande confirmation avant de valider une tétée', (
    tester,
  ) async {
    BabyEvent? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<BabyEvent>(
                  MaterialPageRoute(
                    builder: (_) => const EventEditorPage(
                      babyId: 'baby-1',
                      type: BabyEventType.breastfeeding,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('00:00:00'), findsOneWidget);

    await tester.tap(find.text('Démarrer'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.tap(find.text('Arrêter'));
    await tester.pumpAndSettle();
    expect(find.text('Terminer cette session ?'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Le minuteur est en cours.'), findsOneWidget);

    await tester.tap(find.text('Arrêter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arrêter').last);
    await tester.pumpAndSettle();
    expect(find.text('Valider et ouvrir le journal'), findsOneWidget);
    await tester.tap(find.text('Valider et ouvrir le journal'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.type, BabyEventType.breastfeeding);
    expect(saved!.durationSeconds, greaterThanOrEqualTo(1));
  });

  testWidgets('valide une mesure avec deux décimales de kilogramme', (
    tester,
  ) async {
    BabyEvent? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<BabyEvent>(
                  MaterialPageRoute(
                    builder: (_) => const EventEditorPage(
                      babyId: 'baby-1',
                      type: BabyEventType.weight,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '3,50');
    await tester.tap(find.text('Valider et ouvrir le journal'));
    await tester.pumpAndSettle();

    expect(saved?.type, BabyEventType.weight);
    expect(saved?.measurement, 3.5);
    expect(saved?.startedAt, saved?.createdAt);
  });
}
