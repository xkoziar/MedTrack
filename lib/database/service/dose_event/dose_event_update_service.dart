import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/dose_event/dose_event_creating_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';

import 'package:med_track/database/service/auth_service.dart';

class DoseEventUpdateService {
  final _doseEventService = get<DoseEventDatabaseService>();
  final _authService = get<AuthService>();
  final _creationService = DoseEventCreationService();

  Future<void> updateDoseEventsForMedication(
    Medication updatedMedication,
  ) async {
    final userId = _authService.user?.uid;

    final futureEventsForMedication = await _doseEventService.getUpcomingUserDoseEventsForMedication(userId!, updatedMedication.id);
    _doseEventService.deleteListOfDoseEvents(futureEventsForMedication);

    await _creationService.createDoseEventsForMedication(updatedMedication);
  }
}
