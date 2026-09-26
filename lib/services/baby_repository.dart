import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/baby.dart';
import '../models/baby_event.dart';

const babiesStorageKey = 'biberon_ananas_babies_v1';
const eventsStorageKey = 'biberon_ananas_events_v1';
const activeBabyStorageKey = 'biberon_ananas_active_baby_v1';

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
    }
  }
}
