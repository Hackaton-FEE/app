# Calidad del cliente

- Usa Flutter 3.47.2 / Dart 3.13.2. Mantén las dependencias existentes salvo que la tarea justifique añadir otra.
- Preserva la separación actual entre datos en memoria, dominio y presentación. Una tarea pequeña no requiere una arquitectura nueva ni bibliotecas de estado adicionales.
- Comprueba formato, análisis y pruebas con los comandos de [CONTRIBUTING.md](../CONTRIBUTING.md). Prueba comportamiento observable cuando cambie lógica o interacción; una corrección puramente editorial no requiere una prueba que replique su texto.
- Verifica la compilación Android al cerrar cambios de código del cliente. Los cambios nativos iOS requieren validación en macOS/Xcode o una limitación explícita en el PR.
- Las pruebas de la demo no deben depender del backend ni de servicios externos. Distingue pruebas ejecutadas, pendientes y bloqueadas; no declares éxito por ausencia de errores observados.
