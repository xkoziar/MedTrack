import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Icon? icon;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = AppButtonStyles.primaryButton.copyWith(
      backgroundColor: WidgetStateProperty.all<Color>(Colors.transparent),
      shadowColor: WidgetStateProperty.all<Color>(Colors.transparent),
    );

    final textLabel = Text(label, style: AppTextStyles.bodyMediumSemiBold);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.purple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon != null
          ? ElevatedButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: icon!,
              label: textLabel,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: buttonStyle,
              child: textLabel,
            ),
    );
  }
}
