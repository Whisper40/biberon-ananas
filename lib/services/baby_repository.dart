import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/baby.dart';
import '../models/baby_event.dart';

const babiesStorageKey = 'biberon_ananas_babies_v1';
const eventsStorageKey = 'biberon_ananas_events_v1';
const activeBabyStorageKey = 'biberon_ananas_active_baby_v1';

class BabyBackup {
  const BabyBackup({
    required this.babies,
    required this.events,
    required this.activeBabyId,
  });

  final List<Baby> babies;
  final List<BabyEvent> events;
  final String? activeBabyId;
}

class BabyRepository {
  BabyRepository({SharedPreferences? preferences}) {
    _preferences = preferences;
  }

  SharedPreferences? _preferences;
  final List<Baby> _babies = [];
  final List<BabyEvent> _events = [];
  String? _activeBabyId;

  List<Baby> get babies => List.unmodifiable(_babies);
  List<BabyEvent> get events => List.unmodifiable(_events);
  Baby? get activeBaby => _babies.cast<Baby?>().firstWhere(
    (baby) => baby?.id == _activeBabyId,
    orElse: () => _babies.isEmpty ? null : _babies.first,
  );

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
    _babies
      ..clear()
      ..addAll(
        _decodeList(_preferences!.getString(babiesStorageKey), Baby.fromJson),
      );
    _events
      ..clear()
      ..addAll(
        _decodeList(
          _preferences!.getString(eventsStorageKey),
          BabyEvent.fromJson,
        ),
      );
    _activeBabyId = _preferences!.getString(activeBabyStorageKey);
    if (!_babies.any((baby) => baby.id == _activeBabyId)) {
      _activeBabyId = _babies.isEmpty ? null : _babies.first.id;
    }
  }

  List<T> _decodeList<T>(
    String? source,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (source == null || source.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return <T>[];
      return decoded.whereType<Map<String, dynamic>>().map(decode).toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> addBaby(Baby baby) async {
    _babies.add(baby);
    _activeBabyId ??= baby.id;
    await _persist();
  }

  Future<void> updateBaby(Baby baby) async {
    final index = _babies.indexWhere((candidate) => candidate.id == baby.id);
    if (index < 0) return;
    _babies[index] = baby;
    await _persist();
  }

  Future<void> setActiveBaby(String id) async {
    if (!_babies.any((baby) => baby.id == id)) return;
    _activeBabyId = id;
    await _preferences!.setString(activeBabyStorageKey, id);
  }

  Future<void> saveEvent(BabyEvent event) async {
    if (!_babies.any((baby) => baby.id == event.babyId)) {
      throw StateError(
        'Impossible d’enregistrer un événement sans enfant associé.',
      );
    }
    final index = _events.indexWhere((candidate) => candidate.id == event.id);
    if (index == -1) {
      _events.add(event);
    } else {
      _events[index] = event;
    }
    await _persist();
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((event) => event.id == id);
    await _persist();
  }

  List<BabyEvent> eventsForBaby(String babyId) =>
      _events.where((event) => event.babyId == babyId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  String exportJson() {
    final payload = <String, Object?>{
      'format': 'biberon_ananas_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeBabyId': activeBaby?.id,
      'babies': _babies.map((baby) => baby.toJson()).toList(),
      'events': _events.map((event) => event.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  BabyBackup parseBackupData(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'biberon_ananas_backup' ||
        decoded['version'] != 1) {
      throw const FormatException(
        'Ce fichier n’est pas une sauvegarde Biberon Ananas reconnue.',
      );
    }
    final rawBabies = decoded['babies'];
    final rawEvents = decoded['events'];
    if (rawBabies is! List || rawEvents is! List) {
      throw const FormatException(
        'La sauvegarde doit contenir les profils et les événements.',
      );
    }

    try {
      final babies = rawBabies.map((raw) {
        if (raw is! Map) throw const FormatException('Profil enfant invalide.');
        return Baby.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
      final events = rawEvents.map((raw) {
        if (raw is! Map) throw const FormatException('Événement invalide.');
        return BabyEvent.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
      final babyIds = babies.map((baby) => baby.id).toSet();
      if (babyIds.length != babies.length) {
        throw const FormatException(
          'La sauvegarde contient des profils en double.',
        );
      }
      final eventIds = events.map((event) => event.id).toSet();
      if (eventIds.length != events.length) {
        throw const FormatException(
          'La sauvegarde contient des événements en double.',
        );
      }
      if (events.any((event) => !babyIds.contains(event.babyId))) {
        throw const FormatException(
          'Un événement de la sauvegarde ne correspond à aucun profil enfant.',
        );
      }
      final activeBabyId = decoded['activeBabyId'] as String?;
      if (activeBabyId != null && !babyIds.contains(activeBabyId)) {
        throw const FormatException(
          'Le profil actif indiqué dans la sauvegarde est introuvable.',
        );
      }
      return BabyBackup(
        babies: babies,
        events: events,
        activeBabyId: activeBabyId,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'La sauvegarde contient des profils ou événements illisibles.',
      );
    }
  }

  Future<void> restoreBackup(BabyBackup backup) async {
    final babyIds = backup.babies.map((baby) => baby.id).toSet();
    if (babyIds.length != backup.babies.length ||
        backup.events.any((event) => !babyIds.contains(event.babyId))) {
      throw const FormatException(
        'La sauvegarde contient des données incohérentes.',
      );
    }
    _babies
      ..clear()
      ..addAll(backup.babies);
    _events
      ..clear()
      ..addAll(backup.events);
    _activeBabyId =
        backup.activeBabyId != null && babyIds.contains(backup.activeBabyId)
        ? backup.activeBabyId
        : _babies.firstOrNull?.id;
    await _persist();
  }

  Future<void> _persist() async {
    await _preferences!.setString(
      babiesStorageKey,
      jsonEncode(_babies.map((baby) => baby.toJson()).toList()),
    );
    await _preferences!.setString(
      eventsStorageKey,
      jsonEncode(_events.map((event) => event.toJson()).toList()),
    );
    if (_activeBabyId != null) {
      await _preferences!.setString(activeBabyStorageKey, _activeBabyId!);
    } else {
      await _preferences!.remove(activeBabyStorageKey);
    }
  }
}
