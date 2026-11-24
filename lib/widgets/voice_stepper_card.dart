import 'package:material_ui/material_ui.dart';
import '../models/voice_config.dart';
import '../theme/app_theme.dart';

/// Reusable Voice Stepper Card widget.
/// Used on both the Home Screen (ConfigurationScreen) and ManageVoicesScreen.
class VoiceStepperCard extends StatelessWidget {
  final VoiceConfig voice;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;
  final VoidCallback? onLeadingTap;
  final IconData leadingIcon;
  final Widget? trailing;
  final Color? titleColor;
  final String? subtitle;

  const VoiceStepperCard({
    super.key,
    required this.voice,
    this.onPrevious,
    this.onNext,
    this.onTap,
    this.onLeadingTap,
    this.leadingIcon = Icons.record_voice_over,
    this.trailing,
    this.titleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = AppSemanticColors.of(context);
    final isLight = theme.brightness == Brightness.light;

    final voiceInfo = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            voice.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: titleColor ?? colorScheme.onSurface,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: semantic.muted,
              ),
            ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(29),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
          boxShadow: isLight
              ? const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular Leading Icon
            if (onLeadingTap != null)
              InkWell(
                onTap: onLeadingTap,
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: semantic.sandSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(leadingIcon, color: colorScheme.onSurface, size: 22),
                ),
              )
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: semantic.sandSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: colorScheme.onSurface, size: 22),
              ),

            // Previous Chevron
            IconButton(
              icon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
              onPressed: onPrevious,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              splashRadius: 22,
            ),

            // Voice Info
            Expanded(
              child: onTap != null
                  ? InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: voiceInfo,
                    )
                  : voiceInfo,
            ),

            // Next Chevron
            IconButton(
              icon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
              onPressed: onNext,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              splashRadius: 22,
            ),

            // Optional Trailing Widget
            ?trailing,
          ],
        ),
      ),
    );
  }
}
