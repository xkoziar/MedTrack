import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.purple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: AppButtonStyles.primaryButton.copyWith(
          backgroundColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMediumSemiBold
        ),
      ),
    );
  }
}
