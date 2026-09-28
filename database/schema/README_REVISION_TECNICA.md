# Revisión técnica integral – Base de Datos SIGA Superarse

**Versión revisada:** V2  
**Bloques revisados:** 001–023  
**Motor objetivo:** MySQL 8.x / InnoDB / utf8mb4

## Resultado general

La revisión estática de los 23 bloques quedó **sin referencias FK inexistentes, sin referencias hacia tablas creadas posteriormente, sin tablas duplicadas, sin nombres de constraints duplicados, sin INSERT a columnas inexistentes y sin identificadores mayores a 64 caracteres**.

La base revisada contiene **539 tablas** distribuidas en los 23 módulos.

> Importante: esta revisión valida estructura, dependencias y coherencia estática. Antes de producción todavía se debe hacer una importación real en una instancia MySQL 8 de prueba y ejecutar pruebas de integración/carga.

## Errores bloqueantes encontrados y corregidos

### 1. Tabla `sesiones_usuario` duplicada
El bloque 001 ya creaba `sesiones_usuario` y el bloque 020 intentaba crearla nuevamente. Eso habría detenido la importación.

**Corrección:** 001 conserva la tabla maestra y 020 ahora la amplía mediante `ALTER TABLE`, agregando datos de autenticación y seguridad.

### 2. Parámetros del sistema duplicados
El bloque 001 contenía una versión simple de `parametros_sistema`, mientras que 023 contenía el modelo avanzado.

**Corrección:** se eliminó el modelo simple de 001. El bloque 023 es ahora la única fuente de verdad de configuración y parámetros.

### 3. Auditoría duplicada
001 tenía `auditoria_acciones` / `auditoria_eventos`, mientras que 020 contiene el sistema completo de auditoría.

**Corrección:** se retiró la auditoría simplificada de 001. El bloque 020 es ahora la única capa transversal de auditoría y seguridad.

### 4. FK inválida de asistencia
`009_asistencia` apuntaba a `horarios(id)`, tabla que no existe. En 006 la tabla real se llama `seccion_horarios`.

**Corrección:** `sesiones_clase.horario_id -> seccion_horarios.id`.

### 5. Nombres de FOREIGN KEY repetidos
Había nombres de constraints repetidos entre módulos, lo que puede causar conflictos en MySQL/InnoDB.

**Corrección:** todos los símbolos de constraints quedaron únicos en el esquema.

### 6. UNIQUE con columnas NULL
En MySQL un `UNIQUE` permite múltiples filas cuando alguno de sus componentes es `NULL`. Esto afectaba:
- requisitos documentales por período;
- relaciones/asignaciones de encuestas;
- resúmenes académicos/financieros/titulación/becas;
- parámetros por contexto.

**Corrección:** se agregaron claves generadas con `IFNULL(...,0)` para garantizar la unicidad lógica esperada.

### 7. Microsoft 365 duplicaba el modelo del bloque 002
El bloque 022 recreaba solicitudes, cuentas, licencias y ciclo de vida que ya existían en 002. Eso habría generado dos fuentes de verdad.

**Corrección:** 022 fue rediseñado como **extensión Microsoft Graph** del bloque 002.  
Ahora:
- 002 = identidad institucional, solicitudes, cuentas, licencias y ciclo de vida;
- 022 = operaciones Graph, vínculos activos, conflictos, snapshots técnicos y dashboard TIC.

### 8. Escala de titulación inconsistente
El bloque 014 permitía notas hasta 100, mientras el modelo académico institucional trabaja de 0 a 10.

**Corrección:** intentos, examen complexivo y defensa de titulación quedaron en escala **0–10**.

## Validaciones ejecutadas

- 23 archivos en orden 001 → 023.
- 539 tablas finales.
- 0 tablas duplicadas.
- 0 referencias FK a tablas inexistentes.
- 0 referencias FK a columnas inexistentes.
- 0 FK adelantadas respecto al orden de creación.
- 0 nombres de constraints duplicados.
- 0 INSERT con columnas inexistentes.
- 0 identificadores de tabla/index/constraint > 64 caracteres.

## Normalización

La estructura principal cumple el enfoque de **1FN, 2FN y 3FN**:

- **1FN:** los datos transaccionales principales son atómicos; listas reales se modelan con tablas puente.
- **2FN:** las relaciones N:M se resuelven mediante entidades asociativas.
- **3FN:** catálogos, estados, políticas, versiones y dimensiones se encuentran separados de las entidades transaccionales.

Los campos `JSON` se mantienen únicamente donde son apropiados: payloads de integración, auditoría, configuración flexible, snapshots o criterios dinámicos. No sustituyen relaciones normales del dominio académico.

## Decisiones arquitectónicas ratificadas

- SIGA es maestro del registro académico oficial.
- Moodle es LMS operativo y se integra por API/Web Services; no se escriben tablas `mdl_*`.
- Microsoft Entra ID es el proveedor de autenticación.
- Una persona conserva una sola identidad institucional y puede tener varios perfiles/vínculos.
- Financiero controla habilitación/bloqueo, pero no elimina historial Moodle.
- Cambios excepcionales de nota se aprueban en SIGA y luego se sincronizan a Moodle.
- Documentos se versionan y solo una versión aprobada queda vigente.
- Workflows son idempotentes y usan colas/reintentos.
- Los secretos viven fuera de MySQL y fuera de Git.
- Reportes pesados se procesan en background.
- Parámetros cambiantes no quedan hardcodeados en PHP.

## Orden recomendado de importación

Importar estrictamente:

`001 → 002 → 003 → ... → 023`

No ejecutar los archivos antiguos:
- `001_core_superarse_siga.sql`
- `002_modelo_evaluacion_academica.sql`

Fueron versiones previas y no forman parte de la estructura definitiva.

## Próxima prueba obligatoria antes de producción

1. Crear una base MySQL 8 de pruebas vacía.
2. Ejecutar los 23 scripts revisados en orden.
3. Guardar cualquier warning/error exacto.
4. Ejecutar `SHOW ENGINE INNODB STATUS` si aparece un error de FK.
5. Probar datos semilla y CRUD básico.
6. Probar transacciones de matrícula, pagos, notas, asistencia y documentos.
7. Probar workers sin credenciales reales primero.
8. Probar Moodle y Microsoft en entorno controlado.
9. Generar backup antes del primer despliegue productivo.

## Estado

**Aprobado para pasar a prueba de importación MySQL de staging.**  
**Todavía no aprobado para producción sin esa ejecución real y pruebas funcionales.**
