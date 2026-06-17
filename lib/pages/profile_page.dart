import 'package:flutter/material.dart';
import 'package:med_track/components/profile/profile_content.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/account_link.dart';
import 'package:med_track/database/service/account_link_database_service.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/notification_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/pages/account_qr_scanner_page.dart';
import 'package:med_track/pages/nfc_management_page.dart';
import 'package:med_track/utils/helpers/account_share_payload.dart';

import 'package:med_track/components/profile/dialogs/change_password_dialog.dart';
import 'package:med_track/components/profile/dialogs/delete_account_dialog.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/snackbar_utils.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final _authService = get<AuthService>();
  final _userDbService = get<UserDatabaseService>();
  final _doseEventDbService = get<DoseEventDatabaseService>();
  final _medicationDbService = get<MedicationDatabaseService>();
  final _accountLinkDbService = get<AccountLinkDatabaseService>();
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

          return HandlingStreamBuilder<List<Medication>>(
            stream: _medicationDbService.observeUserMedications(user.id!),
            builder: (medications) {
              return HandlingStreamBuilder<List<DoseEvent>>(
                stream: _doseEventDbService.observeUserDoseEvents(user.id!),
                builder: (events) {
                  return ProfileContent(
                    user: user,
                    events: events,
                    medications: medications,
                    onLogout: _authService.signOut,
                    onChangePassword: () =>
                        _showChangePasswordDialog(context, user),
                    onManageNfcTags: () => _navigateToNfcManagement(context),
                    onDeleteAccount: () =>
                        _showDeleteAccountDialog(context, user),
                    onToggleNotifications: (value) =>
                        _onToggleNotifications(context, user, value),
                    onReminderChanged: (minutes) =>
                        _onReminderChanged(context, user, minutes),
                    onScanAccountQr: () =>
                        _openAccountQrScanner(context, user),
                  );
                },
              );
            },
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

      if (value) {
        await NotificationService.requestPermission();
        await NotificationService.scheduleForUser(
          user.id!,
          user.reminderMinutes,
        );
      } else {
        await NotificationService.cancelAll();
      }

      if (context.mounted) {
        showSnackBar(
          context,
          value ? 'Notifications enabled' : 'Notifications disabled',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to update settings: $e');
      }
    }
  }

  Future<void> _onReminderChanged(
    BuildContext context,
    AppUser user,
    int minutes,
  ) async {
    try {
      final updatedUser = user.copyWith(reminderMinutes: minutes);
      await _userDbService.update(updatedUser.id!, updatedUser);

      if (user.notificationsEnabled) {
        await NotificationService.scheduleForUser(user.id!, minutes);
      }

      if (context.mounted) {
        final msg = minutes == 0
            ? 'Reminder set to dose time'
            : 'Reminder set to $minutes min before';
        showSnackBar(context, msg);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to update reminder: $e');
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

  void _navigateToNfcManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NfcManagementPage()),
    );
  }

  Future<void> _openAccountQrScanner(
    BuildContext context,
    AppUser caregiver,
  ) async {
    final scannedValue = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const AccountQrScannerPage()),
    );

    if (!context.mounted || scannedValue == null || scannedValue.isEmpty) {
      return;
    }

    final payload = AccountSharePayload.tryParse(scannedValue);
    if (payload == null) {
      showSnackBar(context, 'This is not a MedTrack account QR code.');
      return;
    }

    if (payload.userId == caregiver.id) {
      showSnackBar(context, 'You cannot link your own account.');
      return;
    }

    final patientLabel = payload.name.trim().isNotEmpty
        ? payload.name
        : payload.email;

    try {
      final created = await _accountLinkDbService.createLinkIfMissing(
        AccountLink(
          id: AccountLink.buildId(payload.userId, caregiver.id!),
          patientUserId: payload.userId,
          patientName: payload.name,
          patientEmail: payload.email,
          caregiverUserId: caregiver.id!,
          caregiverName: caregiver.name,
          caregiverEmail: caregiver.email,
        ),
      );

      if (!context.mounted) return;
      showSnackBar(
        context,
        created == null
            ? 'You are already linked to $patientLabel.'
            : 'Linked to $patientLabel.',
      );
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to link account: $e');
      }
    }
  }
}
