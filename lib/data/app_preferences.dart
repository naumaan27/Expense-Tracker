import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// Key-value preference store backed by an on-device SQLite table.
/// Survives app restarts and doesn't require Drift schema bumps.
class AppPreferencesRepository {
  AppPreferencesRepository(this._db);

  final AppDatabase _db;
  bool _initialized = false;
  final _changeController = StreamController<void>.broadcast();

  Future<void> _ensureTable() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS app_kv_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    _initialized = true;
  }

  Stream<bool> watchBool(String key, {bool defaultValue = false}) async* {
    await _ensureTable();
    yield await getBool(key, defaultValue: defaultValue);
    yield* _changeController.stream.asyncMap((_) => getBool(key, defaultValue: defaultValue));
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _ensureTable();
    final row = await _db
        .customSelect(
          'SELECT value FROM app_kv_preferences WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    if (row == null) return defaultValue;
    final val = row.data['value'] as String?;
    return val == 'true' || val == '1';
  }

  Future<void> setBool(String key, bool value) async {
    await _ensureTable();
    await _db.customInsert(
      '''
      INSERT OR REPLACE INTO app_kv_preferences (key, value)
      VALUES (?, ?)
      ''',
      variables: [
        Variable.withString(key),
        Variable.withString(value ? 'true' : 'false'),
      ],
    );
    _changeController.add(null);
  }
}

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((ref) {
  final db = ref.watch(dbProvider);
  return AppPreferencesRepository(db);
});

/// Preference for whether to use the native Android keyboard for amount inputs
/// instead of the in-app custom numpad. Defaults to true as requested.
final useSystemKeyboardProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(appPreferencesRepositoryProvider);
  return repo.watchBool('use_system_keyboard', defaultValue: true);
});
