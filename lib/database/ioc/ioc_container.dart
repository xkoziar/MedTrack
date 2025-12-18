import 'package:get_it/get_it.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';

import '../service/user_database_service.dart';
import '../service/medication_database_service.dart';
import '../service/nfc/nfc_tag_database_service.dart';
import '../service/nfc/nfc_manager_service.dart';
import '../service/nfc/nfc_background_service.dart';
import '../service/nfc/nfc_writer_service.dart';
import '../service/nfc/nfc_dose_marker_service.dart';

final get = GetIt.instance;

class IocContainer {
  static void initialize() {
    get.registerSingleton(UserDatabaseService());
    get.registerSingleton(AuthService());
    get.registerSingleton(MedicationDatabaseService());
    get.registerSingleton(DoseEventDatabaseService());
    get.registerSingleton(NfcTagDatabaseService());
    get.registerSingleton(NfcManagerService());
    get.registerSingleton(NfcDoseMarkerService());
    get.registerSingleton(NfcBackgroundService());
    get.registerSingleton(NfcWriterService());
  }
}
