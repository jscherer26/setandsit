import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';

enum _DialMode { hour, minute }

class ClockTimePickerDialog extends StatefulWidget {
  final int initialHour12;
  final int initialMinute;
  final bool initialIsAm;

  const ClockTimePickerDialog({
    super.key,
    required this.initialHour12,
    required this.initialMinute,
    required this.initialIsAm,
  });

  /// Displays the custom clock time selector dialog.
  static Future<TimeOfDay?> show({
    required BuildContext context,
    required int initialHour12,
    required int initialMinute,
    required bool initialIsAm,
  }) {
    return showDialog<TimeOfDay>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClockTimePickerDialog(
        initialHour12: initialHour12,
        initialMinute: initialMinute,
        initialIsAm: initialIsAm,
      ),
    );
  }

  @override
  State<ClockTimePickerDialog> createState() => _ClockTimePickerDialogState();
}

class _ClockTimePickerDialogState extends State<ClockTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAm;
  _DialMode _mode = _DialMode.minute;

  static const double _dialSize = 230.0;
  static const double _radius = 82.0;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour12 == 0 ? 12 : widget.initialHour12;
    _selectedMinute = widget.initialMinute;
    _isAm = widget.initialIsAm;
  }

  @override
  void didUpdateWidget(covariant ClockTimePickerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHour12 != widget.initialHour12 ||
        oldWidget.initialMinute != widget.initialMinute ||
        oldWidget.initialIsAm != widget.initialIsAm) {
      setState(() {
        _selectedHour = widget.initialHour12 == 0 ? 12 : widget.initialHour12;
        _selectedMinute = widget.initialMinute;
        _isAm = widget.initialIsAm;
      });
    }
  }

  int get _diffMinutes {
    final now = DateTime.now();
    final hour24 = _isAm
        ? (_selectedHour == 12 ? 0 : _selectedHour)
        : (_selectedHour == 12 ? 12 : _selectedHour + 12);

    final todayTarget = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      _selectedMinute,
    );

    final diffSeconds = todayTarget.difference(now).inSeconds;
    final diffMins = (diffSeconds / 60.0).round();

    // If deeply negative, check if it's within 90 minutes tomorrow (midnight wrap)
    if (diffMins < -720) {
      final tomorrowTarget = todayTarget.add(const Duration(days: 1));
      final tomorrowMins = (tomorrowTarget.difference(now).inSeconds / 60.0).round();
      if (tomorrowMins >= 0 && tomorrowMins <= 90) {
        return tomorrowMins;
      }
    }

    return diffMins;
  }

  double get _currentAngle {
    if (_mode == _DialMode.hour) {
      return (_selectedHour * 30.0 - 90.0) * (pi / 180.0);
    } else {
      return (_selectedMinute * 6.0 - 90.0) * (pi / 180.0);
    }
  }

  void _handleTouch(Offset localPosition) {
    const center = Offset(_dialSize / 2, _dialSize / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final theta = atan2(dy, dx);
    var degrees = theta * (180.0 / pi) + 90.0;
    if (degrees < 0) {
      degrees += 360.0;
    }

    if (_mode == _DialMode.hour) {
      final rawHour = (degrees / 30.0).round() % 12;
      final hour = rawHour == 0 ? 12 : rawHour;
      if (_selectedHour != hour) {
        setState(() {
          _selectedHour = hour;
        });
      }
    } else {
      final minute = (degrees / 6.0).round() % 60;
      if (_selectedMinute != minute) {
        setState(() {
          _selectedMinute = minute;
        });
      }
    }
  }

  void _onDialInteractionEnd() {
    if (_mode == _DialMode.hour) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() {
            _mode = _DialMode.minute;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);

    final diffMins = _diffMinutes;
    final isNegative = diffMins <= 0;
    final isTooLong = diffMins > 90;
    final isValid = !isNegative && !isTooLong;

    String durationText;
    if (diffMins < 0) {
      durationText = '$diffMins min';
    } else if (diffMins == 0) {
      durationText = '0 min';
    } else if (diffMins > 90) {
      durationText = '$diffMins min (max 90 min)';
    } else {
      durationText = '$diffMins min practice';
    }

    final statusColor = isValid ? colorScheme.primary : colorScheme.error;
    final statusBg = isValid
        ? colorScheme.primary.withValues(alpha: 0.1)
        : colorScheme.error.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Finish Time',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: semantic.muted,
              ),
            ),
            const SizedBox(height: 14),

            // Digital Time Display & AM/PM Selector
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hour Box
                  GestureDetector(
                    onTap: () => setState(() => _mode = _DialMode.hour),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _mode == _DialMode.hour
                            ? colorScheme.primary.withValues(alpha: 0.14)
                            : semantic.sandSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mode == _DialMode.hour
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _selectedHour.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Minute Box
                  GestureDetector(
                    onTap: () => setState(() => _mode = _DialMode.minute),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _mode == _DialMode.minute
                            ? colorScheme.primary.withValues(alpha: 0.14)
                            : semantic.sandSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mode == _DialMode.minute
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _selectedMinute.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // AM / PM Stacked Pill
                  Container(
                    decoration: BoxDecoration(
                      color: semantic.sandSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isAm = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isAm ? colorScheme.primary : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            ),
                            child: Text(
                              'AM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isAm ? colorScheme.onPrimary : semantic.muted,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isAm = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: !_isAm ? colorScheme.primary : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            ),
                            child: Text(
                              'PM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !_isAm ? colorScheme.onPrimary : semantic.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live Session Length / Negative Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isValid ? Colors.transparent : colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isValid ? Icons.timer_outlined : Icons.info_outline,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Circular Clock Dial with interactive selector arm
            SizedBox(
              width: _dialSize,
              height: _dialSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _handleTouch(details.localPosition),
                onPanUpdate: (details) => _handleTouch(details.localPosition),
                onPanEnd: (_) => _onDialInteractionEnd(),
                onTapDown: (details) => _handleTouch(details.localPosition),
                onTapUp: (_) => _onDialInteractionEnd(),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(_dialSize, _dialSize),
                      painter: _ClockArmPainter(
                        angle: _currentAngle,
                        radius: _radius,
                        dialBgColor: semantic.clockDialSurface,
                        armColor: colorScheme.primary,
                        dotColor: colorScheme.onPrimary,
                        isMinuteNonFive: _mode == _DialMode.minute && _selectedMinute % 5 != 0,
                      ),
                    ),
                    ..._buildDialNumbers(colorScheme),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons (Cancel / OK)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: semantic.muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  ),
                  onPressed: isValid
                      ? () {
                          final hour24 = _isAm
                              ? (_selectedHour == 12 ? 0 : _selectedHour)
                              : (_selectedHour == 12 ? 12 : _selectedHour + 12);
                          Navigator.pop(
                            context,
                            TimeOfDay(hour: hour24, minute: _selectedMinute),
                          );
                        }
                      : null,
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDialNumbers(ColorScheme colorScheme) {
    const center = Offset(_dialSize / 2, _dialSize / 2);
    final numbers = <Widget>[];

    if (_mode == _DialMode.hour) {
      const hours = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      for (final h in hours) {
        final ang = (h * 30.0 - 90.0) * (pi / 180.0);
        final x = center.dx + _radius * cos(ang);
        final y = center.dy + _radius * sin(ang);
        final isSelected = _selectedHour == h;

        numbers.add(
          Positioned(
            left: x - 16,
            top: y - 16,
            width: 32,
            height: 32,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '$h',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      const minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
      for (final m in minutes) {
        final ang = (m * 6.0 - 90.0) * (pi / 180.0);
        final x = center.dx + _radius * cos(ang);
        final y = center.dy + _radius * sin(ang);
        final isSelected = _selectedMinute == m;

        numbers.add(
          Positioned(
            left: x - 16,
            top: y - 16,
            width: 32,
            height: 32,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  m.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return numbers;
  }
}

class _ClockArmPainter extends CustomPainter {
  final double angle;
  final double radius;
  final Color dialBgColor;
  final Color armColor;
  final Color dotColor;
  final bool isMinuteNonFive;

  _ClockArmPainter({
    required this.angle,
    required this.radius,
    required this.dialBgColor,
    required this.armColor,
    required this.dotColor,
    this.isMinuteNonFive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final selectorCenter = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    // Background clock dial circle
    final bgPaint = Paint()
      ..color = dialBgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width / 2, bgPaint);

    // Arm line
    final armPaint = Paint()
      ..color = armColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, selectorCenter, armPaint);

    // Center pivot
    final pivotPaint = Paint()
      ..color = armColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, pivotPaint);

    // Tip selector circle
    final selectorPaint = Paint()
      ..color = armColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(selectorCenter, 18.0, selectorPaint);

    // Small center dot if minute is between 5-minute ticks
    if (isMinuteNonFive) {
      final dotPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectorCenter, 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClockArmPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.radius != radius ||
        oldDelegate.dialBgColor != dialBgColor ||
        oldDelegate.armColor != armColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.isMinuteNonFive != isMinuteNonFive;
  }
}
