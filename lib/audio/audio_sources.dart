import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/audio_models.dart';

/// Resolved playback source paired with a display/debug label (e.g., asset path or URL).
@immutable
class ResolvedAudio {
  final Source source;
  final String debugLabel;

  const ResolvedAudio({
    required this.source,
    required this.debugLabel,
  });
}

/// Abstract loader for meditation script banks, clip durations, and staged overrides.
abstract class ManifestSource {
  Future<String> loadSessionManifestJson();
  Future<String> loadAudioDurationsJson();
  Future<String?> loadStagedChangesJson();
}

/// Synchronous audio clip resolver so Web/PWA user-gesture priming and
/// dual-player playback stay independent of bundled asset assumptions.
abstract class AudioSourceResolver {
  ResolvedAudio resolveVoiceClip({
    required String voiceId,
    required String segmentCode,
    required String variantId,
    bool useStagedOverride = false,
  });

  ResolvedAudio resolveBellClip(AudioSegment bell);

  /// Must resolve synchronously inside the "Begin Practice" user gesture on Web/PWA.
  ResolvedAudio resolveSilenceKeepAlive();

  ResolvedAudio resolveAudioReference(String reference);
}

/// Deterministic in-memory [ManifestSource] for unit and widget tests.
class InMemoryManifestSource implements ManifestSource {
  final String sessionManifestJson;
  final String audioDurationsJson;
  final String? stagedChangesJson;

  const InMemoryManifestSource({
    required this.sessionManifestJson,
    required this.audioDurationsJson,
    this.stagedChangesJson,
  });

  @override
  Future<String> loadSessionManifestJson() async => sessionManifestJson;

  @override
  Future<String> loadAudioDurationsJson() async => audioDurationsJson;

  @override
  Future<String?> loadStagedChangesJson() async => stagedChangesJson;
}
