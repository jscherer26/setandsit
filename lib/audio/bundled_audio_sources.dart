import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../models/audio_models.dart';
import 'audio_sources.dart';

/// Offline bundled [ManifestSource] reading Set&Sit JSON manifests via [AssetBundle].
class BundledManifestSource implements ManifestSource {
  final AssetBundle? bundle;

  const BundledManifestSource({this.bundle});

  AssetBundle get _effectiveBundle => bundle ?? rootBundle;

  @override
  Future<String> loadSessionManifestJson() {
    return _effectiveBundle.loadString('assets/raw/session_manifest.json');
  }

  @override
  Future<String> loadAudioDurationsJson() {
    return _effectiveBundle.loadString('assets/raw/audio_durations.json');
  }

  @override
  Future<String?> loadStagedChangesJson() async {
    try {
      return await _effectiveBundle.loadString('assets/audio/changes_manifest.json');
    } catch (_) {
      try {
        return await _effectiveBundle.loadString('assets/raw/staged_changes.json');
      } catch (_) {
        return null;
      }
    }
  }
}

/// Offline bundled [AudioSourceResolver] mapping voice clips, bells, and silence
/// keep-alive to Flutter `AssetSource` entries.
class BundledAudioSourceResolver implements AudioSourceResolver {
  const BundledAudioSourceResolver();

  static String _toAssetSourcePath(String rawPath) {
    var clean = rawPath.startsWith('assets/') ? rawPath.substring(7) : rawPath;
    if (clean.startsWith('audio/voices/')) {
      clean = clean.replaceFirst('audio/voices/', 'audio/');
    }
    return clean;
  }

  @override
  ResolvedAudio resolveVoiceClip({
    required String voiceId,
    required String segmentCode,
    required String variantId,
    bool useStagedOverride = false,
  }) {
    final vNorm = voiceId.trim().toLowerCase();
    final assetPath = useStagedOverride
        ? 'assets/audio/$vNorm/changes/${segmentCode}_$variantId.mp3'
        : 'assets/audio/$vNorm/${segmentCode}_$variantId.mp3';
    return ResolvedAudio(
      source: AssetSource(_toAssetSourcePath(assetPath)),
      debugLabel: assetPath,
    );
  }

  @override
  ResolvedAudio resolveBellClip(AudioSegment bell) {
    return ResolvedAudio(
      source: AssetSource(_toAssetSourcePath(bell.filePath)),
      debugLabel: bell.filePath,
    );
  }

  @override
  ResolvedAudio resolveSilenceKeepAlive() {
    const assetPath = 'assets/audio/silence.mp3';
    return ResolvedAudio(
      source: AssetSource('audio/silence.mp3'),
      debugLabel: assetPath,
    );
  }

  @override
  ResolvedAudio resolveAudioReference(String reference) {
    return ResolvedAudio(
      source: AssetSource(_toAssetSourcePath(reference)),
      debugLabel: reference,
    );
  }
}
