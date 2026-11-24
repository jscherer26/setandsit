import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/models/practice_config.dart';
import 'package:setandsit/models/voice_config.dart';
import 'package:setandsit/screens/about_screen.dart';
import 'package:setandsit/screens/bell_configuration_screen.dart';
import 'package:setandsit/screens/clock_time_picker_dialog.dart';
import 'package:setandsit/screens/configuration_screen.dart';
import 'package:setandsit/screens/manage_practices_screen.dart';
import 'package:setandsit/screens/manage_voices_screen.dart';
import 'package:setandsit/screens/practice_screen.dart';
import 'package:setandsit/screens/session_debug_screen.dart';
import 'package:setandsit/screens/settings_screen.dart';
import 'package:setandsit/models/display_preferences.dart';
import 'package:setandsit/services/preferences_service.dart';
import 'package:setandsit/shell/shared_preferences_key_value_store.dart';
import 'package:setandsit/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pref_clock_hour': 8,
      'pref_clock_minute': 3,
      'pref_clock_is_am': true,
      'pref_duration': 3,
      'pref_prep_delay': 3,
    });
    final store = await SharedPreferencesKeyValueStore.open();
    preferencesService = PreferencesService(store);
    PackageInfo.setMockInitialValues(
      appName: 'Set&Sit',
      packageName: 'com.example.setandsit',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('Display & Appearance Preferences', () {
    test('PreferencesService round-trips themeMode and clamps fontSizePx to 2px stops', () async {
      expect(await preferencesService.loadThemeMode(), ThemeMode.system);
      expect(await preferencesService.loadFontSizePx(), 18);

      await preferencesService.saveThemeMode(ThemeMode.dark);
      expect(await preferencesService.loadThemeMode(), ThemeMode.dark);

      await preferencesService.saveThemeMode(ThemeMode.light);
      expect(await preferencesService.loadThemeMode(), ThemeMode.light);

      await preferencesService.saveFontSizePx(24);
      expect(await preferencesService.loadFontSizePx(), 24);

      // Out-of-bounds and odd values clamp/snap to 2px stops [14..24]
      await preferencesService.saveFontSizePx(10);
      expect(await preferencesService.loadFontSizePx(), 14);

      await preferencesService.saveFontSizePx(30);
      expect(await preferencesService.loadFontSizePx(), 24);

      await preferencesService.saveFontSizePx(19);
      expect(await preferencesService.loadFontSizePx(), 20);
    });

    testWidgets('Settings Display & Appearance updates ThemeMode and Text Size and persists',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Open Settings via Home gear icon
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Scroll to Display & Appearance
      await tester.scrollUntilVisible(
        find.text('Display & Appearance'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Display & Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      for (final px in DisplayPreferences.allowedFontSizes) {
        expect(find.text('${px}px'), findsOneWidget);
      }

      // Select Dark theme
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Select 24px text size
      await tester.scrollUntilVisible(
        find.text('24px'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('24px'));
      await tester.pumpAndSettle();

      // Verify persistence
      expect(await preferencesService.loadThemeMode(), ThemeMode.dark);
      expect(await preferencesService.loadFontSizePx(), 24);

      // Verify MaterialApp reflects dark ThemeMode and scaled MediaQuery
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    });

    testWidgets('Developer Mode card appears at bottom of Settings only when active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SettingsScreen(
            practiceDurationMinutes: 3,
            instructionDensity: 3.0,
            redirectionDensity: 3.0,
            isDeveloperMode: false,
            onPracticeDurationChanged: (_) {},
            onInstructionDensityChanged: (_) {},
            onRedirectionDensityChanged: (_) {},
            onPreparationDelayChanged: (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Staged Audio Overrides Active'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SettingsScreen(
            practiceDurationMinutes: 3,
            instructionDensity: 3.0,
            redirectionDensity: 3.0,
            isDeveloperMode: true,
            stagedVariantsCount: 1,
            onDisableDeveloperMode: () {},
            onPracticeDurationChanged: (_) {},
            onInstructionDensityChanged: (_) {},
            onRedirectionDensityChanged: (_) {},
            onPreparationDelayChanged: (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Staged Audio Overrides Active'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Staged Audio Overrides Active'), findsOneWidget);
      expect(find.text('Staged variants loaded: 1'), findsOneWidget);
      expect(find.text('Disable Developer Mode'), findsOneWidget);
    });
  });

  group('Narrow Mobile (360x780) & 1.50x Text Scaling Compliance', () {
    Future<void> pumpScaledScreen(
      WidgetTester tester, {
      required ThemeData theme,
      required Widget child,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Capture FlutterError overflows reliably during layout
      final originalOnError = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) {
        errors.add(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: inner!,
          ),
          home: child,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
      expect(tester.takeException(), isNull);
    }

    for (final entry in {
      'Light': AppTheme.light(),
      'Dark': AppTheme.dark(),
    }.entries) {
      final modeName = entry.key;
      final theme = entry.value;

      testWidgets('Home screen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: ConfigurationScreen(
            onOpenSettings: () {},
            practiceDurationMinutes: 10,
            onEnsureFutureTime: () {},
            bells: BellData.defaultBells,
            selectedBellId: 'bell_meditation',
            onSelectedBellChanged: (_) {},
            onOpenBellSettings: () {},
            selectedType: 'Guided',
            onSelectedTypeChanged: (_) {},
            practices: PracticeConfig.defaultPractices,
            selectedPracticeId: 'focused_calm',
            onSelectedPracticeIdChanged: (_) {},
            onOpenManagePractices: () {},
            voices: VoiceConfig.defaultVoices,
            selectedVoiceId: 'grace',
            isDeveloperMode: true,
            clockHour: 9,
            clockMinute: 30,
            isAm: true,
            onClockTimeChanged: (_, _, _) {},
            onBeginPractice: (_, _, _, _) {},
          ),
        );
        expect(find.text('Set&Sit'), findsOneWidget);
      });

      testWidgets('Settings screen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: SettingsScreen(
            practiceDurationMinutes: 10,
            instructionDensity: 3.0,
            redirectionDensity: 3.0,
            themeMode: ThemeMode.dark,
            fontSizePx: 24,
            isDeveloperMode: true,
            stagedVariantsCount: 1,
            onDisableDeveloperMode: () {},
            onPracticeDurationChanged: (_) {},
            onInstructionDensityChanged: (_) {},
            onRedirectionDensityChanged: (_) {},
            onPreparationDelayChanged: (_) {},
            onBack: () {},
            onOpenManagePractices: () {},
            onOpenManageVoices: () {},
            onOpenBellSettings: () {},
            onOpenAbout: () {},
          ),
        );
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('ManagePracticesScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: ManagePracticesScreen(
            initialPractices: PracticeConfig.defaultPractices,
            initialSelectedPracticeId: 'focused_calm',
            onPracticesUpdated: (_) {},
            onBack: () {},
          ),
        );
        expect(find.text('Manage Practices'), findsOneWidget);
      });

      testWidgets('ManageVoicesScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: ManageVoicesScreen(
            isDeveloperMode: true,
            initialVoices: VoiceConfig.defaultVoices,
            initialSelectedVoiceId: 'grace',
            onVoicesUpdated: (_) {},
            onBack: () {},
          ),
        );
        expect(find.text('Manage Voices'), findsOneWidget);
      });

      testWidgets('BellConfigurationScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: BellConfigurationScreen(
            bells: BellData.defaultBells,
            selectedBellId: 'bell_meditation',
            onBellSelected: (_) {},
            onBellUpdated: (_) {},
            onBack: () {},
          ),
        );
        expect(find.text('Manage Bells'), findsOneWidget);
      });

      testWidgets('AboutScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: AboutScreen(onBack: () {}),
        );
        expect(find.text('About Set&Sit'), findsOneWidget);
      });

      testWidgets('PracticeScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: PracticeScreen(
            isDeveloperMode: true,
            sessionQueue: [
              PauseSilenceItem(
                60,
                displayTitle: 'Quiet Settling Space',
                phaseName: 'Phase 1: Settling',
              ),
            ],
            targetDurationSeconds: 60,
            preparationDelaySeconds: 5,
            selectedMeditationType: 'Trauma-Sensitive Grounding',
            onEndSession: () {},
          ),
        );
        expect(find.text('Practice'), findsOneWidget);
      });

      testWidgets('SessionDebugScreen renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: SessionDebugScreen(
            targetSeconds: 600,
            selectedType: 'Trauma-Sensitive Grounding',
            instructionDensity: 3.0,
            redirectionDensity: 3.0,
            selectedBell: BellData.defaultBells.first,
            sessionQueue: [
              PauseSilenceItem(
                30,
                displayTitle: 'Quiet Settling Space',
                phaseName: 'Arrival & Agency',
              ),
              PlayAudioItem(
                id: 'S16_v01',
                displayTitle: 'Closing Bell & Transition',
                phaseName: 'Re-Orientation & Close',
                audioAssetPath: 'assets/audio/grace/S16_v01.mp3',
                durationSeconds: 7.0,
                segment: ClinicalSegment.S16,
                bellAssetPath: 'assets/bells/bell_meditation.mp3',
              ),
            ],
            onBack: () {},
          ),
        );
        expect(find.text('Session Debugger'), findsOneWidget);
      });

      testWidgets('ClockTimePickerDialog renders with zero overflow in $modeName at 1.50x',
          (WidgetTester tester) async {
        await pumpScaledScreen(
          tester,
          theme: theme,
          child: const Scaffold(
            body: ClockTimePickerDialog(
              initialHour12: 12,
              initialMinute: 45,
              initialIsAm: false,
            ),
          ),
        );
        expect(find.text('Select Finish Time'), findsOneWidget);
      });
    }
  });
}
