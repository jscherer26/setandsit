import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../audio/audio_sources.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class PracticeScreen extends StatefulWidget {
  final List<SessionItem> sessionQueue;
  final int targetDurationSeconds;
  final int preparationDelaySeconds;
  final int? targetClockHour;
  final int? targetClockMinute;
  final bool? targetClockIsAm;
  final List<SessionItem> Function(int actualTargetSeconds)? onBuildQueue;
  final void Function(List<SessionItem> queue, int targetSeconds)? onPracticeStarted;
  final String selectedMeditationType;
  final AudioSegment? selectedBell;
  final Widget Function()? buildDebugScreen;
  final Widget Function(List<SessionItem> queue, int targetSeconds)? buildDebugScreenWithQueue;
  final VoidCallback onEndSession;
  final VoidCallback? onSessionComplete;
  final bool isDeveloperMode;
  final AudioPlayer? voicePlayer;
  final AudioPlayer? bellPlayer;
  final AudioSourceResolver? audioSourceResolver;
  final DateTime Function()? nowProvider;

  const PracticeScreen({
    super.key,
    required this.sessionQueue,
    required this.targetDurationSeconds,
    this.preparationDelaySeconds = 3,
    this.targetClockHour,
    this.targetClockMinute,
    this.targetClockIsAm,
    this.onBuildQueue,
    this.onPracticeStarted,
    required this.selectedMeditationType,
    this.selectedBell,
    this.buildDebugScreen,
    this.buildDebugScreenWithQueue,
    required this.onEndSession,
    this.onSessionComplete,
    this.isDeveloperMode = false,
    this.voicePlayer,
    this.bellPlayer,
    this.audioSourceResolver,
    this.nowProvider,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Phase 2: Dual AudioPlayer Architecture
  late final AudioPlayer _voicePlayer;
  late final AudioPlayer _bellPlayer;
  late final bool _ownsVoicePlayer;
  late final bool _ownsBellPlayer;
  StreamSubscription? _voiceCompleteSubscription;
  StreamSubscription? _bellCompleteSubscription;
  StreamSubscription? _voiceLogSubscription;
  StreamSubscription? _bellLogSubscription;
  Timer? _countdownTimer;
  Timer? _silenceTimer;
  Timer? _fallbackTimer;
  Timer? _overlapTimer;
  Timer? _preparationTimer;

  bool _isPreparing = false;
  int _preparationSecondsRemaining = 0;
  DateTime? _preparationStartTime;
  bool _isVoiceSegmentPlaying = false;
  bool _isBellSegmentPlaying = false;
  int _playbackGeneration = 0;
  bool _isDisposed = false;
  bool _needsAudioResume = false;

  late List<SessionItem> _activeQueue;
  late int _targetDurationSeconds;
  int _totalSecondsRemaining = 0;
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _isFinished = false;
  int _silenceSecondsRemaining = 0;
  DateTime? _sessionStartTime;
  DateTime? _silenceStartTime;
  DateTime? _activeAudioStartTime;
  int _silenceTotalSeconds = 0;

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  bool _isStale(int generation) =>
      _isDisposed || !mounted || _isFinished || generation != _playbackGeneration;

  SessionItem? get currentItem =>
      (_currentIndex >= 0 && _currentIndex < _activeQueue.length)
          ? _activeQueue[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsVoicePlayer = widget.voicePlayer == null;
    _ownsBellPlayer = widget.bellPlayer == null;
    _voicePlayer = widget.voicePlayer ?? AudioPlayer();
    _bellPlayer = widget.bellPlayer ?? AudioPlayer();
    _activeQueue = List.from(widget.sessionQueue);
    _targetDurationSeconds = widget.targetDurationSeconds;
    _totalSecondsRemaining = widget.targetDurationSeconds;

    // Keep screen awake throughout the entire practice, including S16 and bell decay
    WakelockPlus.enable().catchError((e) {
      debugPrint('[PracticeScreen] Error enabling Wakelock: $e');
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioPlayers();

    if (widget.preparationDelaySeconds > 0) {
      _isPreparing = true;
      _preparationSecondsRemaining = widget.preparationDelaySeconds;
      _preparationStartTime = _now();
      _startPreparationCountdown();
    } else {
      _startActualPractice();
    }
  }

  void _startPreparationCountdown() {
    _preparationTimer?.cancel();
    _preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted || _isFinished || !_isPreparing) {
        timer.cancel();
        return;
      }
      final start = _preparationStartTime;
      final elapsed = start != null ? _now().difference(start).inSeconds : 0;
      final wallRemaining = widget.preparationDelaySeconds - elapsed;
      final nextRemaining = min(_preparationSecondsRemaining - 1, wallRemaining);
      if (nextRemaining > 0) {
        setState(() {
          _preparationSecondsRemaining = nextRemaining;
        });
      } else {
        timer.cancel();
        setState(() {
          _isPreparing = false;
          _preparationSecondsRemaining = 0;
        });
        _startActualPractice();
      }
    });
  }

  void _skipPreparation() {
    if (!_isPreparing || _isFinished) return;
    _preparationTimer?.cancel();
    WakelockPlus.enable().catchError((e) {
      debugPrint('[PracticeScreen] Error enabling Wakelock on Begin Now: $e');
    });
    setState(() {
      _isPreparing = false;
      _preparationSecondsRemaining = 0;
    });
    _startActualPractice();
  }

  int _resolveActualTargetSeconds() {
    if (widget.targetClockHour != null && widget.targetClockMinute != null) {
      final now = _now();
      final hour24 = widget.targetClockIsAm == true
          ? (widget.targetClockHour == 12 ? 0 : widget.targetClockHour!)
          : (widget.targetClockHour == 12 ? 12 : widget.targetClockHour! + 12);
      var targetDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour24,
        widget.targetClockMinute!,
      );
      if (!targetDateTime.isAfter(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }
      final diff = targetDateTime.difference(now).inSeconds;
      if (diff >= 60 && diff <= 90 * 60) {
        return diff;
      }
    }
    return widget.targetDurationSeconds;
  }

  void _startActualPractice() {
    if (widget.onBuildQueue != null) {
      final actualSeconds = _resolveActualTargetSeconds();
      debugPrint('[PracticeScreen] Starting practice at ${_now()} with actualSeconds=$actualSeconds');
      final freshQueue = widget.onBuildQueue!(actualSeconds);
      if (freshQueue.isNotEmpty) {
        _activeQueue = freshQueue;
        _targetDurationSeconds = actualSeconds;
        _totalSecondsRemaining = actualSeconds;
        widget.onPracticeStarted?.call(freshQueue, actualSeconds);
      }
    }
    _sessionStartTime = _now();
    _startCountdownTimer();
    _playCurrentQueueItem();
  }

  void _openDebugScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (widget.buildDebugScreenWithQueue != null) {
            return widget.buildDebugScreenWithQueue!(
              _activeQueue,
              _targetDurationSeconds,
            );
          }
          if (widget.buildDebugScreen != null) {
            return widget.buildDebugScreen!();
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _initAudioPlayers() {
    _voiceCompleteSubscription = _voicePlayer.onPlayerComplete.listen((_) {
      if (_isDisposed || !mounted || _isFinished) return;
      if (!_isVoiceSegmentPlaying) {
        // Ignore loop completions or stop events from background silence
        return;
      }
      _isVoiceSegmentPlaying = false;

      final item = currentItem;
      if (item is PauseSilenceItem) {
        // Handled by wall-clock timer & duration check
        return;
      }
      final isS16 = item is PlayAudioItem &&
          (item.segment == ClinicalSegment.S16 || item.id.startsWith('S16'));
      if (isS16) {
        // Direct hook to session completion state
        _finishSession();
      } else {
        _advanceQueue();
      }
    });

    _bellCompleteSubscription = _bellPlayer.onPlayerComplete.listen((_) {
      if (_isDisposed || !mounted || _isFinished) return;
      if (!_isBellSegmentPlaying) {
        // Ignore priming silence completions before an active bell segment begins
        return;
      }
      _isBellSegmentPlaying = false;
      // Standalone bell queue items (e.g. silent session closing bell) advance queue on completion.
      // S16 overlap bell decay finishes independently; queue advancement for S16 is driven by _voicePlayer.
      final item = currentItem;
      if (item is PlayAudioItem &&
          item.isBell &&
          item.segment != ClinicalSegment.S16 &&
          !item.id.startsWith('S16')) {
        _advanceQueue();
      }
    });

    _voiceLogSubscription = _voicePlayer.onLog.listen((msg) {
      debugPrint('[VoicePlayer] $msg');
    });

    _bellLogSubscription = _bellPlayer.onLog.listen((msg) {
      debugPrint('[BellPlayer] $msg');
    });

    if (!kIsWeb) {
      // AndroidAudioFocus.none ensures neither voice nor bell audio pauses/ducks the other on Android
      _voicePlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      ).catchError((e) {
        debugPrint('[VoicePlayer] Error setting AudioContext: $e');
      });

      _bellPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      ).catchError((e) {
        debugPrint('[BellPlayer] Error setting AudioContext: $e');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _isDisposed || !mounted) {
      return;
    }

    // 1. If session is already finished, ensure all audio is completely stopped
    if (_isFinished) {
      _voicePlayer.stop().catchError((_) {});
      _bellPlayer.stop().catchError((_) {});
      return;
    }

    // 2. Reconcile preparation countdown against wall-clock time if still preparing
    if (_isPreparing) {
      // Work around wakelock_plus 1.8.1 no_sleep.js dropping wake lock on web tab hide/resume
      WakelockPlus.enable().catchError((e) {
        debugPrint('[PracticeScreen] Error re-enabling Wakelock on resume: $e');
      });
      final prepStart = _preparationStartTime;
      if (prepStart != null) {
        final prepElapsed = _now().difference(prepStart).inSeconds;
        final prepWallRemaining = widget.preparationDelaySeconds - prepElapsed;
        if (prepWallRemaining <= 0) {
          _preparationTimer?.cancel();
          setState(() {
            _isPreparing = false;
            _preparationSecondsRemaining = 0;
          });
          _startActualPractice();
        } else if (prepWallRemaining < _preparationSecondsRemaining) {
          setState(() {
            _preparationSecondsRemaining = prepWallRemaining;
          });
        }
      }
      return;
    }

    // 3. Reconcile active session countdown, silence, and audio items against wall-clock time
    if (_sessionStartTime != null) {
      final elapsed = _now().difference(_sessionStartTime!).inSeconds;
      if (elapsed >= _targetDurationSeconds || _totalSecondsRemaining <= 0) {
        _totalSecondsRemaining = 0;
        _finishSession();
        _voicePlayer.stop().catchError((_) {});
        _bellPlayer.stop().catchError((_) {});
        return;
      }

      // Session is still active — re-enable wakelock to recover from web tab-hide drops
      WakelockPlus.enable().catchError((e) {
        debugPrint('[PracticeScreen] Error re-enabling Wakelock on resume: $e');
      });

      final wallRemaining = max(0, _targetDurationSeconds - elapsed);
      if (wallRemaining < _totalSecondsRemaining) {
        setState(() {
          _totalSecondsRemaining = wallRemaining;
        });
      }

      final item = currentItem;
      if (item is PauseSilenceItem) {
        final silenceStart = _silenceStartTime;
        if (silenceStart != null) {
          final silenceElapsed = _now().difference(silenceStart).inSeconds;
          final silenceWallRemaining = _silenceTotalSeconds - silenceElapsed;
          if (silenceWallRemaining <= 0) {
            _silenceTimer?.cancel();
            _advanceQueue();
            return;
          }
          if (silenceWallRemaining < _silenceSecondsRemaining) {
            setState(() {
              _silenceSecondsRemaining = silenceWallRemaining;
            });
          }
        }
        if (_voicePlayer.state != PlayerState.playing) {
          _restartSilenceKeepAlive();
        }
      } else if (item is PlayAudioItem) {
        final isS16 = item.segment == ClinicalSegment.S16 || item.id.startsWith('S16');
        final audioStart = _activeAudioStartTime;
        if (audioStart != null) {
          final audioElapsedMs = _now().difference(audioStart).inMilliseconds;
          final maxExpectedMs =
              (item.durationSeconds * 1000).round() + (isS16 ? 5000 : 1500);
          if (audioElapsedMs >= maxExpectedMs) {
            if (isS16) {
              _finishSession();
            } else {
              _advanceQueue();
            }
            return;
          }
        }

        final expectedPlayer = (item.isBell && !isS16)
            ? _bellPlayer
            : (isS16 && !_isVoiceSegmentPlaying ? _bellPlayer : _voicePlayer);
        if (expectedPlayer.state != PlayerState.playing) {
          _playCurrentQueueItem();
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playbackGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _voiceCompleteSubscription?.cancel();
    _bellCompleteSubscription?.cancel();
    _voiceLogSubscription?.cancel();
    _bellLogSubscription?.cancel();
    _countdownTimer?.cancel();
    _silenceTimer?.cancel();
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();
    _preparationTimer?.cancel();
    try {
      _voicePlayer.setReleaseMode(ReleaseMode.release).catchError((_) {});
      _voicePlayer.stop().catchError((_) {});
    } catch (_) {}
    try {
      _bellPlayer.stop().catchError((_) {});
    } catch (_) {}
    if (_ownsVoicePlayer) {
      _voicePlayer.dispose();
    }
    if (_ownsBellPlayer) {
      _bellPlayer.dispose();
    }
    // Ensure screen lock / wakelock is released if user exits early
    WakelockPlus.disable().catchError((e) {
      debugPrint('[PracticeScreen] Error disabling Wakelock on dispose: $e');
    });
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFinished && mounted && !_isDisposed) {
        final elapsed = _sessionStartTime != null
            ? _now().difference(_sessionStartTime!).inSeconds
            : 0;
        final wallRemaining = _targetDurationSeconds - elapsed;
        final nextRemaining = min(_totalSecondsRemaining - 1, wallRemaining);
        setState(() {
          _totalSecondsRemaining = max(0, nextRemaining);
        });
      }
    });
  }

  ResolvedAudio? _resolveSilenceKeepAlive() {
    return widget.audioSourceResolver?.resolveSilenceKeepAlive();
  }

  ResolvedAudio? _resolveItemVoice(PlayAudioItem item) {
    final resolver = widget.audioSourceResolver;
    if (resolver == null) return null;
    if (item.voiceId != null && item.segment != null && item.variantId != null) {
      return resolver.resolveVoiceClip(
        voiceId: item.voiceId!,
        segmentCode: item.segment!.code,
        variantId: item.variantId!,
        useStagedOverride: item.isStagedOverride,
      );
    }
    return resolver.resolveAudioReference(item.audioAssetPath);
  }

  ResolvedAudio? _resolveS16Bell(PlayAudioItem item) {
    final resolver = widget.audioSourceResolver;
    if (resolver == null) return null;
    if (widget.selectedBell != null &&
        (item.bellId == null || item.bellId == widget.selectedBell!.id)) {
      return resolver.resolveBellClip(widget.selectedBell!);
    }
    if (item.bellAssetPath != null) {
      return resolver.resolveAudioReference(item.bellAssetPath!);
    }
    if (widget.selectedBell != null) {
      return resolver.resolveBellClip(widget.selectedBell!);
    }
    return resolver.resolveAudioReference('assets/bells/bell_meditation.mp3');
  }

  ResolvedAudio? _resolveStandaloneBell(PlayAudioItem item) {
    final resolver = widget.audioSourceResolver;
    if (resolver == null) return null;
    if (widget.selectedBell != null &&
        (item.bellId == null || item.bellId == widget.selectedBell!.id)) {
      return resolver.resolveBellClip(widget.selectedBell!);
    }
    return resolver.resolveAudioReference(item.audioAssetPath);
  }

  Future<bool> _playResolvedSafely(
    AudioPlayer player,
    ResolvedAudio? resolved, {
    required double volume,
    required ReleaseMode releaseMode,
    required int generation,
    void Function()? beforePlay,
    void Function()? onFailure,
    String? errorLabel,
  }) async {
    if (resolved == null) return false;
    try {
      await player.setReleaseMode(releaseMode);
      if (_isStale(generation)) return false;
      await player.setVolume(volume);
      if (_isStale(generation)) return false;
      beforePlay?.call();
      await player.play(resolved.source);
      if (_isStale(generation)) return false;
      if (_needsAudioResume && mounted) {
        setState(() => _needsAudioResume = false);
      }
      return true;
    } catch (e) {
      onFailure?.call();
      debugPrint(
        '[PracticeScreen] Error playing ${errorLabel ?? resolved.debugLabel}: $e',
      );
      if (kIsWeb && !_isStale(generation) && mounted) {
        setState(() => _needsAudioResume = true);
      }
      return false;
    }
  }

  Future<void> _restartSilenceKeepAlive() async {
    final gen = _playbackGeneration;
    await _playResolvedSafely(
      _voicePlayer,
      _resolveSilenceKeepAlive(),
      volume: 0.0,
      releaseMode: ReleaseMode.loop,
      generation: gen,
      errorLabel: 'background silence keep-alive',
    );
  }

  void _resumeWebAudio() {
    if (_isDisposed || !mounted || _isFinished) return;
    WakelockPlus.enable().catchError((e) {
      debugPrint('[PracticeScreen] Error enabling Wakelock on Resume Audio: $e');
    });
    setState(() {
      _needsAudioResume = false;
    });
    if (!_isPreparing) {
      _playCurrentQueueItem();
    }
  }

  void _playCurrentQueueItem() async {
    if (_isDisposed || !mounted || _isFinished) return;
    final gen = ++_playbackGeneration;

    if (_currentIndex >= _activeQueue.length) {
      _finishSession();
      return;
    }

    final item = _activeQueue[_currentIndex];

    if (item is PauseSilenceItem) {
      _silenceTotalSeconds = item.durationSeconds;
      _silenceSecondsRemaining = item.durationSeconds;
      _silenceStartTime = _now();
      _activeAudioStartTime = null;
      _silenceTimer?.cancel();
      _fallbackTimer?.cancel();
      _overlapTimer?.cancel();
      _isVoiceSegmentPlaying = false;
      _isBellSegmentPlaying = false;

      if (_silenceSecondsRemaining <= 0) {
        _advanceQueue();
        return;
      }

      // Loop silent audio asset so OS maintains active media playback & keeps CPU awake
      await _playResolvedSafely(
        _voicePlayer,
        _resolveSilenceKeepAlive(),
        volume: 0.0,
        releaseMode: ReleaseMode.loop,
        generation: gen,
        errorLabel: 'background silence',
      );
      if (_isStale(gen)) return;

      _silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_isStale(gen)) {
          timer.cancel();
          return;
        }
        final elapsed = _silenceStartTime != null
            ? _now().difference(_silenceStartTime!).inSeconds
            : 0;
        final wallRemaining = _silenceTotalSeconds - elapsed;
        final nextRemaining = max(0, min(_silenceSecondsRemaining - 1, wallRemaining));

        if (nextRemaining > 0) {
          setState(() {
            _silenceSecondsRemaining = nextRemaining;
          });
        } else {
          timer.cancel();
          try {
            await _voicePlayer.stop();
            if (_isStale(gen)) return;
            await _voicePlayer.setReleaseMode(ReleaseMode.release);
          } catch (_) {}
          if (_isStale(gen)) return;
          _advanceQueue();
        }
      });
      setState(() {});
    } else if (item is PlayAudioItem) {
      _silenceTimer?.cancel();
      _fallbackTimer?.cancel();
      _overlapTimer?.cancel();
      _activeAudioStartTime = _now();

      final isS16 = item.segment == ClinicalSegment.S16 || item.id.startsWith('S16');
      final isBellOnly = item.isBell && !isS16;

      // Arm a safety watchdog timer so queue CANNOT freeze if onPlayerComplete is dropped
      final clipMs = (item.durationSeconds * 1000).round();
      final timeoutMs = isS16 ? max(18000, clipMs + 5000) : max(2000, clipMs + 2000);
      _fallbackTimer = Timer(Duration(milliseconds: timeoutMs), () {
        if (_isStale(gen)) return;
        debugPrint('[PracticeScreen] Watchdog timeout triggered for ${item.id}');
        if (isS16) {
          // Preserve closing bell decay on _bellPlayer instead of calling _advanceQueue()
          _finishSession();
        } else {
          _advanceQueue();
        }
      });

      if (isS16) {
        // --- Phase 2: Dual-Player Overlap Engine for S16 ---
        _isVoiceSegmentPlaying = false; // Voice triggers at +2.5s over decaying bell

        final bellAudio = _resolveS16Bell(item);
        final voiceAudio = _resolveItemVoice(item);

        // Calibrated gain: strike closing singing bowl / chime at 100% target volume (1.0)
        final bellVol = _isMuted ? 0.35 : 1.0;
        final voiceVol = _isMuted ? 0.0 : 1.0;

        // 1. Instantly fire the acoustic bell asset using _bellPlayer
        await _playResolvedSafely(
          _bellPlayer,
          bellAudio,
          volume: bellVol,
          releaseMode: ReleaseMode.release,
          generation: gen,
          beforePlay: () => _isBellSegmentPlaying = true,
          onFailure: () => _isBellSegmentPlaying = false,
          errorLabel: 'bell on _bellPlayer',
        );
        if (_isStale(gen)) return;

        // 2. Start a Flutter Timer for exactly 2.5 seconds
        // When the timer triggers, play the chosen S16 voice variant using _voicePlayer
        _overlapTimer = Timer(const Duration(milliseconds: 2500), () async {
          if (_isStale(gen)) return;
          await _playResolvedSafely(
            _voicePlayer,
            voiceAudio,
            volume: voiceVol,
            releaseMode: ReleaseMode.release,
            generation: gen,
            beforePlay: () => _isVoiceSegmentPlaying = true,
            onFailure: () => _isVoiceSegmentPlaying = false,
            errorLabel: 'S16 voice on _voicePlayer',
          );
        });
      } else if (isBellOnly) {
        // Standalone bell playback on dedicated _bellPlayer
        _isVoiceSegmentPlaying = false;
        final volume = _isMuted ? 0.35 : 1.0;
        await _playResolvedSafely(
          _bellPlayer,
          _resolveStandaloneBell(item),
          volume: volume,
          releaseMode: ReleaseMode.release,
          generation: gen,
          beforePlay: () => _isBellSegmentPlaying = true,
          onFailure: () => _isBellSegmentPlaying = false,
          errorLabel: 'standalone bell',
        );
        if (_isStale(gen)) return;
      } else {
        // Standard sequential playback for S01 through S15 on _voicePlayer
        _isBellSegmentPlaying = false;
        final volume = _isMuted ? 0.0 : 1.0;
        await _playResolvedSafely(
          _voicePlayer,
          _resolveItemVoice(item),
          volume: volume,
          releaseMode: ReleaseMode.release,
          generation: gen,
          beforePlay: () => _isVoiceSegmentPlaying = true,
          onFailure: () => _isVoiceSegmentPlaying = false,
          errorLabel: item.audioAssetPath,
        );
        if (_isStale(gen)) return;
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _advanceQueue() async {
    if (_isDisposed || !mounted || _isFinished) return;
    final gen = ++_playbackGeneration;
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();
    _silenceTimer?.cancel();
    _isVoiceSegmentPlaying = false;
    _isBellSegmentPlaying = false;
    try {
      await _voicePlayer.stop();
      if (_isStale(gen)) return;
      await _bellPlayer.stop();
      if (_isStale(gen)) return;
      await _voicePlayer.setReleaseMode(ReleaseMode.release);
    } catch (_) {}
    if (_isStale(gen)) return;
    _currentIndex++;
    if (_currentIndex < _activeQueue.length) {
      _playCurrentQueueItem();
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    if (_isDisposed || _isFinished) return;
    _playbackGeneration++;

    // Immediately mark finished and update UI to guard against re-entrant calls
    if (mounted) {
      setState(() {
        _isFinished = true;
        _isVoiceSegmentPlaying = false;
        _isBellSegmentPlaying = false;
        _needsAudioResume = false;
        _totalSecondsRemaining = 0;
      });
    } else {
      _isFinished = true;
      _isVoiceSegmentPlaying = false;
      _isBellSegmentPlaying = false;
      _needsAudioResume = false;
      _totalSecondsRemaining = 0;
    }

    _silenceTimer?.cancel();
    _countdownTimer?.cancel();
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();

    try {
      _voicePlayer.setReleaseMode(ReleaseMode.release).catchError((_) {});
    } catch (_) {}

    // Always stop voice playback upon session completion
    try {
      _voicePlayer.stop().catchError((_) {});
    } catch (_) {}

    final item = currentItem;
    final isBellPlaying = item is PlayAudioItem && item.isBell;
    final isOutroPlaying = item is PlayAudioItem &&
        (item.segment == ClinicalSegment.S16 || item.id.startsWith('S16'));

    if (!isBellPlaying && !isOutroPlaying) {
      try {
        _bellPlayer.stop().catchError((_) {});
      } catch (_) {}
      if (_isMuted) {
        try {
          _bellPlayer.setReleaseMode(ReleaseMode.release).catchError((_) {});
          _bellPlayer.setVolume(0.35).catchError((_) {});
          final resolver = widget.audioSourceResolver;
          final resolvedBell = resolver != null
              ? (widget.selectedBell != null
                  ? resolver.resolveBellClip(widget.selectedBell!)
                  : resolver.resolveAudioReference('assets/bells/bell_meditation.mp3'))
              : null;
          if (resolvedBell != null) {
            _bellPlayer.play(resolvedBell.source).catchError((_) {});
          }
        } catch (_) {}
      }
    }

    // Release wakelock only upon final transition to the completion screen
    WakelockPlus.disable().catchError((e) {
      debugPrint('[PracticeScreen] Error disabling Wakelock on completion: $e');
    });

    widget.onSessionComplete?.call();
  }

  void _toggleMute() async {
    if (_isFinished) return;

    unawaited(WakelockPlus.enable().catchError((e) {
      debugPrint('[PracticeScreen] Error enabling Wakelock on Mute toggle: $e');
    }));

    setState(() {
      _isMuted = !_isMuted;
    });

    if (kIsWeb && _needsAudioResume) {
      _resumeWebAudio();
      return;
    }

    final item = currentItem;
    if (item is PlayAudioItem) {
      final isS16 = item.segment == ClinicalSegment.S16 || item.id.startsWith('S16');
      if (isS16) {
        await _bellPlayer.setVolume(_isMuted ? 0.35 : 1.0);
        await _voicePlayer.setVolume(_isMuted ? 0.0 : 1.0);
      } else if (item.isBell) {
        await _bellPlayer.setVolume(_isMuted ? 0.35 : 1.0);
      } else {
        await _voicePlayer.setVolume(_isMuted ? 0.0 : 1.0);
      }
    } else {
      // In silence phase: keep silent loop at volume 0.0
      await _voicePlayer.setVolume(0.0);
      await _bellPlayer.setVolume(_isMuted ? 0.35 : 1.0);
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);

    final totalDuration = _targetDurationSeconds > 0
        ? _targetDurationSeconds
        : 1;
    final progress =
        ((totalDuration - _totalSecondsRemaining) / totalDuration)
            .clamp(0.0, 1.0);

    final screenHeight = MediaQuery.of(context).size.height;
    final isCompactScreen = screenHeight < 850;
    final circleOuterSize = isCompactScreen ? 190.0 : 220.0;
    final circleInnerSize = isCompactScreen ? 144.0 : 168.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Protect active meditation practice from accidental back gestures.
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _playbackGeneration++;
              _preparationTimer?.cancel();
              _countdownTimer?.cancel();
              _silenceTimer?.cancel();
              _fallbackTimer?.cancel();
              _overlapTimer?.cancel();
              try {
                _voicePlayer.stop().catchError((_) {});
                _bellPlayer.stop().catchError((_) {});
              } catch (_) {}
              widget.onEndSession();
            },
          ),
          title: const Text('Practice'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isCompactScreen ? 10 : 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Center Visual & Timer
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.selectedMeditationType,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isCompactScreen ? 26 : 30,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: isCompactScreen ? 16 : 28),

                            // Ambient Breathing Circle (continues pulsing while muted)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                final scale =
                                    _isFinished ? 1.0 : _pulseAnimation.value;
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: circleOuterSize,
                                height: circleOuterSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: semantic.circleOuterGlow,
                                  border: Border.all(
                                    color: semantic.circleBorder,
                                    width: isCompactScreen ? 7 : 8,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: circleInnerSize,
                                    height: circleInnerSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.surfaceContainerLow,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (_isPreparing) ...[
                                              Text(
                                                '$_preparationSecondsRemaining',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: isCompactScreen ? 42 : 48,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'seconds to settle',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: semantic.muted,
                                                ),
                                              ),
                                            ] else if (_isFinished) ...[
                                              Text(
                                                'Sit Complete',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: isCompactScreen ? 20 : 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'May you be well',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: semantic.muted,
                                                ),
                                              ),
                                            ] else ...[
                                              Text(
                                                _formatTime(_totalSecondsRemaining),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: isCompactScreen ? 32 : 36,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'remaining',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: semantic.muted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isCompactScreen ? 12 : 16),

                            // Progress Line anchored directly below the circle
                            SizedBox(
                              width: circleOuterSize,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _isPreparing
                                      ? ((widget.preparationDelaySeconds > 0
                                              ? 1.0 -
                                                  (_preparationSecondsRemaining /
                                                      widget.preparationDelaySeconds)
                                              : 1.0)
                                          .clamp(0.0, 1.0))
                                      : progress,
                                  minHeight: 5,
                                  backgroundColor: semantic.pillUnselected,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isCompactScreen ? 12 : 16),

                            if (_isPreparing) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: semantic.pillUnselected,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Settling In',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              SizedBox(height: isCompactScreen ? 8 : 12),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: isCompactScreen ? 54 : 76,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: Text(
                                    'Take a moment to set your phone down and get comfortable before guidance begins.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: semantic.muted,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.isDeveloperMode) ...[
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 28),
                                  child: Center(
                                    child: Text(
                                      'Preparing Practice Space',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: semantic.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else if (_isFinished) ...[
                              Text(
                                'End of Formal Practice',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Carry this clarity and quiet presence with you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: semantic.muted,
                                ),
                              ),
                            ] else ...[
                              // Phase badge and Mute indicator
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: semantic.pillUnselected,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentItem?.phaseName ?? 'Arrival & Agency',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (_isMuted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: semantic.sandSurface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.volume_off,
                                              size: 13, color: semantic.muted),
                                          const SizedBox(width: 4),
                                          Text(
                                            'MUTED',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: semantic.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: isCompactScreen ? 8 : 12),

                              // Spoken Guidance Text with minHeight so it never causes layout shifts
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: isCompactScreen ? 58 : 76,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                          ? currentItem!.text
                                          : (currentItem is PauseSilenceItem
                                              ? 'Resting in open stillness...'
                                              : ''),
                                      key: ValueKey<String>(
                                        (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                            ? currentItem!.text
                                            : (currentItem is PauseSilenceItem ? 'silence' : ''),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontStyle: (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                        color: (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                            ? colorScheme.onSurface
                                            : semantic.muted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (widget.isDeveloperMode) ...[
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 28),
                                  child: Center(
                                    child: Text(
                                      currentItem?.displayTitle ?? 'Preparing Practice Space',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: semantic.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            if (_needsAudioResume && !_isFinished) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: semantic.pillUnselected,
                                  foregroundColor: colorScheme.primary,
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: _resumeWebAudio,
                                icon: const Icon(Icons.volume_up, size: 18),
                                label: const Text(
                                  'Tap to Resume Audio',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Bottom Controls
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: _isPreparing
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: double.infinity,
                                    minHeight: 52,
                                  ),
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _skipPreparation,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text(
                                      'Begin Now',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              : _isFinished
                                  ? ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: double.infinity,
                                        minHeight: 54,
                                      ),
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: widget.onEndSession,
                                        child: const Text(
                                          'Finished',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        if (widget.isDeveloperMode) ...[
                                          Expanded(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(minHeight: 52),
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 12, vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                onPressed: _openDebugScreen,
                                                icon: const Icon(Icons.bug_report_outlined),
                                                label: const Text(
                                                  'Debug',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 52),
                                            child: FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: _isMuted
                                                    ? semantic.subtle
                                                    : colorScheme.primary,
                                                foregroundColor: _isMuted
                                                    ? Colors.white
                                                    : colorScheme.onPrimary,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                              onPressed: _toggleMute,
                                              icon: Icon(_isMuted
                                                  ? Icons.volume_up
                                                  : Icons.volume_off),
                                              label: Text(
                                                _isMuted ? 'Unmute' : 'Mute',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
