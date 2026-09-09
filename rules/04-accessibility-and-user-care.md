# Accesibilidad y atención al usuario

Aplica estos requisitos a las pantallas y estados afectados por cada cambio. La justificación y los límites de evidencia están en [la revisión dirigida](../docs/research/accessibility-and-user-care.md).

- Diseña controles pulsables con objetivo de 48 × 48 unidades lógicas, etiquetas comprensibles y separación suficiente. La prueba iOS de Flutter usa 44 × 44; esto no equivale al criterio WCAG AA de 24 × 24 CSS px ni demuestra conformidad global.
- Conserva etiquetas visibles al escribir. Expón nombre, rol, estado y obligatoriedad; usa encabezados para secciones y evita duplicar focos o anunciar decoración. No dependas únicamente del color para comunicar un error o estado.
- Al validar, muestra cómo corregir y lleva foco y vista al primer campo inválido. Conserva los valores. Los campos desplazados deben seguir participando en la validación.
- Protege cambios sin guardar con opciones claras para seguir editando o descartar. No interrumpas una salida limpia ni un guardado confirmado. Abrir ayuda y volver debe conservar el formulario.
- Identifica el caso y la consecuencia antes de eliminarlo; permite cancelar. Distingue archivar, eliminar, guardar localmente y cualquier futura acción externa. Muestra éxito solo tras confirmación del repositorio.
- Mantén visibles los errores y resultados importantes mientras sean pertinentes. Expón cambios de estado a tecnologías de asistencia sin robar foco ni repetir contenido personal innecesariamente. Respeta la preferencia de reducir animaciones.
- Mantén ayuda de uso en una ubicación consistente. Escribe en español directo, sin culpa ni garantías de protección. Las notas son opcionales; no exijas relatos ni inventes soporte, recuperación o envíos que el producto no ofrece.
- Verifica comportamiento, semántica y guidelines en los estados afectados, incluido contenido desplazado; comprueba texto al 200 % y ancho reducido cuando afecte al diseño. Registra por separado pruebas de widgets, comprobaciones nativas y recorridos reales con lectores de pantalla. Deja explícito lo no ejecutado; no atribuyas resultados clínicos ni conformidad global al número de tests.
