import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const updateChannelStorageKey = 'biberon_ananas_update_channel_v1';

enum UpdateChannel {
  stable('Stable'),
  beta('Bêta');

  const UpdateChannel(this.label);

  final String label;

  static UpdateChannel fromStorage(String? value) =>
      value == UpdateChannel.beta.name
      ? UpdateChannel.beta
      : UpdateChannel.stable;
}

class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.downloadUrl,
    required this.body,
  });

  final String tagName;
  final String downloadUrl;
  final String body;

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] is List<dynamic>
        ? json['assets'] as List<dynamic>
        : const <dynamic>[];
    final apk = assets.whereType<Map<String, dynamic>>().firstWhere(
      (asset) => (asset['browser_download_url'] as String? ?? '')
          .toLowerCase()
          .endsWith('.apk'),
      orElse: () => const <String, dynamic>{},
    );
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      downloadUrl: apk['browser_download_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

String logicalBuildNumber(PackageInfo info) {
  final number = int.tryParse(info.buildNumber);
  return number == null || number < 10000
      ? info.buildNumber
      : (number % 100).toString();
}

class UpdateChecker {
  UpdateChecker({
    required this.owner,
    required this.repo,
    this.client,
    this.packageInfoProvider,
    this.channel = UpdateChannel.stable,
  });

  final String owner;
  final String repo;
  final http.Client? client;
  final Future<PackageInfo?> Function()? packageInfoProvider;
  UpdateChannel channel;

  Uri get _uri => Uri.https(
    'api.github.com',
    channel == UpdateChannel.stable
        ? '/repos/$owner/$repo/releases/latest'
        : '/repos/$owner/$repo/releases',
    {
      if (channel == UpdateChannel.beta) 'per_page': '20',
      'cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );

  Future<GitHubRelease?> checkForUpdate() async {
    final requestClient = client ?? http.Client();
    try {
      final info =
          await (packageInfoProvider == null
                  ? PackageInfo.fromPlatform()
                  : packageInfoProvider!())
              .timeout(const Duration(seconds: 5));
      if (info == null) return null;
      final response = await requestClient
          .get(
            _uri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final releases = channel == UpdateChannel.stable
          ? [
              if (decoded is Map<String, dynamic>)
                GitHubRelease.fromJson(decoded),
            ]
          : decoded is List
          ? decoded
                .whereType<Map<String, dynamic>>()
                .where((release) => release['draft'] != true)
                .map(GitHubRelease.fromJson)
                .toList()
          : <GitHubRelease>[];
      final current = _Version.parse(info.version, logicalBuildNumber(info));
      if (current == null) return null;
      final candidates =
          releases
              .where(
                (release) =>
                    release.downloadUrl.isNotEmpty &&
                    _Version.parseTag(release.tagName) != null,
              )
              .toList()
            ..sort(
              (a, b) => _Version.parseTag(
                b.tagName,
              )!.compareTo(_Version.parseTag(a.tagName)!),
            );
      for (final release in candidates) {
        if (_Version.parseTag(release.tagName)!.compareTo(current) > 0) {
          return release;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) requestClient.close();
    }
  }

  Future<void> downloadAndInstall(
    BuildContext context,
    GitHubRelease release, {
    required VoidCallback onInstallComplete,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final path = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadDialog(
          download: (onProgress) => _download(release.downloadUrl, onProgress),
        ),
      );
      if (!context.mounted || path == null) return;
      final installed = await FlutterAppInstaller().installApk(filePath: path);
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            installed
                ? 'Installation lancée. Confirmez-la dans Android.'
                : 'Autorisez Biberon Ananas à installer des applications dans les réglages Android.',
          ),
          backgroundColor: installed ? Colors.green : Colors.red,
        ),
      );
      if (installed) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (context.mounted) onInstallComplete();
      }
    } catch (error) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Impossible d’installer la mise à jour : $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _download(
    String url,
    void Function(int received, int total) onProgress,
  ) async {
    final downloadClient = http.Client();
    IOSink? sink;
    try {
      final response = await downloadClient
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/biberon-ananas-update.apk');
      sink = file.openWrite();
      final total = response.contentLength ?? -1;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return file.path;
    } catch (_) {
      return null;
    } finally {
      await sink?.close();
      downloadClient.close();
    }
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static _Version? parse(String version, String build) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version.trim());
    if (match == null) return null;
    return _Version(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      int.tryParse(build.trim()) ?? 0,
    );
  }

  static _Version? parseTag(String tag) {
    final parts = tag.trim().replaceFirst(RegExp(r'^v'), '').split('+');
    if (parts.length > 2) return null;
    return parse(parts[0], parts.length == 2 ? parts[1] : '0');
  }

  @override
  int compareTo(_Version other) {
    for (final (left, right) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
      (build, other.build),
    ]) {
      final difference = left.compareTo(right);
      if (difference != 0) return difference;
    }
    return 0;
  }
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.download});

  final Future<String?> Function(void Function(int, int)) download;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final path = await widget.download((received, total) {
      if (mounted) {
        setState(() => _progress = total > 0 ? received / total : null);
      }
    });
    if (!mounted) return;
    setState(() => _finished = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mise à jour disponible'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Téléchargement de la nouvelle version…'),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress),
        if (_finished) ...[
          const SizedBox(height: 8),
          const Text('Téléchargement terminé.'),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _finished ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
    ],
  );
}
