import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';

import '../database/service/auth_service.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = get<AuthService>();

    return Center(
      child: ElevatedButton(onPressed: authService.signOut, child: const Text("Logout")),
    );
  }
}
