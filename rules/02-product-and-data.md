# Producto y datos

- La versión inicial crea y muestra borradores locales en memoria. No implica envío, recepción por terceros, retiro en origen ni desindexación. La interfaz debe distinguir esos estados si se implementan después.
- Mantén URL, nombres, correos y demás datos personales fuera de logs, analítica, mensajes de error y capturas de ejemplo. Usa datos ficticios en pruebas y demostraciones.
- No presentes un hash como una garantía de conocimiento cero, anonimato o certificación. Describe únicamente lo que una implementación verifica.
- No implementes KYC, tratamiento de imágenes íntimas, extensiones de compartir, solicitudes externas ni reportes automáticos como parte del scaffold. Son funciones de roadmap que necesitan una tarea y criterios de aceptación propios.
- Conserva el texto visible orientado al usuario: estado del borrador, siguiente acción y limitaciones reales, sin promesas de eliminación ni plazos no comprobados.
