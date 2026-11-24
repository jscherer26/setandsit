import 'package:material_ui/material_ui.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class SessionDebugScreen extends StatelessWidget {
  final int targetSeconds;
  final String selectedType;
  final double instructionDensity;
  final double redirectionDensity;
  final AudioSegment selectedBell;
  final List<SessionItem> sessionQueue;
  final VoidCallback onBack;

  const SessionDebugScreen({
    super.key,
    required this.targetSeconds,
    required this.selectedType,
    required this.instructionDensity,
    required this.redirectionDensity,
    required this.selectedBell,
    required this.sessionQueue,
    required this.onBack,
  });

  static String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);

    var totalAudio = 0.0;
    var totalSilence = 0;
    final startTimes = <int>[];
    var acc = 0.0;

    for (final item in sessionQueue) {
      startTimes.add(acc.round());
      if (item is PlayAudioItem) {
        totalAudio += item.durationSeconds;
        acc += item.durationSeconds;
      } else if (item is PauseSilenceItem) {
        totalSilence += item.durationSeconds;
        acc += item.durationSeconds;
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              onBack();
            }
          },
        ),
        title: const Text('Session Debugger'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Configuration Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuration Parameters',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _debugRow(context, 'Practice Type', selectedType),
                            _debugRow(
                              context,
                              'Target Duration',
                              '${targetSeconds ~/ 60}m (${targetSeconds}s)',
                            ),
                            _debugRow(
                              context,
                              'Settings',
                              'Instructions: ${instructionDensity.toInt()}, Mind-Wandering: ${redirectionDensity.toInt()}',
                            ),
                            _debugRow(context, 'Selected Bell', selectedBell.title),
                            _debugRow(
                              context,
                              'Total Items in Queue',
                              '${sessionQueue.length} items',
                            ),
                            _debugRow(
                              context,
                              'Total Audio Duration',
                              '${totalAudio.round()}s',
                            ),
                            _debugRow(
                              context,
                              'Total Silence Pauses',
                              '${totalSilence}s',
                            ),
                            _debugRow(
                              context,
                              'Total Queue Duration',
                              '${_formatSeconds((totalAudio + totalSilence).round())} (${(totalAudio + totalSilence).round()}s)',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generated SessionItems (${sessionQueue.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverList.builder(
                itemCount: sessionQueue.length,
                itemBuilder: (context, index) {
                  final item = sessionQueue[index];
                  final startSec = startTimes.isNotEmpty ? startTimes[index] : 0;
                  final totalQueueSec = (totalAudio + totalSilence).round();
                  final countdownBase = targetSeconds > 0 ? targetSeconds : totalQueueSec;
                  final remainingSec = (countdownBase - startSec).clamp(0, countdownBase);

                  if (item is PlayAudioItem) {
                    final isOverlap = item.bellAssetPath != null ||
                        item.segment == ClinicalSegment.S16;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isOverlap
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isOverlap ? 1.5 : 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    isOverlap
                                        ? '#${index + 1} [DUAL-PLAYER OVERLAP]  ⏱ ${_formatSeconds(remainingSec)}'
                                        : '#${index + 1} [PLAY AUDIO]  ⏱ ${_formatSeconds(remainingSec)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isOverlap
                                          ? colorScheme.primary
                                          : semantic.success,
                                    ),
                                  ),
                                  Text(
                                    item.phaseName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.displayTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Phase: ${item.phaseName} | Duration: ${item.durationSeconds.round()}s',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: semantic.muted,
                                ),
                              ),
                              if (isOverlap) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: semantic.sandSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.primary.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.notifications_active,
                                            size: 13,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Bell Player: ${item.bellAssetPath ?? selectedBell.filePath} (fires instantly)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.record_voice_over,
                                            size: 13,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Voice Player: ${item.audioAssetPath} (speaks at +2.5s over bell decay)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Path: ${item.audioAssetPath}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: semantic.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (item is PauseSilenceItem) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '#${index + 1} [PAUSE SILENCE]  ⏱ ${_formatSeconds(remainingSec)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: semantic.warning,
                                ),
                              ),
                              Text(
                                '${item.durationSeconds}s pause',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _debugRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: semantic.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
