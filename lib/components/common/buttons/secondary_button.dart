import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

class SecondaryOutlineButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback? onPressed;
  final Icon? icon;

  const SecondaryOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : AppColors.primary;
    final isEnabled = onPressed != null;

    final buttonStyle = AppButtonStyles.primaryOutlinedButton.copyWith(
      foregroundColor: WidgetStateProperty.all<Color>(c),
      side: WidgetStateProperty.all<BorderSide>(
        BorderSide(color: c, width: 2),
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final textLabel = Text(label, style: AppTextStyles.bodyMediumSemiBold);

    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: icon!,
              label: textLabel,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: buttonStyle,
              child: textLabel,
            ),
    );
  }
}
