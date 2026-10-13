USE superarse_siga;
-- Orion v0.8.1 - Historial Académico. Idempotente.
SET @mod=(SELECT id FROM modulos WHERE codigo='ACADEMICO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.historial.ver','Ver historial académico','Consultar carreras, períodos, asignaturas, intentos y calificaciones del expediente académico',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.historial.ver');
