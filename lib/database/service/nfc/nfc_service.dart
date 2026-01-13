import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc/nfc_tag_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/nfc_tag_formatter.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  bool _isSessionActive = false;
  bool _isPaused = false;

  Future<bool> isNfcAvailable() async {
    if (kIsWeb) {
      return false;
    }
    return await NfcManager.instance.isAvailable();
  }

  void pauseScanning() => _isPaused = true;
  void resumeScanning() => _isPaused = false;

  Future<void> startListening({
    required void Function(String tagName, int count) onDoseMarked,
    required void Function(String error) onError,
  }) async {
    if (kIsWeb) {
      onError('NFC is not available on web. Please use the mobile app.');
      return;
    }

    if (_isSessionActive || !await isNfcAvailable()) return;

    _isSessionActive = true;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        final tagId = NfcTagFormatter.extractTagId(tag);
        if (_isPaused || tagId == null) return;

        final result = await markDosesForTag(tagId);
        if (result.success) {
          onDoseMarked(result.tagName!, result.count!);
        } else {
          onError(result.error!);
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (kIsWeb) return;
    if (!_isSessionActive) return;
    await NfcManager.instance.stopSession();
    _isSessionActive = false;
  }

  Future<void> scanTag({
    required void Function(NfcTag tag) onTagDiscovered,
    required void Function() onError,
  }) async {
    if (kIsWeb) {
      onError();
      return;
    }

    if (_isSessionActive) await stopListening();

    _isSessionActive = true;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        await stopListening();
        onTagDiscovered(tag);
      },
      onError: (_) async {
        await stopListening();
        onError();
      },
    );
  }

  Future<void> scanAndWriteTag({
    required void Function(NfcTag tag, String tagId) onSuccess,
    required void Function(String error) onError,
  }) async {
    if (kIsWeb) {
      onError('NFC is not available on web. Please use the mobile app.');
      return;
    }

    if (_isSessionActive) await stopListening();

    _isSessionActive = true;
    bool hasProcessedTag = false;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        if (hasProcessedTag) return;
        hasProcessedTag = true;

        final tagId = NfcTagFormatter.extractTagId(tag);
        if (tagId == null) {
          await stopListening();
          onError('Could not read tag ID');
          return;
        }

        final writeSuccess = await writeAppLaunchRecord(tag, tagId);
        if (!writeSuccess) {
          await stopListening();
          onError('Failed to write to tag. Make sure tag is writable and try again.');
          return;
        }

        onSuccess(tag, tagId);
      },
      onError: (error) async {
        await stopListening();
        onError('Error scanning tag');
      },
    );
  }

  Future<bool> writeAppLaunchRecord(NfcTag tag, String tagId) async {
    try {
      final ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) return false;

      final textRecord = NdefRecord(
        typeNameFormat: NdefTypeNameFormat.nfcWellknown,
        type: Uint8List.fromList('T'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList('en$tagId'.codeUnits),
      );

      final aarRecord = NdefRecord(
        typeNameFormat: NdefTypeNameFormat.nfcExternal,
        type: Uint8List.fromList('android.com:pkg'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(MedicationConstants.nfcPackageName.codeUnits),
      );

      final message = NdefMessage([textRecord, aarRecord]);
      if (message.byteLength > ndef.maxSize) return false;

      await ndef.write(message);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DoseResult> markDosesForTag(String tagId) async {
    final auth = get<AuthService>();
    final userId = auth.user?.uid;
    if (userId == null) return DoseResult.failure('User not authenticated');

    try {
      final tagService = get<NfcTagDatabaseService>();
      final normalizedId = NfcTagFormatter.normalizeTagId(tagId);
      var tag = await tagService.findByTagId(userId, tagId);
      tag ??= await tagService.findByTagId(userId, normalizedId);

      if (tag == null) return DoseResult.failure('Unknown tag');

      final medService = get<MedicationDatabaseService>();
      final medications = await medService.getUserMedications(userId);
      final assigned = medications.where((m) => m.nfcTagIds.contains(tag!.id)).toList();

      if (assigned.isEmpty) {
        return DoseResult.failure('No medications on tag "${tag.name}"');
      }

      final doseService = get<DoseEventDatabaseService>();
      final now = DateTime.now();
      int marked = 0;

      for (final med in assigned.where((m) => m.isActive)) {
        final doseTime = _findDoseToMark(med, now);
        if (doseTime != null) {
          await doseService.recordDose(
            userId: userId,
            medicationId: med.id,
            scheduledAt: doseTime,
            taken: true,
          );
          marked++;
        }
      }

      if (marked > 0) {
        return DoseResult.success(tag.name, marked);
      }
      return DoseResult.failure('No doses to mark right now');
    } catch (e) {
      return DoseResult.failure('Error: $e');
    }
  }

  DateTime? _findDoseToMark(Medication med, DateTime now) {
    if (!med.scheduleDays.contains(now.weekday)) return null;
    if (now.isBefore(med.startDate)) return null;

    final today = DateTime(now.year, now.month, now.day);
    DateTime? latestDose;

    for (final timeStr in med.scheduleTimes) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final doseTime = DateTime(today.year, today.month, today.day, hour, minute);

      if (doseTime.isBefore(now)) {
        if (latestDose == null || doseTime.isAfter(latestDose)) {
          latestDose = doseTime;
        }
      }
    }

    return latestDose;
  }
}

class DoseResult {
  final bool success;
  final String? tagName;
  final int? count;
  final String? error;

  DoseResult._({required this.success, this.tagName, this.count, this.error});

  factory DoseResult.success(String tagName, int count) =>
      DoseResult._(success: true, tagName: tagName, count: count);

  factory DoseResult.failure(String error) =>
      DoseResult._(success: false, error: error);
}
