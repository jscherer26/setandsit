import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setandsit/setandsit_module.dart';

class _FakeUrlAudioSourceResolver implements AudioSourceResolver {
  static const String _baseUrl = 'https://cdn.example.test';

  const _FakeUrlAudioSourceResolver();

  @override
  ResolvedAudio resolveVoiceClip({
    required String voiceId,
    required String segmentCode,
    required String variantId,
    bool useStagedOverride = false,
  }) {
    final vNorm = voiceId.trim().toLowerCase();
    final segmentPath = useStagedOverride
        ? '$_baseUrl/audio/$vNorm/changes/${segmentCode}_$variantId.mp3'
        : '$_baseUrl/audio/$vNorm/${segmentCode}_$variantId.mp3';
    return ResolvedAudio(
      source: UrlSource(segmentPath),
      debugLabel: segmentPath,
    );
  }

  @override
  ResolvedAudio resolveBellClip(AudioSegment bell) {
    final url = '$_baseUrl/bells/${bell.id}.mp3';
    return ResolvedAudio(
      source: UrlSource(url),
      debugLabel: url,
    );
  }

  @override
  ResolvedAudio resolveSilenceKeepAlive() {
    const url = '$_baseUrl/audio/silence.mp3';
    return ResolvedAudio(
      source: UrlSource(url),
      debugLabel: url,
    );
  }

  @override
  ResolvedAudio resolveAudioReference(String reference) {
    final url = reference.startsWith('http') ? reference : '$_baseUrl/$reference';
    return ResolvedAudio(
      source: UrlSource(url),
      debugLabel: url,
    );
  }
}

InMemoryManifestSource _buildFakeManifestSource() {
  final sessionManifest = <String, dynamic>{
    'app': 'SetAndSit',
    'schema_version': '3.5.0',
    'description': 'In-memory test manifest',
    'script_bank': <String, dynamic>{
      for (final seg in ClinicalSegment.values)
        seg.code: <Map<String, dynamic>>[
          <String, dynamic>{
            'variant_id': 'v01',
            'variant_name': '1. Default ${seg.code}',
            'active': true,
            'text': 'Script text for ${seg.code}',
            'word_count': 4,
          },
        ],
    },
  };

  final durations = <String, dynamic>{
    'grace': <String, dynamic>{
      for (final seg in ClinicalSegment.values)
        seg.code: <String, dynamic>{'v01': seg == ClinicalSegment.S16 ? 5.0 : 8.0},
    },
  };

  final staged = <String, dynamic>{
    'staged_at': '2026-11-24T00:00:00Z',
    'variants': <String, dynamic>{
      'S01_v01': <String, dynamic>{
        'text': 'Staged override S01 text',
        'word_count': 4,
        'durations': <String, dynamic>{'grace': 6.5},
      },
    },
  };

  return InMemoryManifestSource(
    sessionManifestJson: jsonEncode(sessionManifest),
    audioDurationsJson: jsonEncode(durations),
    stagedChangesJson: jsonEncode(staged),
  );
}

void main() {
  group('Modular persistence seam (PreferencesService + InMemoryKeyValueStore)', () {
    test('round-trips state, practices, voices, display prefs, migrations, and dev mode reset', () async {
      final store = InMemoryKeyValueStore({
        'set_and_sit_voices': jsonEncode([
          {
            'id': 'kia',
            'name': 'Kia',
            'description': 'Retired',
            'gender': 'Male',
            'isSystem': true,
            'isIncluded': true,
            'assetFolder': 'assets/audio/voices/kia',
          },
          VoiceConfig.defaultVoices.first.toJson(),
        ]),
        'set_and_sit_practices': jsonEncode([
          {
            'id': 'trauma_informed',
            'name': 'Trauma-Informed Regulation',
            'subtitle': 'Old',
            'isSystem': true,
            'isIncluded': true,
            'segmentIds': ['S01', 'S02', 'S04', 'S12', 'S15', 'S16'],
          },
        ]),
        'pref_selected_voice_id': 'kia',
        'pref_selected_practice_name': 'Trauma-Informed Regulation',
        'pref_developer_mode': true,
      });

      final prefs = PreferencesService(store);

      // Dev mode startup reset
      expect(await prefs.isDeveloperMode(), isTrue);
      await prefs.resetDeveloperModeOnStartup();
      expect(await prefs.isDeveloperMode(), isFalse);

      // Legacy kia purge & Trauma rename migration
      final voices = await prefs.loadVoices();
      expect(voices.any((v) => v.id == 'kia'), isFalse);
      expect(voices.any((v) => v.id == 'grace'), isTrue);

      final practices = await prefs.loadPractices();
      expect(
        practices.firstWhere((p) => p.id == 'trauma_informed').name,
        'Trauma-Sensitive Grounding',
      );

      final state = await prefs.loadState();
      expect(state.selectedVoiceId, 'grace');
      expect(state.selectedPractice, 'Trauma-Sensitive Grounding');

      // Display preferences & full SavedState round-trip
      await prefs.saveThemeMode(ThemeMode.dark);
      await prefs.saveFontSizePx(21);
      expect(await prefs.loadThemeMode(), ThemeMode.dark);
      expect(await prefs.loadFontSizePx(), 22);

      final updated = state.copyWith(
        practiceDurationMinutes: 20,
        practiceMode: 'Silent',
        selectedBellId: 'gong_watts',
      );
      await prefs.saveState(updated);
      final reloaded = await prefs.loadState();
      expect(reloaded.practiceDurationMinutes, 20);
      expect(reloaded.practiceMode, 'Silent');
      expect(reloaded.selectedBellId, 'gong_watts');
    });
  });

  group('Decoupled audio & manifest seam (InMemoryManifestSource + UrlSource resolver)', () {
    test('resolves voice clips, bells, silence keep-alive, and staged overrides to UrlSource', () async {
      final manifestSource = _buildFakeManifestSource();
      const resolver = _FakeUrlAudioSourceResolver();
      final manifestService = AudioManifestService(
        manifestSource: manifestSource,
        audioSourceResolver: resolver,
      );
      await manifestService.initialize(developerMode: false);

      final engine = SessionQueueEngine(
        manifestService: manifestService,
        audioSourceResolver: resolver,
        random: Random(0),
      );

      final keepAlive = resolver.resolveSilenceKeepAlive();
      expect(keepAlive.source, isA<UrlSource>());
      expect(
        (keepAlive.source as UrlSource).url,
        'https://cdn.example.test/audio/silence.mp3',
      );

      // Standard mode
      final prodQueue = engine.generateGuidedSessionQueue(
        targetDurationSeconds: 120,
        archetype: ClinicalArchetype.focusedCalm,
        voicePersona: 'grace',
        selectedBell: BellData.defaultBells.first,
      );
      final s01Prod = prodQueue.whereType<PlayAudioItem>().firstWhere(
            (i) => i.segment == ClinicalSegment.S01,
          );
      expect(s01Prod.isStagedOverride, isFalse);
      expect(s01Prod.audioAssetPath, 'https://cdn.example.test/audio/grace/S01_v01.mp3');
      expect(s01Prod.durationSeconds, 8.0);

      final s16Prod = prodQueue.whereType<PlayAudioItem>().firstWhere(
            (i) => i.segment == ClinicalSegment.S16,
          );
      expect(
        s16Prod.bellAssetPath,
        'https://cdn.example.test/bells/${BellData.defaultBells.first.id}.mp3',
      );

      // Developer Mode enabled -> resolves staged S01 text, duration, and UrlSource
      await manifestService.setDeveloperMode(true);
      final stagedAudio = manifestService.resolveVoiceAudio(
        voice: 'grace',
        segmentCode: 'S01',
        variantId: 'v01',
      );
      expect(stagedAudio.source, isA<UrlSource>());
      expect(
        (stagedAudio.source as UrlSource).url,
        'https://cdn.example.test/audio/grace/changes/S01_v01.mp3',
      );
      expect(
        manifestService.getAudioDuration(
          voice: 'grace',
          segmentCode: 'S01',
          variantId: 'v01',
        ),
        6.5,
      );
      expect(
        manifestService.getVariantsForSegment('S01').first.text,
        'Staged override S01 text',
      );
    });
  });

  group('Zero static state isolation across concurrent controllers', () {
    test('two SetAndSitController instances maintain completely independent state', () async {
      final controllerA = SetAndSitController(
        preferencesService: PreferencesService(InMemoryKeyValueStore()),
        manifestService: AudioManifestService(
          manifestSource: _buildFakeManifestSource(),
          audioSourceResolver: const _FakeUrlAudioSourceResolver(),
        ),
      );
      final controllerB = SetAndSitController(
        preferencesService: PreferencesService(InMemoryKeyValueStore()),
        manifestService: AudioManifestService(
          manifestSource: _buildFakeManifestSource(),
          audioSourceResolver: const _FakeUrlAudioSourceResolver(),
        ),
      );
      addTearDown(() {
        controllerA.dispose();
        controllerB.dispose();
      });

      await controllerA.loadFromPreferences();
      await controllerB.loadFromPreferences();

      await controllerA.setDeveloperMode(true);
      controllerA.updateBell(
        controllerA.bells.first.copyWith(isEnabled: false),
      );
      controllerA.updatePractices([
        ...controllerA.practices,
        PracticeConfig(
          id: 'custom_a',
          name: 'Controller A Practice',
          subtitle: 'Isolated',
          segmentIds: ['S01', 'S02', 'S03', 'S12', 'S15', 'S16'],
        ),
      ]);

      expect(controllerA.isDeveloperMode, isTrue);
      expect(controllerB.isDeveloperMode, isFalse);

      expect(controllerA.bells.first.isEnabled, isFalse);
      expect(controllerB.bells.first.isEnabled, isTrue);
      expect(BellData.defaultBells.first.isEnabled, isTrue);

      expect(controllerA.practices.any((p) => p.id == 'custom_a'), isTrue);
      expect(controllerB.practices.any((p) => p.id == 'custom_a'), isFalse);
    });
  });

  group('Embedded SetAndSitRoot host integration', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'renders inside host MaterialApp in ${brightness.name} mode and respects SetAndSitHostOptions',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(420, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var exited = false;
          final store = InMemoryKeyValueStore();

          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? ThemeData.light(useMaterial3: true)
                  : ThemeData.dark(useMaterial3: true),
              home: SetAndSitRoot(
                keyValueStore: store,
                manifestSource: _buildFakeManifestSource(),
                audioSourceResolver: const _FakeUrlAudioSourceResolver(),
                hostOptions: SetAndSitHostOptions(
                  showDisplaySettings: false,
                  showAbout: false,
                  allowDeveloperMode: false,
                  onExitModule: () => exited = true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Exit back button is present and invokes host callback
          final exitBtn = find.byTooltip('Back');
          expect(exitBtn, findsOneWidget);
          await tester.tap(exitBtn);
          expect(exited, isTrue);

          // Triple-tap on Set&Sit title must NOT open Developer Mode dialog when allowDeveloperMode is false
          final title = find.text('Set&Sit');
          await tester.tap(title);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(title);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(
            find.text('Enter passcode to enable Developer Mode:'),
            findsNothing,
          );

          // Settings hides Display & Appearance and About when opted out by host
          await tester.tap(find.byIcon(Icons.settings));
          await tester.pumpAndSettle();
          expect(find.text('Settings'), findsOneWidget);
          expect(find.text('Display & Appearance'), findsNothing);
          expect(find.text('About Set&Sit'), findsNothing);
        },
      );
    }
  });
}
