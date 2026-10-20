-- Orion v0.11.22: vinculación explícita por ID de grupo Moodle.
-- Ejecutar una vez en la base de datos Orion antes de habilitar la acción.
CREATE TABLE IF NOT EXISTS orion_moodle_vinculos_grupo (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  seccion_id BIGINT UNSIGNED NOT NULL,
  moodle_course_id BIGINT UNSIGNED NOT NULL,
  moodle_group_id BIGINT UNSIGNED NOT NULL,
  nombre_grupo VARCHAR(255) NOT NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_orion_moodle_grupo_seccion (seccion_id),
  UNIQUE KEY uq_orion_moodle_grupo_curso_id (moodle_course_id,moodle_group_id),
  KEY idx_orion_moodle_grupo_curso (moodle_course_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
