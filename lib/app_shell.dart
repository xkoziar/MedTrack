import 'package:flutter/material.dart';
import 'package:med_track/pages/history_page.dart';
import 'package:med_track/pages/home_page.dart';
import 'package:med_track/pages/medication_page.dart';
import 'package:med_track/pages/profile_page.dart';

import 'package:med_track/pages/medication_details_page.dart';
import 'database/model/medication.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final Medication _mockMedication;

  @override
  void initState() {
    super.initState();

    //createMockData(); <--- uprav user id
  }

  List<Widget> get _pages => [
    HistoryPage(),
    ProfilePage(),
    MedicationPage(),
    const HomePage(),
    MedicationDetailPage(
      medication: _mockMedication,
      nfcTagId: '04:A2:7F:19:CC:2B:80',
      onPairNfc: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('TODO: Pair NFC')));
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: "Medication",
          ),
        ],
      ),
    );
  }
}
