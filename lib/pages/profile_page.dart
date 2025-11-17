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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
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
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'Current Password',
                hintText: '••••••••',
                obscure: true,
                controller: currentPasswordController,
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'Current password is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'New Password',
                hintText: '••••••••',
                obscure: true,
                controller: newPasswordController,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Confirm New Password',
                hintText: '••••••••',
                obscure: true,
                controller: confirmPasswordController,
                validator: (value) =>
                    Validators.confirmPassword(newPasswordController.text, value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
                confirmPasswordController.text,
              );
              if (mounted) navigator.pop();
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    ).then((_) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final passwordError = Validators.password(newPassword);
    final confirmError =
        Validators.confirmPassword(newPassword, confirmPassword);

    if (currentPassword.isEmpty) {
      showSnackBar(context, 'Current password is required');
      return;
    }

    if (passwordError != null) {
      showSnackBar(context, passwordError);
      return;
    }

    if (confirmError != null) {
      showSnackBar(context, confirmError);
      return;
    }

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
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.danger),
            const SizedBox(width: AppSpacing.sm),
            const Text('Delete Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Please enter your password to confirm:'),
              const SizedBox(height: AppSpacing.md),
              CustomTextField(
                label: 'Password',
                hintText: '••••••••',
                obscure: true,
                controller: passwordController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Password is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text;
              Navigator.pop(context);
              _deleteAccount(password);
            },
            style: AppButtonStyles.dangerButton,
            child: const Text('Delete Account'),
          ),
        ],
      ),
    ).then((_) {
      passwordController.dispose();
    });
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
