import 'package:flutter/material.dart';
import 'package:med_track/database/model/user.dart';
import 'package:med_track/database/service/user_database_service.dart';

import '../database/ioc/ioc_container.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final UserDatabaseService _userService = get<UserDatabaseService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movies Rating')),
      body: Center(
        child: TextButton(
          onPressed: () {
            _userService.addUser(
              User(id: '0', name: 'John Doe', email: 'email@google.com'),
            );
          },
          child: const Text('Add User'),
        ),
      ),
    );
  }
}
