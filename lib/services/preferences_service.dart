import 'dart:convert';
import 'package:material_ui/material_ui.dart';

import '../data/bell_data.dart';
import '../models/audio_models.dart';
import '../models/display_preferences.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../storage/key_value_store.dart';

class PreferencesService {
  static const String _keyPractices = 'set_and_sit_practices';
  static const String _keyVoices = 'set_and_sit_voices';
  static const String _keyDeveloperMode = 'pref_developer_mode';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyFontSizePx = 'pref_font_size_px';

  static const List<int> allowedFontSizes = DisplayPreferences.allowedFontSizes;
  static const int defaultFontSizePx = DisplayPreferences.defaultFontSizePx;

  final KeyValueStore _store;

  const PreferencesService(this._store);

  /// Normalizes a requested font size to the nearest 2px stop in [14..24].
  static int normalizeFontSizePx(int? value) =>
      DisplayPreferences.normalizeFontSizePx(value);

  /// Loads the persisted [ThemeMode], defaulting to [ThemeMode.system].
  Future<ThemeMode> loadThemeMode() async {
    try {
      final raw = _store.getString(_keyThemeMode);
      switch (raw) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    } catch (_) {
      return ThemeMode.system;
    }
  }

  /// Persists the selected [ThemeMode].
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _store.setString(_keyThemeMode, value);
    } catch (e) {
      debugPrint('[PreferencesService] Error saving theme mode: $e');
    }
  }

  /// Loads the persisted display font size in px (14–24 in 2px stops, default 18).
  Future<int> loadFontSizePx() async {
    try {
      return normalizeFontSizePx(_store.getInt(_keyFontSizePx));
    } catch (_) {
      return defaultFontSizePx;
    }
  }

  /// Persists the selected display font size in px (normalized to 14–24, 2px stops).
  Future<void> saveFontSizePx(int fontSizePx) async {
    try {
      await _store.setInt(_keyFontSizePx, normalizeFontSizePx(fontSizePx));
    } catch (e) {
      debugPrint('[PreferencesService] Error saving font size: $e');
    }
  }

  /// Returns whether Developer Mode is enabled.
  Future<bool> isDeveloperMode() async {
    return _store.getBool(_keyDeveloperMode) ?? false;
  }

  /// Sets Developer Mode state.
  Future<void> setDeveloperMode(bool enabled) async {
    await _store.setBool(_keyDeveloperMode, enabled);
  }

  /// Ensures Developer Mode always starts as false on fresh application launch.
  Future<void> resetDeveloperModeOnStartup() async {
    try {
      await _store.setBool(_keyDeveloperMode, false);
    } catch (_) {}
  }

  /// Loads voices from local storage, returning defaults if not found.
  /// Automatically purges any retired voices (e.g. legacy 'kia') and migrates storage.
  Future<List<VoiceConfig>> loadVoices() async {
    final raw = _store.getString(_keyVoices);
    if (raw == null) {
      return List<VoiceConfig>.from(VoiceConfig.defaultVoices);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final voices = list
          .map((e) => VoiceConfig.fromJson(e as Map<String, dynamic>))
          .where((v) => v.id.toLowerCase() != 'kia')
          .toList();

      for (final def in VoiceConfig.defaultVoices) {
        if (!voices.any((v) => v.id == def.id)) {
          voices.insert(0, def);
        }
      }

      if (voices.length != list.length) {
        await saveVoices(voices);
      }

      return voices.isNotEmpty
          ? voices
          : List<VoiceConfig>.from(VoiceConfig.defaultVoices);
    } catch (_) {
      return List<VoiceConfig>.from(VoiceConfig.defaultVoices);
    }
  }

  /// Saves the list of voices to local storage.
  Future<void> saveVoices(List<VoiceConfig> voices) async {
    final jsonList = voices.map((v) => v.toJson()).toList();
    await _store.setString(_keyVoices, jsonEncode(jsonList));
  }

  /// Loads practices from local storage, returning defaults if not found.
  Future<List<PracticeConfig>> loadPractices() async {
    final raw = _store.getString(_keyPractices);
    if (raw == null) {
      return List<PracticeConfig>.from(PracticeConfig.defaultPractices);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      var practices = list
          .map((e) => PracticeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      if (practices.isEmpty) {
        return List<PracticeConfig>.from(PracticeConfig.defaultPractices);
      }

      // Sync system practices with updated system defaults (e.g. renamed "Trauma-Sensitive Grounding")
      var changed = false;
      practices = practices.map((p) {
        if (p.isSystem) {
          final sysDefault =
              PracticeConfig.defaultPractices.cast<PracticeConfig?>().firstWhere(
            (def) => def?.id == p.id,
            orElse: () => null,
          );
          if (sysDefault != null &&
              (sysDefault.name != p.name || sysDefault.subtitle != p.subtitle)) {
            changed = true;
            return p.copyWith(
              name: sysDefault.name,
              subtitle: sysDefault.subtitle,
            );
          }
        }
        return p;
      }).toList();

      if (changed) {
        await savePractices(practices);
      }

      return practices;
    } catch (_) {
      return List<PracticeConfig>.from(PracticeConfig.defaultPractices);
    }
  }

  /// Saves the list of practices to local storage.
  Future<void> savePractices(List<PracticeConfig> practices) async {
    final jsonList = practices.map((p) => p.toJson()).toList();
    await _store.setString(_keyPractices, jsonEncode(jsonList));
  }

  Future<void> saveState(SavedState state) async {
    try {
      await _store.setInt('pref_duration', state.practiceDurationMinutes);
      await _store.setDouble(
        'pref_instruction_density',
        state.instructionDensity,
      );
      await _store.setDouble(
        'pref_redirection_density',
        state.redirectionDensity,
      );
      await _store.setInt('pref_prep_delay', state.preparationDelaySeconds);
      await _store.setString('pref_practice_mode', state.practiceMode);
      await _store.setString('pref_selected_bell_id', state.selectedBellId);
      await _store.setString(
        'pref_selected_practice_id',
        state.selectedPracticeId ?? 'focused_calm',
      );
      await _store.setString(
        'pref_selected_practice_name',
        state.selectedPractice,
      );
      await _store.setString(
        'pref_selected_voice_id',
        state.selectedVoiceId ?? 'grace',
      );
      await _store.setInt('pref_selected_voice_idx', state.selectedVoiceIndex);
      await _store.setInt('pref_clock_hour', state.targetClockTimeHour);
      await _store.setInt('pref_clock_minute', state.targetClockTimeMinute);
      await _store.setBool('pref_clock_is_am', state.targetClockTimeIsAm);
    } catch (e) {
      debugPrint('[PreferencesService] Error during disk save: $e');
    }
  }

  Future<SavedState> loadState() async {
    try {
      // Only fall back to the default when the value has never been set.
      // A stored value of 20 is a legitimate user choice and must be preserved.
      var duration = _store.getInt('pref_duration');
      if (duration == null) {
        duration = 3;
        await _store.setInt('pref_duration', 3);
      }
      final instruction = _store.getDouble('pref_instruction_density') ?? 3.0;
      final redirection = _store.getDouble('pref_redirection_density') ?? 3.0;
      // Only fall back to the default when the value has never been set.
      // A stored value of 10 is a legitimate user choice and must be preserved.
      var delay = _store.getInt('pref_prep_delay');
      if (delay == null) {
        delay = 3;
        await _store.setInt('pref_prep_delay', 3);
      }
      final mode = _store.getString('pref_practice_mode') ?? 'Guided';
      final bellId =
          _store.getString('pref_selected_bell_id') ?? 'bell_meditation';
      final practiceId =
          _store.getString('pref_selected_practice_id') ?? 'focused_calm';
      var practiceName =
          _store.getString('pref_selected_practice_name') ?? 'Focused Calm';
      if (practiceName == 'Trauma-Informed Regulation') {
        practiceName = 'Trauma-Sensitive Grounding';
        await _store.setString(
          'pref_selected_practice_name',
          'Trauma-Sensitive Grounding',
        );
      }
      var voiceId = _store.getString('pref_selected_voice_id') ?? 'grace';
      if (voiceId.toLowerCase() == 'kia') {
        voiceId = 'grace';
        await _store.setString('pref_selected_voice_id', 'grace');
      }
      final voiceIdx = _store.getInt('pref_selected_voice_idx') ?? 0;
      final clockHour = _store.getInt('pref_clock_hour') ?? 8;
      final clockMin = _store.getInt('pref_clock_minute') ?? 3;
      final clockIsAm = _store.getBool('pref_clock_is_am') ?? true;

      return SavedState(
        practiceDurationMinutes: duration,
        instructionDensity: instruction,
        redirectionDensity: redirection,
        preparationDelaySeconds: delay,
        practiceMode: mode,
        bells: BellData.createDefaultBells(),
        selectedBellId: bellId,
        selectedPractice: practiceName,
        selectedPracticeId: practiceId,
        selectedVoiceIndex: voiceIdx,
        selectedVoiceId: voiceId,
        targetClockTimeHour: clockHour,
        targetClockTimeMinute: clockMin,
        targetClockTimeIsAm: clockIsAm,
      );
    } catch (e) {
      debugPrint('[PreferencesService] Error during disk load: $e');
      return SavedState(
        practiceDurationMinutes: 3,
        instructionDensity: 3.0,
        redirectionDensity: 3.0,
        preparationDelaySeconds: 3,
        practiceMode: 'Guided',
        bells: BellData.createDefaultBells(),
        selectedBellId: 'bell_meditation',
        selectedPractice: 'Focused Calm',
        selectedPracticeId: 'focused_calm',
        selectedVoiceIndex: 0,
        selectedVoiceId: 'grace',
        targetClockTimeHour: 8,
        targetClockTimeMinute: 3,
        targetClockTimeIsAm: true,
      );
    }
  }
}

class SavedState {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final int preparationDelaySeconds;
  final String practiceMode;
  final List<AudioSegment> bells;
  final String selectedBellId;
  final String selectedPractice;
  final String? selectedPracticeId;
  final int selectedVoiceIndex;
  final String? selectedVoiceId;
  final int targetClockTimeHour;
  final int targetClockTimeMinute;
  final bool targetClockTimeIsAm;

  SavedState({
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    this.preparationDelaySeconds = 3,
    this.practiceMode = 'Guided',
    required this.bells,
    required this.selectedBellId,
    required this.selectedPractice,
    this.selectedPracticeId,
    required this.selectedVoiceIndex,
    this.selectedVoiceId,
    required this.targetClockTimeHour,
    required this.targetClockTimeMinute,
    required this.targetClockTimeIsAm,
  });

  SavedState copyWith({
    int? practiceDurationMinutes,
    double? instructionDensity,
    double? redirectionDensity,
    int? preparationDelaySeconds,
    String? practiceMode,
    List<AudioSegment>? bells,
    String? selectedBellId,
    String? selectedPractice,
    String? selectedPracticeId,
    int? selectedVoiceIndex,
    String? selectedVoiceId,
    int? targetClockTimeHour,
    int? targetClockTimeMinute,
    bool? targetClockTimeIsAm,
  }) {
    return SavedState(
      practiceDurationMinutes:
          practiceDurationMinutes ?? this.practiceDurationMinutes,
      instructionDensity: instructionDensity ?? this.instructionDensity,
      redirectionDensity: redirectionDensity ?? this.redirectionDensity,
      preparationDelaySeconds:
          preparationDelaySeconds ?? this.preparationDelaySeconds,
      practiceMode: practiceMode ?? this.practiceMode,
      bells: bells ?? this.bells,
      selectedBellId: selectedBellId ?? this.selectedBellId,
      selectedPractice: selectedPractice ?? this.selectedPractice,
      selectedPracticeId: selectedPracticeId ?? this.selectedPracticeId,
      selectedVoiceIndex: selectedVoiceIndex ?? this.selectedVoiceIndex,
      selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
      targetClockTimeHour: targetClockTimeHour ?? this.targetClockTimeHour,
      targetClockTimeMinute:
          targetClockTimeMinute ?? this.targetClockTimeMinute,
      targetClockTimeIsAm: targetClockTimeIsAm ?? this.targetClockTimeIsAm,
    );
  }
}
