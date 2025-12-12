import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:med_track/database/service/auth_service.dart';

import '../components/custom_text_field.dart';
import '../database/ioc/ioc_container.dart';
import '../database/model/app_user.dart';
import '../database/service/user_database_service.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../utils/snackbar_utils.dart';

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
          credential.user!.uid,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.medical_services, size: 60),
                const SizedBox(height: 12),

                const Text(
                  'MedTrack',
                  style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Take your meds ahh app',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSwitchButton("Login", true),
                    const SizedBox(width: 8),
                    _buildSwitchButton("Register", false),
                  ],
                ),

                const SizedBox(height: 25),

                if (!_isLogin) ...[
                  CustomTextField(
                    label: "Username",
                    hintText: 'Your name',
                    controller: _usernameController,
                    validator: (value) {
                      return Validators.username(value?.trim());
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                CustomTextField(
                  label: "Email",
                  hintText: 'your@email.com',
                  controller: _emailController,
                  validator: (value) => _isLogin
                      ? Validators.loginEmail(value)
                      : Validators.email(value?.trim()),
                ),
                const SizedBox(height: AppSpacing.lg),

                CustomTextField(
                  label: "Password",
                  hintText: '••••••••',
                  obscure: true,
                  controller: _passwdController,
                  validator: (value) => _isLogin
                      ? Validators.loginPassword(value)
                      : Validators.password(value),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (!_isLogin) ...[
                  CustomTextField(
                    label: "Confirm Password",
                    hintText: '••••••••',
                    obscure: true,
                    controller: _confirmPasswdController,
                    validator: (value) {
                      return Validators.confirmPassword(
                        _passwdController.text,
                        value,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Login' : 'Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchButton(String text, bool isLoginButton) {
    final bool isActive = (isLoginButton == _isLogin);

    return TextButton(
      onPressed: () {
        if (_isLogin == isLoginButton) return;

        setState(() {
          _isLogin = isLoginButton;

          _formKey.currentState?.reset();
          _passwdController.clear();
          _confirmPasswdController.clear();
          if (_isLogin) {
            _usernameController.clear();
          }
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: isActive ? Colors.deepPurpleAccent : Colors.grey[400],
        foregroundColor: isActive ? Colors.white : Colors.black54,
      ),
      child: Text(text),
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
