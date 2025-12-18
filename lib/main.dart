import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:med_track/app_wrapper.dart';
import 'package:med_track/database/service/nfc_background_channel.dart';
import 'database/ioc/ioc_container.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  IocContainer.initialize();

  // Initialize NFC background channel
  NfcBackgroundChannel.initialize();

  runApp(AppWrapper());
}
