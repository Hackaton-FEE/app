/// A small encrypted record per case, keyed by its opaque identifier.
///
/// Implementations must complete writes/deletes only after storage confirms the
/// operation. There is intentionally no reset/delete-all operation.
abstract interface class CaseStorage {
  Future<Map<String, String>> readAll();
  Future<void> write(String id, String value);
  Future<void> delete(String id);
}
