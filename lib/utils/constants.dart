import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Colors.deepPurpleAccent;
  static final Color textSecondary = Colors.grey[600]!;
  static final Color textTertiary = Colors.grey[800]!;
  static final Color danger = Colors.red[700]!;
  static final Color dangerBackground = Colors.red[50]!;
  static final Color dayPickerSelected = Colors.deepPurpleAccent.withValues(
    alpha: 0.2,
  );
  static final Color dayPickerDefault = Colors.grey[900]!;
  static final Color success = Colors.green[600]!;
  static final Color successBackground = Colors.green[50]!;
  static final Color warning = Colors.orange[700]!;
  static final Color warningBackground = Colors.orange[50]!;
  static final error = Colors.red[600]!;
  static final errorBackground = Colors.red[50]!;
}

class AppTextSizes {
  static const double heading1 = 32.0;
  static const double heading2 = 24.0;
  static const double heading3 = 18.0;
  static const double bodyMedium = 16.0;
  static const double bodySmall = 14.0;
  static const double caption = 12.0;
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

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

  static const TextStyle bodyMedium = TextStyle(fontSize: 16);

  static const TextStyle bodySmall = TextStyle(fontSize: 14);

  static const TextStyle avatarLetter = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle captionSecondary = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static TextStyle adherenceRate = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.white,
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
  static const double pageDouble = 24.0;
  static const EdgeInsets card = EdgeInsets.all(16);
}

class AppButtonStyles {
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class AppGradients {
  static const LinearGradient purple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  );

  static const LinearGradient green = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  );
}

class MedAdherence {
  static const days7 = 7;
  static const days30 = 30;
}

class MedicationConstants {
  static const doseReminderAdvanceMinutes = 15;
  static const doseLateThresholdMinutes = 15;
  static const maxDosesPerDay = 24;

  static const scheduleLookAheadDays = 7;

  static const historyDefaultDays = 30;
  static const streakCalculationDays = 365;

  static const nfcPackageName = 'pv292.fi.muni.cz.med_track';
}

class DoseBuddyConstants {
  static const advertisedName = 'DoseBuddy';
  static const serviceUuid = '8f5a3a62-47ef-4f2b-9b4d-7d716b7b2201';
  static const controlCharacteristicUuid =
      '8f5a3a62-47ef-4f2b-9b4d-7d716b7b2202';
  static const eventCharacteristicUuid = '8f5a3a62-47ef-4f2b-9b4d-7d716b7b2203';
  static const scanTimeoutSeconds = 15;
  static const earlyConfirmationMinutes = 60;
  static const dispenserWindowMinutes = 60;
  static const missedAlertGraceMinutes = 60;
  static const defaultDispenserCapacity = 15;
  static const maxDispenserCapacity = 15;
  static const maxManualIntervals = 8;
  static const prefsKeyPrefix = 'dose_buddy';
}

class AccountShareConstants {
  static const placeholderQrPrefix = 'medtrack-account-share-placeholder';

  /// Prefix for real account-sharing QR codes (see [AccountSharePayload]).
  static const qrPrefix = 'medtrack-account-share';
}
