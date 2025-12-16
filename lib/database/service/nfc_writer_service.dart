import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';

class NfcWriterService {
  // Package name for Android Application Record
  static const String packageName = 'pv292.fi.muni.cz.med_track';

  Future<bool> writeAppLaunchRecordToTag(NfcTag tag, String tagId) async {
    try {
      return await _writeNdefToTag(tag, tagId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> writeAppLaunchRecord(String tagId) async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return false;
      }

      bool writeSuccess = false;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          writeSuccess = await _writeNdefToTag(tag, tagId);

          if (writeSuccess) {
            await NfcManager.instance.stopSession(
              alertMessage: 'Tag configured! It will now open this app automatically.',
            );
          } else {
            await NfcManager.instance.stopSession(
              errorMessage: 'Could not write to tag. Please try again.',
            );
          }
        },
        onError: (error) async {
          return;
        },
      );

      return writeSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _writeNdefToTag(NfcTag tag, String tagId) async {
    try {
      final textPayload = 'en$tagId';
      final textRecord = NdefRecord(
        typeNameFormat: NdefTypeNameFormat.nfcWellknown,
        type: Uint8List.fromList('T'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(textPayload.codeUnits),
      );

      final aarType = 'android.com:pkg';
      final aarRecord = NdefRecord(
        typeNameFormat: NdefTypeNameFormat.nfcExternal,
        type: Uint8List.fromList(aarType.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(packageName.codeUnits),
      );

      final message = NdefMessage([textRecord, aarRecord]);

      var ndef = Ndef.from(tag);

      if (ndef == null) {
        print('[NfcWriter] Tag is not NDEF formatted or compatible');
        print('[NfcWriter] This might be an unformatted NFC Forum Type 2 tag');
        return false;
      }

      print('[NfcWriter] Tag is NDEF formatted');
      print('[NfcWriter] Writable: ${ndef.isWritable}');
      print('[NfcWriter] Max size: ${ndef.maxSize} bytes');
      print('[NfcWriter] Message size: ${message.byteLength} bytes');

      if (!ndef.isWritable) {
        print('[NfcWriter] Tag is read-only');
        return false;
      }

      final messageSize = message.byteLength;
      if (messageSize > ndef.maxSize) {
        return false;
      }

      await ndef.write(message);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Read NDEF records from a tag
  Future<String?> readTagId() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) return null;

      String? tagId;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef != null && ndef.cachedMessage != null) {
              final records = ndef.cachedMessage!.records;

              // Look for our text record
              for (final record in records) {
                if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
                  final payload = String.fromCharCodes(record.payload);
                  if (payload.startsWith('MedTrack:')) {
                    tagId = payload.substring('MedTrack:'.length);
                    break;
                  }
                }
              }
            }

            await NfcManager.instance.stopSession();
          } catch (e) {
            print('[NfcWriter] Error reading tag: $e');
          }
        },
      );

      return tagId;
    } catch (e) {
      return null;
    }
  }
}
