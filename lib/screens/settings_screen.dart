import 'package:material_ui/material_ui.dart';
import '../models/display_preferences.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final int preparationDelaySeconds;
  final ThemeMode themeMode;
  final int fontSizePx;
  final bool showDisplaySettings;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<int>? onFontSizePxChanged;
  final bool isDeveloperMode;
  final int stagedVariantsCount;
  final VoidCallback? onDisableDeveloperMode;
  final ValueChanged<int> onPracticeDurationChanged;
  final ValueChanged<double> onInstructionDensityChanged;
  final ValueChanged<double> onRedirectionDensityChanged;
  final ValueChanged<int> onPreparationDelayChanged;
  final VoidCallback onBack;
  final VoidCallback? onOpenManagePractices;
  final VoidCallback? onOpenManageVoices;
  final VoidCallback? onOpenBellSettings;
  final VoidCallback? onOpenAbout;

  const SettingsScreen({
    super.key,
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    this.preparationDelaySeconds = 3,
    this.themeMode = ThemeMode.system,
    this.fontSizePx = DisplayPreferences.defaultFontSizePx,
    this.showDisplaySettings = true,
    this.onThemeModeChanged,
    this.onFontSizePxChanged,
    this.isDeveloperMode = false,
    this.stagedVariantsCount = 0,
    this.onDisableDeveloperMode,
    required this.onPracticeDurationChanged,
    required this.onInstructionDensityChanged,
    required this.onRedirectionDensityChanged,
    required this.onPreparationDelayChanged,
    required this.onBack,
    this.onOpenManagePractices,
    this.onOpenManageVoices,
    this.onOpenBellSettings,
    this.onOpenAbout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;
  String? _errorMessage;

  late TextEditingController _delayController;
  late FocusNode _delayFocusNode;
  String? _delayErrorMessage;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.practiceDurationMinutes.toString(),
    );
    _durationFocusNode = FocusNode();
    _durationFocusNode.addListener(() {
      if (!_durationFocusNode.hasFocus) {
        _validateDuration();
      }
    });

    _delayController = TextEditingController(
      text: widget.preparationDelaySeconds.toString(),
    );
    _delayFocusNode = FocusNode();
    _delayFocusNode.addListener(() {
      if (!_delayFocusNode.hasFocus) {
        _validateDelay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.practiceDurationMinutes != widget.practiceDurationMinutes) {
      if (!_durationFocusNode.hasFocus &&
          _durationController.text !=
              widget.practiceDurationMinutes.toString()) {
        _durationController.text = widget.practiceDurationMinutes.toString();
        setState(() {
          _errorMessage = null;
        });
      }
    }
    if (oldWidget.preparationDelaySeconds != widget.preparationDelaySeconds) {
      if (!_delayFocusNode.hasFocus &&
          _delayController.text !=
              widget.preparationDelaySeconds.toString()) {
        _delayController.text = widget.preparationDelaySeconds.toString();
        setState(() {
          _delayErrorMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _durationFocusNode.dispose();
    _delayController.dispose();
    _delayFocusNode.dispose();
    super.dispose();
  }

  void _validateDuration({bool updateUi = true}) {
    final text = _durationController.text.trim();
    if (text.isEmpty) {
      if (updateUi && mounted) {
        setState(() {
          _errorMessage = 'Please enter a duration.';
        });
      }
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 90) {
      if (updateUi && mounted) {
        setState(() {
          _errorMessage = 'Duration must be between 1 and 90 minutes.';
        });
      }
      return;
    }
    if (updateUi && mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    widget.onPracticeDurationChanged(parsed);
  }

  void _validateDelay({bool updateUi = true}) {
    final text = _delayController.text.trim();
    if (text.isEmpty) {
      if (updateUi && mounted) {
        setState(() {
          _delayErrorMessage = 'Please enter a delay (0 to 20 seconds).';
        });
      }
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > 20) {
      if (updateUi && mounted) {
        setState(() {
          _delayErrorMessage = 'Delay must be between 0 and 20 seconds.';
        });
      }
      return;
    }
    if (updateUi && mounted) {
      setState(() {
        _delayErrorMessage = null;
      });
    }
    widget.onPreparationDelayChanged(parsed);
  }

  void _handleBack() {
    final text = _durationController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 90) {
      setState(() {
        _errorMessage = 'Duration must be between 1 and 90 minutes.';
      });
      return;
    }

    final delayText = _delayController.text.trim();
    final delayParsed = int.tryParse(delayText);
    if (delayParsed == null || delayParsed < 0 || delayParsed > 20) {
      setState(() {
        _delayErrorMessage = 'Delay must be between 0 and 20 seconds.';
      });
      return;
    }

    widget.onPracticeDurationChanged(parsed);
    widget.onPreparationDelayChanged(delayParsed);
    widget.onBack();
  }

  void _handleNavigationSilently() {
    final text = _durationController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 1 && parsed <= 90) {
      widget.onPracticeDurationChanged(parsed);
    }
    final delayText = _delayController.text.trim();
    final delayParsed = int.tryParse(delayText);
    if (delayParsed != null && delayParsed >= 0 && delayParsed <= 20) {
      widget.onPreparationDelayChanged(delayParsed);
    }
  }

  Widget _buildLeadingCircle({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: semantic.sandSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: iconColor ?? colorScheme.primary,
        size: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final hasManagementLinks = widget.onOpenManagePractices != null ||
        widget.onOpenManageVoices != null ||
        widget.onOpenBellSettings != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handleBack,
            ),
            title: const Text('Settings'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Defaults',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: semantic.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. Defaults Card (Duration & Delay)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Practice Duration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Practice Duration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 104,
                                  maxWidth: 136,
                                  minHeight: 46,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: semantic.sandSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _errorMessage != null
                                          ? colorScheme.error
                                          : colorScheme.outlineVariant,
                                      width: _errorMessage != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _durationController,
                                    focusNode: _durationFocusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _errorMessage != null
                                          ? colorScheme.error
                                          : colorScheme.primary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 11,
                                      ),
                                      suffixText: 'min',
                                      suffixStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: semantic.muted,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final trimmed = val.trim();
                                      final parsed = int.tryParse(trimmed);
                                      if (parsed != null && parsed >= 1 && parsed <= 90) {
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                        widget.onPracticeDurationChanged(parsed);
                                      } else {
                                        _validateDuration();
                                      }
                                    },
                                    onSubmitted: (_) => _validateDuration(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(),
                          ),

                          // Row 2: Practice Delay
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Practice Delay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 104,
                                  maxWidth: 136,
                                  minHeight: 46,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: semantic.sandSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _delayErrorMessage != null
                                          ? colorScheme.error
                                          : colorScheme.outlineVariant,
                                      width: _delayErrorMessage != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _delayController,
                                    focusNode: _delayFocusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _delayErrorMessage != null
                                          ? colorScheme.error
                                          : colorScheme.primary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 11,
                                      ),
                                      suffixText: 'sec',
                                      suffixStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: semantic.muted,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final trimmed = val.trim();
                                      final parsed = int.tryParse(trimmed);
                                      if (parsed != null && parsed >= 0 && parsed <= 20) {
                                        setState(() {
                                          _delayErrorMessage = null;
                                        });
                                        widget.onPreparationDelayChanged(parsed);
                                      } else {
                                        _validateDelay();
                                      }
                                    },
                                    onSubmitted: (_) => _validateDelay(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'The guidance will start this many seconds after "Begin Practice" is pressed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: semantic.muted,
                            ),
                          ),

                          if (_delayErrorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _delayErrorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 2. Practice & Audio Management Card
                  if (hasManagementLinks) ...[
                    const SizedBox(height: 18),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          if (widget.onOpenManagePractices != null)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: _buildLeadingCircle(
                                context: context,
                                icon: Icons.self_improvement,
                              ),
                              title: Text(
                                'Manage Practices',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Create, copy, and customize clinical meditation practices',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: semantic.muted,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: semantic.muted,
                              ),
                              onTap: () {
                                _handleNavigationSilently();
                                widget.onOpenManagePractices!();
                              },
                            ),

                          if (widget.onOpenManageVoices != null) ...[
                            if (widget.onOpenManagePractices != null)
                              const Divider(indent: 20, endIndent: 20),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: _buildLeadingCircle(
                                context: context,
                                icon: Icons.record_voice_over,
                              ),
                              title: Text(
                                'Manage Voices',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Browse voices, inspect script variants, and audition audio',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: semantic.muted,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: semantic.muted,
                              ),
                              onTap: () {
                                _handleNavigationSilently();
                                widget.onOpenManageVoices!();
                              },
                            ),
                          ],

                          if ((widget.onOpenManagePractices != null ||
                                  widget.onOpenManageVoices != null) &&
                              widget.onOpenBellSettings != null)
                            const Divider(indent: 20, endIndent: 20),

                          if (widget.onOpenBellSettings != null)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: _buildLeadingCircle(
                                context: context,
                                icon: Icons.notifications_active_outlined,
                              ),
                              title: Text(
                                'Manage Bells',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Select and configure acoustic meditation bells',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: semantic.muted,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: semantic.muted,
                              ),
                              onTap: () {
                                _handleNavigationSilently();
                                widget.onOpenBellSettings!();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],

                  // 3. Display & Appearance Card
                  if (widget.showDisplaySettings) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Display & Appearance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: semantic.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.system,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('System', maxLines: 1),
                                    ),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.light,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Light', maxLines: 1),
                                    ),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.dark,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Dark', maxLines: 1),
                                    ),
                                  ),
                                ],
                                selected: {widget.themeMode},
                                onSelectionChanged: (selection) {
                                  if (selection.isNotEmpty) {
                                    widget.onThemeModeChanged?.call(selection.first);
                                  }
                                },
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(),
                            ),

                            Text(
                              'Text Size',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: DisplayPreferences.allowedFontSizes.map((px) {
                                final isSelected = widget.fontSizePx == px;
                                return ChoiceChip(
                                  label: Text('${px}px'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      widget.onFontSizePxChanged?.call(px);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 4. About Card
                  if (widget.onOpenAbout != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: _buildLeadingCircle(
                          context: context,
                          icon: Icons.info_outline,
                        ),
                        title: Text(
                          'About Set&Sit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'App info, mission, feedback, and licenses',
                          style: TextStyle(
                            fontSize: 12,
                            color: semantic.muted,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: semantic.muted,
                        ),
                        onTap: () {
                          _handleNavigationSilently();
                          widget.onOpenAbout!();
                        },
                      ),
                    ),
                  ],

                  // 5. Developer Mode Card (strictly last, behind amber divider, only when active)
                  if (widget.isDeveloperMode) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Developer Mode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: semantic.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Divider(
                            color: semantic.warning.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildLeadingCircle(
                                  context: context,
                                  icon: Icons.developer_mode,
                                  iconColor: semantic.warning,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Staged Audio Overrides Active',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Staged variants loaded: ${widget.stagedVariantsCount}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: semantic.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.onDisableDeveloperMode != null) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onDisableDeveloperMode,
                                  child: const Text('Disable Developer Mode'),
                                ),
                              ),
                            ],
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
        ),
      ),
    );
  }
}
