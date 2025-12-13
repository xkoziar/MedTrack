// import 'model/medication.dart';
// import 'service/medication_database_service.dart';
//
// class DevDataHelper {
//   static Future<void> createSampleMedications(
//     MedicationDatabaseService service,
//     String userId,
//   ) async {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//
//     final sampleMeds = [
//       Medication(
//         id: '${userId}_med1',
//         userId: userId,
//         name: 'Aspirin',
//         description: 'Pain relief',
//         dosage: '100mg',
//         scheduleTimes: [
//           today.add(const Duration(hours: 8)),
//           today.add(const Duration(hours: 20)),
//         ],
//         scheduleDays: [1, 2, 3, 4, 5, 6, 7],
//       ),
//       Medication(
//         id: '${userId}_med2',
//         userId: userId,
//         name: 'Vitamin D',
//         description: 'Daily supplement',
//         dosage: '1000 IU',
//         scheduleTimes: [
//           today.add(const Duration(hours: 9)),
//         ],
//         scheduleDays: [1, 2, 3, 4, 5, 6, 7],
//       ),
//       Medication(
//         id: '${userId}_med3',
//         userId: userId,
//         name: 'Ibuprofen',
//         description: 'Anti-inflammatory',
//         dosage: '200mg',
//         scheduleTimes: [
//           today.add(const Duration(hours: 12)),
//           today.add(const Duration(hours: 18)),
//         ],
//         scheduleDays: [1, 2, 3, 4, 5],
//       ),
//     ];
//
//     for (final med in sampleMeds) {
//       await service.create(med.id, med);
//     }
//   }
// }
