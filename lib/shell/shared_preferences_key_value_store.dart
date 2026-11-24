import 'package:shared_preferences/shared_preferences.dart';

import '../storage/key_value_store.dart';

/// [KeyValueStore] backed by `SharedPreferences` for standalone Set&Sit mode.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  final SharedPreferences _prefs;

  const SharedPreferencesKeyValueStore(this._prefs);

  /// Opens the platform `SharedPreferences` instance and wraps it.
  static Future<SharedPreferencesKeyValueStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesKeyValueStore(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  double? getDouble(String key) => _prefs.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);
}

/// [KeyValueStore] that buffers reads/writes in memory until [SharedPreferences]
/// attaches, keeping frame-1 rendering synchronous when mounted bare (e.g. `const SetAndSitApp()`).
class DeferredSharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferences? _prefs;
  final Map<String, Object?> _pending = <String, Object?>{};
  Future<void>? _attachFuture;

  bool get isAttached => _prefs != null;

  /// Attaches an already-resolved [SharedPreferences] instance and flushes pending writes.
  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_pending.isEmpty) return;
    final entries = Map<String, Object?>.from(_pending);
    _pending.clear();
    for (final entry in entries.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) {
        await prefs.remove(key);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
    }
  }

  /// Resolves `SharedPreferences.getInstance()` once and attaches it.
  Future<void> open() {
    return _attachFuture ??= () async {
      final prefs = await SharedPreferences.getInstance();
      await attach(prefs);
    }();
  }

  @override
  String? getString(String key) {
    if (_pending.containsKey(key)) {
      final val = _pending[key];
      return val is String ? val : null;
    }
    return _prefs?.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.setString(key, value);
    }
    _pending[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) {
    if (_pending.containsKey(key)) {
      final val = _pending[key];
      return val is bool ? val : null;
    }
    return _prefs?.getBool(key);
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.setBool(key, value);
    }
    _pending[key] = value;
    return true;
  }

  @override
  int? getInt(String key) {
    if (_pending.containsKey(key)) {
      final val = _pending[key];
      return val is int ? val : null;
    }
    return _prefs?.getInt(key);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.setInt(key, value);
    }
    _pending[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) {
    if (_pending.containsKey(key)) {
      final val = _pending[key];
      return val is double ? val : null;
    }
    return _prefs?.getDouble(key);
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.setDouble(key, value);
    }
    _pending[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) {
    if (_pending.containsKey(key)) {
      final val = _pending[key];
      return val is List<String> ? List<String>.unmodifiable(val) : null;
    }
    return _prefs?.getStringList(key);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.setStringList(key, value);
    }
    _pending[key] = List<String>.from(value);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.remove(key);
    }
    _pending[key] = null;
    return true;
  }
}
