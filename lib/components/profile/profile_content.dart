import 'package:flutter/material.dart';
import 'package:med_track/components/common/adherence_rate_card.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/profile/danger_zone_card.dart';
import 'package:med_track/components/profile/notification_settings_card.dart';
import 'package:med_track/components/profile/profile_action_buttons.dart';
import 'package:med_track/components/profile/user_info_card.dart';
import 'package:med_track/components/profile/user_stats_card.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/adherence_calculator.dart';

class ProfileContent extends StatelessWidget {
  final AppUser user;
  final List<DoseEvent> events;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final Function(bool) onToggleNotifications;

  const ProfileContent({
    super.key,
    required this.user,
    required this.events,
    required this.onLogout,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.onToggleNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final adherence30d = calculateAdherence(events, MedAdherence.days30);
    final thisWeekStats = formatAdherence(events, MedAdherence.days7);
    final thisMonthStats = formatAdherence(events, MedAdherence.days30);
    final streak = calculateStreak(events);

    return CustomScrollView(
      slivers: [
        const GradientSliverHeader(
          title: 'Profile',
          subtitle: 'Settings and stats',
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
                ),
                const SizedBox(height: AppSpacing.xl),
                ProfileActionButtons(
                  onChangePassword: onChangePassword,
                  onLogout: onLogout,
                ),
                const SizedBox(height: AppSpacing.md),
                DangerZoneCard(onDelete: onDeleteAccount),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
