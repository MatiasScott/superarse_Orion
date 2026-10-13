USE superarse_siga;
INSERT INTO modulos (modulo_padre_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
SELECT NULL,'TIC_MICROSOFT','TIC · Microsoft 365','Aprobación y provisionamiento de cuentas institucionales','/admin/tic','shield',30,1
WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE codigo='TIC_MICROSOFT');
SET @m=(SELECT id FROM modulos WHERE codigo='TIC_MICROSOFT' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @m,'tic.cuentas.ver','Ver solicitudes de cuentas','Acceso a bandeja TIC',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tic.cuentas.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @m,'tic.cuentas.aprobar','Aprobar y provisionar cuentas','Validar username y ejecutar provisionamiento Microsoft',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tic.cuentas.aprobar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @m,'tic.licencias.gestionar','Gestionar licencias Microsoft','Consultar SKU y mapear licencias Orion',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='tic.licencias.gestionar');
