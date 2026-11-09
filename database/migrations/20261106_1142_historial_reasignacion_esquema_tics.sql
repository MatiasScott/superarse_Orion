-- Ejecutar UNA VEZ en la base de Orion antes de utilizar la reasignación excepcional.
CREATE TABLE IF NOT EXISTS historial_reasignacion_esquema_tics (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 seccion_id BIGINT UNSIGNED NOT NULL,
 asignacion_id BIGINT UNSIGNED NOT NULL,
 version_anterior_id BIGINT UNSIGNED NOT NULL,
 version_nueva_id BIGINT UNSIGNED NOT NULL,
 usuario_tics_id BIGINT UNSIGNED NOT NULL,
 motivo TEXT NOT NULL,
 fecha_reasignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_reasignacion_seccion_fecha (seccion_id,fecha_reasignacion),
 FOREIGN KEY (seccion_id) REFERENCES secciones(id),
 FOREIGN KEY (asignacion_id) REFERENCES seccion_esquema_evaluacion(id),
 FOREIGN KEY (version_anterior_id) REFERENCES esquema_evaluacion_versiones(id),
 FOREIGN KEY (version_nueva_id) REFERENCES esquema_evaluacion_versiones(id),
 FOREIGN KEY (usuario_tics_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
