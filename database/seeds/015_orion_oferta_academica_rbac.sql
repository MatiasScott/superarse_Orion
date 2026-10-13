USE superarse_siga;
-- Orion v0.9.0 - Períodos y oferta académica. Idempotente.
SET @mod=(SELECT id FROM modulos WHERE codigo='ACADEMICO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.oferta.ver','Ver períodos y oferta académica','Consultar períodos, ofertas y secciones académicas',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.oferta.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'academico.oferta.gestionar','Gestionar períodos y oferta académica','Crear y editar períodos, ofertas y secciones académicas',1
WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='academico.oferta.gestionar');
