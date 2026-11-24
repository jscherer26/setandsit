# Set&Sit

Clinical meditation and somatic mindfulness application built with Flutter (`sdk: ^3.13.5`).

Set&Sit calculates dynamically proportioned silence intervals between spoken guidance segments based on a wall-clock target finish time or explicit duration input (1–90 minutes). The application currently operates offline on-device without user accounts, telemetry, or backend dependencies.

## Clinical Features

- **16-Segment Clinical Meditation Taxonomy** (`S01`–`S16`) across four system archetypes:
  - Focused Calm
  - Trauma-Sensitive Grounding
  - Open Awareness / Insight
  - Metta / Compassion
- **Progressive Settling Funnel** with dynamic silence timing and segment pruning
- **Acoustic Bell Integration** with 10 selectable bells/bowls and dual-player `S16` closing overlap
- **Voice Guidance** featuring the `Grace` persona (with custom voice management)
- **Custom Practice Configuration**, preparation delay settings, and About / version info

## Architecture

- **Comprehensive Runtime Architecture**: See [project_architecture.md](project_architecture.md) for navigation lifecycles, `lib/` structure, clinical taxonomy (`S01`–`S16`), asset hierarchy, persistence design, dependencies, and test coverage.

## Running & Building

```bash
# Install dependencies
flutter pub get

# Run locally
flutter run

# Run static analysis and tests
flutter analyze
flutter test

# Build Android release APK
flutter build apk --release

# Build Web release (GitHub Pages subpath)
flutter build web --release --base-href "/SetAndSit/" --no-tree-shake-icons
```

## Platform & Deployment Notes

- **Web / GitHub Pages**: Pushes to `main` automatically build and deploy Flutter Web to GitHub Pages via `.github/workflows/deploy.yml` (`--base-href "/SetAndSit/"`). Desktop browsers (`maxWidth > 500`) render inside a centered `440px` phone-frame wrapper.
- **Android**: Java 17 compile target using Flutter's default `minSdkVersion` / `targetSdkVersion`, `WAKE_LOCK` and `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions, and auto-backup disabled (`allowBackup="false"`). Currently uses `applicationId = "com.example.setandsit"`.
- **iOS**: Deployment target iOS 15.0 with `UIBackgroundModes: audio` configured.
