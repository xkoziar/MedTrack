import 'package:get_it/get_it.dart';
import 'package:med_track/database/service/auth_service.dart';

import '../service/user_database_service.dart';
import '../service/medication_database_service.dart';
import '../service/dose_event_database_service.dart';

final get = GetIt.instance;

class IocContainer {
  static void initialize() {
    get.registerSingleton(UserDatabaseService());
    get.registerSingleton(AuthService());
    get.registerSingleton(MedicationDatabaseService());
    get.registerSingleton(DoseEventDatabaseService());
  }
}
