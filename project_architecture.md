# Set&Sit — Architecture & Runtime Specification

---

## 1. High-Level Engine Overview
Set&Sit is an offline clinical meditation and somatic guidance application written in Flutter/Dart (`sdk: ^3.13.5`). It calculates dynamically proportioned silence intervals between spoken audio segments based on a wall-clock target finish time or explicit duration input (1–90 minutes).

### State Management, Navigation & Web Frame
- State is centrally lifted into `RootControllerScreen` (`lib/main.dart`) using vanilla Flutter `StatefulWidget`.
- Screen transitions are coordinated via an internal navigation stack enum (`AppScreen`):
  `configuration`, `settings`, `bellSettings`, `managePractices`, `manageVoices`, `practice`, `sessionDebug`, `about`.
- Android system predictive back gestures and hardware back navigation are intercepted by `PopScope` to preserve in-memory and disk states before screen unmounting.
- On desktop web (`maxWidth > 500`), `SetAndSitApp` (`lib/main.dart`) wraps the app in a centered `440px` phone-frame container (`kIsWeb`).

### Directory Structure
```text
lib/
├── main.dart                          # App entry, RootControllerScreen, AppScreen stack, Web frame
├── data/
│   └── bell_data.dart                 # Pre-configured acoustic bells metadata
├── engine/
│   └── session_queue_engine.dart      # Progressive settling funnel, pruning & timeline math
├── models/
│   ├── audio_models.dart              # ClinicalSegment, ClinicalArchetype, SessionItem models
│   ├── practice_config.dart           # System & custom practice configurations (S01–S16 metadata)
│   └── voice_config.dart              # Voice persona configuration
├── screens/
│   ├── about_screen.dart              # App version, clinical philosophy, and feedback mailto link
│   ├── bell_configuration_screen.dart # Acoustic bell selection and auditioning
│   ├── clock_time_picker_dialog.dart  # Interactive wall-clock finish time picker
│   ├── configuration_screen.dart      # Home screen: dial, practice/voice/bell steppers
│   ├── manage_practices_screen.dart   # Practice management (custom archetype creation)
│   ├── manage_voices_screen.dart      # Voice persona selection and auditioning
│   ├── practice_screen.dart           # Active meditation playback & timer screen
│   ├── session_debug_screen.dart      # Detailed queue timeline inspector
│   └── settings_screen.dart           # Global defaults (duration, delay, density sliders)
├── services/
│   ├── audio_manifest_service.dart    # Manifest reader, duration cache & Developer Mode overrides
│   └── preferences_service.dart       # Native key & JSON persistence engine
├── theme/
│   └── app_theme.dart                 # Botanical minimalist Linen & Olive palette
└── widgets/
    ├── practice_stepper_card.dart     # Reusable practice stepper card
    └── voice_stepper_card.dart        # Reusable voice stepper card
```

### Persistence Engine
- Handled by `PreferencesService` (`lib/services/preferences_service.dart`) using `shared_preferences`.
- Primitive settings are written directly to disk using atomic keys (`pref_duration` defaulting to `3` min, `pref_prep_delay` defaulting to `3` s, `pref_instruction_density`, `pref_redirection_density`, `pref_practice_mode`, `pref_selected_bell_id`, `pref_selected_practice_id`, `pref_selected_practice_name`, `pref_selected_voice_id`, `pref_selected_voice_idx`, `pref_clock_hour`, `pref_clock_minute`, `pref_clock_is_am`, and `pref_developer_mode`).
- `pref_developer_mode` is explicitly reset to `false` on fresh startup (`PreferencesService.resetDeveloperModeOnStartup()`).
- Multi-object collections (`set_and_sit_practices` for `PracticeConfig` list and `set_and_sit_voices` for `VoiceConfig` list) are stored as JSON strings.

---

## 2. Master Asset Hierarchy & Storage Locations
All session audio cues and metadata are bundled locally within the app:
- **Clinical Script Bank:** `assets/raw/session_manifest.json` (Manifest Schema `3.5.0`, 16 segments, 15 variants each = 240 scripts).
- **High-Precision Audio Durations:** `assets/raw/audio_durations.json` (Pre-calculated exact segment durations in seconds).
- **Spoken Voice Guidance Files:**
  - `assets/audio/grace/`: 240 MP3 files for `Grace` (Soft & Centered Female persona — active default voice). Legacy `kia` voice entries are retired and automatically purged on load by `PreferencesService.loadVoices()` and `PreferencesService.loadState()`.
- **Developer Mode Staged Overrides:**
  - `assets/audio/changes_manifest.json` (with fallback to `assets/raw/staged_changes.json`) and `assets/audio/<voice>/changes/*.mp3` provide staged script text, durations, and replacement audio when Developer Mode is enabled (`AudioManifestService`).
- **Acoustic Meditation Bells:**
  - `assets/bells/`: 10 acoustic meditation bells/singing bowls in OGG format.
- **Silent Buffer:**
  - `assets/audio/silence.mp3`: 100ms silent audio track for hardware platform audio warming.

---

## 3. Clinical Archetypes & Active Pipelines
The clinical guidance is structured across a **16-Segment Clinical Meditation Taxonomy (`S01`–`S16`)** defined in `lib/models/practice_config.dart`:

### Phase Breakdown
1. **Phase 1: Arrival, Agency & Safety Setup (`S01`–`S05`):** External arrival, permission & choice, natural breath flow, somatic grounding, sensory & environmental anchor.
2. **Phase 2: Down-Regulation & Attentional Anchoring (`S06`–`S08`):** Restorative breath pacing, vagal & somatic release, focused anchor & wandering return.
3. **Phase 3: Core Practice & State Cultivation (`S09`–`S11`):** Open awareness & decentering, mental noting & labeling, metta / loving-kindness.
4. **Phase 4: Deep Integration Silence (`S12`):** Silent integration window.
5. **Phase 5: Re-Orientation, Meaning & Close (`S13`–`S16`):** Physical re-awakening, gratitude & meaning transfer, visual orientation, closing bell & transition.

### Official System Archetypes
- **Focused Calm (`focused_calm`):** Standard attentional stability archetype (`S01`, `S02`, `S03`, `S04`, `S06`, `S07`, `S08`, `S12`, `S13`, `S15`, `S16`).
- **Trauma-Sensitive Grounding (`trauma_informed`):** Omits breath orientation (`S03`) to prevent hyperventilation loops, utilizing grounded anchors (`S01`, `S02`, `S04`, `S05`, `S07`, `S08`, `S10`, `S12`, `S13`, `S14`, `S15`, `S16`).
- **Open Awareness / Insight (`open_awareness`):** Receptive non-judgmental observation (`S01`, `S02`, `S03`, `S04`, `S08`, `S09`, `S10`, `S12`, `S13`, `S15`, `S16`).
- **Metta / Compassion (`metta_compassion`):** Benevolent self and relational compassion (`S01`, `S02`, `S03`, `S04`, `S07`, `S11`, `S12`, `S13`, `S14`, `S15`, `S16`).

---

## 4. The Progressive Settling Funnel & Dynamic Silence Math
Implemented in `SessionQueueEngine.generateGuidedSessionQueue` (`lib/engine/session_queue_engine.dart`):

For standard sessions (`>= 300s`), rather than using a static silent pause between every opening segment, the runtime engine implements a Progressive Settling Funnel across Phases 1–3, paired with a Progressive Re-Awakening Taper in Phase 5:

$$\text{Silence Window Duration } (S12) = T_{\text{total}} - D_{\text{audio}} - \sum D_{\text{pacing\_gaps}}$$

Where:
- $T_{\text{total}}$: Target duration in seconds ($60\text{s} \le T_{\text{total}} \le 5400\text{s}$).
- $D_{\text{audio}}$: Sum of exact audio durations for all selected script variants (plus `S16` bell overlap offset of `2.5s`).
- $\sum D_{\text{pacing\_gaps}}$: Calibrated physiological inter-segment pacing gaps derived from duration tier in `SessionQueueEngine.getProgressivePauseSeconds`.

### Timing Matrix by Session Duration
| Transition Pair | Physiological Task | Quick Reset (`< 10` min) | Standard Sit (`10–19` min) | Deep Practice (`20+` min) |
|---|---|---|---|---|
| **Start → `S01`** | Phone set-down & physical arrival | User Default (`3s`, configurable `0–20s`) | User Default (`3s`, configurable `0–20s`) | User Default (`3s`, configurable `0–20s`) |
| **`S01` → `S02`** | Exteroceptive room orientation | `3s` | `4–5s` | `6s` |
| **`S02` → `S03`** | Physical posture micro-adjustments | `4s` | `6–8s` | `8–10s` |
| **`S03` → `S04`** | Natural, unforced breath cycles | `6s` | `10–12s` | `12–15s` |
| **`S04` / `S05` → next** | Gravitational release & safety harbor | `7s` | `12–15s` | `15–20s` |
| **`S06` / `S07` / `S08`** | Sustained focus & mind-wandering return | `12s` | `20–30s` | `45–60s` |
| **`S09` / `S10` / `S11`** | State cultivation & open monitoring | `10s` | `20–25s` | `35–50s` |
| **`S12` (Silence Window)** | Dynamic exact-timestamp budget solver | Remainder (`>= 45s` trigger) | Remainder | Remainder |
| **`S13` → `S14` / `S15`** | Somatic re-awakening bridge | `4s` | `8–10s` | `10–12s` |
| **`S14` → `S15`** | Meaning bridge to visual orientation | `4s` | `8–10s` | `10–12s` |
| **`S15` → Bell + `S16`** | Extremity movement & eye opening before bell | `5s` | `7–8s` | `8–10s` |

---

## 5. Segment Pruning Engine & Test Mode Bypass
When session duration is short (`<= 300s`) or remaining open silence is constrained (`< 45s`), the engine automatically prunes lower-priority segments according to clinical priority:

### Standard Sessions (`>= 300s`)
- **Protected Frame:** `S01`, `S02`, `S12`, `S13`, `S15`, `S16` (never pruned).
- **Protected Signature Pairs:**
  - Focused Calm: `S03`, `S08`
  - Trauma-Sensitive Grounding: `S04`, `S05`
  - Open Awareness / Insight: `S08`, `S09`
  - Metta / Compassion: `S04`, `S11`
- **Pruning Priority Order:** Dropped sequentially if silence window is constrained:
  `['S14', 'S06', 'S04', 'S03', 'S07', 'S10', 'S08']`.

### Test Mode Bypass (`< 300s`)
- `<= 120s`: Truncated to 4 essential segments (`S01`, primary signature segment, `S12`, `S16`).
- `121s`–`299s`: Preserves protected frame plus the practice's protected signature pair.

---

## 6. Closing Sequence & Dual-Player Acoustic Overlap
To execute the `S16` overlay cleanly:
1. Following `S15`, a `5–10s` pause (tier-dependent) is scheduled allowing the practitioner to stretch, deepen their breath, and open their eyes to the room.
2. The closing singing bowl / chime strikes at `100%` target volume (`1.0`).
3. At `+2.5s` after the initial strike (allowing the sharp attack transient of the bell to settle into harmonic decay), the chosen `S16` voice guidance variant triggers layered over the fading resonance using the secondary audio player.
4. Bell resonance naturally trails past the spoken guidance of `S16`, closing the session container smoothly without an abrupt cutoff.

---

## 7. Edge Cases, Interruption Handling & Screen Lifecycle
- **Wakelock:** Managed by `wakelock_plus` to keep display on during practice.
- **Premature Termination:** Tapping the exit button displays a confirmation dialog that pauses session timers; confirming discards the active queue and safely resets audio players.
- **Silent Mode:** When `"Silent"` practice mode is selected, voice segments are omitted and `SessionQueueEngine.generateSilentSessionQueue` schedules the silence period followed by a closing acoustic bell (no opening bell).
- **Storage Protection:** `PreferencesService` utilizes direct native key commits and safe JSON parsing fallbacks to avoid app-restart data loss or schema corruption.

---

## 8. Clinical Script Bank & Audio Matrix
- **Total Segments:** 16 (`S01`–`S16`)
- **Variants per Segment:** 15 (240 total script variants in `assets/raw/session_manifest.json`)
- **Active Spoken Voice Assets:** 240 MP3s in `assets/audio/grace/` (`Grace`)
- **Acoustic Bells:** 10 selectable bells in `BellData` (`assets/bells/`)

---

## 9. Practice & Voice Customization Architecture
- `PracticeConfig` (`lib/models/practice_config.dart`): Allows users to duplicate existing archetypes, toggle active segment IDs (enforcing mandatory segments `S01, S02, S12, S15, S16` and at least one segment in `S03`–`S11`), rename practices, and control inclusion in the home stepper.
- `VoiceConfig` (`lib/models/voice_config.dart`): Supports selecting, auditioning, and toggling voice guidance personas.

---

## 10. Dependencies, Testing & Technical Debt

### Dependencies (`pubspec.yaml`)
- **Runtime:** `flutter`, `cupertino_icons`, `audioplayers`, `shared_preferences`, `intl`, `wakelock_plus`, `package_info_plus`, `url_launcher`
- **Dev:** `flutter_test`, `audioplayers_platform_interface`, `flutter_lints`

### Automated Test Suites (`test/`)
- `test/timeline_engine_test.dart`: Silence distribution math, test-mode bypass, pruning validation, and `S16` dual-player overlap.
- `test/preferences_test.dart`: `SharedPreferences` primitive key persistence and legacy migration (`kia` purge / practice rename).
- `test/manage_practices_test.dart`: Custom practice creation, segment constraints, and selection persistence.
- `test/manage_voices_test.dart`: Voice persona filtering, audition playback, and inclusion logic.
- `test/about_screen_test.dart`: About screen sections, version display, and feedback links.
- `test/developer_mode_test.dart`: Developer Mode passcode activation, startup reset, and staged audio manifest switching.
- `test/widget_test.dart`: Root controller smoke test, clock picker updates, and navigation verification.

### Known Technical Debt
- **Background Media3 / AudioService Integration:** Audio playback currently relies on foreground wakelock (`wakelock_plus`); migrating to a native MediaSession / Foreground AudioService is recommended for lock-screen media controls.
- **Package ID Migration:** Android `applicationId` remains `com.example.setandsit` and should be updated prior to Play Store publishing.
