// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biberon_ananas/main.dart';
import 'package:biberon_ananas/models/baby.dart';
import 'package:biberon_ananas/models/baby_event.dart';
import 'package:biberon_ananas/services/baby_repository.dart';
import 'package:biberon_ananas/services/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('crée le premier profil avant d’accéder au suivi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = BabyRepository(preferences: preferences);
    await repository.init();
    final checker = UpdateChecker(
      owner: 'Whisper40',
      repo: 'biberon-ananas',
      client: MockClient((_) async => http.Response('', 404)),
      packageInfoProvider: () async => PackageInfo(
        appName: 'Biberon Ananas',
        packageName: 'com.biberon.biberon_ananas',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      ),
    );

    await tester.pumpWidget(
      BiberonApp(
        repository: repository,
        preferences: preferences,
        updateChecker: checker,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Commençons par votre bébé'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Zoé');
    await tester.tap(find.text('Créer le profil'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Zoé'), findsOneWidget);
    expect(find.text('Ajouter un événement'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('valide un biberon et ouvre le journal filtré', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = BabyRepository(preferences: preferences);
    await repository.init();
    await repository.addBaby(
      Baby(
        id: 'baby-1',
        name: 'Milo',
        gender: BabyGender.boy,
        birthDate: DateTime(2026, 1, 1),
      ),
    );
    final checker = UpdateChecker(
      owner: 'Whisper40',
      repo: 'biberon-ananas',
      client: MockClient((_) async => http.Response('', 404)),
      packageInfoProvider: () async => PackageInfo(
        appName: 'Biberon Ananas',
        packageName: 'com.biberon.biberon_ananas',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      ),
    );
    await tester.pumpWidget(
      BiberonApp(
        repository: repository,
        preferences: preferences,
        updateChecker: checker,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Biberon'));
    await tester.tap(find.text('Biberon'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Valider et ouvrir le journal'));
    await tester.tap(find.text('Valider et ouvrir le journal'));
    await tester.pumpAndSettle();

    expect(repository.events, hasLength(1));
    expect(repository.events.single.type, BabyEventType.bottle);
    expect(find.text('Journal'), findsNWidgets(2));
    expect(find.text('Quantité : N/A'), findsOneWidget);
  });
}
