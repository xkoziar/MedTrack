import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcTagFormatter {
  static String formatTagId(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(':');
  }

  static String? extractTagId(NfcTag tag) {
    final nfcA = NfcA.from(tag);
    if (nfcA != null) {
      return formatTagId(nfcA.identifier);
    }

    final nfcB = NfcB.from(tag);
    if (nfcB != null) {
      return formatTagId(nfcB.identifier);
    }

    final nfcF = NfcF.from(tag);
    if (nfcF != null) {
      return formatTagId(nfcF.identifier);
    }

    final nfcV = NfcV.from(tag);
    if (nfcV != null) {
      return formatTagId(nfcV.identifier);
    }

    final miFare = MiFare.from(tag);
    if (miFare != null) {
      return formatTagId(miFare.identifier);
    }

    final feliCa = FeliCa.from(tag);
    if (feliCa != null) {
      return formatTagId(feliCa.currentIDm);
    }

    return null;
  }

  static String normalizeTagId(String tagId) {
    return tagId.replaceAll(':', '').toLowerCase();
  }
}
