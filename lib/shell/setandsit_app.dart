import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../audio/audio_sources.dart';
import '../audio/bundled_audio_sources.dart';
import '../engine/session_queue_engine.dart';
import '../models/display_preferences.dart';
import '../models/host_options.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../services/audio_manifest_service.dart';
import '../services/preferences_service.dart';
import '../setandsit_root.dart';
import '../state/setandsit_controller.dart';
import '../storage/key_value_store.dart';
import '../theme/app_theme.dart';
import 'shared_preferences_key_value_store.dart';

/// Thin standalone Set&Sit application shell owning `MaterialApp`,
/// Botanical Light/Dark theme, desktop web 440px frame, and app-level display prefs.
class SetAndSitApp extends StatefulWidget {
  final SavedState? initialState;
  final List<VoiceConfig>? initialVoices;
  final List<PracticeConfig>? initialPractices;
  final bool? initialDeveloperMode;
  final ThemeMode? initialThemeMode;
  final int? initialFontSizePx;
  final KeyValueStore? keyValueStore;
  final PreferencesService? preferencesService;
  final ManifestSource? manifestSource;
  final AudioSourceResolver? audioSourceResolver;
  final AudioManifestService? manifestService;
  final SessionQueueEngine? queueEngine;

  const SetAndSitApp({
    super.key,
    this.initialState,
    this.initialVoices,
    this.initialPractices,
    this.initialDeveloperMode,
    this.initialThemeMode,
    this.initialFontSizePx,
    this.keyValueStore,
    this.preferencesService,
    this.manifestSource,
    this.audioSourceResolver,
    this.manifestService,
    this.queueEngine,
  });

  @override
  State<SetAndSitApp> createState() => _SetAndSitAppState();
}

class _SetAndSitAppState extends State<SetAndSitApp> {
  late final KeyValueStore _keyValueStore;
  late final PreferencesService _preferencesService;
  late final AudioManifestService _manifestService;
  late final SessionQueueEngine _queueEngine;
  late final AudioSourceResolver _audioSourceResolver;
  late final SetAndSitController _controller;

  late ThemeMode _themeMode;
  late int _fontSizePx;
  bool _themeEditedByUser = false;
  bool _fontEditedByUser = false;

  @override
  void initState() {
    super.initState();
    _audioSourceResolver =
        widget.audioSourceResolver ?? const BundledAudioSourceResolver();
    final deferredStore =
        widget.keyValueStore == null && widget.preferencesService == null
            ? DeferredSharedPreferencesKeyValueStore()
            : null;
    _keyValueStore =
        widget.keyValueStore ?? deferredStore ?? InMemoryKeyValueStore();
    _preferencesService =
        widget.preferencesService ?? PreferencesService(_keyValueStore);
    _manifestService = widget.manifestService ??
        AudioManifestService(
          manifestSource:
              widget.manifestSource ?? const BundledManifestSource(),
          audioSourceResolver: _audioSourceResolver,
        );
    _queueEngine = widget.queueEngine ??
        SessionQueueEngine(
          manifestService: _manifestService,
          audioSourceResolver: _audioSourceResolver,
        );
    _controller = SetAndSitController(
      preferencesService: _preferencesService,
      manifestService: _manifestService,
      queueEngine: _queueEngine,
      audioSourceResolver: _audioSourceResolver,
      initialState: widget.initialState,
      initialVoices: widget.initialVoices,
      initialPractices: widget.initialPractices,
      initialDeveloperMode: widget.initialDeveloperMode,
    );

    _themeMode = widget.initialThemeMode ?? ThemeMode.system;
    _fontSizePx =
        DisplayPreferences.normalizeFontSizePx(widget.initialFontSizePx);

    unawaited(_bootstrap(deferredStore));
  }

  Future<void> _bootstrap(
    DeferredSharedPreferencesKeyValueStore? deferredStore,
  ) async {
    if (deferredStore != null) {
      await deferredStore.open();
    }
    if (!mounted) return;

    if (!_controller.isInitialized) {
      await _controller.loadFromPreferences();
    }
    if (!mounted) return;

    if (widget.initialThemeMode == null || widget.initialFontSizePx == null) {
      await _loadDisplayPreferences();
    }

    unawaited(
      _manifestService
          .initialize(developerMode: widget.initialDeveloperMode ?? false)
          .catchError((Object e) {
        debugPrint('[SetAndSitApp] AudioManifestService error: $e');
      }),
    );
  }

  @override
  void didUpdateWidget(covariant SetAndSitApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialThemeMode != null &&
        widget.initialThemeMode != oldWidget.initialThemeMode) {
      _themeMode = widget.initialThemeMode!;
    }
    if (widget.initialFontSizePx != null &&
        widget.initialFontSizePx != oldWidget.initialFontSizePx) {
      _fontSizePx =
          DisplayPreferences.normalizeFontSizePx(widget.initialFontSizePx);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDisplayPreferences() async {
    final loadedTheme = await _preferencesService.loadThemeMode();
    final loadedFont = await _preferencesService.loadFontSizePx();
    if (!mounted) return;
    setState(() {
      if (widget.initialThemeMode == null && !_themeEditedByUser) {
        _themeMode = loadedTheme;
      }
      if (widget.initialFontSizePx == null && !_fontEditedByUser) {
        _fontSizePx = loadedFont;
      }
    });
  }

  void _handleThemeModeChanged(ThemeMode mode) {
    setState(() {
      _themeEditedByUser = true;
      _themeMode = mode;
    });
    unawaited(_preferencesService.saveThemeMode(mode));
  }

  void _handleFontSizeChanged(int fontSizePx) {
    final normalized = DisplayPreferences.normalizeFontSizePx(fontSizePx);
    setState(() {
      _fontEditedByUser = true;
      _fontSizePx = normalized;
    });
    unawaited(_preferencesService.saveFontSizePx(normalized));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Set&Sit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final baseScaler = mediaQuery.textScaler;
        final appScale = _fontSizePx / DisplayPreferences.defaultFontSizePx;
        final effectiveScaler = appScale == 1.0
            ? baseScaler
            : TextScaler.linear(baseScaler.scale(1.0) * appScale);

        if (!kIsWeb) {
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: effectiveScaler),
            child: child ?? const SizedBox.shrink(),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // When opened on a mobile device's browser, fill the screen normally
            if (constraints.maxWidth <= 500) {
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: effectiveScaler),
                child: child ?? const SizedBox.shrink(),
              );
            }
            // On desktop/laptop web browsers, constrain to phone width and center with a backdrop
            const double maxAppWidth = 440;
            final semantic = AppSemanticColors.of(context);
            return Container(
              color: semantic.desktopFrameBackdrop,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: maxAppWidth),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        size: Size(maxAppWidth, constraints.maxHeight),
                        textScaler: effectiveScaler,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      home: SetAndSitRoot(
        controller: _controller,
        hostOptions: SetAndSitHostOptions(
          themeMode: _themeMode,
          fontSizePx: _fontSizePx,
          onThemeModeChanged: _handleThemeModeChanged,
          onFontSizePxChanged: _handleFontSizeChanged,
          showDisplaySettings: true,
          showAbout: true,
          allowDeveloperMode: true,
        ),
      ),
    );
  }
}
