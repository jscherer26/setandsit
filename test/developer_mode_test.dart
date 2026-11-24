import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/services/audio_manifest_service.dart';
import 'package:setandsit/services/preferences_service.dart';
import 'package:setandsit/shell/shared_preferences_key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesService preferencesService;
  late AudioManifestService manifestService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferencesKeyValueStore.open();
    preferencesService = PreferencesService(store);
    manifestService = AudioManifestService();
    await manifestService.initialize(developerMode: false);
  });

  test('PreferencesService handles developer mode persistence', () async {
    expect(await preferencesService.isDeveloperMode(), isFalse);

    await preferencesService.setDeveloperMode(true);
    expect(await preferencesService.isDeveloperMode(), isTrue);

    await preferencesService.setDeveloperMode(false);
    expect(await preferencesService.isDeveloperMode(), isFalse);
  });

  test('AudioManifestService switches asset paths and durations with Developer Mode', () async {
    // 1. With developer mode OFF
    await manifestService.setDeveloperMode(false);
    final prodPath = manifestService.getAudioAssetPath(
      voice: 'grace',
      segmentCode: 'S01',
      variantId: 'v08',
    );
    expect(prodPath, 'assets/audio/grace/S01_v08.mp3');

    // 2. With developer mode ON and staged mock changes
    await manifestService.setDeveloperMode(true);
    manifestService.setMockStagedChanges({
      "variants": {
        "S01_v08": {
          "text": "Settling into your seat—giving yourself permission to transition out of doing mode, and gently leaning into being.",
          "word_count": 17,
          "durations": {
            "grace": 8.75
          }
        }
      }
    });

    final stagedPath = manifestService.getAudioAssetPath(
      voice: 'grace',
      segmentCode: 'S01',
      variantId: 'v08',
    );
    expect(stagedPath, 'assets/audio/grace/changes/S01_v08.mp3');

    // Staged duration for S01_v08 grace should be 8.75
    final dur = manifestService.getAudioDuration(
      voice: 'grace',
      segmentCode: 'S01',
      variantId: 'v08',
    );
    expect(dur, 8.75);

    // Staged text override check
    final variants = manifestService.getVariantsForSegment('S01');
    final v08 = variants.firstWhere((v) => v.variantId == 'v08');
    expect(v08.text, contains('Settling into your seat'));
  });

  testWidgets('Triple-tapping Set&Sit prompts for passcode 2217 and activates Developer Mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SetAndSitApp());
    await tester.pumpAndSettle();

    // Verify initially no Developer Mode badge
    expect(find.text('Developer Mode'), findsNothing);

    final titleFinder = find.text('Set&Sit');
    expect(titleFinder, findsOneWidget);

    // Rapid triple tap
    await tester.tap(titleFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(titleFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(titleFinder);
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Enter passcode to enable Developer Mode:'), findsOneWidget);

    // Enter wrong passcode first
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect passcode'), findsOneWidget);
    expect(find.text('Developer Mode'), findsOneWidget); // Dialog still open

    // Enter correct passcode 2217
    await tester.enterText(find.byType(TextField), '2217');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed, red Developer Mode badge should appear
    expect(find.text('Developer Mode'), findsOneWidget);
  });
}
