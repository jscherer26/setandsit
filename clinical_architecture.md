# Clinical Architecture & Meditation Framework

- **Last Updated:** 2026-10-23 00:45 EDT
- **Current Version:** 1.0.0+1
- **Repository State:** main | c12189a

## 1. Clinical Taxonomy Overview

Set&Sit implements a comprehensive 16-segment clinical meditation framework ($S01$–$S16$) across four primary clinical archetypes:

### Phase Breakdown
1. **Phase 1: Arrival & Agency ($S01$–$S05$)**: Posture, gentle transition, breath awareness, body grounding, somatic agency.
2. **Phase 2: Attentional Anchoring ($S06$–$S08$)**: Progressive muscle softening, diaphragmatic cadence, cognitive stabilization.
3. **Phase 3: State Cultivation ($S09$–$S11$)**: Open awareness, emotional regulation, loving-kindness (metta).
4. **Phase 4: Deep Silence ($S12$)**: Silent integration window and unguided open awareness.
5. **Phase 5: Re-Orientation & Close ($S13$–$S16$)**: Physical re-awakening, sensory awakening, appreciation & closure, closing acoustic resonance bell.

## 2. Clinical Archetypes

### Focused Calm (`focused_calm`)
Standard attentional stability archetype ($S01, S02, S03, S04, S06, S07, S08, S12, S13, S15, S16$).

### Trauma-Sensitive Grounding (`trauma_informed`)
Omits breath orientation ($S03$) to prevent hyperventilation loops, utilizing grounded anchors ($S01, S02, S04, S05, S07, S08, S10, S12, S13, S14, S15, S16$).

### Open Awareness / Insight (`open_awareness`)
Receptive non-judgmental observation ($S01, S02, S03, S04, S08, S09, S10, S12, S13, S15, S16$).

### Metta / Compassion (`metta_compassion`)
Benevolent self and relational compassion ($S01, S02, S03, S04, S07, S11, S12, S13, S14, S15, S16$).

## 3. Progressive Settling Funnel

The application implements a sophisticated timing engine that dynamically calculates silence intervals based on session duration and clinical requirements.

### Timing Matrix by Session Duration
| Transition Pair | Physiological Task | Quick Reset (3–5 Min) | Standard Sit (10–15 Min) | Deep Practice (20–30+ Min) |
|---|---|---|---|---|
| **Start → S01** | Phone set-down & physical arrival | User Default (5–10s) | User Default (10–20s) | User Default (15–30s) |
| **S01 → S02** | Exteroceptive room orientation | 3s | 4–5s | 5–6s |
| **S02 → S03** | Physical posture micro-adjustments | 4s | 6–8s | 8–10s |
| **S03 → S04** | 2 natural, unforced breath cycles | 6s | 10–12s | 12–15s |
| **S04 → S05 → S06** | Gravitational release & safety harbor | 6–8s | 12–15s | 15–20s |
| **S06 → S07 / S08 Loops** | Sustained focus & mind-wandering return | 10–15s | 20–35s | 40–75s |
| **S09 / S10 / S11** | State cultivation & open monitoring | Omitted or 10s | 20–30s | 35–60s |
| **S12 (Silence Window)** | Dynamic exact-timestamp budget solver | 15–30s | 60–180s | 3–12+ minutes |
| **S13 → S14 / S15** | Somatic re-awakening bridge | 4s | 8–10s | 10–12s |
| **S14 → S15** | Meaning bridge to somatic awakening | 4s | 8–10s | 110–12s |
| **S15 → Bell + S16** | Extremity movement & eye opening before bell | 4–5s | 6–8s | 8–10s |

## 4. Segment Pruning Engine

When session duration is short or remaining open silence is constrained, the engine automatically prunes lower-priority segments according to clinical priority:

### Standard Sessions ($\ge 300\text{s}$)
- **Protected Frame:** $S01, S02, S12, S13, S15, S16$ (never pruned).
- **Protected Signature Pairs:**
  - Focused Calm: `S03, S08`
  - Trauma-Informed: `S04, S05`
  - Open Awareness: `S08, S09`
  - Metta: `S04, S11`
- **Pruning Priority Order:** Dropped sequentially if silence window is constrained:
  `['S14', 'S06', 'S04', 'S03', 'S07', 'S10', 'S08']`.

### Test Mode Bypass ($< 300\text{s}$)
- $\le 120\text{s}$: Truncated to 4 essential segments (`S01`, primary signature segment, `S12`, `S16`).
- $121\text{s}$–$299\text{s}$: Preserves protected frame plus the archetype's protected signature pair.

## 5. Closing Sequence & Dual-Player Acoustic Overlap

To execute the $S16$ overlay cleanly:
1. Following $S15$, a $6$–$8\text{s}$ pause is scheduled allowing the practitioner to physically stretch, deepen their breath, and blink their eyes open to the room.
2. The closing singing bowl / chime strikes at $100\%$ target volume ($1.0$).
3. At $+2.5\text{s}$ after the initial strike (allowing the sharp metallic attack transient of the bell to pass and settle into its warm harmonic decay), the chosen $S16$ voice guidance variant triggers layered directly over the fading resonance using the secondary audio player.
4. Bell resonance duration ($14$–$18\text{s}$) naturally trails $2$–$4\text{s}$ past the last spoken word of $S16$, sealing the session container smoothly without an abrupt cutoff.

## 6. Clinical Script Bank & Audio Durations

- Total Segments: 16
- Variants per Segment: 15
- Total Script Variants: 240
- Total Registered Audio Files: 480 MP3s (240 Kia + 240 Grace)
- Acoustic Bells: 10 selectable bells in `BellData`