import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:med_track/database/model/entity.dart';

import 'repository.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json, String id);
typedef ToJson<T> = Map<String, dynamic> Function(T model);

class FirestoreRepository<T extends IEntity> implements Repository<T> {
  final CollectionReference<T> ref;
  final ToJson<T> _toJson;

  FirestoreRepository({
    required String collectionPath,
    required T Function(Map<String, dynamic>, String) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) : _toJson = toJson,
       ref = FirebaseFirestore.instance
           .collection(collectionPath)
           .withConverter<T>(
             fromFirestore: (snap, _) => fromJson(snap.data() ?? {}, snap.id),
             toFirestore: (model, _) => toJson(model),
           );

  @override
  Future<void> create(T entity) {
    return ref.doc(entity.id).set(entity);
  }

  @override
  Future<T?> get(String id) async {
    final snap = await ref.doc(id).get();
    return snap.data();
  }

  @override
  Future<void> update(String id, T entity) async =>
      ref.doc(id).update(_toJson(entity));

  @override
  Future<void> delete(String id) async => ref.doc(id).delete();

  @override
  Stream<T?> observe(String id) =>
      ref.doc(id).snapshots().map((s) => s.data());

  @override
  Stream<List<T>> observeAll() =>
      ref.snapshots().map((s) => s.docs.map((d) => d.data()).toList());
}
