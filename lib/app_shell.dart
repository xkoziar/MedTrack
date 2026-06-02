import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_service.dart';
import 'package:med_track/database/service/notification_service.dart';
import 'package:med_track/pages/history_page.dart';
import 'package:med_track/pages/home_page.dart';
import 'package:med_track/pages/med_button_page.dart';
import 'package:med_track/pages/medication_page.dart';
import 'package:med_track/pages/profile_page.dart';

final GlobalKey<State<AppShell>> appShellKey = GlobalKey<State<AppShell>>();

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 4;

  void navigateToHome() {
    if (mounted) {
      setState(() => _index = 0);
    }
  }

  void navigateToMedications() {
    if (mounted) {
      setState(() => _index = 2);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationWindow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkNotificationWindow();
      get<DoseBuddyService>().handleAppResumed();
    }
  }

  Future<void> _checkNotificationWindow() async {
    await Future.delayed(const Duration(milliseconds: 500));
    NotificationService.checkAndExtendWindow();
  }

  @override
  Widget build(BuildContext context) {
    final bottomBar = BottomNavigationBar(
      currentIndex: _index,
      onTap: (i) => setState(() => _index = i),

      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: "History",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_rounded),
          label: "MedList",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medication_rounded),
          label: "DoseBuddy",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(key: ValueKey('home_page')),
          HistoryPage(),
          MedicationPage(key: const ValueKey('medication_page')),
          const MedButtonPage(key: ValueKey('med_button_page')),
          ProfilePage(key: const ValueKey('profile_page')),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: medButtonTutorialOverlayActive,
        builder: (context, tutorialActive, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: tutorialActive ? const SizedBox.shrink() : child,
          );
        },
        child: bottomBar,
      ),
    );
  }
}
