import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/pages/auth_page.dart';
import 'package:med_track/pages/add_medication_page.dart';
import 'package:med_track/utils/constants.dart';

import 'app_shell.dart';

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = get<AuthService>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {'/add-medication': (context) => const AddMedicationPage()},
      home: StreamBuilder(
        stream: authService.currentUserStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            // Use a key to force rebuild when user changes
            return AppShell(key: ValueKey(snapshot.data?.id));
          }

          return const AuthPage();
        },
      ),
      theme: ThemeData(
        textTheme: TextTheme(
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: AppTextStyles.bodyMediumSemiBold,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: AppTextStyles.bodyMediumSemiBold,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: AppTextStyles.bodyMediumSemiBold,
          ),
        ),
      ),
    );
  }
}
