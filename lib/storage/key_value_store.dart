/// Pure key-value storage port matching `ScopedPreferences.forModule` surface
/// (`villagers_ally/mobile`) so standalone and embedded host stores swap cleanly.
abstract class KeyValueStore {
  String? getString(String key);
  Future<bool> setString(String key, String value);

  bool? getBool(String key);
  Future<bool> setBool(String key, bool value);

  int? getInt(String key);
  Future<bool> setInt(String key, int value);

  double? getDouble(String key);
  Future<bool> setDouble(String key, double value);

  List<String>? getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);

  Future<bool> remove(String key);
}

/// Deterministic in-memory [KeyValueStore] for unit and widget tests.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _data;

  InMemoryKeyValueStore([Map<String, Object>? initialValues])
      : _data = initialValues != null
            ? _copyInitialValues(initialValues)
            : <String, Object>{};

  static Map<String, Object> _copyInitialValues(Map<String, Object> source) {
    final copy = <String, Object>{};
    source.forEach((key, value) {
      if (value is List<String>) {
        copy[key] = List<String>.from(value);
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  @override
  String? getString(String key) {
    final val = _data[key];
    return val is String ? val : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) {
    final val = _data[key];
    return val is bool ? val : null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) {
    final val = _data[key];
    return val is int ? val : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) {
    final val = _data[key];
    return val is double ? val : null;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) {
    final val = _data[key];
    return val is List<String> ? List<String>.unmodifiable(val) : null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = List<String>.from(value);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }
}
