-- Orion v0.11.8: registro de solicitudes de ampliación de cupos.
-- Esta migración NO cambia los cupos históricos ni crea matrículas.
CREATE TABLE IF NOT EXISTS orion_solicitudes_cupos (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 seccion_id BIGINT UNSIGNED NOT NULL,
 cupos_solicitados SMALLINT UNSIGNED NOT NULL,
 motivo TEXT NOT NULL,
 estado ENUM('PENDIENTE','APROBADA','RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
 solicitado_por BIGINT UNSIGNED NOT NULL,
 resuelto_por BIGINT UNSIGNED NULL,
 observacion_resolucion TEXT NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 resolved_at DATETIME NULL,
 INDEX idx_orion_cupos_estado (estado,created_at),
 CONSTRAINT fk_orion_cupos_seccion FOREIGN KEY (seccion_id) REFERENCES secciones(id),
 CONSTRAINT fk_orion_cupos_solicitante FOREIGN KEY (solicitado_por) REFERENCES usuarios(id),
 CONSTRAINT fk_orion_cupos_resolutor FOREIGN KEY (resuelto_por) REFERENCES usuarios(id),
 CONSTRAINT chk_orion_cupos_positivos CHECK (cupos_solicitados > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
