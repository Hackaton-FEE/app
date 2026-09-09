/// An in-memory demo profile. It is not an authenticated identity.
class LocalAccount {
  const LocalAccount({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}
