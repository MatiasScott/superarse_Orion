-- Orion v0.11.4: registro de sincronización de categorías. No modifica tablas Moodle.
CREATE TABLE IF NOT EXISTS orion_moodle_categoria_sync_log (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 periodo_academico_id BIGINT UNSIGNED NOT NULL,
 moodle_category_id BIGINT UNSIGNED NOT NULL,
 moodle_parent_id BIGINT UNSIGNED NOT NULL,
 nombre VARCHAR(255) NOT NULL,
 accion ENUM('CREADA','REUTILIZADA') NOT NULL,
 creado_por BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_moodle_categoria_periodo (periodo_academico_id,created_at),
 INDEX idx_moodle_categoria_id (moodle_category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
