import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

class SecondaryOutlineButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onPressed;

  const SecondaryOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : AppColors.primary;

    return OutlinedButton(
      onPressed: onPressed,
      style: AppButtonStyles.primaryOutlinedButton.copyWith(
        foregroundColor: WidgetStatePropertyAll<Color>(c),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: c, width: 2),
        ),
        // TODO: nevhapem preco ten shape nejde dat do AppButtonStyles.primaryOutlinedButton
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMediumSemiBold,
      ),
    );
  }
}
