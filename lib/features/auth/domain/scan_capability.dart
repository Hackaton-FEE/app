/// Proveedor de escaneo y capacidades devuelto por `GET /api/v1/scans/capabilities`.
class ScanCapabilityProvider {
  const ScanCapabilityProvider({
    required this.providerId,
    required this.name,
    required this.capabilities,
    required this.available,
  });

  factory ScanCapabilityProvider.fromJson(Map<String, dynamic> json) {
    return ScanCapabilityProvider(
      providerId: json['provider_id'] as String,
      name: json['name'] as String,
      capabilities: (json['capabilities'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      available: json['available'] as bool? ?? false,
    );
  }

  final String providerId;
  final String name;
  final List<String> capabilities;
  final bool available;
}
