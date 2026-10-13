USE superarse_siga;
-- Orion v0.10.0 - Financiero. Idempotente.
INSERT INTO modulos(modulo_padre_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
SELECT NULL,'FINANCIERO','Financiero','Órdenes, pagos y habilitación financiera','/admin/financiero','finance',40,1
WHERE NOT EXISTS(SELECT 1 FROM modulos WHERE codigo='FINANCIERO');
SET @mod=(SELECT id FROM modulos WHERE codigo='FINANCIERO' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'financiero.ver','Ver Financiero','Consultar órdenes, pagos y habilitaciones',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='financiero.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'financiero.tarifas.gestionar','Gestionar tarifas','Crear tarifas académicas versionadas',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='financiero.tarifas.gestionar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'financiero.ordenes.generar','Generar órdenes','Generar órdenes de pago de prematrícula',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='financiero.ordenes.generar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'financiero.pagos.registrar','Registrar pagos','Registrar comprobantes y pagos',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='financiero.pagos.registrar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo) SELECT @mod,'financiero.pagos.revisar','Revisar pagos','Aprobar, abonar o rechazar pagos',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='financiero.pagos.revisar');
