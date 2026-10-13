USE superarse_siga;
-- Orion v0.9.1 - Motor de matrícula y renovación. Idempotente.
SET @mod=(SELECT id FROM modulos WHERE codigo='ACADEMICO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.matriculas.ver','Ver matrículas y renovación','Consultar motor, propuestas y matrículas académicas',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.matriculas.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.matriculas.gestionar','Gestionar matrículas y renovación','Calcular propuestas y crear borradores de matrícula',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.matriculas.gestionar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.matriculas.confirmar','Confirmar matrícula académica','Confirmar selección académica; respeta habilitación financiera',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.matriculas.confirmar');
