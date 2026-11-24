import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import '../audio/audio_sources.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class BellConfigurationScreen extends StatefulWidget {
  final List<AudioSegment> bells;
  final String selectedBellId;
  final ValueChanged<String> onBellSelected;
  final ValueChanged<AudioSegment> onBellUpdated;
  final VoidCallback onBack;
  final AudioSourceResolver? audioSourceResolver;

  const BellConfigurationScreen({
    super.key,
    required this.bells,
    required this.selectedBellId,
    required this.onBellSelected,
    required this.onBellUpdated,
    required this.onBack,
    this.audioSourceResolver,
  });

  @override
  State<BellConfigurationScreen> createState() =>
      _BellConfigurationScreenState();
}

class _BellConfigurationScreenState extends State<BellConfigurationScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _completeSubscription;
  bool _isPlaying = false;

  AudioSegment get currentBell {
    return widget.bells.firstWhere(
      (b) => b.id == widget.selectedBellId,
      orElse: () => widget.bells.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _audioPlayer.stop().catchError((_) {});
    _audioPlayer.dispose();
    super.dispose();
  }

  void _previewBell(AudioSegment bell) async {
    final resolved = widget.audioSourceResolver?.resolveBellClip(bell);
    if (resolved == null) return;
    try {
      await _audioPlayer.stop();
      setState(() => _isPlaying = true);
      await _audioPlayer.play(resolved.source);
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _stopAudition() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final currentIndex =
        widget.bells.indexWhere((b) => b.id == widget.selectedBellId);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopAudition();
            widget.onBack();
          },
        ),
        title: const Text('Manage Bells'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Bell to Configure',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: semantic.muted,
                ),
              ),
              const SizedBox(height: 8),

              // 1. Stepper Card
              Card(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
                          onPressed: currentIndex > 0
                              ? () {
                                  _stopAudition();
                                  widget.onBellSelected(
                                      widget.bells[currentIndex - 1].id);
                                }
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            currentBell.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
                          onPressed: currentIndex < widget.bells.length - 1
                              ? () {
                                  _stopAudition();
                                  widget.onBellSelected(
                                      widget.bells[currentIndex + 1].id);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. "Include on Home Screen" Switch
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Include on Home Screen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentBell.isEnabled
                                  ? 'Active in Home Screen Bell selector'
                                  : 'Hidden from Home Screen Bell selector',
                              style: TextStyle(
                                fontSize: 12,
                                color: semantic.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: currentBell.isEnabled,
                        activeTrackColor: colorScheme.primary,
                        activeThumbColor: colorScheme.onPrimary,
                        onChanged: (checked) {
                          widget.onBellUpdated(
                              currentBell.copyWith(isEnabled: checked));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. "Audition Bell" Button
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 50),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isPlaying ? colorScheme.error : colorScheme.primary,
                    foregroundColor:
                        _isPlaying ? colorScheme.onError : colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                      size: 22),
                  label: Text(
                    _isPlaying ? 'Stop Audition' : 'Audition Bell',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _isPlaying
                      ? _stopAudition
                      : () => _previewBell(currentBell),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
