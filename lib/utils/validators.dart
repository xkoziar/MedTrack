class Validators {
  static String? email(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty) return 'Email is required';
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    return null;
  }

  static String? password(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? username(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length > 50) return 'Username cannot be longer than 50 characters';
    return null;
  }

  static String? confirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) return 'Please confirm your password';
    if (password != confirmPassword) return 'Passwords do not match';
    return null;
  }
}
