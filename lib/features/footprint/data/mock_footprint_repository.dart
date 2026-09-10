import '../../cases/domain/privacy_case.dart';
import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';

class MockFootprintRepository implements FootprintRepository {
  MockFootprintRepository({
    FootprintProfile? initialProfile,
    String? targetIdentity,
  }) : _currentProfile =
           initialProfile ?? _createDefaultProfile(targetIdentity);

  FootprintProfile _currentProfile;

  static FootprintProfile _createDefaultProfile(String? targetIdentity) {
    return FootprintProfile(
      targetIdentity: targetIdentity ?? 'pedro.gomez@gmail.com',
      lastScannedAt: DateTime.now().subtract(const Duration(hours: 3)),
      items: [
        FootprintItem(
          id: 'fp-broker-1',
          platform: 'Radaris / Buscador de Personas',
          category: FootprintCategory.dataBroker,
          riskLevel: FootprintRisk.high,
          title: 'Ficha personal pública en Data Broker',
          description: 'Tus posibles familiares, rango de edad y ciudades de residencia están indexadas en directorios públicos accesibles para cualquiera.',
          exposedData: [
            'Ubicación aproximada',
            'Rango de edad',
            'Registros públicos',
          ],
          sourceUrl: 'https://radaris.com/p/pedro-gomez',
          recommendedAction: 'Solicitar el retiro y desindexación formal de datos amparado en normativas de privacidad.',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
        FootprintItem(
          id: 'fp-breach-1',
          platform: 'Colección de Filtraciones (Breaches)',
          category: FootprintCategory.dataBreach,
          riskLevel: FootprintRisk.high,
          title: 'Correo expuesto en brecha masiva de contraseñas',
          description: 'Tu correo electrónico y una contraseña antigua fueron expuestos en la filtración de un servicio web antiguo.',
          exposedData: ['Correo electrónico', 'Contraseña antigua cifrada'],
          sourceUrl: 'https://haveibeenpwned.com',
          recommendedAction: 'Cambiar la contraseña en cuentas donde la hayas reutilizado y activar autenticación en dos pasos.',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
        FootprintItem(
          id: 'fp-oracle-1',
          platform: 'X (Twitter)',
          category: FootprintCategory.exposedContact,
          riskLevel: FootprintRisk.medium,
          title: 'Teléfono parcialmente deducible',
          description: 'El flujo de recuperación de contraseña revela que tu cuenta está vinculada a un número telefónico que termina en 89.',
          exposedData: ['Últimos 2 dígitos del teléfono', 'Usuario de X'],
          sourceUrl: 'https://x.com/pedrogomez_',
          recommendedAction: 'Desactivar en configuración la opción "Permitir que otros me encuentren por teléfono".',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
        FootprintItem(
          id: 'fp-social-1',
          platform: 'Instagram',
          category: FootprintCategory.socialProfile,
          riskLevel: FootprintRisk.medium,
          title: 'Perfil público indexado en Google',
          description: 'Tus fotos, biografía y contactos son visibles para cualquier motor de búsqueda sin necesidad de tener cuenta.',
          exposedData: ['Fotografías', 'Nombre completo', 'Biografía'],
          sourceUrl: 'https://instagram.com/pedrogomez_',
          recommendedAction: 'Cambiar la cuenta a privada y eliminar información sensible de la biografía pública.',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
        FootprintItem(
          id: 'fp-github-1',
          platform: 'GitHub',
          category: FootprintCategory.socialProfile,
          riskLevel: FootprintRisk.low,
          title: 'Correo personal visible en commits públicos',
          description: 'Tu dirección de correo electrónico personal se encuentra en los metadatos de aportaciones públicas de código.',
          exposedData: ['Correo electrónico personal'],
          sourceUrl: 'https://github.com/pedrogomez',
          recommendedAction: 'Habilitar la opción "Keep my email address private" en la configuración de GitHub.',
          suggestedCaseCategory: CaseCategory.other,
        ),
      ],
    );
  }

  @override
  Future<FootprintProfile> getProfile() async {
    return _currentProfile;
  }

  @override
  Future<FootprintProfile> scanIdentity(String identity) async {
    final cleanIdentity = identity.trim();
    if (cleanIdentity.isEmpty) {
      throw const FormatException(
        'Ingresa un correo o nombre de usuario válido para escanear.',
      );
    }

    // Simulate analysis delay
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final isEmail = cleanIdentity.contains('@');
    final List<FootprintItem> generatedItems = [];

    if (isEmail) {
      generatedItems.add(
        FootprintItem(
          id: 'fp-scan-breach-${DateTime.now().millisecondsSinceEpoch}',
          platform: 'Bases de Datos Filtradas',
          category: FootprintCategory.dataBreach,
          riskLevel: FootprintRisk.high,
          title: 'Aparición en filtraciones de credenciales',
          description:
              'El correo "$cleanIdentity" ha sido localizado en al menos 1 incidente de seguridad histórico.',
          exposedData: ['Correo electrónico', 'Contraseñas antiguas'],
          sourceUrl: 'https://haveibeenpwned.com',
          recommendedAction:
              'Revisar accesos recientes y asegurar contraseñas únicas.',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
      );
      generatedItems.add(
        FootprintItem(
          id: 'fp-scan-phone-${DateTime.now().millisecondsSinceEpoch}',
          platform: 'Oráculo de Recuperación',
          category: FootprintCategory.exposedContact,
          riskLevel: FootprintRisk.medium,
          title: 'Teléfono asociado detectable',
          description: 'Servicios de mensajería asocian este correo con un número de móvil.',
          exposedData: ['Dígitos parciales de teléfono'],
          sourceUrl:
              'https://security.google.com/settings/security/secureaccount',
          recommendedAction:
              'Ocultar número en perfiles de recuperación pública.',
          suggestedCaseCategory: CaseCategory.personalData,
        ),
      );
    }

    generatedItems.add(
      FootprintItem(
        id: 'fp-scan-broker-${DateTime.now().millisecondsSinceEpoch}',
        platform: 'Agregador de Datos (Data Broker)',
        category: FootprintCategory.dataBroker,
        riskLevel: FootprintRisk.high,
        title: 'Registro público indexado',
        description:
            'Información asociada a "$cleanIdentity" disponible en páginas de búsqueda de personas.',
        exposedData: ['Historial público', 'Registros asociados'],
        sourceUrl:
            'https://radaris.com/p/${Uri.encodeComponent(cleanIdentity)}',
        recommendedAction:
            'Generar solicitud de retiro legal de la información expuesta.',
        suggestedCaseCategory: CaseCategory.personalData,
      ),
    );

    generatedItems.add(
      FootprintItem(
        id: 'fp-scan-social-${DateTime.now().millisecondsSinceEpoch}',
        platform: 'Redes Sociales',
        category: FootprintCategory.socialProfile,
        riskLevel: FootprintRisk.low,
        title: 'Cuentas públicas encontradas',
        description:
            'Se detectaron perfiles activos con el identificador "$cleanIdentity".',
        exposedData: ['Nombre público', 'Avatar'],
        sourceUrl:
            'https://instagram.com/${Uri.encodeComponent(cleanIdentity)}',
        recommendedAction:
            'Verificar la configuración de privacidad de los perfiles.',
        suggestedCaseCategory: CaseCategory.personalData,
      ),
    );

    _currentProfile = FootprintProfile(
      targetIdentity: cleanIdentity,
      items: generatedItems,
      lastScannedAt: DateTime.now(),
    );

    return _currentProfile;
  }
}
