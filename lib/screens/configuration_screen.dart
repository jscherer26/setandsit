import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../theme/app_theme.dart';
import '../widgets/practice_stepper_card.dart';
import '../widgets/voice_stepper_card.dart';
import 'clock_time_picker_dialog.dart';

class ConfigurationScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;

  final int practiceDurationMinutes;
  final VoidCallback onEnsureFutureTime;

  final List<AudioSegment> bells;
  final String selectedBellId;
  final ValueChanged<String> onSelectedBellChanged;
  final VoidCallback onOpenBellSettings;

  final String selectedType;
  final ValueChanged<String> onSelectedTypeChanged;

  final List<PracticeConfig> practices;
  final String selectedPracticeId;
  final ValueChanged<String> onSelectedPracticeIdChanged;
  final VoidCallback onOpenManagePractices;

  final List<VoiceConfig>? voices;
  final String? selectedVoiceId;
  final ValueChanged<String>? onSelectedVoiceIdChanged;
  final VoidCallback? onOpenManageVoices;

  final int voiceIndex;
  final ValueChanged<int>? onVoiceIndexChanged;

  final int clockHour;
  final int clockMinute;
  final bool isAm;
  final Function(int hour, int minute, bool isAm) onClockTimeChanged;

  final bool isDeveloperMode;
  final int stagedVariantsCount;
  final bool allowDeveloperMode;
  final VoidCallback? onExit;
  final ValueChanged<bool>? onDeveloperModeChanged;

  final Function(
    int targetSeconds,
    String practiceType,
    AudioSegment bell,
    PracticeConfig? practiceConfig,
  ) onBeginPractice;

  const ConfigurationScreen({
    super.key,
    required this.onOpenSettings,
    required this.practiceDurationMinutes,
    required this.onEnsureFutureTime,
    required this.bells,
    required this.selectedBellId,
    required this.onSelectedBellChanged,
    required this.onOpenBellSettings,
    required this.selectedType,
    required this.onSelectedTypeChanged,
    required this.practices,
    required this.selectedPracticeId,
    required this.onSelectedPracticeIdChanged,
    required this.onOpenManagePractices,
    this.voices,
    this.selectedVoiceId,
    this.onSelectedVoiceIdChanged,
    this.onOpenManageVoices,
    this.voiceIndex = 0,
    this.onVoiceIndexChanged,
    required this.clockHour,
    required this.clockMinute,
    required this.isAm,
    required this.onClockTimeChanged,
    this.isDeveloperMode = false,
    this.stagedVariantsCount = 0,
    this.allowDeveloperMode = true,
    this.onExit,
    this.onDeveloperModeChanged,
    required this.onBeginPractice,
  });

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  Timer? _periodicCheckTimer;
  int _titleTapCount = 0;
  DateTime? _lastTitleTapTime;

  @override
  void initState() {
    super.initState();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkTimeStillInFuture();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTimeStillInFuture();
    });
  }

  void _handleTitleTap() {
    if (!widget.allowDeveloperMode) return;
    final now = DateTime.now();
    if (_lastTitleTapTime == null ||
        now.difference(_lastTitleTapTime!) > const Duration(milliseconds: 1500)) {
      _titleTapCount = 1;
    } else {
      _titleTapCount++;
    }
    _lastTitleTapTime = now;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      unawaited(_showDeveloperModeDialog());
    }
  }

  void _submitPasscode(
    BuildContext dialogContext,
    String rawValue,
    void Function(void Function()) setDialogState,
    void Function(String) setError,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (rawValue.trim() == '2217') {
      Navigator.of(dialogContext).pop();
      widget.onDeveloperModeChanged?.call(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Developer Mode enabled. Staged audio active.'),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setDialogState(() {
        setError('Incorrect passcode');
      });
    }
  }

  Future<void> _showDeveloperModeDialog() async {
    if (widget.isDeveloperMode) {
      await _showActiveDeveloperModeDialog();
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final semantic = AppSemanticColors.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.developer_mode, color: semantic.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Developer Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter passcode to enable Developer Mode:',
                      style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: semantic.sandSurface,
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (val) => _submitPasscode(
                        dialogContext,
                        val,
                        setDialogState,
                        (msg) => errorText = msg,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: TextStyle(color: semantic.muted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _submitPasscode(
                    dialogContext,
                    controller.text,
                    setDialogState,
                    (msg) => errorText = msg,
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showActiveDeveloperModeDialog() async {
    final count = widget.stagedVariantsCount;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final semantic = AppSemanticColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.bug_report, color: semantic.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Developer Mode Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Previewing staged script audio from /changes directories.',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Staged variants loaded: $count',
                  style: TextStyle(
                    fontSize: 13,
                    color: semantic.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Keep Active', style: TextStyle(color: semantic.muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onDeveloperModeChanged?.call(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Developer Mode disabled.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Disable Developer Mode'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  void _checkTimeStillInFuture() {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );
    if (!target.isAfter(now)) {
      widget.onEnsureFutureTime();
    }
  }

  AudioSegment get currentBell {
    final enabled = widget.bells.where((b) => b.isEnabled).toList();
    final list = enabled.isNotEmpty ? enabled : widget.bells;
    return list.firstWhere(
      (b) => b.id == widget.selectedBellId,
      orElse: () => list.first,
    );
  }

  void _showTimeAdjustmentDialog(BuildContext context) async {
    final picked = await ClockTimePickerDialog.show(
      context: context,
      initialHour12: widget.clockHour,
      initialMinute: widget.clockMinute,
      initialIsAm: widget.isAm,
    );

    if (picked != null) {
      final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final pickedIsAm = picked.period == DayPeriod.am;
      widget.onClockTimeChanged(hour12, picked.minute, pickedIsAm);
    }
  }

  List<PracticeConfig> get includedPractices {
    final list = widget.practices.where((p) => p.isIncluded).toList();
    return list.isNotEmpty ? list : widget.practices;
  }

  PracticeConfig get currentPractice {
    final list = includedPractices;
    return list.firstWhere(
      (p) => p.id == widget.selectedPracticeId,
      orElse: () => list.firstWhere(
        (p) => p.name == widget.selectedType,
        orElse: () => list.first,
      ),
    );
  }

  int get currentDurationMinutes {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);

    var targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );

    if (!targetDateTime.isAfter(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }

    final diff = targetDateTime.difference(now).inSeconds;
    if (diff > 90 * 60 || diff < 60) {
      return widget.practiceDurationMinutes;
    }
    return (diff / 60.0).round();
  }

  int _calculateTargetSeconds() {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);

    var targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );

    if (!targetDateTime.isAfter(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }

    final diff = targetDateTime.difference(now).inSeconds;
    if (diff > 90 * 60 || diff < 60) {
      widget.onEnsureFutureTime();
      return widget.practiceDurationMinutes * 60;
    }
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = AppSemanticColors.of(context);
    final isLight = theme.brightness == Brightness.light;

    final isGuided = widget.selectedType != 'Silent';
    final formattedTime =
        '${widget.clockHour.toString().padLeft(2, '0')}:${widget.clockMinute.toString().padLeft(2, '0')}';
    final amPmText = widget.isAm ? 'AM' : 'PM';

    final voiceList = (widget.voices ?? VoiceConfig.defaultVoices)
        .where((v) => v.id.toLowerCase() != 'kia')
        .toList();
    final effectiveVoiceList = voiceList.isNotEmpty ? voiceList : VoiceConfig.defaultVoices;
    final includedVoices = effectiveVoiceList.where((v) => v.isIncluded).toList();
    final activeVoices =
        includedVoices.isNotEmpty ? includedVoices : effectiveVoiceList;
    final currentVoiceConfig = activeVoices.firstWhere(
      (v) => v.id == widget.selectedVoiceId,
      orElse: () => activeVoices.first,
    );

    final enabledBells = widget.bells.where((b) => b.isEnabled).toList();
    final availableBells = enabledBells.isNotEmpty ? enabledBells : widget.bells;
    final currentBellIndex =
        availableBells.indexWhere((b) => b.id == currentBell.id);

    final size = MediaQuery.of(context).size;
    final isCompactScreen = size.height < 850;
    final heroDialOuterSize = (isCompactScreen ? (size.height * 0.28).clamp(230.0, 270.0) : 300.0).toDouble();
    final heroDialInnerSize = heroDialOuterSize * 0.8;
    final heroVerticalSpacing = isCompactScreen ? 16.0 : 36.0;
    final itemVerticalSpacing = isCompactScreen ? 10.0 : 14.0;
    final buttonVerticalSpacing = isCompactScreen ? 18.0 : 28.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isCompactScreen ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Settings Gear Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.onExit != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: isLight
                            ? const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: Icon(
                          Icons.arrow_back,
                          color: colorScheme.onSurface,
                          size: 22,
                        ),
                        onPressed: widget.onExit,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: _handleTitleTap,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set&Sit',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adaptive Guided Meditation',
                            style: TextStyle(
                              fontSize: 14,
                              color: semantic.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: isLight
                          ? const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: IconButton(
                      tooltip: 'Settings',
                      icon: Icon(
                        Icons.settings,
                        color: colorScheme.onSurface,
                        size: 22,
                      ),
                      onPressed: widget.onOpenSettings,
                    ),
                  ),
                ],
              ),

              if (widget.isDeveloperMode) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showActiveDeveloperModeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: semantic.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: semantic.warning, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: semantic.warning),
                        const SizedBox(width: 6),
                        Text(
                          'Developer Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: heroVerticalSpacing),

              // Hero Circular Dial
              Center(
                child: ClipOval(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showTimeAdjustmentDialog(context),
                    child: Container(
                      width: heroDialOuterSize,
                      height: heroDialOuterSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: semantic.circleOuterGlow.withValues(alpha: 0.55),
                        border: Border.all(
                          color: semantic.circleBorder,
                          width: isCompactScreen ? 10 : 12,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: heroDialInnerSize,
                          height: heroDialInnerSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerLow,
                            boxShadow: isLight
                                ? const [
                                    BoxShadow(
                                      color: AppColors.cardShadow,
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Practice Ends At',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: semantic.muted,
                                    ),
                                  ),
                                  SizedBox(height: isCompactScreen ? 4 : 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: isCompactScreen ? 40 : 48,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        amPmText,
                                        style: TextStyle(
                                          fontSize: isCompactScreen ? 18 : 20,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$currentDurationMinutes min practice',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(height: isCompactScreen ? 6 : 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompactScreen ? 14 : 18,
                                      vertical: isCompactScreen ? 4 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: semantic.sandSurface,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Tap to Adjust',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: semantic.subtle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: heroVerticalSpacing),

              // Guided vs Silent Toggle Pill
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: semantic.pillUnselected,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isGuided) {
                              widget.onSelectedTypeChanged('Guided');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isGuided
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Guided',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isGuided
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onSelectedTypeChanged('Silent'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isGuided
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Silent',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: !isGuided
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isCompactScreen ? 14 : 20),

              // Practice Card (Guided mode only)
              if (isGuided) ...[
                PracticeStepperCard(
                  practice: currentPractice,
                  onPrevious: includedPractices.length > 1
                      ? () {
                          final list = includedPractices;
                          final idx = list.indexWhere((p) => p.id == currentPractice.id);
                          final nextIdx = (idx - 1 + list.length) % list.length;
                          widget.onSelectedPracticeIdChanged(list[nextIdx].id);
                        }
                      : null,
                  onNext: includedPractices.length > 1
                      ? () {
                          final list = includedPractices;
                          final idx = list.indexWhere((p) => p.id == currentPractice.id);
                          final nextIdx = (idx + 1) % list.length;
                          widget.onSelectedPracticeIdChanged(list[nextIdx].id);
                        }
                      : null,
                ),
                SizedBox(height: itemVerticalSpacing),

                // Voice Card
                VoiceStepperCard(
                  voice: currentVoiceConfig,
                  onPrevious: activeVoices.length > 1
                      ? () {
                          final idx = activeVoices.indexWhere(
                              (v) => v.id == currentVoiceConfig.id);
                          final nextIdx = (idx - 1 + activeVoices.length) %
                              activeVoices.length;
                          widget.onSelectedVoiceIdChanged
                              ?.call(activeVoices[nextIdx].id);
                          widget.onVoiceIndexChanged?.call(nextIdx);
                        }
                      : null,
                  onNext: activeVoices.length > 1
                      ? () {
                          final idx = activeVoices.indexWhere(
                              (v) => v.id == currentVoiceConfig.id);
                          final nextIdx =
                              (idx + 1) % activeVoices.length;
                          widget.onSelectedVoiceIdChanged
                              ?.call(activeVoices[nextIdx].id);
                          widget.onVoiceIndexChanged?.call(nextIdx);
                        }
                      : null,
                ),
                SizedBox(height: itemVerticalSpacing),
              ],

              // Bell Card
              _buildStepperPill(
                context: context,
                icon: Icons.notifications,
                title: currentBell.title,
                onPrevious: () {
                  if (availableBells.isEmpty) return;
                  final validIdx = currentBellIndex == -1
                      ? 0
                      : currentBellIndex;
                  final nextIdx = (validIdx - 1 + availableBells.length) %
                      availableBells.length;
                  widget.onSelectedBellChanged(availableBells[nextIdx].id);
                },
                onNext: () {
                  if (availableBells.isEmpty) return;
                  final validIdx = currentBellIndex == -1
                      ? 0
                      : currentBellIndex;
                  final nextIdx =
                      (validIdx + 1) % availableBells.length;
                  widget.onSelectedBellChanged(availableBells[nextIdx].id);
                },
              ),

              SizedBox(height: buttonVerticalSpacing),

              // Begin Practice Button
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 54),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29),
                    ),
                  ),
                  onPressed: () {
                    final targetSeconds = _calculateTargetSeconds();
                    widget.onBeginPractice(
                      targetSeconds,
                      isGuided ? currentPractice.name : 'Silent',
                      currentBell,
                      isGuided ? currentPractice : null,
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Begin Practice',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // Bottom padding ensures the button is fully visible
              // and has breathing room above system bars / safe area.
              SizedBox(height: isCompactScreen ? 20 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperPill({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = AppSemanticColors.of(context);
    final isLight = theme.brightness == Brightness.light;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(29),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: isLight
              ? const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular Icon (inert display)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: semantic.sandSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.onSurface, size: 22),
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
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  title,
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
    );
  }
}
