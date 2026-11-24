import '../models/audio_models.dart';

class BellData {
  /// Immutable default acoustic bells catalog.
  static final List<AudioSegment> defaultBells = List<AudioSegment>.unmodifiable([
    AudioSegment(
      id: 'bowl_singing',
      title: 'Singing Bowl',
      filePath: 'assets/bells/bowl_singing.mp3',
      durationSeconds: 15,
      minDelayBefore: 6,
      maxDelayBefore: 12,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bowl_singing_big',
      title: 'Large Singing Bowl',
      filePath: 'assets/bells/bowl_singing_big.mp3',
      durationSeconds: 15,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'gong_watts',
      title: 'Watts Gong',
      filePath: 'assets/bells/gong_watts.mp3',
      durationSeconds: 9,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'gong_bodhi',
      title: 'Bodhi Gong',
      filePath: 'assets/bells/gong_bodhi.mp3',
      durationSeconds: 15,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'gong_generated',
      title: 'Generated Gong',
      filePath: 'assets/bells/gong_generated.mp3',
      durationSeconds: 5,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bell_burma',
      title: 'Burma Bell',
      filePath: 'assets/bells/bell_burma.mp3',
      durationSeconds: 6,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bell_burma_three',
      title: 'Burma Triple Bell',
      filePath: 'assets/bells/bell_burma_three.mp3',
      durationSeconds: 16,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bell_indian',
      title: 'Indian Bell',
      filePath: 'assets/bells/bell_indian.mp3',
      durationSeconds: 15,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bell_meditation',
      title: 'Meditation Bell',
      filePath: 'assets/bells/bell_meditation.mp3',
      durationSeconds: 15,
      minDelayBefore: 6,
      maxDelayBefore: 12,
      isEnabled: true,
    ),
    AudioSegment(
      id: 'bell_singing',
      title: 'Singing Bell',
      filePath: 'assets/bells/bell_singing.mp3',
      durationSeconds: 15,
      minDelayBefore: 2,
      maxDelayBefore: 4,
      isEnabled: true,
    ),
  ]);

  /// Returns a fresh mutable copy of [defaultBells] for per-controller isolation.
  static List<AudioSegment> createDefaultBells() =>
      List<AudioSegment>.from(defaultBells);
}
