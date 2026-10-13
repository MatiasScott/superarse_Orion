USE superarse_siga;

INSERT INTO modulos (modulo_padre_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
SELECT NULL,'ADMISIONES','Admisiones y Estudiantes','Gestión de aspirantes, admisión y estudiantes','/admin/admisiones','users',40,1
WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE codigo='ADMISIONES');

SET @mod := (SELECT id FROM modulos WHERE codigo='ADMISIONES' LIMIT 1);
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'admisiones.solicitudes.ver','Ver admisiones','Consultar bandeja y detalle de admisiones',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='admisiones.solicitudes.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'admisiones.solicitudes.crear','Crear admisiones','Registrar aspirantes y solicitudes',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='admisiones.solicitudes.crear');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'admisiones.solicitudes.editar','Revisar admisiones','Tomar y actualizar solicitudes en revisión',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='admisiones.solicitudes.editar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'admisiones.solicitudes.aprobar','Aprobar admisiones','Aprobar y convertir aspirantes en estudiantes',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='admisiones.solicitudes.aprobar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'admisiones.solicitudes.rechazar','Rechazar admisiones','Rechazar solicitudes con motivo',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='admisiones.solicitudes.rechazar');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'estudiantes.ver','Ver estudiantes','Consultar fichas de estudiantes',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='estudiantes.ver');
INSERT INTO permisos(modulo_id,codigo,nombre,descripcion,activo)
SELECT @mod,'estudiantes.editar','Editar estudiantes','Gestionar contactos y datos socioeconómicos',1 WHERE NOT EXISTS(SELECT 1 FROM permisos WHERE codigo='estudiantes.editar');
