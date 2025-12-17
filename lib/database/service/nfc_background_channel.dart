import 'package:flutter/services.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/nfc_dose_marker_service.dart';

/// Handles NFC tag scans that come from the native Android side
/// when the app is launched via NFC intent (background/closed state).
class NfcBackgroundChannel {
  static const MethodChannel _channel = MethodChannel('med_track/nfc_background');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static Future<void> _handleMethod(MethodCall call) async {
    if (call.method == 'onNfcTagScanned') {
      final tagId = call.arguments as String;
      await _processNfcTag(tagId);
    }
  }

  static Future<void> _processNfcTag(String tagId) async {
    try {
      final doseMarker = get<NfcDoseMarkerService>();
      final result = await doseMarker.markDosesForTag(tagId);
      
      if (result.isSuccess) {
        print('[NFC Background] Successfully marked ${result.medicationsMarked} doses for ${result.tagName}');
      } else {
        print('[NFC Background] Error: ${result.errorMessage}');
      }
    } catch (e) {
      print('[NFC Background] Unexpected error: $e');
    }
  }
}
