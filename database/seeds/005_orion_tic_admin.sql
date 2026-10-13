USE superarse_siga;

-- Permiso específico para una acción sensible.
INSERT INTO permisos (modulo_id,codigo,nombre,descripcion,activo)
SELECT m.id,'tic.cuentas.password_reset','Restablecer contraseña Microsoft','Permite a TIC restablecer la contraseña temporal de una cuenta institucional.',1
FROM modulos m
WHERE m.codigo='TIC_MICROSOFT'
  AND NOT EXISTS (SELECT 1 FROM permisos WHERE codigo='tic.cuentas.password_reset');

-- SUPER_ADMIN conserva bypass (*). Para otros roles, asignar este permiso explícitamente.

-- Evento histórico de cuenta; no almacena la contraseña.
INSERT INTO tipos_evento_cuenta (codigo,nombre,activo)
SELECT 'PASSWORD_RESTABLECIDA','Contraseña temporal restablecida',1
WHERE NOT EXISTS (SELECT 1 FROM tipos_evento_cuenta WHERE codigo='PASSWORD_RESTABLECIDA');
