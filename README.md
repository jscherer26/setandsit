# Set&Sit

Clinical meditation and somatic mindfulness mobile application built with Flutter (`sdk: ^3.13.5`).

Set&Sit calculates dynamically proportioned silence intervals between spoken guidance segments based on a wall-clock target finish time or explicit duration input (1–90 minutes). The application operates entirely offline on-device without telemetry, user accounts, or external network dependencies.

## Clinical Features

- **16-Segment Clinical Meditation Taxonomy** ($S01$–$S16$) across four clinical archetypes:
  - Focused Calm
  - Trauma-Sensitive Grounding
  - Open Awareness / Insight
  - Metta / Compassion
- **Progressive Settling Funnel** with dynamic silence math
- **Acoustic Bell Integration** with dual-player acoustic overlap
- **Voice Guidance** with multiple personas (Kia, Grace)
- **Custom Practice Configuration** and voice management

## Architecture & Documentation

- **Project Snapshot & Metrics**: See [project_document.md](project_document.md) for recent changes, test status, and dependency lists.
- **Comprehensive Runtime Architecture**: See [project_architecture.md](project_architecture.md) for navigation lifecycles, clinical taxonomy ($S01$–$S16$), asset hierarchy, and persistence design.

## Running Locally

```bash
flutter pub get
flutter run
```