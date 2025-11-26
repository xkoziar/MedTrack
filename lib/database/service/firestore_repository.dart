import 'package:cloud_firestore/cloud_firestore.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json, String id);
typedef ToJson<T> = Map<String, dynamic> Function(T model);

class FirestoreRepository<T> {
  final CollectionReference<T> _ref;
  final ToJson<T> _toJson;

  FirestoreRepository({
    required String collectionPath,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
  }) : _toJson = toJson,
       _ref = FirebaseFirestore.instance
           .collection(collectionPath)
           .withConverter<T>(
             fromFirestore: (snap, _) => fromJson(snap.data() ?? {}, snap.id),
             toFirestore: (model, _) => toJson(model),
           );

  Future<void> create(String id, T model) async {
    await _ref.doc(id).set(model);
  }

  Future<DocumentReference<T>> add(T model) async {
    return await _ref.add(model);
  }

  Future<T?> get(String id) async {
    final doc = await _ref.doc(id).get();
    return doc.data();
  }

  Stream<T?> observe(String id) {
    return _ref.doc(id).snapshots().map((snap) => snap.data());
  }

  Stream<List<T>> observeAll() {
    return _ref.snapshots().map(
      (snap) => snap.docs.map((d) => d.data()).toList(),
    );
  }

  Future<List<T>> getAll() async {
    final snap = await _ref.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> update(String id, T model) async {
    await _ref.doc(id).update(_toJson(model));
  }

  Future<void> set(String id, T model) async {
    await _ref.doc(id).set(model);
  }

  Future<void> delete(String id) async {
    await _ref.doc(id).delete();
  }

  Query<T> query() => _ref;

  Stream<List<T>> observeQuery(Query<T> query) {
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => d.data()).toList(),
    );
  }

  Future<List<T>> getQuery(Query<T> query) async {
    final snap = await query.get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
