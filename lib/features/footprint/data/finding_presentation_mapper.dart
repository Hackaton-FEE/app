import '../domain/footprint_item.dart';

FootprintCategory mapFindingCategory(
  String name, {
  required List<String> sources,
  required Map<String, dynamic> details,
}) {
  final lowerCat = name.toLowerCase();

  // Verificaciones de correo / teléfono o motor Holehe -> Contacto
  if (sources.contains('holehe') ||
      sources.contains('ignorant') ||
      details['masked_email'] != null ||
      details['masked_phone'] != null ||
      lowerCat.contains('contact') ||
      lowerCat.contains('phone') ||
      lowerCat.contains('messaging') ||
      lowerCat.contains('email')) {
    return FootprintCategory.exposedContact;
  }

  // Filtraciones / leaks / darkweb
  if (lowerCat.contains('breach') ||
      lowerCat.contains('leak') ||
      lowerCat.contains('pwned') ||
      lowerCat.contains('password') ||
      lowerCat.contains('pastebin') ||
      lowerCat.contains('darkweb')) {
    return FootprintCategory.dataBreach;
  }

  // Redes sociales, plataformas de desarrollo, gaming, hobbies
  if (lowerCat.contains('social') ||
      lowerCat.contains('coding') ||
      lowerCat.contains('forum') ||
      lowerCat.contains('tech') ||
      lowerCat.contains('gaming') ||
      lowerCat.contains('music') ||
      lowerCat.contains('hobby')) {
    return FootprintCategory.socialProfile;
  }

  // Directorios, finanzas, brokers, dominios y registros públicos
  if (lowerCat.contains('broker') ||
      lowerCat.contains('search') ||
      lowerCat.contains('lookup') ||
      lowerCat.contains('finance') ||
      lowerCat.contains('domain') ||
      lowerCat.contains('adult') ||
      lowerCat.contains('other')) {
    return FootprintCategory.dataBroker;
  }

  return FootprintCategory.socialProfile;
}

FootprintRisk mapFindingRisk(String status, int confidence) {
  if (status == 'CONFIRMED' && confidence >= 85) {
    return FootprintRisk.high;
  }
  if (confidence >= 60 || status == 'POTENTIAL_MATCH') {
    return FootprintRisk.medium;
  }
  return FootprintRisk.low;
}

String recommendedFindingAction(FootprintCategory category, String platform) {
  return switch (category) {
    FootprintCategory.dataBreach => 'Cambiar la contraseña inmediatamente y habilitar autenticación multifactor.',
    FootprintCategory.dataBroker =>
      'Generar un reclamo formal de desindexación y retiro de registros en $platform.',
    FootprintCategory.exposedContact => 'Ocultar teléfonos y correos en los ajustes de privacidad de recuperación.',
    FootprintCategory.socialProfile =>
      'Revisar la visibilidad de tu perfil en $platform y restringir datos personales públicos.',
  };
}
