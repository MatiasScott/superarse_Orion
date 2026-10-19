-- Orion v0.11.2. Catálogo de escuelas y relaciones configurables. No modifica Moodle.
CREATE TABLE IF NOT EXISTS escuelas_academicas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(150) NOT NULL,
 activo TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS carrera_escuela_moodle (
 carrera_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 escuela_id BIGINT UNSIGNED NOT NULL,
 CONSTRAINT fk_cem_carrera FOREIGN KEY(carrera_id) REFERENCES carreras(id),
 CONSTRAINT fk_cem_escuela FOREIGN KEY(escuela_id) REFERENCES escuelas_academicas(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS modalidad_categoria_moodle_reglas (
 sede_id BIGINT UNSIGNED NOT NULL,
 carrera_id BIGINT UNSIGNED NOT NULL,
 requiere_modalidad TINYINT(1) NOT NULL DEFAULT 1,
 PRIMARY KEY(sede_id,carrera_id),
 CONSTRAINT fk_mcmr_sede FOREIGN KEY(sede_id) REFERENCES sedes(id),
 CONSTRAINT fk_mcmr_carrera FOREIGN KEY(carrera_id) REFERENCES carreras(id)
) ENGINE=InnoDB;
INSERT INTO escuelas_academicas(codigo,nombre) VALUES
 ('ECSOS','ECSOS'),('ECAVET','ECAVET'),('ECSET','ECSET')
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre);
-- Semillas no destructivas: solamente nombres exactos; revisar ambigüedades.
INSERT IGNORE INTO carrera_escuela_moodle(carrera_id,escuela_id)
SELECT c.id,e.id FROM carreras c JOIN escuelas_academicas e
 ON (e.codigo='ECSOS' AND UPPER(TRIM(c.nombre)) IN ('TOPOGRAFÍA','MINERÍA','SEGURIDAD E HIGIENE DEL TRABAJO','SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES'))
 OR (e.codigo='ECAVET' AND UPPER(TRIM(c.nombre)) IN ('ENFERMERÍA VETERINARIA','PRODUCCIÓN ANIMAL'))
 OR (e.codigo='ECSET' AND UPPER(TRIM(c.nombre)) IN ('ADMINISTRACIÓN','MARKETING DIGITAL','MARKETING DIGITAL Y DISEÑO MULTIMEDIA','EDUCACIÓN BÁSICA','EDUCACIÓN BILINGÜE'));
-- Regla especial solo para la carrera y sede indicadas, por nombre exacto.
INSERT IGNORE INTO modalidad_categoria_moodle_reglas(sede_id,carrera_id,requiere_modalidad)
SELECT s.id,c.id,1 FROM sedes s CROSS JOIN carreras c
WHERE UPPER(TRIM(s.nombre)) IN ('CAMPUS MATRIZ','MATRIZ')
 AND UPPER(TRIM(c.nombre))='ENFERMERÍA VETERINARIA';
-- Auditoría manual recomendada tras instalar:
SELECT c.id,c.nombre,COALESCE(e.codigo,'SIN ESCUELA') escuela
 FROM carreras c LEFT JOIN carrera_escuela_moodle ce ON ce.carrera_id=c.id
 LEFT JOIN escuelas_academicas e ON e.id=ce.escuela_id ORDER BY c.nombre;
