import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../audio/audio_sources.dart';
import '../audio/bundled_audio_sources.dart';
import '../models/audio_models.dart';

class AudioManifestService {
  final ManifestSource _manifestSource;
  final AudioSourceResolver _audioSourceResolver;

  Map<String, List<ScriptVariant>>? _cachedScriptBank;
  Map<String, Map<String, Map<String, double>>>? _cachedDurations;
  bool _isDeveloperMode = false;
  Map<String, dynamic>? _cachedStagedChanges;

  AudioManifestService({
    ManifestSource? manifestSource,
    AudioSourceResolver? audioSourceResolver,
  })  : _manifestSource = manifestSource ?? const BundledManifestSource(),
        _audioSourceResolver =
            audioSourceResolver ?? const BundledAudioSourceResolver();

  bool get isDeveloperMode => _isDeveloperMode;

  Future<void> setDeveloperMode(bool enabled) async {
    _isDeveloperMode = enabled;
    if (enabled && _cachedStagedChanges == null) {
      await loadStagedChanges();
    }
  }

  int get stagedVariantsCount {
    if (_cachedStagedChanges == null) return 0;
    final variants = _cachedStagedChanges!['variants'];
    if (variants is Map) return variants.length;
    return 0;
  }

  Map<String, dynamic>? get stagedChanges => _cachedStagedChanges;

  @visibleForTesting
  void setMockStagedChanges(Map<String, dynamic>? data) {
    _cachedStagedChanges = data;
  }

  /// Loads staged changes from the injected [ManifestSource].
  Future<void> loadStagedChanges() async {
    try {
      final jsonStr = await _manifestSource.loadStagedChangesJson();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _cachedStagedChanges = data;
        debugPrint(
          '[AudioManifestService] Loaded staged changes with $stagedVariantsCount variants.',
        );
      }
    } catch (e) {
      debugPrint('[AudioManifestService] Error loading staged changes: $e');
    }
  }

  /// Loads session manifest, audio durations, and staged changes from [ManifestSource].
  Future<void> initialize({bool? developerMode}) async {
    if (developerMode != null) {
      _isDeveloperMode = developerMode;
    }

    if (_cachedScriptBank != null && _cachedDurations != null) {
      if (_isDeveloperMode && _cachedStagedChanges == null) {
        await loadStagedChanges();
      }
      return;
    }

    try {
      final manifestJson = await _manifestSource.loadSessionManifestJson();
      final Map<String, dynamic> manifestMap = jsonDecode(manifestJson);
      final manifest = SessionManifest.fromJson(manifestMap);
      _cachedScriptBank = manifest.scriptBank;

      final durationsJson = await _manifestSource.loadAudioDurationsJson();
      final Map<String, dynamic> durMap = jsonDecode(durationsJson);

      final parsedDurations = <String, Map<String, Map<String, double>>>{};
      durMap.forEach((voiceKey, segsRaw) {
        final vNorm = voiceKey.toLowerCase();
        parsedDurations[vNorm] = {};
        if (segsRaw is Map<String, dynamic>) {
          segsRaw.forEach((segCode, varsRaw) {
            parsedDurations[vNorm]![segCode] = {};
            if (varsRaw is Map<String, dynamic>) {
              varsRaw.forEach((varCode, secVal) {
                parsedDurations[vNorm]![segCode]![varCode] =
                    (secVal as num).toDouble();
              });
            }
          });
        }
      });
      _cachedDurations = parsedDurations;

      if (_isDeveloperMode) {
        await loadStagedChanges();
      }
    } catch (e) {
      debugPrint('[AudioManifestService] Error initializing audio manifests: $e');
      _cachedScriptBank ??= {};
      _cachedDurations ??= {};
    }
  }

  /// Returns script variants for a segment code (e.g. 'S01').
  /// When Developer Mode is on, staged text overrides are applied.
  List<ScriptVariant> getVariantsForSegment(String segmentCode) {
    final list = _cachedScriptBank?[segmentCode] ?? [];
    if (!_isDeveloperMode || _cachedStagedChanges == null) {
      return list;
    }

    final variantsMap = _cachedStagedChanges!['variants'];
    if (variantsMap is! Map<String, dynamic>) {
      return list;
    }

    return list.map((v) {
      final key = '${segmentCode}_${v.variantId}';
      final staged = variantsMap[key];
      if (staged is Map<String, dynamic>) {
        return ScriptVariant(
          variantId: v.variantId,
          variantName: v.variantName,
          active: v.active,
          text: staged['text'] as String? ?? v.text,
          wordCount: (staged['word_count'] as num?)?.toInt() ?? v.wordCount,
        );
      }
      return v;
    }).toList();
  }

  /// Checks if a staged replacement exists for this variant.
  bool hasStagedAudio({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    if (!_isDeveloperMode || _cachedStagedChanges == null) return false;
    final key = '${segmentCode}_$variantId';
    final staged = _cachedStagedChanges!['variants']?[key];
    if (staged is Map<String, dynamic>) {
      final durations = staged['durations'];
      if (durations is Map<String, dynamic>) {
        final vNorm = voice.toLowerCase();
        return durations.containsKey(vNorm);
      }
      return true;
    }
    return false;
  }

  /// Returns the exact audio duration for a voice, segment code, and variant.
  /// When in Developer Mode, staged durations take precedence.
  double getAudioDuration({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    final vNorm = voice.toLowerCase();
    if (_isDeveloperMode && _cachedStagedChanges != null) {
      final key = '${segmentCode}_$variantId';
      final staged = _cachedStagedChanges!['variants']?[key];
      if (staged is Map<String, dynamic>) {
        final durations = staged['durations'];
        if (durations is Map<String, dynamic>) {
          final dur = durations[vNorm];
          if (dur != null) {
            final sec = (dur as num).toDouble();
            if (sec > 0) return sec;
          }
        }
      }
    }

    final sec = _cachedDurations?[vNorm]?[segmentCode]?[variantId];
    if (sec != null && sec > 0) return sec;
    // Default fallback based on segment type
    return segmentCode == 'S16' ? 4.5 : 10.0;
  }

  /// Resolves the playback [ResolvedAudio] for a voice clip, applying staged
  /// Developer Mode overrides when active.
  ResolvedAudio resolveVoiceAudio({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    final useStaged = _isDeveloperMode &&
        hasStagedAudio(
          voice: voice,
          segmentCode: segmentCode,
          variantId: variantId,
        );
    return _audioSourceResolver.resolveVoiceClip(
      voiceId: voice,
      segmentCode: segmentCode,
      variantId: variantId,
      useStagedOverride: useStaged,
    );
  }

  /// Resolves the debug path/URI label for a voice persona clip.
  String getAudioAssetPath({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    return resolveVoiceAudio(
      voice: voice,
      segmentCode: segmentCode,
      variantId: variantId,
    ).debugLabel;
  }
}
