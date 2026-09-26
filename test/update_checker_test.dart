import 'dart:convert';

import 'package:biberon_ananas/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo appInfo({String version = '1.0.0', String build = '1'}) =>
    PackageInfo(
      appName: 'Biberon Ananas',
      packageName: 'com.biberon.biberon_ananas',
      version: version,
      buildNumber: build,
      buildSignature: '',
    );

void main() {
  test(
    'cherche la release stable et ignore une version déjà installée',
    () async {
      late Uri uri;
      final checker = UpdateChecker(
        owner: 'Whisper40',
        repo: 'biberon-ananas',
        client: MockClient((request) async {
          uri = request.url;
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.0.2+1',
              'assets': [
                {'browser_download_url': 'https://example.com/biberon.apk'},
              ],
            }),
            200,
          );
        }),
        packageInfoProvider: () async => appInfo(),
      );
      final release = await checker.checkForUpdate();
      expect(uri.path, '/repos/Whisper40/biberon-ananas/releases/latest');
      expect(uri.queryParameters['cache_bust'], isNotNull);
      expect(release?.tagName, 'v1.0.2+1');
    },
  );

  test(
    'choisit la version bêta la plus élevée et ignore les brouillons',
    () async {
      final checker = UpdateChecker(
        owner: 'Whisper40',
        repo: 'biberon-ananas',
        channel: UpdateChannel.beta,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.0.0+2',
                'draft': false,
                'assets': [
                  {'browser_download_url': 'https://example.com/old.apk'},
                ],
              },
              {
                'tag_name': 'v1.0.0+8',
                'draft': true,
                'assets': [
                  {'browser_download_url': 'https://example.com/draft.apk'},
                ],
              },
              {
                'tag_name': 'v1.0.1+3',
                'draft': false,
                'assets': [
                  {'browser_download_url': 'https://example.com/new.apk'},
                ],
              },
            ]),
            200,
          ),
        ),
        packageInfoProvider: () async => appInfo(),
      );
      final release = await checker.checkForUpdate();
      expect(release?.tagName, 'v1.0.1+3');
      expect(release?.downloadUrl, 'https://example.com/new.apk');
    },
  );

  test('retourne null quand aucune APK plus récente n’existe', () async {
    final checker = UpdateChecker(
      owner: 'Whisper40',
      repo: 'biberon-ananas',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0+1',
            'assets': [
              {'browser_download_url': 'https://example.com/current.apk'},
            ],
          }),
          200,
        ),
      ),
      packageInfoProvider: () async => appInfo(),
    );
    expect(await checker.checkForUpdate(), isNull);
  });
}
