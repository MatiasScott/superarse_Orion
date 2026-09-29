-- Orion v0.3.0 - catálogo inicial de Administración/RBAC
-- Idempotente: puede ejecutarse más de una vez.
START TRANSACTION;

INSERT INTO modulos (modulo_padre_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
VALUES (NULL,'ADMINISTRACION','Administración','Administración de identidad y acceso','/admin','settings',10,1)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre),descripcion=VALUES(descripcion),ruta_base=VALUES(ruta_base),activo=1;

SET @admin_modulo := (SELECT id FROM modulos WHERE codigo='ADMINISTRACION' LIMIT 1);

INSERT INTO permisos (modulo_id,codigo,nombre,descripcion,activo) VALUES
(@admin_modulo,'admin.usuarios.ver','Ver usuarios','Consultar usuarios y sus accesos',1),
(@admin_modulo,'admin.usuarios.crear','Crear usuarios','Crear persona y usuario',1),
(@admin_modulo,'admin.usuarios.editar','Editar usuarios','Editar identidad básica y estado',1),
(@admin_modulo,'admin.usuarios.accesos','Gestionar accesos','Asignar perfiles y roles a usuarios',1),
(@admin_modulo,'admin.roles.ver','Ver roles','Consultar roles',1),
(@admin_modulo,'admin.roles.crear','Crear roles','Crear roles institucionales',1),
(@admin_modulo,'admin.roles.editar','Editar roles','Editar roles institucionales',1),
(@admin_modulo,'admin.roles.permisos','Gestionar permisos de roles','Asignar permisos a roles',1),
(@admin_modulo,'admin.permisos.ver','Ver permisos','Consultar catálogo de permisos',1)
ON DUPLICATE KEY UPDATE modulo_id=VALUES(modulo_id),nombre=VALUES(nombre),descripcion=VALUES(descripcion),activo=1;

COMMIT;
