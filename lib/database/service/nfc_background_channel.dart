import 'package:flutter/services.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';

class NfcBackgroundChannel {
  static const MethodChannel _channel = MethodChannel('med_track/nfc_background');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static Future<void> _handleMethod(MethodCall call) async {
    if (call.method == 'onNfcTagScanned') {
      final tagId = call.arguments as String;
      await processNfcTag(tagId);
    }
  }

  static Future<void> processNfcTag(String tagId) async {
    final authService = get<AuthService>();
    final nfcTagService = get<NfcTagDatabaseService>();
    final medicationService = get<MedicationDatabaseService>();
    final doseEventService = get<DoseEventDatabaseService>();

    final userId = authService.user?.uid;
    if (userId == null) {
      return;
    }

    try {
      final nfcTag = await nfcTagService.findByTagId(userId, tagId);

      if (nfcTag == null) {
        return;
      }

      final medications = await medicationService.getUserMedications(userId);
      final assignedMedications = medications
          .where((med) => med.nfcTagId == nfcTag.id)
          .toList();

      if (assignedMedications.isEmpty) {
        return;
      }

      int markedCount = 0;
      final now = DateTime.now();

      for (final medication in assignedMedications) {
        if (!medication.isActive) continue;

        final doseToMark = _findLastScheduledDoseBeforeScan(medication, now);

        if (doseToMark != null) {
          await doseEventService.recordDose(
            userId: userId,
            medicationId: medication.id,
            scheduledAt: doseToMark,
            taken: true,
          );
          markedCount++;
        }
      }
    } catch (e) {
      // Silent failure
    }
  }

  static DateTime? _findLastScheduledDoseBeforeScan(medication, DateTime scanTime) {
    final currentWeekday = scanTime.weekday;

    if (!medication.scheduleDays.contains(currentWeekday)) return null;
    if (medication.endDate != null && scanTime.isAfter(medication.endDate!)) return null;
    if (scanTime.isBefore(medication.startDate)) return null;

    final today = DateTime(scanTime.year, scanTime.month, scanTime.day);
    final dosesBeforeScan = <DateTime>[];

    for (final timeStr in medication.scheduleTimes) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final scheduledTime = DateTime(today.year, today.month, today.day, hour, minute);

      if (scheduledTime.isBefore(scanTime)) {
        dosesBeforeScan.add(scheduledTime);
      }
    }

    if (dosesBeforeScan.isEmpty) return null;

    dosesBeforeScan.sort();
    return dosesBeforeScan.last;
  }
}
