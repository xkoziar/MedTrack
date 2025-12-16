import 'package:nfc_manager/nfc_manager.dart';
import 'package:med_track/utils/nfc_tag_formatter.dart';

class NfcManagerService {
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  // Check if NFC is available on the device
  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  // Start NFC session and wait for tag to be scanned
  Future<void> scanNfcTag({
    required Function(String tagId, NfcTag nfcTag) onTagDiscovered,
    required Function() onError,
  }) async {
    final isAvailable = await isNfcAvailable();

    if (!isAvailable) {
      onError();
      return;
    }

    if (_isSessionActive) {
      return;
    }

    _isSessionActive = true;

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final identifier = NfcTagFormatter.extractTagId(tag);

          if (identifier != null) {
            await onTagDiscovered(identifier, tag);
          }

          await stopSession();
        },
        onError: (error) async {
          await stopSession();
          onError();
        },
      );
    } catch (e) {
      _isSessionActive = false;
      onError();
    }
  }

  // Start a persistent NFC session that doesnt auto-stop after each tag
  Future<void> startPersistentSession({
    required Function(String tagId, NfcTag nfcTag) onTagDiscovered,
  }) async {
    final isAvailable = await isNfcAvailable();

    if (!isAvailable || _isSessionActive) {
      return;
    }

    _isSessionActive = true;

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final identifier = NfcTagFormatter.extractTagId(tag);

          if (identifier != null) {
            await onTagDiscovered(identifier, tag);
          }
        },
        onError: (error) async {
          // Keep session alive on error
        },
      );
    } catch (e) {
      _isSessionActive = false;
    }
  }

  Future<void> stopSession({String? alertMessage}) async {
    if (_isSessionActive) {
      try {
        await NfcManager.instance.stopSession(
          alertMessage: alertMessage,
        );
      } catch (e) {
        // Ignore stop errors
      } finally {
        _isSessionActive = false;
      }
    }
  }
}
