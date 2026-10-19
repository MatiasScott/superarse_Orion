-- Orion v0.11.12: solicitudes por cohorte, separadas de solicitudes históricas por sección.
-- Ejecutar una sola vez, previa copia de seguridad.
CREATE TABLE IF NOT EXISTS solicitudes_cupos_cohorte (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 oferta_academica_id BIGINT UNSIGNED NOT NULL,
 nivel_academico_id BIGINT UNSIGNED NOT NULL,
 paralelo_id BIGINT UNSIGNED NOT NULL,
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
 INDEX idx_cohorte (oferta_academica_id,nivel_academico_id,paralelo_id,estado),
 INDEX idx_estado_fecha (estado,solicitado_en),
 CONSTRAINT chk_cohorte_cantidad CHECK (cantidad_solicitada > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
