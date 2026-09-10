/// Adaptador de almacenamiento clave-valor para el perfil de identidad.
abstract class IdentityStorage {
  Future<Map<String, String>> readAll();
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
