import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/model/user.dart';

import '../database/components/custom_text_field.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../utils/snackbar_utils.dart';
import 'profile/profile_header.dart';
import 'profile/user_info_card.dart';
import 'profile/notification_settings_card.dart';
import 'profile/profile_action_buttons.dart';
import 'profile/danger_zone_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = get<AuthService>();
  final UserDatabaseService _userDbService = get<UserDatabaseService>();

  User? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _authService.user?.uid;
    if (userId != null) {
      final user = await _userDbService.getUser(userId);
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: AppPadding.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(user: _currentUser!),
            const SizedBox(height: AppSpacing.xxl),
            UserInfoCard(user: _currentUser!),
            const SizedBox(height: AppSpacing.xl),
            NotificationSettingsCard(
              user: _currentUser!,
              onToggle: _toggleNotifications,
            ),
            const SizedBox(height: AppSpacing.xl),
            ProfileActionButtons(
              onChangePassword: _showChangePasswordDialog,
              onLogout: _authService.signOut,
            ),
            const SizedBox(height: AppSpacing.lg),
            DangerZoneCard(onDelete: _showDeleteAccountDialog),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final updatedUser = _currentUser!.copyWith(notificationsEnabled: value);

      await _userDbService.updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUser;
      });

      if (!mounted) return;
      showSnackBar(context, 'Notification settings updated');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to update settings: $e');
    }
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();

    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Change Password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    label: "Current Password",
                    hintText: "••••••••",
                    obscure: true,
                    controller: currentPasswordCtrl,
                    validator: (value) => Validators.password(value),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: "New Password",
                    hintText: "••••••••",
                    obscure: true,
                    controller: newPasswordCtrl,
                    validator: (value) => Validators.password(value),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: "Confirm New Password",
                    hintText: "••••••••",
                    obscure: true,
                    controller: confirmPasswordCtrl,
                    validator: (value) =>
                        Validators.confirmPassword(newPasswordCtrl.text, value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                await _changePassword(
                  currentPasswordCtrl.text,
                  newPasswordCtrl.text,
                  confirmPasswordCtrl.text,
                );

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Change Password"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      await _authService.resetPasswordFromCurrentPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        email: _currentUser!.email,
      );

      if (!mounted) return;
      showSnackBar(context, 'Password changed successfully');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to change password: $e');
    }
  }

  void _showDeleteAccountDialog() {
    final formKey = GlobalKey<FormState>();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "This action cannot be undone. All your data will be permanently deleted.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: "Password",
                    hintText: "••••••••",
                    obscure: true,
                    controller: passwordCtrl,
                    validator: (value) => Validators.password(value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                await _deleteAccount(passwordCtrl.text);

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Delete Account"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(String password) async {
    if (password.isEmpty) {
      showSnackBar(context, 'Password is required');
      return;
    }

    try {
      await _authService.deleteUser(
        currentPassword: password,
        email: _currentUser!.email,
      );

      if (!mounted) return;
      showSnackBar(context, 'Account deleted successfully');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to delete account: $e');
    }
  }
}
