import 'dart:async';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/nfc_dose_marker_service.dart';
import 'package:med_track/database/service/nfc_manager_service.dart';
import 'package:nfc_manager/nfc_manager.dart' as nfc_manager;


class NfcBackgroundService {
  final _nfcManager = get<NfcManagerService>();
  final _doseMarker = get<NfcDoseMarkerService>();

  StreamSubscription? _nfcSubscription;
  bool _isListening = false;
  bool _ignoreScans = false;
  Future<void> Function(nfc_manager.NfcTag nfcTag)? _manualScanCallback;

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

  /// Start listening for NFC tags continuously in the foreground
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

  /// Handle NFC tag scan by delegating to the dose marker service
  Future<void> _handleNfcTagScanned(
    String tagId, {
    required Function(String tagName, int medicationsMarked) onDoseMarked,
    required Function(String error) onError,
  }) async {
    if (_ignoreScans) return;

    final result = await _doseMarker.markDosesForTag(tagId);

    if (result.isSuccess) {
      onDoseMarked(result.tagName!, result.medicationsMarked!);
    } else {
      onError(result.errorMessage!);
    }
  }

  /// One-time scan to mark doses as taken
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
