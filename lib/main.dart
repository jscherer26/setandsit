import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'audio/bundled_audio_sources.dart';
import 'engine/session_queue_engine.dart';
import 'models/display_preferences.dart';
import 'models/practice_config.dart';
import 'models/voice_config.dart';
import 'services/audio_manifest_service.dart';
import 'services/preferences_service.dart';
import 'shell/setandsit_app.dart';
import 'shell/shared_preferences_key_value_store.dart';

export 'shell/setandsit_app.dart' show SetAndSitApp;
export 'state/setandsit_controller.dart' show AppScreen;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferencesKeyValueStore? store;
  PreferencesService? preferencesService;
  SavedState? savedState;
  List<VoiceConfig>? voices;
  List<PracticeConfig>? practices;
  ThemeMode themeMode = ThemeMode.system;
  int fontSizePx = DisplayPreferences.defaultFontSizePx;

  try {
    store = await SharedPreferencesKeyValueStore.open();
    preferencesService = PreferencesService(store);
    await preferencesService.resetDeveloperModeOnStartup();
    savedState = await preferencesService.loadState();
    voices = await preferencesService.loadVoices();
    practices = await preferencesService.loadPractices();
    themeMode = await preferencesService.loadThemeMode();
    fontSizePx = await preferencesService.loadFontSizePx();
  } catch (e, stack) {
    debugPrint('[SetAndSit] Error loading preferences: $e\n$stack');
  }

  const audioSourceResolver = BundledAudioSourceResolver();
  final manifestService = AudioManifestService(
    manifestSource: const BundledManifestSource(),
    audioSourceResolver: audioSourceResolver,
  );
  final queueEngine = SessionQueueEngine(
    manifestService: manifestService,
    audioSourceResolver: audioSourceResolver,
  );

  // Run app unconditionally so UI renders even if preferences encountered an error
  runApp(SetAndSitApp(
    initialState: savedState,
    initialVoices: voices,
    initialPractices: practices,
    initialDeveloperMode: false,
    initialThemeMode: themeMode,
    initialFontSizePx: fontSizePx,
    keyValueStore: store,
    preferencesService: preferencesService,
    manifestService: manifestService,
    audioSourceResolver: audioSourceResolver,
    queueEngine: queueEngine,
  ));

  // Non-blocking initialization after runApp
  unawaited(manifestService.initialize(developerMode: false).catchError((Object e) {
    debugPrint('[SetAndSit] AudioManifestService error: $e');
  }));
}
