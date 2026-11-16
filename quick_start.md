# Quick Start Guide

## Getting Started

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Key Components

### Core Architecture
- `RootControllerScreen` (`main.dart`) - Central state management and navigation
- `SessionQueueEngine` (`engine/session_queue_engine.dart`) - Timing math and silence calculation
- `PreferencesService` (`services/preferences_service.dart`) - Data persistence layer

### Clinical Features
- 16-Segment Clinical Taxonomy ($S01$–$S16$)
- Four clinical archetypes: Focused Calm, Trauma-Sensitive Grounding, Open Awareness, Metta/Compassion
- Progressive Settling Funnel timing engine
- Dual-Player acoustic overlap for clean session closure

### Audio System
- 240 voice MP3s (Kia + Grace personas)
- 10 acoustic meditation bells
- `audioplayers` audio playback engine

## Development Workflow

### Adding New Features
1. Identify the appropriate component file
2. Follow existing code patterns and conventions
3. Write tests for new functionality
4. Update documentation

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/timeline_engine_test.dart
```

### Building
```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```