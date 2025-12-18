import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc/nfc_tag_database_service.dart';
import 'package:med_track/utils/nfc_tag_formatter.dart';

class NfcDoseMarkerService {
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _doseEventService = get<DoseEventDatabaseService>();
  final _authService = get<AuthService>();

  /// Process NFC tag scan and mark doses
  Future<DoseMarkResult> markDosesForTag(String tagId) async {
    final userId = _authService.user?.uid;
    if (userId == null) {
      return DoseMarkResult.error('User not authenticated');
    }

    try {
      // Find NFC tag
      final nfcTag = await _findTagWithFallback(userId, tagId);
      if (nfcTag == null) {
        return DoseMarkResult.error('NFC tag not found: $tagId');
      }

      // Get medications for this tag
      final medications = await _medicationService.getUserMedications(userId);
      final assignedMedications = medications
          .where((med) => med.nfcTagId == nfcTag.id)
          .toList();

      if (assignedMedications.isEmpty) {
        return DoseMarkResult.error('No medications assigned to tag "${nfcTag.name}"');
      }

      // Mark doses per medication
      int markedCount = 0;
      final now = DateTime.now();

      for (final medication in assignedMedications) {
        if (!medication.isActive) {
          // Skip inactive medications
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

  /// Find last scheduled dose before scan time
  DateTime? _findLastScheduledDoseBeforeScan(Medication medication, DateTime scanTime) {
    final currentWeekday = scanTime.weekday;
    if (!medication.scheduleDays.contains(currentWeekday)) {
      return null;
    }

    if (scanTime.isBefore(medication.startDate)) {
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

      if (scheduledTime.isBefore(scanTime)) {
        dosesBeforeScan.add(scheduledTime);
      }
    }

    if (dosesBeforeScan.isEmpty) {
      return null;
    }

  dosesBeforeScan.sort();
  final selectedDose = dosesBeforeScan.last;

  return selectedDose;
  }
}

/// Result of marking doses for NFC tag
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
