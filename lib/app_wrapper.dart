import 'package:flutter/material.dart';
import 'package:med_track/pages/auth_page.dart';

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthPage(),
      theme: ThemeData(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
