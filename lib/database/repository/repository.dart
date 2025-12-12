abstract class Repository<T> {
  Future<void> create(String id, T entity);
  Future<T?> get(String id);
  Future<void> update(String id, T entity);
  Future<void> delete(String id);

  Stream<T?> observe(String id);
  Stream<List<T>> observeAll();
}
