/// A profile or authenticated identity used in the application.
class LocalAccount {
  const LocalAccount({
    required this.id,
    required this.name,
    required this.email,
    this.isDemo = false,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final bool isDemo;
  final bool isActive;
  final DateTime? createdAt;
}

