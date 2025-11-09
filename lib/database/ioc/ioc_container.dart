import 'package:get_it/get_it.dart';

import '../service/user_database_service.dart';

final get = GetIt.instance;

class IocContainer {
  static void initialize() {
    get.registerSingleton(UserDatabaseService());
  }
}
