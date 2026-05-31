import 'package:med_track/database/model/dose_buddy_device.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class DoseBuddyDeviceDatabaseService
    extends FirestoreRepository<DoseBuddyDevice> {
  DoseBuddyDeviceDatabaseService()
    : super(
        collectionPath: 'dose_buddy_devices',
        fromJson: (json, id) => DoseBuddyDevice.fromJson(json, id: id),
        toJson: (device) => device.toJson(),
      );

  Stream<DoseBuddyDevice?> observePrimaryDevice(String userId) =>
      observe(userId);

  Future<DoseBuddyDevice?> getPrimaryDevice(String userId) => get(userId);

  Future<void> savePrimaryDevice(DoseBuddyDevice device) {
    return create(device.copyWith(id: device.userId));
  }
}
