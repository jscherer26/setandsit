import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/screens/practice_screen.dart';
import 'package:setandsit/theme/app_theme.dart';

class _RecordingAudioPlayer extends Fake implements AudioPlayer {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  PlayerState _state = PlayerState.stopped;
  final List<String> playedAssetPaths = [];
  int stopCalls = 0;
  int disposeCalls = 0;
  ReleaseMode releaseModeSet = ReleaseMode.release;
  double volumeSet = 1.0;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Stream<String> get onLog => _logController.stream;

  @override
  PlayerState get state => _state;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    releaseModeSet = releaseMode;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeSet = volume;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    _state = PlayerState.playing;
    if (source is AssetSource) {
      playedAssetPaths.add(source.path);
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _state = PlayerState.stopped;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _completeController.close();
    await _logController.close();
  }
}

class _WakelockToggleCodec extends StandardMessageCodec {
  const _WakelockToggleCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == 129) {
      final list = readValue(buffer) as List<Object?>;
      return list.first as bool?;
    }
    return super.readValueOfType(type, buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bell MP3 portability', () {
    test('BellData.defaultBells preserves all IDs and points to existing .mp3 files', () {
      const expectedIds = [
        'bowl_singing',
        'bowl_singing_big',
        'gong_watts',
        'gong_bodhi',
        'gong_generated',
        'bell_burma',
        'bell_burma_three',
        'bell_indian',
        'bell_meditation',
        'bell_singing',
      ];

      expect(BellData.defaultBells.map((b) => b.id).toList(), expectedIds);

      for (final bell in BellData.defaultBells) {
        expect(bell.filePath, startsWith('assets/bells/'));
        expect(bell.filePath, endsWith('.mp3'));
        expect(
          File(bell.filePath).existsSync(),
          isTrue,
          reason: 'Expected converted bell asset on disk: ${bell.filePath}',
        );
      }
    });
  });

  group('PracticeScreen audio & wakelock hardening', () {
    const wakelockToggleChannel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';

    testWidgets(
      'S16 watchdog finishes session without stopping closing bell player and preserves injected ownership',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final voicePlayer = _RecordingAudioPlayer();
        final bellPlayer = _RecordingAudioPlayer();
        addTearDown(() async {
          await voicePlayer.dispose();
          await bellPlayer.dispose();
        });

        var completedCount = 0;
        final s16Item = PlayAudioItem(
          id: 'S16_v01',
          displayTitle: 'Closing Bell & Transition',
          phaseName: 'Re-Orientation & Close',
          audioAssetPath: 'assets/audio/grace/S16_v01.mp3',
          durationSeconds: 7.0,
          segment: ClinicalSegment.S16,
          bellAssetPath: 'assets/bells/bell_meditation.mp3',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: PracticeScreen(
              sessionQueue: [s16Item],
              targetDurationSeconds: 10,
              preparationDelaySeconds: 0,
              selectedMeditationType: 'Focused Calm',
              selectedBell: BellData.defaultBells
                  .firstWhere((b) => b.id == 'bell_meditation'),
              voicePlayer: voicePlayer,
              bellPlayer: bellPlayer,
              onSessionComplete: () => completedCount++,
              onEndSession: () {},
            ),
          ),
        );

        await tester.pump();
        expect(bellPlayer.playedAssetPaths, contains('bells/bell_meditation.mp3'));
        expect(bellPlayer.stopCalls, 0);

        // Trigger +2.5s voice overlap, then advance past the 18s S16 watchdog
        await tester.pump(const Duration(seconds: 3));
        expect(voicePlayer.playedAssetPaths, contains('audio/grace/S16_v01.mp3'));

        await tester.pump(const Duration(seconds: 16));
        await tester.pump();

        expect(completedCount, 1);
        expect(find.text('Sit Complete'), findsOneWidget);
        expect(find.text('End of Formal Practice'), findsOneWidget);
        // Critical regression check: S16 watchdog must NOT stop _bellPlayer mid-decay
        expect(bellPlayer.stopCalls, 0);
        expect(voicePlayer.stopCalls, greaterThanOrEqualTo(1));

        // Unmounting PracticeScreen must not dispose injected shared players
        await tester.pumpWidget(const SizedBox.shrink());
        expect(voicePlayer.disposeCalls, 0);
        expect(bellPlayer.disposeCalls, 0);
      },
    );

    testWidgets(
      'Preparation countdown reconciles against wall-clock time on AppLifecycleState.resumed',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final voicePlayer = _RecordingAudioPlayer();
        final bellPlayer = _RecordingAudioPlayer();
        addTearDown(() async {
          await voicePlayer.dispose();
          await bellPlayer.dispose();
        });

        var currentNow = DateTime(2026, 11, 24, 12, 0, 0);
        final silenceItem = PauseSilenceItem(
          60,
          displayTitle: 'Quiet Settling Space',
          phaseName: 'Phase 1: Settling',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: PracticeScreen(
              isDeveloperMode: true,
              sessionQueue: [silenceItem],
              targetDurationSeconds: 60,
              preparationDelaySeconds: 10,
              selectedMeditationType: 'Focused Calm',
              voicePlayer: voicePlayer,
              bellPlayer: bellPlayer,
              nowProvider: () => currentNow,
              onEndSession: () {},
            ),
          ),
        );

        expect(find.text('10'), findsOneWidget);
        expect(find.text('Settling In'), findsOneWidget);

        // Simulate 4s of throttled background wall-clock progress -> partial reconciliation
        currentNow = currentNow.add(const Duration(seconds: 4));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Settling In'), findsOneWidget);

        // Simulate another 6s elapsed while backgrounded -> completes preparation immediately
        currentNow = currentNow.add(const Duration(seconds: 6));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        expect(find.text('Settling In'), findsNothing);
        expect(find.text('Quiet Settling Space'), findsOneWidget);
        expect(find.text('01:00'), findsOneWidget);
      },
    );

    testWidgets(
      'WakelockPlus re-enables on AppLifecycleState.resumed while active and stays off once finished',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final toggleCalls = <bool?>[];
        const codec = _WakelockToggleCodec();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(wakelockToggleChannel, (ByteData? message) async {
          if (message != null) {
            final decoded = codec.decodeMessage(message) as List<Object?>;
            toggleCalls.add(decoded.first as bool?);
          }
          return const StandardMessageCodec().encodeMessage(<Object?>[null]);
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMessageHandler(wakelockToggleChannel, null);
        });

        final voicePlayer = _RecordingAudioPlayer();
        final bellPlayer = _RecordingAudioPlayer();
        addTearDown(() async {
          await voicePlayer.dispose();
          await bellPlayer.dispose();
        });

        var currentNow = DateTime(2026, 11, 24, 12, 0, 0);
        final silenceItem = PauseSilenceItem(
          60,
          displayTitle: 'Quiet Settling Space',
          phaseName: 'Phase 1: Settling',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: PracticeScreen(
              sessionQueue: [silenceItem],
              targetDurationSeconds: 60,
              preparationDelaySeconds: 0,
              selectedMeditationType: 'Focused Calm',
              voicePlayer: voicePlayer,
              bellPlayer: bellPlayer,
              nowProvider: () => currentNow,
              onEndSession: () {},
            ),
          ),
        );
        await tester.pump();

        // Initial enable on mount
        expect(toggleCalls, [true]);

        // Mid-session resume re-enables wakelock
        currentNow = currentNow.add(const Duration(seconds: 10));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(toggleCalls, [true, true]);

        // Resume after expiration finishes session and disables wakelock without re-enabling
        currentNow = currentNow.add(const Duration(seconds: 60));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.text('Sit Complete'), findsOneWidget);
        expect(toggleCalls, [true, true, false]);

        // Subsequent resume while already finished does not re-enable wakelock
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(toggleCalls, [true, true, false]);
      },
    );
  });
}
