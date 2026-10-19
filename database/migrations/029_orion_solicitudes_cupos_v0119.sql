-- Orion v0.11.9: ejecutar UNA VEZ en superarse_siga; respaldo previo obligatorio.
CREATE TABLE IF NOT EXISTS solicitudes_ampliacion_cupos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 seccion_id BIGINT UNSIGNED NOT NULL,
 cantidad_solicitada INT UNSIGNED NOT NULL,
 motivo TEXT NOT NULL,
 estado ENUM('PENDIENTE','APROBADA','RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
 solicitado_por_usuario_id BIGINT UNSIGNED NOT NULL,
 solicitado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 resuelto_por_usuario_id BIGINT UNSIGNED NULL,
 resuelto_en DATETIME NULL,
 observacion_resolucion TEXT NULL,
 cupo_anterior INT UNSIGNED NULL,
 cupo_nuevo INT UNSIGNED NULL,
 INDEX idx_estado (estado,solicitado_en), INDEX idx_seccion (seccion_id),
 CONSTRAINT chk_cupos_cantidad CHECK (cantidad_solicitada > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
