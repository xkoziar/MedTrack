import 'package:flutter/services.dart';
import 'package:med_track/app_shell.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/nfc/nfc_service.dart';

class NfcBackgroundChannel {
  static const MethodChannel _channel = MethodChannel('med_track/nfc_background');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static Future<void> _handleMethod(MethodCall call) async {
    if (call.method == 'onNfcTagScanned') {
      final tagId = call.arguments as String;
      await _processNfcTag(tagId);

      final state = appShellKey.currentState;
      if (state != null && state.mounted) {
        (state as dynamic).navigateToHome();
      }
    }
  }

  static Future<void> _processNfcTag(String tagId) async {
    try {
      final nfcService = get<NfcService>();
      await nfcService.markDosesForTag(tagId);
    } catch (_) {}
  }
}

