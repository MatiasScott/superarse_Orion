-- Orion v0.11.5: auditoría de cursos creados desde TIC
CREATE TABLE IF NOT EXISTS orion_moodle_curso_sync_log (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 periodo_academico_id BIGINT UNSIGNED NOT NULL,
 oferta_academica_id BIGINT UNSIGNED NOT NULL,
 asignatura_id BIGINT UNSIGNED NOT NULL,
 moodle_course_id BIGINT UNSIGNED NOT NULL,
 moodle_category_id BIGINT UNSIGNED NOT NULL,
 nombre VARCHAR(255) NOT NULL,
 creado_por BIGINT UNSIGNED NULL,
 creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_orion_moodle_curso_creado (moodle_course_id),
 KEY idx_orion_moodle_curso_oferta (oferta_academica_id,asignatura_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
