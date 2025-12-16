import 'dart:async';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc_manager_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';
import 'package:med_track/utils/nfc_tag_formatter.dart';
import 'package:nfc_manager/nfc_manager.dart' as nfc_manager;

class NfcBackgroundService {
  final _nfcManager = get<NfcManagerService>();
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _doseEventService = get<DoseEventDatabaseService>();
  final _authService = get<AuthService>();

  StreamSubscription? _nfcSubscription;
  bool _isListening = false;
  bool _ignoreScans = false;
  Future<void> Function(nfc_manager.NfcTag nfcTag)? _manualScanCallback;

  static const int timeWindowMinutes = 30;

  bool get isListening => _isListening;

  void setManualScanCallback(Future<void> Function(nfc_manager.NfcTag nfcTag) callback) {
    _manualScanCallback = callback;
  }

  void clearManualScanCallback() {
    _manualScanCallback = null;
  }

  Future<void> startIgnoringScans() async {
    _ignoreScans = true;
  }

  void stopIgnoringScans() {
    _ignoreScans = false;
  }

  Future<dynamic> _findTagWithFallback(String userId, String tagId) async {
    var tag = await _nfcTagService.findByTagId(userId, tagId);

    if (tag == null && tagId.contains(':')) {
      final normalizedId = NfcTagFormatter.normalizeTagId(tagId);
      tag = await _nfcTagService.findByTagId(userId, normalizedId);
    }

    return tag;
  }

  // Start listening for NFC tags in the background
  Future<void> startListening({
    required Function(String tagName, int medicationsMarked) onDoseMarked,
    required Function(String error) onError,
  }) async {
    if (_isListening) return;

    final isAvailable = await _nfcManager.isNfcAvailable();
    if (!isAvailable) return;

    _isListening = true;
    _startContinuousNfcSession(onDoseMarked, onError);
  }

  Future<void> _startContinuousNfcSession(
    Function(String tagName, int medicationsMarked) onDoseMarked,
    Function(String error) onError,
  ) async {
    await _nfcManager.startPersistentSession(
      onTagDiscovered: (tagId, nfcTag) async {
        if (_manualScanCallback != null) {
          await _manualScanCallback!(nfcTag);
          return;
        }

        if (_ignoreScans) return;

        await _handleNfcTagScanned(
          tagId,
          onDoseMarked: onDoseMarked,
          onError: onError,
        );
      },
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    _ignoreScans = true;

    await _nfcSubscription?.cancel();
    _nfcSubscription = null;
    await _nfcManager.stopSession();
  }

  // Handle NFC tag scan
  Future<void> _handleNfcTagScanned(
    String tagId, {
    required Function(String tagName, int medicationsMarked) onDoseMarked,
    required Function(String error) onError,
  }) async {
    if (_ignoreScans) return;

    final userId = _authService.user?.uid;
    if (userId == null) {
      onError('User not authenticated');
      return;
    }

    final nfcTag = await _findTagWithFallback(userId, tagId);

    if (nfcTag == null) {
      onError('Unknown NFC tag. Please assign it to a medication first.');
      return;
    }

    final medications = await _medicationService.getUserMedications(userId);

    final assignedMedications = medications
        .where((med) => med.nfcTagId == nfcTag!.id)
        .toList();

    if (assignedMedications.isEmpty) {
      onError('No medications assigned to tag "${nfcTag.name}"');
      return;
    }

    int markedCount = 0;
    final now = DateTime.now();

    print('[NFC] Processing ${assignedMedications.length} medications for tag "${nfcTag.name}"');

    for (final medication in assignedMedications) {
      print('[NFC] Checking medication: ${medication.name}');
      print('[NFC]   Active: ${medication.isActive}');
      print('[NFC]   Schedule days: ${medication.scheduleDays}');
      print('[NFC]   Schedule times: ${medication.scheduleTimes}');
      print('[NFC]   Current time: $now');
      print('[NFC]   Current weekday: ${now.weekday}');

      if (!medication.isActive) {
        print('[NFC]   Skipping (not active)');
        continue;
      }

      final doseToMark = _findLastScheduledDoseBeforeScan(medication, now);
      print('[NFC]   Dose to mark: $doseToMark');

      if (doseToMark != null) {
        try {
          await _doseEventService.recordDose(
            userId: userId,
            medicationId: medication.id,
            scheduledAt: doseToMark,
            taken: true,
          );
          markedCount++;
          print('[NFC]   ✓ Marked dose successfully');
        } catch (e) {
          print('[NFC]   ✗ Error marking dose: $e');
          continue;
        }
      } else {
        print('[NFC]   No dose found to mark');
      }
    }

    if (markedCount > 0) {
      onDoseMarked(nfcTag.name, markedCount);
    } else {
      onError('No doses found to mark for tag "${nfcTag.name}"');
    }
  }

  DateTime? _findLastScheduledDoseBeforeScan(Medication medication, DateTime scanTime) {
    final currentWeekday = scanTime.weekday;

    print('[NFC] _findLastScheduledDoseBeforeScan for ${medication.name}');
    print('[NFC]   Current weekday: $currentWeekday');
    print('[NFC]   Schedule days: ${medication.scheduleDays}');
    print('[NFC]   Contains weekday: ${medication.scheduleDays.contains(currentWeekday)}');

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

    print('[NFC]   Schedule times: ${medication.scheduleTimes}');

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
    return dosesBeforeScan.last;
  }

  // One-time scan to mark doses as taken
  Future<void> scanAndMarkDose({
    required Function(String tagName, int medicationsMarked) onSuccess,
    required Function(String error) onError,
  }) async {
    final isAvailable = await _nfcManager.isNfcAvailable();
    if (!isAvailable) {
      onError('NFC is not available on this device');
      return;
    }

    await _nfcManager.scanNfcTag(
      onTagDiscovered: (tagId, nfcTag) async {
        await _handleNfcTagScanned(
          tagId,
          onDoseMarked: onSuccess,
          onError: onError,
        );
      },
      onError: () {
        onError('Error scanning NFC tag');
      },
    );
  }
}
