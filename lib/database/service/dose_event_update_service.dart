import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/dose_event_creating_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';

import 'auth_service.dart';

class DoseEventUpdateService {
  final _doseEventService = get<DoseEventDatabaseService>();
  final _authService = get<AuthService>();
  final _creationService = DoseEventCreationService();

  /// Updates the dose events for a medication when its schedule changes.
  ///
  /// This process involves two main steps:
  /// 1. Deleting all future, pending dose events associated with the medication.
  /// 2. Creating new dose events based on the updated medication schedule.
  Future<void> updateDoseEventsForMedication(
    Medication updatedMedication,
  ) async {
    final userId = _authService.user?.uid;

    final futureEventsForMedication = await _doseEventService.getUpcomingUserDoseEventsForMedication(userId!, updatedMedication.id);
    _doseEventService.deleteListOfDoseEvents(futureEventsForMedication);

    await _creationService.createDoseEventsForMedication(updatedMedication);
  }
}
