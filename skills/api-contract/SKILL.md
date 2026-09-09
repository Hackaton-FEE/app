---
name: api-contract
description: Proponer, revisar o integrar el contrato HTTP entre Hackaton-FEE/app y Hackaton-FEE/server desde el cliente Flutter. Usar cuando una tarea cambie endpoints, payloads, errores o compatibilidad; no para pantallas sin red.
---

# Contrato desde el cliente

Consulta [arquitectura](../../docs/architecture.md). La demo no tiene backend conectado; una tarea de UI por sí sola no autoriza introducir esa integración.

Antes de programar el consumidor, lee el esquema OpenAPI o los modelos y pruebas del servidor en la revisión que se integrará. El contrato inicial disponible es `GET /api/v1/health`, HTTP 200:

```json
{"status":"ok","service":"fee-server","version":"0.1.0"}
```

No deduzcas que existen endpoints de casos, identidad o reportes. Si el servidor no está disponible, documenta el contrato propuesto y el bloqueo de integración; usa un doble de prueba claramente identificado para el trabajo independiente.

Para un cambio compartido, acuerda método, ruta, campos, obligatoriedad, respuestas y errores observables. Enlaza el PR servidor/cliente y señala el orden de integración o conserva compatibilidad para que cada `main` siga funcionando por separado.

Prueba serialización y los estados de éxito/error relevantes sin hacer solicitudes reales a terceros. La creación o envío de una solicitud nunca equivale por sí sola a retiro o desindexación. Mantén payloads y URL fuera de logs y mensajes de diagnóstico.

Actualiza la documentación del contrato al modificarlo; no afirmes integración completa basándote solo en mocks. Sigue [el flujo de PR](../../docs/workflow.md).
