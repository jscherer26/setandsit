import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import '../audio/audio_sources.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_stepper_card.dart';

class ManageVoicesScreen extends StatefulWidget {
  final List<VoiceConfig> initialVoices;
  final String? initialSelectedVoiceId;
  final ValueChanged<List<VoiceConfig>> onVoicesUpdated;
  final VoidCallback? onBack;
  final AudioPlayer? audioPlayer;
  final bool? isDeveloperMode;
  final List<ScriptVariant> Function(String segmentCode)? variantsProvider;
  final ResolvedAudio Function({
    required String voiceId,
    required String segmentCode,
    required String variantId,
  })? voiceAudioResolver;
  final Future<void> Function()? onInitializeManifest;

  const ManageVoicesScreen({
    super.key,
    required this.initialVoices,
    this.initialSelectedVoiceId,
    required this.onVoicesUpdated,
    this.onBack,
    this.audioPlayer,
    this.isDeveloperMode,
    this.variantsProvider,
    this.voiceAudioResolver,
    this.onInitializeManifest,
  });

  @override
  State<ManageVoicesScreen> createState() => _ManageVoicesScreenState();
}

class _ManageVoicesScreenState extends State<ManageVoicesScreen> {
  late List<VoiceConfig> _voices;
  late String _selectedVoiceId;

  bool get _isDevMode => widget.isDeveloperMode ?? false;

  static const List<String> _segmentCodes = [
    'S01', 'S02', 'S03', 'S04', 'S05', 'S06', 'S07', 'S08',
    'S09', 'S10', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16',
  ];

  int _selectedSegmentIndex = 0;
  int _selectedVariantIndex = 0;

  // Dedicated AudioPlayer instance for audition
  late final AudioPlayer _audioPlayer;
  late final bool _ownsAudioPlayer;
  bool _isPlaying = false;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _ownsAudioPlayer = widget.audioPlayer == null;
    _audioPlayer = widget.audioPlayer ?? AudioPlayer();

    _voices = widget.initialVoices
        .where((v) => v.id.toLowerCase() != 'kia')
        .toList();
    if (_voices.isEmpty) {
      _voices = List<VoiceConfig>.from(VoiceConfig.defaultVoices);
    }
    _selectedVoiceId = widget.initialSelectedVoiceId ??
        (_voices.isNotEmpty ? _voices.first.id : 'grace');
    if (_selectedVoiceId.toLowerCase() == 'kia') {
      _selectedVoiceId = _voices.first.id;
    }

    if (!_voices.any((v) => v.id == _selectedVoiceId) && _voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
    }

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });

    if (widget.onInitializeManifest != null) {
      unawaited(widget.onInitializeManifest!().then((_) {
        if (mounted) setState(() {});
      }));
    }
  }

  @override
  void dispose() {
    unawaited(_playerCompleteSubscription?.cancel());
    unawaited(_audioPlayer.stop());
    if (_ownsAudioPlayer) {
      unawaited(_audioPlayer.dispose());
    }
    super.dispose();
  }

  VoiceConfig get currentVoice {
    return _voices.firstWhere(
      (v) => v.id == _selectedVoiceId,
      orElse: () => _voices.first,
    );
  }

  String get currentSegmentCode => _segmentCodes[_selectedSegmentIndex];

  List<ScriptVariant> get currentVariants {
    return widget.variantsProvider?.call(currentSegmentCode) ??
        const <ScriptVariant>[];
  }

  ScriptVariant? get currentVariant {
    final vars = currentVariants;
    if (vars.isEmpty) return null;
    if (_selectedVariantIndex >= vars.length) {
      return vars.first;
    }
    return vars[_selectedVariantIndex];
  }

  void _saveAndNotify() {
    widget.onVoicesUpdated(_voices);
  }

  Future<void> _stopAudition() async {
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _startAudition() async {
    if (_isPlaying) {
      await _stopAudition();
    }

    final voice = currentVoice;
    final seg = currentSegmentCode;
    final variant = currentVariant;
    if (variant == null) return;

    final resolved = widget.voiceAudioResolver?.call(
      voiceId: voice.id,
      segmentCode: seg,
      variantId: variant.variantId,
    );
    if (resolved == null) return;

    if (mounted) {
      setState(() {
        _isPlaying = true;
      });
    }

    try {
      await _audioPlayer.play(resolved.source);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play audio: $e')),
        );
      }
    }
  }

  void _stepVoicePrevious() {
    _stopAudition();
    final list = _voices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((v) => v.id == _selectedVoiceId);
    final nextIdx = (idx - 1 + list.length) % list.length;
    setState(() {
      _selectedVoiceId = list[nextIdx].id;
    });
  }

  void _stepVoiceNext() {
    _stopAudition();
    final list = _voices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((v) => v.id == _selectedVoiceId);
    final nextIdx = (idx + 1) % list.length;
    setState(() {
      _selectedVoiceId = list[nextIdx].id;
    });
  }

  void _stepSegmentPrevious() {
    _stopAudition();
    setState(() {
      _selectedSegmentIndex =
          (_selectedSegmentIndex - 1 + _segmentCodes.length) %
              _segmentCodes.length;
      _selectedVariantIndex = 0;
    });
  }

  void _stepSegmentNext() {
    _stopAudition();
    setState(() {
      _selectedSegmentIndex =
          (_selectedSegmentIndex + 1) % _segmentCodes.length;
      _selectedVariantIndex = 0;
    });
  }

  void _stepVariantPrevious() {
    _stopAudition();
    final vars = currentVariants;
    if (vars.isEmpty) return;
    setState(() {
      _selectedVariantIndex =
          (_selectedVariantIndex - 1 + vars.length) % vars.length;
    });
  }

  void _stepVariantNext() {
    _stopAudition();
    final vars = currentVariants;
    if (vars.isEmpty) return;
    setState(() {
      _selectedVariantIndex = (_selectedVariantIndex + 1) % vars.length;
    });
  }

  void _toggleInclude(bool newValue) {
    final voice = currentVoice;
    if (!newValue) {
      final activeCount = _voices.where((v) => v.isIncluded).length;
      if (activeCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one voice must remain active.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() {
      final idx = _voices.indexWhere((v) => v.id == voice.id);
      if (idx != -1) {
        _voices[idx] = voice.copyWith(isIncluded: newValue);
      }
    });
    _saveAndNotify();
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final isEnabled = onPressed != null;
    final color = !isEnabled
        ? semantic.subtle.withValues(alpha: 0.45)
        : (isDestructive ? colorScheme.error : colorScheme.primary);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.surfaceContainerLow
                : semantic.sandSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !isEnabled
                  ? colorScheme.outlineVariant.withValues(alpha: 0.4)
                  : (isDestructive
                      ? colorScheme.error.withValues(alpha: 0.45)
                      : colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperCard({
    required BuildContext context,
    required IconData leadingIcon,
    required String title,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(29),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: semantic.sandSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: colorScheme.onSurface, size: 22),
              ),
              IconButton(
                icon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
                onPressed: onPrevious,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                splashRadius: 22,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
                onPressed: onNext,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                splashRadius: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final voice = currentVoice;
    final segmentMeta = kSegmentMetadata[currentSegmentCode];
    final variant = currentVariant;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopAudition();
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Manage Voices'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Voice Stepper
              VoiceStepperCard(
                voice: voice,
                subtitle: '${voice.description} • ${voice.gender}',
                onPrevious: _voices.length > 1 ? _stepVoicePrevious : null,
                onNext: _voices.length > 1 ? _stepVoiceNext : null,
              ),
              const SizedBox(height: 12),

              // 2. Action Buttons Row: Add | Copy | Rename | Delete (Disabled)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isScaledOrNarrow =
                      MediaQuery.textScalerOf(context).scale(1.0) > 1.2 ||
                          constraints.maxWidth < 360;
                  final itemWidth = isScaledOrNarrow
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.add,
                          label: 'Add',
                          onPressed: null,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.copy,
                          label: 'Copy',
                          onPressed: null,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.edit_outlined,
                          label: 'Rename',
                          onPressed: null,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          isDestructive: true,
                          onPressed: null,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // 3. "Include on Home Screen" Switch
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
                              voice.isIncluded
                                  ? 'Active in Home Screen Voice selector'
                                  : 'Hidden from Home Screen Voice selector',
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
                        value: voice.isIncluded,
                        activeTrackColor: colorScheme.primary,
                        activeThumbColor: colorScheme.onPrimary,
                        onChanged: _toggleInclude,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. "Audition Voice" Button
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
                    _isPlaying ? 'Stop Audition' : 'Audition Voice',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _isPlaying ? _stopAudition : _startAudition,
                ),
              ),

              if (_isDevMode) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(),
                ),

                // Bottom Section: Script & Variant Inspector
                Text(
                  'Script & Variant Inspector',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Segment Stepper
                _buildStepperCard(
                  context: context,
                  leadingIcon: Icons.auto_stories_outlined,
                  title:
                      '$currentSegmentCode • ${segmentMeta?['title'] ?? currentSegmentCode}',
                  onPrevious: _stepSegmentPrevious,
                  onNext: _stepSegmentNext,
                ),
                const SizedBox(height: 10),

                // 2. Segment Description Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            Text(
                              'Segment Rationale',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            if (segmentMeta?['phase'] != null)
                              Text(
                                '• ${segmentMeta!['phase']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: semantic.muted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          segmentMeta?['rationale'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Variant Stepper
                _buildStepperCard(
                  context: context,
                  leadingIcon: Icons.format_quote_outlined,
                  title: variant != null
                      ? '${variant.variantId} • ${variant.variantName}'
                      : 'No variants available',
                  onPrevious:
                      currentVariants.length > 1 ? _stepVariantPrevious : null,
                  onNext: currentVariants.length > 1 ? _stepVariantNext : null,
                ),
                const SizedBox(height: 10),

                // 4. Variant Script Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Script Variant Text',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: semantic.muted,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (variant != null && variant.wordCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: semantic.sandSurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${variant.wordCount} words',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: semantic.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            variant != null
                                ? '“${variant.text}”'
                                : 'No script text found.',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
