import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/audio_sources.dart';
import '../audio/bundled_audio_sources.dart';
import '../engine/session_queue_engine.dart';
import '../models/audio_models.dart';
import '../models/host_options.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../screens/about_screen.dart';
import '../screens/bell_configuration_screen.dart';
import '../screens/configuration_screen.dart';
import '../screens/manage_practices_screen.dart';
import '../screens/manage_voices_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/session_debug_screen.dart';
import '../screens/settings_screen.dart';
import '../services/audio_manifest_service.dart';
import '../services/preferences_service.dart';
import '../state/setandsit_controller.dart';
import '../storage/key_value_store.dart';

/// Embeddable Set&Sit module root widget.
///
/// Renders cleanly inside a host `MaterialApp` / `Navigator` (e.g., Villagers Ally)
/// or inside the standalone [SetAndSitApp] shell, inheriting ambient theme and
/// `MediaQuery` without assuming global singletons or `shared_preferences`.
class SetAndSitRoot extends StatefulWidget {
  final SetAndSitController? controller;
  final KeyValueStore? keyValueStore;
  final PreferencesService? preferencesService;
  final ManifestSource? manifestSource;
  final AudioSourceResolver? audioSourceResolver;
  final AudioManifestService? manifestService;
  final SessionQueueEngine? queueEngine;
  final DateTime Function()? clock;

  final SavedState? initialState;
  final List<VoiceConfig>? initialVoices;
  final List<PracticeConfig>? initialPractices;
  final bool? initialDeveloperMode;

  final SetAndSitHostOptions hostOptions;
  final AudioPlayer? voicePlayer;
  final AudioPlayer? bellPlayer;

  const SetAndSitRoot({
    super.key,
    this.controller,
    this.keyValueStore,
    this.preferencesService,
    this.manifestSource,
    this.audioSourceResolver,
    this.manifestService,
    this.queueEngine,
    this.clock,
    this.initialState,
    this.initialVoices,
    this.initialPractices,
    this.initialDeveloperMode,
    this.hostOptions = const SetAndSitHostOptions(),
    this.voicePlayer,
    this.bellPlayer,
  });

  @override
  State<SetAndSitRoot> createState() => _SetAndSitRootState();
}

class _SetAndSitRootState extends State<SetAndSitRoot>
    with WidgetsBindingObserver {
  late final SetAndSitController _controller;
  late final bool _ownsController;
  late final AudioPlayer _sharedVoicePlayer;
  late final AudioPlayer _sharedBellPlayer;
  late final bool _ownsVoicePlayer;
  late final bool _ownsBellPlayer;

  @override
  void initState() {
    super.initState();
    _ownsVoicePlayer = widget.voicePlayer == null;
    _ownsBellPlayer = widget.bellPlayer == null;
    _sharedVoicePlayer = widget.voicePlayer ?? AudioPlayer();
    _sharedBellPlayer = widget.bellPlayer ?? AudioPlayer();

    final providedController = widget.controller;
    if (providedController != null) {
      _controller = providedController;
      _ownsController = false;
    } else {
      final resolver =
          widget.audioSourceResolver ?? const BundledAudioSourceResolver();
      final prefsService = widget.preferencesService ??
          PreferencesService(widget.keyValueStore ?? InMemoryKeyValueStore());
      final manifestService = widget.manifestService ??
          AudioManifestService(
            manifestSource: widget.manifestSource ?? const BundledManifestSource(),
            audioSourceResolver: resolver,
          );
      final queueEngine = widget.queueEngine ??
          SessionQueueEngine(
            manifestService: manifestService,
            audioSourceResolver: resolver,
          );
      _controller = SetAndSitController(
        preferencesService: prefsService,
        manifestService: manifestService,
        queueEngine: queueEngine,
        audioSourceResolver: resolver,
        clock: widget.clock,
        initialState: widget.initialState,
        initialVoices: widget.initialVoices,
        initialPractices: widget.initialPractices,
        initialDeveloperMode: widget.initialDeveloperMode,
      );
      _ownsController = true;

      if (!_controller.isInitialized) {
        unawaited(_controller.loadFromPreferences());
      }
      unawaited(
        manifestService
            .initialize(developerMode: widget.initialDeveloperMode ?? false)
            .catchError((Object e) {
          debugPrint('[SetAndSitRoot] AudioManifestService error: $e');
        }),
      );
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsVoicePlayer) {
      unawaited(_sharedVoicePlayer.dispose());
    }
    if (_ownsBellPlayer) {
      unawaited(_sharedBellPlayer.dispose());
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycleState(state);
  }

  void _primeAudioAndWakelockForPractice() {
    // Synchronously trigger wakelock and silent playback inside the user gesture
    // so mobile browsers unlock both audio elements before async/timer transitions.
    unawaited(WakelockPlus.enable().catchError((Object e) {
      debugPrint('[SetAndSitRoot] Error enabling Wakelock: $e');
    }));

    final keepAlive = _controller.audioSourceResolver.resolveSilenceKeepAlive();

    unawaited(_sharedVoicePlayer.setReleaseMode(ReleaseMode.loop).catchError((_) {}));
    unawaited(_sharedVoicePlayer.setVolume(0.0).catchError((_) {}));
    unawaited(_sharedVoicePlayer.play(keepAlive.source).catchError((Object e) {
      debugPrint('[SetAndSitRoot] Error priming voice player: $e');
    }));

    unawaited(_sharedBellPlayer.setReleaseMode(ReleaseMode.release).catchError((_) {}));
    unawaited(_sharedBellPlayer.setVolume(0.0).catchError((_) {}));
    unawaited(_sharedBellPlayer.play(keepAlive.source).catchError((Object e) {
      debugPrint('[SetAndSitRoot] Error priming bell player: $e');
    }));
  }

  void _startPractice({
    required int targetSeconds,
    required String practiceType,
    required AudioSegment bell,
    PracticeConfig? practiceConfig,
  }) {
    final outcome = _controller.tryStartPractice(
      targetSeconds: targetSeconds,
      practiceType: practiceType,
      bell: bell,
      practiceConfig: practiceConfig,
    );

    if (outcome == StartPracticeOutcome.invalidDuration) {
      unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Duration'),
          content: const Text(
            'Meditation duration must be between 1 and 90 minutes. Please adjust your finish time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      ));
      return;
    }

    if (outcome == StartPracticeOutcome.durationTooShort) {
      unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duration Too Short'),
          content: const Text(
            'The selected duration is too short for starting and ending bells. Please select a longer duration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      ));
      return;
    }

    _primeAudioAndWakelockForPractice();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: _controller.currentScreen == AppScreen.configuration,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _controller.navigateBackFromSubscreen();
          },
          child: _buildScreen(context),
        );
      },
    );
  }

  Widget _buildScreen(BuildContext context) {
    final host = widget.hostOptions;
    switch (_controller.currentScreen) {
      case AppScreen.configuration:
        return ConfigurationScreen(
          isDeveloperMode: _controller.isDeveloperMode,
          stagedVariantsCount: _controller.stagedVariantsCount,
          allowDeveloperMode: host.allowDeveloperMode,
          onExit: host.onExitModule,
          onDeveloperModeChanged: (enabled) =>
              unawaited(_controller.setDeveloperMode(enabled)),
          practiceDurationMinutes: _controller.practiceDurationMinutes,
          onEnsureFutureTime: _controller.ensureFutureTargetTime,
          onOpenSettings: _controller.openSettings,
          bells: _controller.bells,
          selectedBellId: _controller.selectedBellId,
          onSelectedBellChanged: _controller.setSelectedBellId,
          onOpenBellSettings: () =>
              _controller.openBellSettings(from: AppScreen.configuration),
          selectedType: _controller.practiceMode,
          onSelectedTypeChanged: _controller.setPracticeMode,
          practices: _controller.practices,
          selectedPracticeId: _controller.selectedPracticeId,
          onSelectedPracticeIdChanged: _controller.setSelectedPracticeId,
          onOpenManagePractices: () =>
              _controller.openManagePractices(from: AppScreen.configuration),
          voices: _controller.voices,
          selectedVoiceId: _controller.selectedVoiceId,
          onSelectedVoiceIdChanged: _controller.setSelectedVoiceId,
          onOpenManageVoices: () =>
              _controller.openManageVoices(from: AppScreen.configuration),
          voiceIndex: _controller.voiceIndex,
          onVoiceIndexChanged: _controller.setVoiceIndex,
          clockHour: _controller.clockHour,
          clockMinute: _controller.clockMinute,
          isAm: _controller.isAm,
          onClockTimeChanged: _controller.setClockTime,
          onBeginPractice: (targetSec, practiceType, bell, practiceConfig) {
            _startPractice(
              targetSeconds: targetSec,
              practiceType: _controller.practiceMode,
              bell: bell,
              practiceConfig: practiceConfig,
            );
          },
        );

      case AppScreen.managePractices:
        return ManagePracticesScreen(
          initialPractices: _controller.practices,
          initialSelectedPracticeId: _controller.selectedPracticeId,
          onPracticesUpdated: _controller.updatePractices,
          onBack: _controller.navigateBackFromSubscreen,
        );

      case AppScreen.manageVoices:
        return ManageVoicesScreen(
          isDeveloperMode: _controller.isDeveloperMode,
          initialVoices: _controller.voices,
          initialSelectedVoiceId: _controller.selectedVoiceId,
          variantsProvider: _controller.manifestService.getVariantsForSegment,
          voiceAudioResolver: ({
            required String voiceId,
            required String segmentCode,
            required String variantId,
          }) =>
              _controller.manifestService.resolveVoiceAudio(
            voice: voiceId,
            segmentCode: segmentCode,
            variantId: variantId,
          ),
          onInitializeManifest: _controller.manifestService.initialize,
          onVoicesUpdated: _controller.updateVoices,
          onBack: _controller.navigateBackFromSubscreen,
        );

      case AppScreen.settings:
        return SettingsScreen(
          practiceDurationMinutes: _controller.practiceDurationMinutes,
          instructionDensity: _controller.instructionDensity,
          redirectionDensity: _controller.redirectionDensity,
          preparationDelaySeconds: _controller.preparationDelaySeconds,
          themeMode: host.themeMode ?? ThemeMode.system,
          fontSizePx: host.fontSizePx ?? PreferencesService.defaultFontSizePx,
          showDisplaySettings: host.effectiveShowDisplaySettings,
          onThemeModeChanged: host.onThemeModeChanged,
          onFontSizePxChanged: host.onFontSizePxChanged,
          isDeveloperMode: _controller.isDeveloperMode,
          stagedVariantsCount: _controller.stagedVariantsCount,
          onDisableDeveloperMode: () =>
              unawaited(_controller.setDeveloperMode(false)),
          onPracticeDurationChanged: _controller.updatePracticeDuration,
          onPreparationDelayChanged: _controller.setPreparationDelaySeconds,
          onInstructionDensityChanged: _controller.setInstructionDensity,
          onRedirectionDensityChanged: _controller.setRedirectionDensity,
          onBack: _controller.backFromSettings,
          onOpenManagePractices: () =>
              _controller.openManagePractices(from: AppScreen.settings),
          onOpenManageVoices: () =>
              _controller.openManageVoices(from: AppScreen.settings),
          onOpenBellSettings: () =>
              _controller.openBellSettings(from: AppScreen.settings),
          onOpenAbout: host.showAbout ? _controller.openAbout : null,
        );

      case AppScreen.about:
        return AboutScreen(
          aboutInfo: host.aboutInfo,
          onBack: _controller.closeAbout,
        );

      case AppScreen.bellSettings:
        return BellConfigurationScreen(
          bells: _controller.bells,
          selectedBellId: _controller.selectedBellId,
          audioSourceResolver: _controller.audioSourceResolver,
          onBellSelected: _controller.setSelectedBellId,
          onBellUpdated: _controller.updateBell,
          onBack: _controller.closeBellSettings,
        );

      case AppScreen.practice:
        final currentBell = _controller.currentBell;
        final activeLabel = _controller.activeMeditationDisplayLabel;
        return PracticeScreen(
          isDeveloperMode: _controller.isDeveloperMode,
          voicePlayer: _sharedVoicePlayer,
          bellPlayer: _sharedBellPlayer,
          audioSourceResolver: _controller.audioSourceResolver,
          sessionQueue: _controller.activeSessionQueue,
          targetDurationSeconds: _controller.activeTargetSeconds,
          preparationDelaySeconds: _controller.preparationDelaySeconds,
          targetClockHour: _controller.clockHour,
          targetClockMinute: _controller.clockMinute,
          targetClockIsAm: _controller.isAm,
          nowProvider: _controller.clock,
          onBuildQueue: _controller.rebuildActivePracticeQueue,
          onPracticeStarted: _controller.updateActiveSession,
          selectedMeditationType: activeLabel,
          selectedBell: currentBell,
          buildDebugScreen: () => SessionDebugScreen(
            targetSeconds: _controller.activeTargetSeconds,
            selectedType: activeLabel,
            instructionDensity: _controller.instructionDensity,
            redirectionDensity: _controller.redirectionDensity,
            selectedBell: currentBell,
            sessionQueue: _controller.activeSessionQueue,
            onBack: () {},
          ),
          buildDebugScreenWithQueue: (liveQueue, liveTargetSeconds) =>
              SessionDebugScreen(
            targetSeconds: liveTargetSeconds,
            selectedType: activeLabel,
            instructionDensity: _controller.instructionDensity,
            redirectionDensity: _controller.redirectionDensity,
            selectedBell: currentBell,
            sessionQueue: liveQueue,
            onBack: () {},
          ),
          onEndSession: _controller.endPracticeSession,
        );

      case AppScreen.sessionDebug:
        final currentBell = _controller.currentBell;
        final activeLabel = _controller.activeMeditationDisplayLabel;
        return SessionDebugScreen(
          targetSeconds: _controller.activeTargetSeconds,
          selectedType: activeLabel,
          instructionDensity: _controller.instructionDensity,
          redirectionDensity: _controller.redirectionDensity,
          selectedBell: currentBell,
          sessionQueue: _controller.activeSessionQueue,
          onBack: _controller.closeSessionDebug,
        );
    }
  }
}
