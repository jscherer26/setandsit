import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../audio/audio_sources.dart';
import '../audio/bundled_audio_sources.dart';
import '../data/bell_data.dart';
import '../engine/session_queue_engine.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../services/audio_manifest_service.dart';
import '../services/preferences_service.dart';

enum AppScreen {
  configuration,
  settings,
  bellSettings,
  managePractices,
  manageVoices,
  practice,
  sessionDebug,
  about,
}

enum StartPracticeOutcome {
  started,
  invalidDuration,
  durationTooShort,
}

/// Pure-Flutter [ChangeNotifier] controller owning Set&Sit session state,
/// preferences persistence, and internal screen navigation without `BuildContext`.
class SetAndSitController extends ChangeNotifier {
  final PreferencesService preferencesService;
  final AudioManifestService manifestService;
  final SessionQueueEngine queueEngine;
  final AudioSourceResolver audioSourceResolver;
  final DateTime Function() clock;

  AppScreen _currentScreen = AppScreen.configuration;
  AppScreen _previousScreen = AppScreen.configuration;

  int _practiceDurationMinutes = 3;
  double _instructionDensity = 3.0;
  double _redirectionDensity = 3.0;
  int _preparationDelaySeconds = 3;
  String _practiceMode = 'Guided';

  List<AudioSegment> _bells = BellData.createDefaultBells();
  String _selectedBellId = 'bell_meditation';

  List<PracticeConfig> _practices =
      List<PracticeConfig>.from(PracticeConfig.defaultPractices);
  String _selectedPracticeId = 'focused_calm';
  String _selectedPractice = ClinicalArchetype.focusedCalm.title;
  List<VoiceConfig> _voices =
      List<VoiceConfig>.from(VoiceConfig.defaultVoices);
  String _selectedVoiceId = 'grace';
  int _voiceIndex = 0;

  int _clockHour = 8;
  int _clockMinute = 3;
  bool _isAm = true;
  bool _isInitialized = false;
  bool _isDeveloperMode = false;

  List<SessionItem> _activeSessionQueue = const <SessionItem>[];
  int _activeTargetSeconds = 180;

  bool _disposed = false;

  SetAndSitController({
    required this.preferencesService,
    AudioManifestService? manifestService,
    SessionQueueEngine? queueEngine,
    AudioSourceResolver? audioSourceResolver,
    DateTime Function()? clock,
    SavedState? initialState,
    List<VoiceConfig>? initialVoices,
    List<PracticeConfig>? initialPractices,
    bool? initialDeveloperMode,
  })  : manifestService = manifestService ?? AudioManifestService(),
        audioSourceResolver =
            audioSourceResolver ?? const BundledAudioSourceResolver(),
        clock = clock ?? DateTime.now,
        queueEngine = queueEngine ??
            SessionQueueEngine(
              manifestService: manifestService,
              audioSourceResolver: audioSourceResolver,
            ) {
    if (initialDeveloperMode != null) {
      _isDeveloperMode = initialDeveloperMode;
    }
    if (initialState != null &&
        initialVoices != null &&
        initialPractices != null) {
      _practiceDurationMinutes = initialState.practiceDurationMinutes;
      _applyLoadedState(
        saved: initialState,
        voices: initialVoices,
        practices: initialPractices,
      );
      _isInitialized = true;
    }
  }

  AppScreen get currentScreen => _currentScreen;
  AppScreen get previousScreen => _previousScreen;

  int get practiceDurationMinutes => _practiceDurationMinutes;
  double get instructionDensity => _instructionDensity;
  double get redirectionDensity => _redirectionDensity;
  int get preparationDelaySeconds => _preparationDelaySeconds;
  String get practiceMode => _practiceMode;

  List<AudioSegment> get bells => List<AudioSegment>.unmodifiable(_bells);
  String get selectedBellId => _selectedBellId;

  List<PracticeConfig> get practices =>
      List<PracticeConfig>.unmodifiable(_practices);
  String get selectedPracticeId => _selectedPracticeId;
  String get selectedPractice => _selectedPractice;

  List<VoiceConfig> get voices => List<VoiceConfig>.unmodifiable(_voices);
  String get selectedVoiceId => _selectedVoiceId;
  int get voiceIndex => _voiceIndex;

  int get clockHour => _clockHour;
  int get clockMinute => _clockMinute;
  bool get isAm => _isAm;
  bool get isInitialized => _isInitialized;
  bool get isDeveloperMode => _isDeveloperMode;

  List<SessionItem> get activeSessionQueue =>
      List<SessionItem>.unmodifiable(_activeSessionQueue);
  int get activeTargetSeconds => _activeTargetSeconds;
  int get stagedVariantsCount => manifestService.stagedVariantsCount;

  AudioSegment get currentBell => _bells.firstWhere(
        (b) => b.id == _selectedBellId,
        orElse: () => _bells.first,
      );

  PracticeConfig get currentPractice => _practices.firstWhere(
        (p) => p.id == _selectedPracticeId,
        orElse: () => _practices.first,
      );

  String get activeMeditationDisplayLabel => _practiceMode == 'Silent'
      ? 'Silent'
      : (_selectedPractice == 'Breath'
          ? 'Breath Awareness'
          : _selectedPractice);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _applyLoadedState({
    required SavedState saved,
    required List<VoiceConfig> voices,
    required List<PracticeConfig> practices,
  }) {
    final now = clock();

    // Check if the saved target clock time represents a valid future time (within 1 to 90 minutes)
    final savedHour24 = saved.targetClockTimeIsAm
        ? (saved.targetClockTimeHour == 12 ? 0 : saved.targetClockTimeHour)
        : (saved.targetClockTimeHour == 12
            ? 12
            : saved.targetClockTimeHour + 12);
    var savedTarget = DateTime(
      now.year,
      now.month,
      now.day,
      savedHour24,
      saved.targetClockTimeMinute,
    );

    // If the saved target clock time is in the past for today, advance it by 1 day
    // to match midnight rollover logic used across the app
    if (!savedTarget.isAfter(now)) {
      savedTarget = savedTarget.add(const Duration(days: 1));
    }

    int initHour;
    int initMinute;
    bool initIsAm;

    final diffSeconds = savedTarget.difference(now).inSeconds;
    if (diffSeconds >= 60 && diffSeconds <= 90 * 60) {
      initHour = saved.targetClockTimeHour;
      initMinute = saved.targetClockTimeMinute;
      initIsAm = saved.targetClockTimeIsAm;
    } else {
      final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
      final base =
          DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
      final initialEnd =
          base.add(Duration(minutes: saved.practiceDurationMinutes));
      initHour = initialEnd.hour % 12 == 0 ? 12 : initialEnd.hour % 12;
      initMinute = initialEnd.minute;
      initIsAm = initialEnd.hour < 12;
    }

    var practice = saved.selectedPractice;
    if (practice == 'Breath' ||
        practice == 'Breath Awareness' ||
        practice == 'Guided') {
      practice = ClinicalArchetype.focusedCalm.title;
    } else if (practice == 'Trauma-Informed Regulation') {
      practice = ClinicalArchetype.traumaInformed.title;
    }

    final savedId = saved.selectedPracticeId;
    var match = practices.cast<PracticeConfig?>().firstWhere(
          (p) => p?.id == savedId && p?.isIncluded == true,
          orElse: () => null,
        );
    match ??= practices.cast<PracticeConfig?>().firstWhere(
          (p) => p?.name == practice && p?.isIncluded == true,
          orElse: () => null,
        );
    match ??= practices.cast<PracticeConfig?>().firstWhere(
          (p) => p?.isIncluded == true,
          orElse: () => null,
        );
    final resolved = match ??
        (practices.isNotEmpty
            ? practices.first
            : PracticeConfig.defaultPractices.first);

    final cleanedVoices =
        voices.where((v) => v.id.toLowerCase() != 'kia').toList();
    final effectiveVoices = cleanedVoices.isNotEmpty
        ? cleanedVoices
        : List<VoiceConfig>.from(VoiceConfig.defaultVoices);

    final savedVoiceId = (saved.selectedVoiceId != null &&
            saved.selectedVoiceId!.toLowerCase() != 'kia')
        ? saved.selectedVoiceId
        : null;
    var voiceMatch = savedVoiceId != null
        ? effectiveVoices.cast<VoiceConfig?>().firstWhere(
              (v) => v?.id == savedVoiceId && v?.isIncluded == true,
              orElse: () => null,
            )
        : null;
    if (voiceMatch == null &&
        saved.selectedVoiceIndex >= 0 &&
        saved.selectedVoiceIndex < effectiveVoices.length) {
      final candidate = effectiveVoices[saved.selectedVoiceIndex];
      if (candidate.isIncluded && candidate.id.toLowerCase() != 'kia') {
        voiceMatch = candidate;
      }
    }
    voiceMatch ??= effectiveVoices.cast<VoiceConfig?>().firstWhere(
          (v) => v?.isIncluded == true,
          orElse: () => null,
        );
    final resolvedVoice = voiceMatch ??
        (effectiveVoices.isNotEmpty
            ? effectiveVoices.first
            : VoiceConfig.defaultVoices.first);

    _practiceDurationMinutes = saved.practiceDurationMinutes;
    _instructionDensity = saved.instructionDensity;
    _redirectionDensity = saved.redirectionDensity;
    _preparationDelaySeconds = saved.preparationDelaySeconds;
    _practiceMode = saved.practiceMode;
    _bells = List<AudioSegment>.from(saved.bells);
    _selectedBellId = saved.selectedBellId;
    _practices = List<PracticeConfig>.from(practices);
    _selectedPracticeId = resolved.id;
    _selectedPractice = resolved.name;
    _voices = effectiveVoices;
    _selectedVoiceId = resolvedVoice.id;
    final resolvedIdx =
        effectiveVoices.indexWhere((v) => v.id == resolvedVoice.id);
    _voiceIndex = resolvedIdx >= 0 ? resolvedIdx : 0;
    _clockHour = initHour;
    _clockMinute = initMinute;
    _isAm = initIsAm;
    _isInitialized = true;
  }

  Future<void> loadFromPreferences() async {
    try {
      final voices = await preferencesService.loadVoices();
      final practices = await preferencesService.loadPractices();
      final saved = await preferencesService.loadState();
      final isDev = await preferencesService.isDeveloperMode();
      if (_disposed) return;

      _isDeveloperMode = isDev;
      _applyLoadedState(
        saved: saved,
        voices: voices,
        practices: practices,
      );
      _safeNotify();
    } catch (e, stack) {
      debugPrint(
        '[SetAndSitController] Error in loadFromPreferences: $e\n$stack',
      );
      if (!_disposed) {
        _isInitialized = true;
        _safeNotify();
      }
    }
  }

  void _ensureValidSelectedVoice() {
    _voices = _voices.where((v) => v.id.toLowerCase() != 'kia').toList();
    if (_voices.isEmpty) {
      _voices = List<VoiceConfig>.from(VoiceConfig.defaultVoices);
    }
    if (_selectedVoiceId.toLowerCase() == 'kia') {
      _selectedVoiceId = _voices.first.id;
    }
    final match = _voices.cast<VoiceConfig?>().firstWhere(
          (v) => v?.id == _selectedVoiceId && v?.isIncluded == true,
          orElse: () => null,
        );
    if (match != null) {
      final idx = _voices.indexWhere((v) => v.id == match.id);
      _voiceIndex = idx >= 0 ? idx : 0;
      return;
    }

    final firstIncluded = _voices.cast<VoiceConfig?>().firstWhere(
          (v) => v?.isIncluded == true,
          orElse: () => null,
        );
    if (firstIncluded != null) {
      _selectedVoiceId = firstIncluded.id;
      final idx = _voices.indexWhere((v) => v.id == firstIncluded.id);
      _voiceIndex = idx >= 0 ? idx : 0;
      return;
    }

    if (_voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
      _voiceIndex = 0;
    }
  }

  void _ensureValidSelectedPractice() {
    final match = _practices.cast<PracticeConfig?>().firstWhere(
          (p) => p?.id == _selectedPracticeId && p?.isIncluded == true,
          orElse: () => null,
        );
    if (match != null) {
      _selectedPractice = match.name;
      return;
    }

    final firstIncluded = _practices.cast<PracticeConfig?>().firstWhere(
          (p) => p?.isIncluded == true,
          orElse: () => null,
        );
    if (firstIncluded != null) {
      _selectedPracticeId = firstIncluded.id;
      _selectedPractice = firstIncluded.name;
      return;
    }

    if (_practices.isNotEmpty) {
      _selectedPracticeId = _practices.first.id;
      _selectedPractice = _practices.first.name;
    }
  }

  void ensureFutureTargetTime() {
    if (!_isInitialized) return;
    final now = clock();
    final hour24 = _isAm
        ? (_clockHour == 12 ? 0 : _clockHour)
        : (_clockHour == 12 ? 12 : _clockHour + 12);
    final target =
        DateTime(now.year, now.month, now.day, hour24, _clockMinute);
    if (!target.isAfter(now)) {
      final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
      final base =
          DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
      final newTarget = base.add(Duration(minutes: _practiceDurationMinutes));
      _clockHour = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
      _clockMinute = newTarget.minute;
      _isAm = newTarget.hour < 12;
      _safeNotify();
      unawaited(persistState());
    }
  }

  void updatePracticeDuration(int newDurationMinutes) {
    final now = clock();
    final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
    final base =
        DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
    final newTarget = base.add(Duration(minutes: newDurationMinutes));
    _practiceDurationMinutes = newDurationMinutes;
    _clockHour = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
    _clockMinute = newTarget.minute;
    _isAm = newTarget.hour < 12;
    _safeNotify();
    unawaited(persistState());
  }

  Future<void> persistState() {
    return preferencesService.saveState(
      SavedState(
        practiceDurationMinutes: _practiceDurationMinutes,
        instructionDensity: _instructionDensity,
        redirectionDensity: _redirectionDensity,
        preparationDelaySeconds: _preparationDelaySeconds,
        practiceMode: _practiceMode,
        bells: _bells,
        selectedBellId: _selectedBellId,
        selectedPractice: _selectedPractice,
        selectedPracticeId: _selectedPracticeId,
        selectedVoiceIndex: _voiceIndex,
        selectedVoiceId: _selectedVoiceId,
        targetClockTimeHour: _clockHour,
        targetClockTimeMinute: _clockMinute,
        targetClockTimeIsAm: _isAm,
      ),
    );
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentScreen == AppScreen.configuration) {
        ensureFutureTargetTime();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(persistState());
    }
  }

  Future<void> setDeveloperMode(bool enabled) async {
    _isDeveloperMode = enabled;
    _safeNotify();
    await manifestService.setDeveloperMode(enabled);
    await preferencesService.setDeveloperMode(enabled);
    _safeNotify();
  }

  void setSelectedBellId(String id) {
    _selectedBellId = id;
    _safeNotify();
    unawaited(persistState());
  }

  void updateBell(AudioSegment updated) {
    final nextBells = List<AudioSegment>.from(_bells);
    final idx = nextBells.indexWhere((b) => b.id == updated.id);
    if (idx != -1) {
      nextBells[idx] = updated;
      _bells = nextBells;
      _safeNotify();
      unawaited(persistState());
    }
  }

  void setPracticeMode(String mode) {
    _practiceMode = mode;
    _safeNotify();
    unawaited(persistState());
  }

  void setSelectedPracticeId(String id) {
    final p = _practices.firstWhere((item) => item.id == id);
    _selectedPracticeId = id;
    _selectedPractice = p.name;
    _safeNotify();
    unawaited(persistState());
  }

  void updatePractices(List<PracticeConfig> updated) {
    _practices = List<PracticeConfig>.from(updated);
    _ensureValidSelectedPractice();
    _safeNotify();
    unawaited(preferencesService.savePractices(_practices));
    unawaited(persistState());
  }

  void setSelectedVoiceId(String id) {
    _selectedVoiceId = id;
    final idx = _voices.indexWhere((v) => v.id == id);
    _voiceIndex = idx >= 0 ? idx : 0;
    _safeNotify();
    unawaited(persistState());
  }

  void setVoiceIndex(int idx) {
    _voiceIndex = idx;
    if (idx >= 0 && idx < _voices.length) {
      _selectedVoiceId = _voices[idx].id;
    }
    _safeNotify();
    unawaited(persistState());
  }

  void updateVoices(List<VoiceConfig> updated) {
    _voices = List<VoiceConfig>.from(updated);
    _ensureValidSelectedVoice();
    _safeNotify();
    unawaited(preferencesService.saveVoices(_voices));
    unawaited(persistState());
  }

  void setClockTime(int hour, int minute, bool isAm) {
    _clockHour = hour;
    _clockMinute = minute;
    _isAm = isAm;
    _safeNotify();
    unawaited(persistState());
  }

  void setPreparationDelaySeconds(int value) {
    _preparationDelaySeconds = value;
    _safeNotify();
    unawaited(persistState());
  }

  void setInstructionDensity(double value) {
    _instructionDensity = value;
    _safeNotify();
    unawaited(persistState());
  }

  void setRedirectionDensity(double value) {
    _redirectionDensity = value;
    _safeNotify();
    unawaited(persistState());
  }

  void openSettings() {
    _previousScreen = AppScreen.configuration;
    _currentScreen = AppScreen.settings;
    _safeNotify();
  }

  void openBellSettings({required AppScreen from}) {
    _previousScreen = from;
    _currentScreen = AppScreen.bellSettings;
    _safeNotify();
    if (from == AppScreen.settings) {
      unawaited(persistState());
    }
  }

  void openManagePractices({required AppScreen from}) {
    _previousScreen = from;
    _currentScreen = AppScreen.managePractices;
    _safeNotify();
    if (from == AppScreen.settings) {
      unawaited(persistState());
    }
  }

  void openManageVoices({required AppScreen from}) {
    _previousScreen = from;
    _currentScreen = AppScreen.manageVoices;
    _safeNotify();
    if (from == AppScreen.settings) {
      unawaited(persistState());
    }
  }

  void openAbout() {
    _previousScreen = AppScreen.settings;
    _currentScreen = AppScreen.about;
    _safeNotify();
    unawaited(persistState());
  }

  void navigateBackFromSubscreen() {
    if (_currentScreen == AppScreen.practice) return;
    if (_currentScreen == AppScreen.manageVoices) {
      _ensureValidSelectedVoice();
    } else if (_currentScreen == AppScreen.managePractices) {
      _ensureValidSelectedPractice();
    }
    _currentScreen = _previousScreen;
    _safeNotify();
    unawaited(persistState());
  }

  void backFromSettings() {
    _currentScreen = AppScreen.configuration;
    _safeNotify();
    unawaited(persistState());
  }

  void closeAbout() {
    _currentScreen = _previousScreen;
    _safeNotify();
  }

  void closeBellSettings() {
    _currentScreen = _previousScreen;
    _safeNotify();
  }

  void endPracticeSession() {
    _currentScreen = AppScreen.configuration;
    _safeNotify();
  }

  void closeSessionDebug() {
    _currentScreen = AppScreen.practice;
    _safeNotify();
  }

  List<SessionItem> buildSessionQueue({
    required int targetSeconds,
    required String practiceType,
    required AudioSegment bell,
    PracticeConfig? practiceConfig,
  }) {
    if (practiceType == 'Silent') {
      return queueEngine.generateSilentSessionQueue(
        targetDurationSeconds: targetSeconds,
        selectedBell: bell,
      );
    }
    return queueEngine.generateGuidedSessionQueue(
      targetDurationSeconds: targetSeconds,
      practice: practiceConfig,
      voicePersona: _selectedVoiceId,
      selectedBell: bell,
    );
  }

  StartPracticeOutcome tryStartPractice({
    required int targetSeconds,
    required String practiceType,
    required AudioSegment bell,
    PracticeConfig? practiceConfig,
  }) {
    final minutes = targetSeconds / 60.0;
    if (minutes < 1.0 || minutes > 90.0) {
      return StartPracticeOutcome.invalidDuration;
    }

    final queue = buildSessionQueue(
      targetSeconds: targetSeconds,
      practiceType: practiceType,
      bell: bell,
      practiceConfig: practiceConfig,
    );
    if (queue.isEmpty) {
      return StartPracticeOutcome.durationTooShort;
    }

    _activeTargetSeconds = targetSeconds;
    _activeSessionQueue = queue;
    _currentScreen = AppScreen.practice;
    _safeNotify();
    return StartPracticeOutcome.started;
  }

  List<SessionItem> rebuildActivePracticeQueue(int actualSeconds) {
    final isGuided = _practiceMode != 'Silent';
    return buildSessionQueue(
      targetSeconds: actualSeconds,
      practiceType: isGuided ? 'Guided' : 'Silent',
      bell: currentBell,
      practiceConfig: isGuided ? currentPractice : null,
    );
  }

  void updateActiveSession(List<SessionItem> freshQueue, int actualSeconds) {
    _activeSessionQueue = freshQueue;
    _activeTargetSeconds = actualSeconds;
    _safeNotify();
  }
}
