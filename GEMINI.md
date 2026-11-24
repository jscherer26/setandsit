# Set&Sit — Project Rules

## Scope & Architecture
- **Standalone Offline App (Embeddable Core)**: Set&Sit operates as a standalone, offline, on-device Flutter app (Android, iOS, Web/GitHub Pages) with no user accounts, telemetry, or backend dependencies; external network use is limited to explicit links via `url_launcher`. Its embeddable core (`lib/setandsit_module.dart`, `SetAndSitRoot`, `SetAndSitController`) is decoupled from the thin standalone shell (`lib/main.dart`, `lib/shell/`) via injectable storage, manifest/audio, and `SetAndSitHostOptions` seams so a host app can embed it cleanly later.
- **State & Navigation**: State and `AppScreen` navigation live in the pure-Flutter `ChangeNotifier` `SetAndSitController` (`lib/state/setandsit_controller.dart`) rendered by `SetAndSitRoot` (`lib/setandsit_root.dart`) via `ListenableBuilder` and `PopScope`. Do not introduce third-party state management, DI, or router packages, or `build_runner`.

## UI & Brand Overrides (vs. Global UI Preferences)
- **Brand Palette**: Use Set&Sit's Botanical Minimalist Linen & Olive palette in `lib/theme/app_theme.dart` (`AppColors.background` `#F3F3EE`, `AppColors.darkOlive` `#434C28`) in standalone mode rather than the global Forest Green seed default; `AppSemanticColors.of(context)` falls back safely when embedded inside a host theme.
- **Responsive Web Frame**: On desktop web (`maxWidth > 500`), preserve the centered `440px` phone-frame wrapper in the standalone shell (`SetAndSitApp` in `lib/shell/setandsit_app.dart`) rather than expanding to a widescreen/rail layout.

## Clinical & Audio Engine Invariants
- **16-Segment Taxonomy (`S01`–`S16`)**: `lib/models/practice_config.dart` is the source of truth for phases (`Phase 1: S01–S05`, `Phase 2: S06–S08`, `Phase 3: S09–S11`, `Phase 4: S12`, `Phase 5: S13–S16`), system archetypes, and mandatory segments (`S01, S02, S12, S15, S16`). Every practice must retain mandatory segments and at least one core segment (`S03`–`S11`).
- **Timeline & Closing Overlap**: Instance-based `SessionQueueEngine` (`lib/engine/session_queue_engine.dart`) governs the Progressive Settling Funnel, segment pruning, and the `+2.5s` dual-player `S16` bell overlap. Any engine change must pass `test/timeline_engine_test.dart`.
- **Audio Assets & Voices**: `ManifestSource` and `AudioSourceResolver` (`lib/audio/audio_sources.dart`) decouple manifest loading and audio clip resolution (voice clips, bells, silence keep-alive, staged overrides) from bundled assets. Standalone mode defaults to 100% offline `BundledManifestSource` and `BundledAudioSourceResolver` backed by `assets/raw/session_manifest.json`, `assets/raw/audio_durations.json`, and `Grace` (`assets/audio/grace/`); legacy `kia` is retired and intentionally purged on load.
- **Developer Mode**: `pref_developer_mode` gates staged audio/script overrides (`assets/audio/changes_manifest.json`) and must always reset to `false` on fresh standalone app startup (`PreferencesService.resetDeveloperModeOnStartup()`).

## Persistence & Naming
- **Local Storage & Zero Static State**: Services (`PreferencesService`, `AudioManifestService`, `SessionQueueEngine`) must be instance-based with zero global/static mutable caches. `PreferencesService` persists through an injectable `KeyValueStore` (`lib/storage/key_value_store.dart`), isolating `shared_preferences` strictly to `lib/shell/shared_preferences_key_value_store.dart`, using atomic `pref_*` keys and JSON lists for practices/voices. UI screens must never import `shared_preferences`, `dart:convert`, `PreferencesService`, or `AudioManifestService` directly.
- **Existing Model JSON Keys**: Preserve existing `camelCase` JSON keys in `PracticeConfig` and `VoiceConfig` (`isSystem`, `isIncluded`, `segmentIds`, `assetFolder`) for backwards compatibility with stored user preferences; use `lowercase_snake_case` for any new `pref_*` keys and asset manifest schemas.

## Verification & Deployment
- Run `flutter analyze` and `flutter test` after edits.
- Pushes to `main` automatically build and deploy Flutter Web to GitHub Pages via `.github/workflows/deploy.yml` (`--base-href "/SetAndSit/"`).
