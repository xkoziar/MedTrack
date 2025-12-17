import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';
import 'package:med_track/utils/nfc_tag_formatter.dart';

class NfcDoseMarkerService {
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _doseEventService = get<DoseEventDatabaseService>();
  final _authService = get<AuthService>();

  /// Process NFC tag scan and mark the appropriate doses.
  /// Returns a result containing success info or error message.
  Future<DoseMarkResult> markDosesForTag(String tagId) async {
    final userId = _authService.user?.uid;
    if (userId == null) {
      return DoseMarkResult.error('User not authenticated');
    }

    try {
      // Find the NFC tag (try with and without colons)
      final nfcTag = await _findTagWithFallback(userId, tagId);
      if (nfcTag == null) {
        return DoseMarkResult.error('NFC tag not found: $tagId');
      }

      // Get medications assigned to this tag
      final medications = await _medicationService.getUserMedications(userId);
      final assignedMedications = medications
          .where((med) => med.nfcTagId == nfcTag.id)
          .toList();

      if (assignedMedications.isEmpty) {
        return DoseMarkResult.error('No medications assigned to tag "${nfcTag.name}"');
      }

      // Mark doses for each medication
      int markedCount = 0;
      final now = DateTime.now();

      for (final medication in assignedMedications) {
        if (!medication.isActive) {
          print('[NFC] Skipping inactive medication: ${medication.name}');
          continue;
        }

        final doseToMark = _findLastScheduledDoseBeforeScan(medication, now);

        if (doseToMark != null) {
          try {
            await _doseEventService.recordDose(
              userId: userId,
              medicationId: medication.id,
              scheduledAt: doseToMark,
              taken: true,
            );
            markedCount++;
          } catch (e) {
            continue;
          }
        } else {
          print('[NFC]   No dose found to mark');
        }
      }

      if (markedCount > 0) {
        return DoseMarkResult.success(
          tagName: nfcTag.name,
          medicationsMarked: markedCount,
        );
      } else {
        return DoseMarkResult.error('No doses found to mark for tag "${nfcTag.name}"');
      }
    } catch (e) {
      return DoseMarkResult.error('Error processing NFC tag: $e');
    }
  }

  /// Find NFC tag, trying both with and without colons in the ID
  Future<dynamic> _findTagWithFallback(String userId, String tagId) async {
    var tag = await _nfcTagService.findByTagId(userId, tagId);

    if (tag == null && tagId.contains(':')) {
      final normalizedId = NfcTagFormatter.normalizeTagId(tagId);
      tag = await _nfcTagService.findByTagId(userId, normalizedId);
    }

    if (tag == null && !tagId.contains(':')) {
      final formattedId = tagId.toUpperCase().split('').map((char) {
        return char;
      }).join(':').replaceAll(':::', ':').replaceAll('::', ':');
      tag = await _nfcTagService.findByTagId(userId, formattedId);
    }

    return tag;
  }

  /// Find the last scheduled dose before the scan time for a medication
  DateTime? _findLastScheduledDoseBeforeScan(Medication medication, DateTime scanTime) {
    final currentWeekday = scanTime.weekday;
    if (!medication.scheduleDays.contains(currentWeekday)) {
      print('[NFC]   Not scheduled for today');
      return null;
    }

    if (medication.endDate != null && scanTime.isAfter(medication.endDate!)) {
      print('[NFC]   Past end date');
      return null;
    }

    if (scanTime.isBefore(medication.startDate)) {
      print('[NFC]   Before start date');
      return null;
    }

    final today = DateTime(scanTime.year, scanTime.month, scanTime.day);
    final dosesBeforeScan = <DateTime>[];

    for (final timeStr in medication.scheduleTimes) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final scheduledTime = DateTime(
        today.year,
        today.month,
        today.day,
        hour,
        minute,
      );

      print('[NFC]   Checking time $timeStr -> $scheduledTime');
      print('[NFC]   Is before scan ($scanTime)? ${scheduledTime.isBefore(scanTime)}');

      if (scheduledTime.isBefore(scanTime)) {
        dosesBeforeScan.add(scheduledTime);
        print('[NFC]   Added to doses before scan');
      }
    }

    print('[NFC]   Total doses before scan: ${dosesBeforeScan.length}');

    if (dosesBeforeScan.isEmpty) {
      return null;
    }

    dosesBeforeScan.sort();
    final selectedDose = dosesBeforeScan.last;
    print('[NFC]   Selected dose: $selectedDose');

    return selectedDose;
  }
}

/// Result of attempting to mark doses for an NFC tag
class DoseMarkResult {
  final bool isSuccess;
  final String? tagName;
  final int? medicationsMarked;
  final String? errorMessage;

  DoseMarkResult._({
    required this.isSuccess,
    this.tagName,
    this.medicationsMarked,
    this.errorMessage,
  });

  factory DoseMarkResult.success({
    required String tagName,
    required int medicationsMarked,
  }) {
    return DoseMarkResult._(
      isSuccess: true,
      tagName: tagName,
      medicationsMarked: medicationsMarked,
    );
  }

  factory DoseMarkResult.error(String message) {
    return DoseMarkResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
