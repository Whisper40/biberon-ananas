import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_page.dart';
import 'services/baby_repository.dart';
import 'services/update_checker.dart';

const githubOwner = 'Whisper40';
const githubRepo = 'biberon-ananas';
final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final repository = BabyRepository(preferences: preferences);
  await repository.init();
  runApp(
    BiberonApp(
      repository: repository,
      preferences: preferences,
      updateChannel: UpdateChannel.fromStorage(
        preferences.getString(updateChannelStorageKey),
      ),
    ),
  );
}

class BiberonApp extends StatefulWidget {
  const BiberonApp({
    required this.repository,
    this.preferences,
    this.updateChecker,
    this.updateChannel = UpdateChannel.stable,
    super.key,
  });

  final BabyRepository repository;
  final SharedPreferences? preferences;
  final UpdateChecker? updateChecker;
  final UpdateChannel updateChannel;

  @override
  State<BiberonApp> createState() => _BiberonAppState();
}

class _BiberonAppState extends State<BiberonApp> {
  late final UpdateChecker _updateChecker;
  late UpdateChannel _updateChannel;

  @override
  void initState() {
    super.initState();
    _updateChannel = widget.updateChannel;
    _updateChecker =
        widget.updateChecker ??
        UpdateChecker(
          owner: githubOwner,
          repo: githubRepo,
          channel: _updateChannel,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _setUpdateChannel(UpdateChannel channel) async {
    setState(() {
      _updateChannel = channel;
      _updateChecker.channel = channel;
    });
    await widget.preferences?.setString(updateChannelStorageKey, channel.name);
  }

  Future<void> _checkForUpdates() async {
    final release = await _updateChecker.checkForUpdate();
    if (!mounted || release == null) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: Text(
          'La version ${release.tagName} est prête à être installée.\n\n${release.body}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Plus tard'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              _updateChecker.downloadAndInstall(
                context,
                release,
                onInstallComplete: SystemNavigator.pop,
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB9472E);
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Biberon Ananas',
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFFBF8),
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: seed, width: 1.5),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
      ),
      home: HomePage(
        repository: widget.repository,
        updateChannel: _updateChannel,
        onUpdateChannelChanged: _setUpdateChannel,
      ),
    );
  }
}
