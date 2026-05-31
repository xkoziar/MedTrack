import 'package:med_track/database/model/dose_buddy_event.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class DoseBuddyEventDatabaseService
    extends FirestoreRepository<DoseBuddyEvent> {
  DoseBuddyEventDatabaseService()
    : super(
        collectionPath: 'dose_buddy_events',
        fromJson: (json, id) => DoseBuddyEvent.fromJson(json, id: id),
        toJson: (event) => event.toJson(),
      );

  Stream<List<DoseBuddyEvent>> observeRecentUserEvents(
    String userId, {
    int limit = 10,
  }) {
    return ref
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final events =
              snapshot.docs
                  .map((doc) => doc.data())
                  .toList()
                ..sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt));

          if (events.length > limit) {
            return events.sublist(0, limit);
          }

          return events;
        });
  }

  Future<void> upsertEvent(DoseBuddyEvent event) => create(event);
}
