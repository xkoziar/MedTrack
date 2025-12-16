import 'package:flutter/material.dart';
import 'package:med_track/components/profile/profile_content.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/model/app_user.dart';

import '../components/profile/dialogs/change_password_dialog.dart';
import '../components/profile/dialogs/delete_account_dialog.dart';
import '../utils/constants.dart';
import '../utils/handling_stream_builder.dart';
import '../utils/snackbar_utils.dart';
import '../components/profile/notification_settings_card.dart';
import '../components/profile/profile_action_buttons.dart';
import '../components/profile/danger_zone_card.dart';
import 'nfc_tags_page.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final _authService = get<AuthService>();
  final _userDbService = get<UserDatabaseService>();
  final _doseEventDbService = get<DoseEventDatabaseService>();
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

          return HandlingStreamBuilder<List<DoseEvent>>(
            stream: _doseEventDbService.observeUserDoseEvents(user.id!),
            builder: (events) {
              return ProfileContent(
                user: user,
                events: events,
                onLogout: _authService.signOut,
                onChangePassword: () =>
                    _showChangePasswordDialog(context, user),
                onDeleteAccount: () => _showDeleteAccountDialog(context, user),
                onToggleNotifications: (value) =>
                    _onToggleNotifications(context, user, value),
              );
            },
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
                      const SizedBox(height: AppSpacing.sm),
                      _buildNfcTagsCard(context),
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

  Widget _buildNfcTagsCard(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NfcTagsPage()),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppGradients.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.nfc,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NFC Tags',
                      style: AppTextStyles.bodyBold,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage your NFC tags',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
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
