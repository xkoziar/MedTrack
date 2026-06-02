import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:med_track/app_wrapper.dart';
import 'package:med_track/database/service/nfc/nfc_background_channel.dart';
import 'package:med_track/database/service/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'database/ioc/ioc_container.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize timezone data for scheduled notifications
  tz.initializeTimeZones();
  final timezoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timezoneName.identifier));

  IocContainer.initialize();

  NfcBackgroundChannel.initialize();
  await NotificationService.initialize();

  runApp(AppWrapper());
}
