/// Orientación local cuando no se puede generar una respuesta personalizada.
/// Solo clasifica la consulta: no atribuye hallazgos ni ejecuta acciones.
String guardAiFallback(String message) {
  var normalized = message.toLowerCase();
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  for (final entry in accents.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  normalized = normalized.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  final words = normalized.split(RegExp(r'[^a-z0-9]+')).toSet();
  bool mentions(Set<String> keywords) => words.any(keywords.contains);

  final String advice;
  if (mentions({
    'phishing',
    'estafa',
    'estafas',
    'fraude',
    'fraudes',
    'sospechoso',
    'sospechosa',
    'suplantacion',
  })) {
    advice =
        'Si recibiste un mensaje sospechoso, evita abrir sus enlaces o compartir códigos. '
        'Abre la aplicación o web oficial por tu cuenta y confirma la solicitud por otro canal. '
        'Si introdujiste una contraseña en una página dudosa, cámbiala desde el servicio oficial '
        'y revisa las sesiones abiertas.';
  } else if (mentions({
    'contrasena',
    'contrasenas',
    'password',
    'passwords',
    '2fa',
    'mfa',
    'autenticacion',
    'verificacion',
    'claves',
  })) {
    advice =
        'Usa una contraseña larga y diferente para cada cuenta; un gestor puede ayudarte a conservarlas. '
        'Activa la verificación en dos pasos cuando esté disponible y guarda los códigos de recuperación '
        'en un lugar seguro. Empieza por tu correo principal y revisa las sesiones que no reconozcas.';
  } else if (mentions({
    'eliminar',
    'borrar',
    'retirar',
    'quitar',
    'desindexar',
    'exposicion',
    'expuesto',
    'expuesta',
    'filtracion',
    'filtraciones',
    'brecha',
    'doxxing',
  })) {
    advice =
        'Primero comprueba que la cuenta o publicación te pertenece y qué datos muestra públicamente. '
        'Puedes limitar su visibilidad, retirar datos de contacto o usar las opciones de eliminación del servicio. '
        'Antes de borrar una cuenta, guarda lo que necesites. La eliminación en un servicio no asegura '
        'que desaparezcan copias publicadas en otros sitios.';
  } else if (mentions({
    'plan',
    'pasos',
    'priorizar',
    'prioridades',
    'empezar',
  })) {
    advice =
        'Puedes organizar tu privacidad en tres pasos:\n'
        '1. Protege el correo principal con contraseña única y verificación en dos pasos.\n'
        '2. Revisa quién puede ver tus perfiles, teléfono y correo; reduce lo que no necesites publicar.\n'
        '3. Revisa las cuentas que ya no usas y los permisos de aplicaciones conectadas. '
        'Haz un cambio a la vez y comprueba su efecto.';
  } else if (mentions({
    'perfil',
    'perfiles',
    'huella',
    'informe',
    'analisis',
    'privacidad',
    'recomendacion',
    'recomendaciones',
    'ayuda',
    'ayudame',
  })) {
    advice =
        'Para revisar tu huella, abre un informe y confirma que cada coincidencia realmente te pertenece. '
        'Comprueba qué correo, teléfono o datos de perfil son visibles y revisa sus ajustes de privacidad. '
        'Una coincidencia no confirma titularidad y la ausencia de resultados no garantiza que no haya exposición. '
        'Si me indicas qué ajuste quieres revisar, puedo orientarte de forma general.';
  } else if (mentions({'hola', 'buenas', 'buenos', 'saludos', 'gracias'})) {
    advice =
        'Hola. Puedo orientarte sobre privacidad, contraseñas, mensajes sospechosos y revisión de perfiles. '
        'Cuéntame qué te gustaría mejorar o qué situación quieres revisar.';
  } else {
    advice =
        'Puedes empezar por revisar la visibilidad de tus perfiles, proteger el correo principal '
        'y comprobar los permisos de las aplicaciones conectadas. '
        'Indícame si tu duda trata de contraseñas, un mensaje sospechoso, una cuenta o datos publicados '
        'para darte pasos más concretos.';
  }
  return 'Orientación general: $advice';
}
