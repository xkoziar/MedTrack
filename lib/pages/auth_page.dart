import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:med_track/database/service/auth_service.dart';

import 'package:med_track/components/common/custom_text_field.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/validators.dart';
import 'package:med_track/utils/snackbar_utils.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _authService;
  late final UserDatabaseService _userDbService;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwdController = TextEditingController();
  final TextEditingController _confirmPasswdController =
      TextEditingController();

  // true = login, false = register
  bool _isLogin = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _authService = get<AuthService>();
    _userDbService = get<UserDatabaseService>();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwdController.dispose();
    _confirmPasswdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim();
    final password = _passwdController.text.trim();
    final username = _usernameController.text.trim();

    try {
      if (_isLogin) {
        await _authService.signIn(email: email, password: password);
      } else {
        final credential = await _authService.signUp(
          email: email,
          password: password,
        );

        await _authService.updateUserName(username);

        await _userDbService.create(
          AppUser(id: credential.user!.uid, email: email, name: username),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSnackBar(context, _mapAuthError(e));
    } catch (_) {
      if (!mounted) return;
      showSnackBar(context, 'Unexpected error, try again');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _switchMode(bool toLogin) {
    if (_isLogin == toLogin) return;
    setState(() {
      _isLogin = toLogin;
      _formKey.currentState?.reset();
      _passwdController.clear();
      _confirmPasswdController.clear();
      if (_isLogin) {
        _usernameController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.purple),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _branding(),
                    const SizedBox(height: AppSpacing.xxl),
                    _formCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _branding() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.medication_rounded,
            size: 46,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'MedTrack',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Never miss a dose',
          style: TextStyle(
            fontSize: AppTextSizes.bodyMedium,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _modeSwitch(),
            const SizedBox(height: AppSpacing.xl),
            if (!_isLogin) ...[
              CustomTextField(
                label: 'Username',
                hintText: 'Your name',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                controller: _usernameController,
                validator: (value) => Validators.username(value?.trim()),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            CustomTextField(
              label: 'Email',
              hintText: 'your@email.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              controller: _emailController,
              validator: (value) => _isLogin
                  ? Validators.loginEmail(value)
                  : Validators.email(value?.trim()),
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomTextField(
              label: 'Password',
              hintText: 'Your password',
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction:
                  _isLogin ? TextInputAction.done : TextInputAction.next,
              controller: _passwdController,
              validator: (value) => _isLogin
                  ? Validators.loginPassword(value)
                  : Validators.password(value),
            ),
            if (!_isLogin) ...[
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                label: 'Confirm password',
                hintText: 'Repeat your password',
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                controller: _confirmPasswdController,
                validator: (value) => Validators.confirmPassword(
                  _passwdController.text,
                  value,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segment('Login', true),
          _segment('Register', false),
        ],
      ),
    );
  }

  Widget _segment(String text, bool isLoginSegment) {
    final isActive = isLoginSegment == _isLogin;

    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(isLoginSegment),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: isActive ? AppGradients.purple : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppTextStyles.bodyMediumSemiBold.copyWith(
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.purple,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin ? 'Login' : 'Create account',
                style: AppTextStyles.bodyMediumSemiBold.copyWith(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Email format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
