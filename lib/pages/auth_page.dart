import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:med_track/database/service/auth_service.dart';

import '../database/components/custom_text_field.dart';
import '../database/ioc/ioc_container.dart';
import '../database/model/user.dart';
import '../database/service/user_database_service.dart';
import '../utils/validators.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _authService;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwdController = TextEditingController();
  final TextEditingController _confirmPasswdController =
      TextEditingController();
  static const double _fieldSpacing = 15.0;

  // true = login, false = register
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    _authService = get<AuthService>();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwdController.dispose();
    _confirmPasswdController.dispose();
    super.dispose();
  }

  Future<void> loginOrRegister() async {
    if (!_validateForm()) return;

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwdController.text.trim(),
        );
      } else {
        final credential = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwdController.text.trim(),
        );
        await _authService.updateUserName(_usernameController.text.trim());

        final userDbService = get<UserDatabaseService>();
        await userDbService.createUser(
          User(
            id: credential.user!.uid,
            email: _emailController.text.trim(),
            name: _usernameController.text.trim(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Email or password is incorrect.';
          break;
        case 'invalid-email':
          message = 'Email format is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again in a moment.';
          break;
        default:
          message = 'Authentication failed. Please try again.';
      }
      _showError(message);
    } catch (e) {
      _showError('Unexpected error. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                ),
                const SizedBox(height: _fieldSpacing),
              ],

              CustomTextField(
                label: "Email",
                hintText: 'your@email.com',
                controller: _emailController,
              ),
              const SizedBox(height: _fieldSpacing),

              CustomTextField(
                label: "Password",
                hintText: '••••••••',
                obscure: true,
                controller: _passwdController,
              ),
              const SizedBox(height: _fieldSpacing),

              if (!_isLogin) ...[
                CustomTextField(
                  label: "Confirm Password",
                  hintText: '••••••••',
                  obscure: true,
                  controller: _confirmPasswdController,
                ),
                const SizedBox(height: _fieldSpacing),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loginOrRegister,
                child: Text(_isLogin ? 'Login' : 'Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchButton(String text, bool isLoginButton) {
    bool isActive = (isLoginButton == _isLogin);

    return TextButton(
      onPressed: () {
        setState(() => _isLogin = isLoginButton);
      },
      style: TextButton.styleFrom(
        backgroundColor: isActive ? Colors.deepPurpleAccent : Colors.grey[400],
        foregroundColor: isActive ? Colors.white : Colors.black54,
      ),
      child: Text(text),
    );
  }

  bool _validateForm() {
    String? emailError = Validators.email(_emailController.text);
    String? passwordError = Validators.password(_passwdController.text);
    String? usernameError = !_isLogin
        ? Validators.username(_usernameController.text)
        : null;
    String? confirmError = !_isLogin
        ? Validators.confirmPassword(
            _passwdController.text,
            _confirmPasswdController.text,
          )
        : null;

    String? error =
        emailError ?? passwordError ?? usernameError ?? confirmError;

    if (error != null) {
      _showError(error);
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
