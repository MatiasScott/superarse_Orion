USE superarse_siga;
-- Orion v0.7.0 - Estructura y trayectoria académica. Idempotente.
SET @mod=(SELECT id FROM modulos WHERE codigo='ACADEMICO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'academico.estructura.ver','Ver estructura académica','Consultar cohortes, asignaturas y estructura de mallas',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.estructura.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'academico.estructura.gestionar','Gestionar estructura académica','Gestionar cohortes, asignaturas, mallas y prerrequisitos',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.estructura.gestionar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'academico.trayectorias.ver','Ver trayectorias académicas','Consultar trayectoria carrera-malla de estudiantes',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.trayectorias.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'academico.trayectorias.gestionar','Gestionar trayectorias académicas','Formalizar y administrar trayectorias académicas',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.trayectorias.gestionar');
