// AppShell
//
//
//
// import 'package:flutter/material.dart';
// import 'package:med_track/pages/home_page.dart';
// import 'package:med_track/pages/profile_page.dart';
//
// import 'package:med_track/pages/medication_details_page.dart';
//
// import 'database/model/dose_event.dart';
// import 'database/model/medication.dart';
//
//
// class AppShell extends StatefulWidget {
//   const AppShell({super.key});
//
//   @override
//   State<AppShell> createState() => _AppShellState();
// }
//
// class _AppShellState extends State<AppShell> {
//   int _index = 0;
//
//   late final Medication _mockMedication;
//   late final List<DoseEvent> _mockEvents;
//
//   @override
//   void initState() {
//     super.initState();
//
//     final now = DateTime.now();
//
//     _mockMedication = Medication(
//       id: 'med_test_1',
//       userId: 'user_test_1',
//       name: 'Ibuprofen',
//       description: 'After meals. Don’t combine with alcohol.',
//       dosage: '200 mg',
//       startDate: now.subtract(const Duration(days: 10)),
//       endDate: null,
//       isActive: false,
//       scheduleDays: const [1, 2, 3, 4, 5, 6, 7],
//       scheduleTimes: const ['08:00', '20:00'],
//       createdAt: now.subtract(const Duration(days: 10)),
//       updatedAt: now,
//     );
//
//     _mockEvents = [
//       DoseEvent(
//         id: 'e1',
//         userId: 'user_test_1',
//         medicationId: 'med_test_1',
//         scheduledAt: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2, hours: -8)),
//         takenAt: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2, hours: -8, minutes: -6)),
//         status: DoseStatus.taken,
//         createdAt: now.subtract(const Duration(days: 2)),
//       ),
//       DoseEvent(
//         id: 'e2',
//         userId: 'user_test_1',
//         medicationId: 'med_test_1',
//         scheduledAt: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1, hours: -20)),
//         takenAt: null,
//         status: DoseStatus.missed,
//         createdAt: now.subtract(const Duration(days: 1)),
//       ),
//       DoseEvent(
//         id: 'e3',
//         userId: 'user_test_1',
//         medicationId: 'med_test_1',
//         scheduledAt: DateTime(now.year, now.month, now.day, 8, 0),
//         takenAt: DateTime(now.year, now.month, now.day, 8, 7),
//         status: DoseStatus.taken,
//         createdAt: now,
//       ),
//       DoseEvent(
//         id: 'e4',
//         userId: 'user_test_1',
//         medicationId: 'med_test_1',
//         scheduledAt: DateTime(now.year, now.month, now.day, 20, 0),
//         takenAt: null,
//         status: DoseStatus.pending,
//         createdAt: now,
//       ),
//     ];
//   }
//
//   List<Widget> get _pages => [
//     const HomePage(),
//     ProfilePage(),
//     MedicationDetailPage(
//       medication: _mockMedication,
//       recentEvents: _mockEvents,
//       nfcTagId: '04:A2:7F:19:CC:2B:80', // optional test value
//       onEdit: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('TODO: Edit medication')),
//         );
//       },
//       onDelete: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('TODO: Delete medication')),
//         );
//       },
//       onPairNfc: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('TODO: Pair NFC')),
//         );
//       },
//     ),
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _pages[_index],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _index,
//         onTap: (i) => setState(() => _index = i),
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: "Home",
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.person),
//             label: "Profile",
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.medication),
//             label: "Medication",
//           ),
//         ],
//       ),
//     );
//   }
// }
