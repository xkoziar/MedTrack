import 'package:flutter/material.dart';
import 'package:med_track/pages/history_page.dart';
import 'package:med_track/pages/home_page.dart';
import 'package:med_track/pages/medication_page.dart';
import 'package:med_track/pages/profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 3;

  @override
  void initState() {
    super.initState();
    //createMockData(); <--- uprav user id
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HistoryPage(),
          ProfilePage(key: const ValueKey('profile_page')),
          MedicationPage(key: const ValueKey('medication_page')),
          const HomePage(key: ValueKey('home_page')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),

        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: "History",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_rounded),
            label: "MedList",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        ],
      ),
    );
  }
}
