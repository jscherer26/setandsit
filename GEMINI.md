# Set&Sit — Project Rules

## Scope & Architecture
- **Standalone Offline App**: Set&Sit currently operates as a standalone, offline, on-device Flutter app (Android, iOS, Web/GitHub Pages) with no user accounts, telemetry, or backend dependencies (no `villagersally.com` or `personal_cloud_hub` integration); external network use is currently limited to explicit links via `url_launcher`.
- **State & Navigation**: State is currently lifted in `RootControllerScreen` (`lib/main.dart`) using vanilla `StatefulWidget` and the `AppScreen` enum stack with `PopScope`. Do not introduce third-party state management or router packages unless requested.

## UI & Brand Overrides (vs. Global UI Preferences)
- **Brand Palette**: Use Set&Sit's Botanical Minimalist Linen & Olive palette in `lib/theme/app_theme.dart` (`AppColors.background` `#F3F3EE`, `AppColors.darkOlive` `#434C28`) rather than the global Forest Green seed default.
- **Responsive Web Frame**: On desktop web (`maxWidth > 500`), preserve the centered `440px` phone-frame wrapper in `SetAndSitApp` (`lib/main.dart`) rather than expanding to a widescreen/rail layout.

## Clinical & Audio Engine Invariants
- **16-Segment Taxonomy (`S01`–`S16`)**: `lib/models/practice_config.dart` is the source of truth for phases (`Phase 1: S01–S05`, `Phase 2: S06–S08`, `Phase 3: S09–S11`, `Phase 4: S12`, `Phase 5: S13–S16`), system archetypes, and mandatory segments (`S01, S02, S12, S15, S16`). Every practice must retain mandatory segments and at least one core segment (`S03`–`S11`).
- **Timeline & Closing Overlap**: `SessionQueueEngine` (`lib/engine/session_queue_engine.dart`) governs the Progressive Settling Funnel, segment pruning, and the `+2.5s` dual-player `S16` bell overlap. Any engine change must pass `test/timeline_engine_test.dart`.
- **Audio Assets & Voices**: `assets/raw/session_manifest.json` and `assets/raw/audio_durations.json` are the source of truth for script variants and durations. `Grace` (`assets/audio/grace/`) is the active voice; legacy `kia` is retired and intentionally purged on load.
- **Developer Mode**: `pref_developer_mode` gates staged audio/script overrides (`assets/audio/changes_manifest.json`) and must always reset to `false` on fresh app startup (`PreferencesService.resetDeveloperModeOnStartup()`).

## Persistence & Naming
- **Local Storage**: Preferences currently persist through `PreferencesService` (`shared_preferences`) using atomic `pref_*` keys and JSON lists for practices/voices.
- **Existing Model JSON Keys**: Preserve existing `camelCase` JSON keys in `PracticeConfig` and `VoiceConfig` (`isSystem`, `isIncluded`, `segmentIds`, `assetFolder`) for backwards compatibility with stored user preferences; use `lowercase_snake_case` for any new `pref_*` keys and asset manifest schemas.

## Verification & Deployment
- Run `flutter analyze` and `flutter test` after edits.
- Pushes to `main` automatically build and deploy Flutter Web to GitHub Pages via `.github/workflows/deploy.yml` (`--base-href "/SetAndSit/"`).
