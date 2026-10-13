USE superarse_siga;

INSERT INTO modulos (parent_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
SELECT NULL,'TALENTO_HUMANO','Talento Humano','Gestión de personal y relaciones laborales','/admin/tthh','users',20,1
WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE codigo='TALENTO_HUMANO');

SET @mod=(SELECT id FROM modulos WHERE codigo='TALENTO_HUMANO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.personal.ver','Ver personal','Consultar personal institucional',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.personal.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.personal.crear','Registrar personal','Crear fichas y relaciones laborales',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.personal.crear');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.personal.editar','Editar personal','Modificar información laboral vigente',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.personal.editar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.desvincular','Desvincular personal','Registrar desvinculaciones laborales',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.desvincular');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.solicitudes.ver','Ver solicitudes TIC','Consultar solicitudes de cuenta originadas en TTHH',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.solicitudes.ver');

INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'tthh.catalogos.gestionar','Gestionar catálogos TTHH','Crear cargos, unidades y sedes',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tthh.catalogos.gestionar');
