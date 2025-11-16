import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Colors.deepPurpleAccent;
  static final Color textSecondary = Colors.grey[600]!;
  static final Color textTertiary = Colors.grey[800]!;
  static final Color danger = Colors.red[700]!;
  static final Color dangerBackground = Colors.red[50]!;
}

class AppTextStyles {
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyMediumSemiBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
  );

  static const TextStyle avatarLetter = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle captionSecondary = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const double radiusMd = 12.0;
  static const double avatarRadius = 50.0;
  static const double iconSm = 20.0;
}

class AppPadding {
  static const EdgeInsets page = EdgeInsets.all(24);
  static const EdgeInsets card = EdgeInsets.all(16);
}

class AppButtonStyles {
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  );

  static ButtonStyle primaryOutlinedButton = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    side: const BorderSide(color: AppColors.primary),
    foregroundColor: AppColors.primary,
  );

  static ButtonStyle dangerButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.danger,
    foregroundColor: Colors.white,
  );

  static ButtonStyle dangerOutlinedButton = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
    side: BorderSide(color: AppColors.danger),
    foregroundColor: AppColors.danger,
  );
}
