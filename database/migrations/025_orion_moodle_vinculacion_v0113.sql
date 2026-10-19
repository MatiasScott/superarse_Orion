-- Orion v0.11.3: vínculo a nivel oferta+asignatura, independiente de paralelos.
-- No altera tablas históricas ni cursos Moodle.
CREATE TABLE IF NOT EXISTS orion_moodle_vinculos_asignatura (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 oferta_academica_id BIGINT UNSIGNED NOT NULL,
 asignatura_id BIGINT UNSIGNED NOT NULL,
 periodo_academico_id BIGINT UNSIGNED NOT NULL,
 moodle_course_id BIGINT UNSIGNED NOT NULL,
 moodle_category_id BIGINT UNSIGNED NOT NULL,
 fullname_moodle VARCHAR(255) NOT NULL,
 shortname_moodle VARCHAR(255) NOT NULL,
 idnumber_moodle VARCHAR(255) NULL,
 creado_por BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_orion_moodle_oferta_asignatura (oferta_academica_id, asignatura_id),
 UNIQUE KEY uq_orion_moodle_curso (moodle_course_id),
 KEY idx_orion_moodle_periodo (periodo_academico_id),
 CONSTRAINT fk_orion_moodle_oferta FOREIGN KEY (oferta_academica_id) REFERENCES ofertas_academicas(id),
 CONSTRAINT fk_orion_moodle_asignatura FOREIGN KEY (asignatura_id) REFERENCES asignaturas(id),
 CONSTRAINT fk_orion_moodle_periodo FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
