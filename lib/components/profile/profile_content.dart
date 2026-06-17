import 'package:flutter/material.dart';
import 'package:med_track/components/common/adherence_rate_card.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/profile/danger_zone_card.dart';
import 'package:med_track/components/profile/linked_accounts_card.dart';
import 'package:med_track/components/profile/notification_settings_card.dart';
import 'package:med_track/components/profile/profile_action_buttons.dart';
import 'package:med_track/components/profile/share_account_card.dart';
import 'package:med_track/components/profile/user_info_card.dart';
import 'package:med_track/components/profile/user_stats_card.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/adherence_calculator.dart';

class ProfileContent extends StatelessWidget {
  final AppUser user;
  final List<DoseEvent> events;
  final List<Medication> medications;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;
  final VoidCallback onManageNfcTags;
  final VoidCallback onDeleteAccount;
  final void Function(bool) onToggleNotifications;
  final void Function(int) onReminderChanged;
  final VoidCallback onScanAccountQr;

  const ProfileContent({
    super.key,
    required this.user,
    required this.events,
    required this.medications,
    required this.onLogout,
    required this.onChangePassword,
    required this.onManageNfcTags,
    required this.onDeleteAccount,
    required this.onToggleNotifications,
    required this.onReminderChanged,
    required this.onScanAccountQr,
  });

  @override
  Widget build(BuildContext context) {
    final adherence30d = calculateAdherence(
      events,
      MedAdherence.days30,
      medications,
    );
    final thisWeekStats = formatAdherence(
      events,
      MedAdherence.days7,
      medications,
    );
    final thisMonthStats = formatAdherence(
      events,
      MedAdherence.days30,
      medications,
    );
    final streak = calculateStreak(events, medications);

    return CustomScrollView(
      slivers: [
        GradientSliverHeader(
          title: 'Profile',
          subtitle: 'Settings and stats',
          trailing: IconButton(
            onPressed: onScanAccountQr,
            tooltip: 'Scan account QR',
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: AppPadding.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UserInfoCard(name: user.name, email: user.email),
                const SizedBox(height: AppSpacing.sm),
                AdherenceRateCard(
                  rate: '${adherence30d.toStringAsFixed(0)}%',
                  period: '${MedAdherence.days30} days',
                ),
                const SizedBox(height: AppSpacing.xl),
                UserStatsCard(
                  thisWeek: thisWeekStats,
                  thisMonth: thisMonthStats,
                  daysStreak: '$streak days without missed dose',
                ),
                const SizedBox(height: AppSpacing.sm),
                NotificationSettingsCard(
                  user: user,
                  onToggle: onToggleNotifications,
                  onReminderChanged: onReminderChanged,
                ),
                const SizedBox(height: AppSpacing.xl),
                ProfileActionButtons(
                  onChangePassword: onChangePassword,
                  onManageNfcTags: onManageNfcTags,
                  onLogout: onLogout,
                ),
                const SizedBox(height: AppSpacing.md),
                DangerZoneCard(onDelete: onDeleteAccount),
                const SizedBox(height: AppSpacing.md),
                ShareAccountCard(user: user),
                const SizedBox(height: AppSpacing.md),
                LinkedAccountsCard(currentUserId: user.id!),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
