import 'package:flutter/material.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/profile/adherence_rate_card.dart';
import 'package:med_track/components/profile/user_stats_card.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/model/app_user.dart';

import '../components/profile/dialogs/change_password_dialog.dart';
import '../components/profile/dialogs/delete_account_dialog.dart';
import '../components/profile/user_info_card.dart';
import '../utils/constants.dart';
import '../utils/handling_stream_builder.dart';
import '../utils/snackbar_utils.dart';
import '../components/profile/notification_settings_card.dart';
import '../components/profile/profile_action_buttons.dart';
import '../components/profile/danger_zone_card.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final _authService = get<AuthService>();
  final _userDbService = get<UserDatabaseService>();
  late final _userId = _authService.user?.uid;

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('No logged-in user')));
    }

    return Scaffold(
      body: HandlingStreamBuilder<AppUser?>(
        stream: _userDbService.observe(_userId),
        builder: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load user data'),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _authService.signOut,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              GradientSliverHeader(
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
                      AdherenceRateCard(rate: '87%', period: '30 days'),
                      const SizedBox(height: AppSpacing.xl),
                      UserStatsCard(
                        thisWeek: '92% (33/36 dávek)',
                        thisMonth: '87% (104/120 dávek)',
                        daysStreak: '5 dní bez vynechání',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NotificationSettingsCard(
                        user: user,
                        onToggle: (value) =>
                            _onToggleNotifications(context, user, value),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ProfileActionButtons(
                        onChangePassword: () =>
                            _showChangePasswordDialog(context, user),
                        onLogout: _authService.signOut,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DangerZoneCard(
                        onDelete: () => _showDeleteAccountDialog(context, user),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onToggleNotifications(
    BuildContext context,
    AppUser user,
    bool value,
  ) async {
    try {
      final updatedUser = user.copyWith(notificationsEnabled: value);
      await _userDbService.update(updatedUser.id!, updatedUser);
      if (context.mounted) {
        showSnackBar(context, 'Notification settings updated');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to update settings: $e');
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (_) => ChangePasswordDialog(
        onSubmit: (currentPass, newPass) =>
            _onChangePassword(context, user, currentPass, newPass),
      ),
    );
  }

  Future<void> _onChangePassword(
    BuildContext context,
    AppUser user,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _authService.resetPasswordFromCurrentPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        email: user.email,
      );
      if (context.mounted) {
        showSnackBar(context, 'Password changed successfully');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to change password: $e');
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (_) => DeleteAccountDialog(
        onDelete: (password) => _onDeleteAccount(context, user, password),
      ),
    );
  }

  Future<void> _onDeleteAccount(
    BuildContext context,
    AppUser user,
    String password,
  ) async {
    try {
      await _authService.deleteUser(
        currentPassword: password,
        email: user.email,
      );
      if (context.mounted) {
        showSnackBar(context, 'Account deleted successfully');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to delete account: $e');
      }
    }
  }
}
