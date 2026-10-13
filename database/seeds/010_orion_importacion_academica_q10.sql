-- ============================================================
-- Orion v0.7.1 - Importación académica Q10
-- Fuente: exportación Q10 entregada 2026-10-02
-- MySQL 8.x
--
-- IMPORTA:
--   * 16 carreras institucionales (18 programas Q10; ALP/Matriz consolidados)
--   * sedes Matriz / Alpallana y relación carrera-sede
--   * 27 mallas académicas únicas (28 registros fuente; 1 duplicado exacto consolidado)
--   * 568 asignaturas maestras únicas
--   * 593 relaciones fuente malla-asignatura
--   * créditos, IH semanal e IH total
--   * trazabilidad Q10 para la futura migración de notas
--
-- NO IMPORTA:
--   * prerrequisitos (se cargarán manualmente)
--   * modalidad a partir de H/L del código Q10: ese marcador se conserva
--     como dato fuente, pero no se interpreta automáticamente.
--
-- El script es re-ejecutable: usa claves de negocio y tablas de trazabilidad.
-- ============================================================
USE superarse_siga;
SET NAMES utf8mb4;
SET @OLD_SQL_SAFE_UPDATES := @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

SET @institucion_id := (
 SELECT id FROM instituciones
 WHERE codigo='SUPERARSE' AND deleted_at IS NULL
 ORDER BY id LIMIT 1
);

-- Sedes necesarias. Primero reutiliza registros existentes por nombre.
INSERT INTO sedes(institucion_id,codigo,nombre,activo)
SELECT @institucion_id,'MATRIZ','Matriz',1
WHERE @institucion_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM sedes
    WHERE institucion_id=@institucion_id AND deleted_at IS NULL
      AND UPPER(nombre)=UPPER('Matriz')
  );

INSERT INTO sedes(institucion_id,codigo,nombre,activo)
SELECT @institucion_id,'ALPALLANA','Alpallana',1
WHERE @institucion_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM sedes
    WHERE institucion_id=@institucion_id AND deleted_at IS NULL
      AND UPPER(nombre)=UPPER('Alpallana')
  );

-- Q10 contiene nivel "Único" en componentes fuera de nivel.
INSERT INTO niveles_academicos(codigo,nombre,orden_nivel,activo)
SELECT 'UNICO','Único',99,1
WHERE NOT EXISTS (SELECT 1 FROM niveles_academicos WHERE codigo='UNICO');

-- Relación malla-sede: el esquema 005 no la tenía y es necesaria para
-- distinguir mallas de la misma carrera ofertadas en Matriz/Alpallana.
CREATE TABLE IF NOT EXISTS malla_sedes (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 malla_id BIGINT UNSIGNED NOT NULL,
 sede_id BIGINT UNSIGNED NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 CONSTRAINT uq_malla_sede UNIQUE(malla_id,sede_id),
 CONSTRAINT fk_malla_sedes_malla FOREIGN KEY(malla_id) REFERENCES mallas_curriculares(id),
 CONSTRAINT fk_malla_sedes_sede FOREIGN KEY(sede_id) REFERENCES sedes(id)
) ENGINE=InnoDB;

-- Trazabilidad permanente para poder migrar después estudiantes/notas Q10.
CREATE TABLE IF NOT EXISTS migracion_q10_programas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 q10_programa_codigo VARCHAR(100) NOT NULL,
 q10_programa_nombre VARCHAR(255) NOT NULL,
 q10_nombre_id VARCHAR(255) NULL,
 carrera_id BIGINT UNSIGNED NOT NULL,
 sede_id BIGINT UNSIGNED NULL,
 marcador_modalidad_q10 VARCHAR(20) NULL,
 resolucion VARCHAR(150) NULL,
 fecha_resolucion DATE NULL,
 estado_q10 VARCHAR(50) NULL,
 categoria_q10 VARCHAR(255) NULL,
 imported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_mig_q10_programa UNIQUE(q10_programa_codigo,q10_programa_nombre),
 CONSTRAINT fk_mig_q10_programa_carrera FOREIGN KEY(carrera_id) REFERENCES carreras(id),
 CONSTRAINT fk_mig_q10_programa_sede FOREIGN KEY(sede_id) REFERENCES sedes(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migracion_q10_mallas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 migracion_q10_programa_id BIGINT UNSIGNED NOT NULL,
 q10_malla_orden SMALLINT UNSIGNED NOT NULL,
 q10_malla_nombre VARCHAR(255) NOT NULL,
 malla_id BIGINT UNSIGNED NOT NULL,
 nota_aprobacion DECIMAL(5,2) NULL,
 nota_minima_supletorio DECIMAL(5,2) NULL,
 peso_supletorio DECIMAL(5,2) NULL,
 imported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_mig_q10_malla UNIQUE(migracion_q10_programa_id,q10_malla_orden),
 CONSTRAINT fk_mig_q10_malla_programa FOREIGN KEY(migracion_q10_programa_id) REFERENCES migracion_q10_programas(id),
 CONSTRAINT fk_mig_q10_malla_malla FOREIGN KEY(malla_id) REFERENCES mallas_curriculares(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migracion_q10_asignaturas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 migracion_q10_malla_id BIGINT UNSIGNED NOT NULL,
 q10_asignatura_codigo VARCHAR(100) NOT NULL,
 q10_asignatura_nombre VARCHAR(255) NOT NULL,
 malla_asignatura_id BIGINT UNSIGNED NOT NULL,
 imported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_mig_q10_asig UNIQUE(migracion_q10_malla_id,q10_asignatura_codigo),
 CONSTRAINT fk_mig_q10_asig_malla FOREIGN KEY(migracion_q10_malla_id) REFERENCES migracion_q10_mallas(id),
 CONSTRAINT fk_mig_q10_asig_rel FOREIGN KEY(malla_asignatura_id) REFERENCES malla_asignaturas(id)
) ENGINE=InnoDB;

DROP TEMPORARY TABLE IF EXISTS _q10_programas;
CREATE TEMPORARY TABLE _q10_programas(
 src_id INT PRIMARY KEY,
 q10_nombre VARCHAR(255) NOT NULL,
 q10_codigo VARCHAR(100) NOT NULL,
 q10_nombre_id VARCHAR(255) NULL,
 carrera_nombre VARCHAR(255) NOT NULL,
 carrera_codigo VARCHAR(60) NOT NULL,
 sede_codigo VARCHAR(30) NOT NULL,
 tipo_carrera_codigo VARCHAR(50) NOT NULL,
 marcador_modalidad VARCHAR(20) NULL,
 resolucion VARCHAR(150) NULL,
 fecha_resolucion DATE NULL,
 estado_q10 VARCHAR(50) NULL,
 categoria_q10 VARCHAR(255) NULL
) ENGINE=InnoDB;


INSERT INTO _q10_programas (src_id,q10_nombre,q10_codigo,q10_nombre_id,carrera_nombre,carrera_codigo,sede_codigo,tipo_carrera_codigo,marcador_modalidad,resolucion,fecha_resolucion,estado_q10,categoria_q10) VALUES

('1','ADMINISTRACIÓN','540413A01-L 1705','ADMINISTRACIÓN','ADMINISTRACIÓN','Q10_ADMINISTRACION','MATRIZ','TECNICO_SUPERIOR','L','RPC-SO-45-N.727-2024','2024-11-07','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('2','ASISTENCIA PEDAGOGICA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','550111A01-H-1705','ASISTENCIA PEDAGOGICA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','ASISTENCIA PEDAGOGICA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','Q10_ASISTENCIA_PEDAGOGICA_CON_NIVEL_EQUIVALENTE_A_TECN','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SE-11-N.107-2020','2022-02-11','Activo','Educación y formación'),
('3','EDUCACIÓN BÁSICA','550113A01-H-1705','EDUCACIÓN BÁSICA','EDUCACIÓN BÁSICA','Q10_EDUCACION_BASICA','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-03-No.039-202','2023-01-18','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('4','EDUCACION BILINGÜE - ALP','550111H01-H-1701','EDUCACION BILINGÜE-ALPALLANA','EDUCACION BILINGÜE','Q10_EDUCACION_BILINGUE','ALPALLANA','TECNOLOGIA_SUPERIOR','H','RPC-SO-36-No.594-202','2024-09-04','Activo','Educación y formación'),
('5','EDUCACION BILINGÜE - MATRÍZ','550111H01-H-1705','EDUCACION BILINGÜE','EDUCACION BILINGÜE','Q10_EDUCACION_BILINGUE','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-36-No.594-202','2024-09-04','Activo','Educación y formación'),
('6','ENFERMERÍA VETERINARIA - ALP','550841C01-H-1701','ENFERMERÍA VETERINARIA-ALPALLANA','ENFERMERÍA VETERINARIA','Q10_ENFERMERIA_VETERINARIA','ALPALLANA','TECNOLOGIA_SUPERIOR','H','RPC-SO-26-No.429-202','2024-06-26','Activo','Agropecuario, silvicultura, pesca, acuicultura y veterinaria'),
('7','ENFERMERÍA VETERINARIA - MATRÍZ','550841C01-H-1705','ENFERMERÍA VETERINARIA','ENFERMERÍA VETERINARIA','Q10_ENFERMERIA_VETERINARIA','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-26-No.429-202','2024-06-26','Activo','Agropecuario, silvicultura, pesca, acuicultura y veterinaria'),
('8','MARKETING DIGITAL','540414G01-L-1705','MARKETING DIGITAL','MARKETING DIGITAL','Q10_MARKETING_DIGITAL','MATRIZ','TECNICO_SUPERIOR','L','RPC-SO-47-No721-2025','2025-12-03','Activo','Comercio, mercadeo y publicidad'),
('9','MARKETING DIGITAL Y DISEÑO MULTIMEDIA','550414M01-L-1705','MARKETING DIGITAL Y DISEÑO MULTIMEDIA','MARKETING DIGITAL Y DISEÑO MULTIMEDIA','Q10_MARKETING_DIGITAL_Y_DISENO_MULTIMEDIA','MATRIZ','TECNOLOGIA_SUPERIOR','L','RPC-SO-07-No109-2026','2026-02-20','Activo','Comercio, mercadeo y publicidad'),
('10','MINERÍA','550724B01-H-1705','MINERÍA','MINERÍA','Q10_MINERIA','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-50-No.796-202','2022-12-14','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('11','PRODUCCIÓN ANIMAL','550811D01-H-1705','PRODUCCIÓN ANIMAL','PRODUCCIÓN ANIMAL','Q10_PRODUCCION_ANIMAL','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-28-N.469-2024','2024-07-10','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('12','SEGURIDAD E HIGIENE DEL TRABAJO','551022C02-L 1705','SEGURIDAD E HIGIENE DEL TRABAJO','SEGURIDAD E HIGIENE DEL TRABAJO','Q10_SEGURIDAD_E_HIGIENE_DEL_TRABAJO','MATRIZ','TECNOLOGIA_SUPERIOR','L','RPC-SO-01-N.001-2025','2025-01-08','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('13','SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES','541022B01-L-1705','SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES','SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES','Q10_SEGURIDAD_Y_PREVENCION_DE_RIESGOS_LABORALES','MATRIZ','TECNICO_SUPERIOR','L','RPC-SO-42-No.685-202','2024-10-16','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('14','TÉCNICO SUPERIOR EN ADMINISTRACIÓN','540413A01-L-1705','TÉCNICO SUPERIOR EN ADMINISTRACIÓN','TÉCNICO SUPERIOR EN ADMINISTRACIÓN','Q10_TECNICO_SUPERIOR_EN_ADMINISTRACION','MATRIZ','TECNICO_SUPERIOR','L','RPC-SE-11-N.107-2020','2022-02-11','Activo','Educación y formación'),
('15','TÉCNICO SUPERIOR EN MARKETING DIGITAL','540414J01-L-1705','TÉCNICO SUPERIOR EN MARKETING DIGITAL','TÉCNICO SUPERIOR EN MARKETING DIGITAL','Q10_TECNICO_SUPERIOR_EN_MARKETING_DIGITAL','MATRIZ','TECNICO_SUPERIOR','L','RPC-SE-19-No.129-202','2020-11-05','Activo','Asignar asignatura  Editar pensum  Eliminar pensum'),
('16','TECNOLOGÍA SUPERIOR EN CUIDADO CANINO','550841B01-H-1705','TECNOLOGÍA SUPERIOR EN CUIDADO CANINO','TECNOLOGÍA SUPERIOR EN CUIDADO CANINO','Q10_TECNOLOGIA_SUPERIOR_EN_CUIDADO_CANINO','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SE-11-N.107-2020','2022-02-11','Activo','Educación y formación'),
('17','TECNOLOGÍA SUPERIOR EN PRODUCCIÓN ANIMAL','550811F01-H-1705','TECNOLOGÍA SUPERIOR EN PRODUCCIÓN ANIMAL','TECNOLOGÍA SUPERIOR EN PRODUCCIÓN ANIMAL','Q10_TECNOLOGIA_SUPERIOR_EN_PRODUCCION_ANIMAL','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SE-11-N.107-2020','2022-02-11','Activo','Educación y formación'),
('18','TOPOGRAFÍA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','550532A01-H-1705','TOPOGRAFÍA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','TOPOGRAFÍA CON NIVEL EQUIVALENTE A TECNOLOGIA SUPERIOR','Q10_TOPOGRAFIA_CON_NIVEL_EQUIVALENTE_A_TECNOLOGIA_SUPE','MATRIZ','TECNOLOGIA_SUPERIOR','H','RPC-SO-12-No.320-202','2021-06-16','Activo','Asignar asignatura  Editar pensum  Eliminar pensum');


-- Carreras: reutiliza por nombre exacto (p.ej. ADMINISTRACIÓN ya creada manualmente).
INSERT INTO carreras(
 institucion_id,tipo_carrera_id,estado_carrera_id,codigo,nombre,
 numero_niveles,fecha_inicio_vigencia,activo
)
SELECT
 @institucion_id,
 tc.id,
 ec.id,
 p.carrera_codigo,
 p.carrera_nombre,
 CASE WHEN p.tipo_carrera_codigo='TECNICO_SUPERIOR' THEN 2 ELSE 4 END,
 MIN(p.fecha_resolucion),
 1
FROM _q10_programas p
JOIN tipos_carrera tc ON tc.codigo=p.tipo_carrera_codigo
JOIN estados_carrera ec ON ec.codigo='ACTIVA'
WHERE NOT EXISTS(
 SELECT 1 FROM carreras c
 WHERE c.institucion_id=@institucion_id AND c.deleted_at IS NULL
   AND UPPER(TRIM(c.nombre))=UPPER(TRIM(p.carrera_nombre))
)
GROUP BY p.carrera_codigo,p.carrera_nombre,tc.id,ec.id,p.tipo_carrera_codigo;

-- Carrera-sede.
INSERT IGNORE INTO carrera_sedes(carrera_id,sede_id,fecha_inicio,activo)
SELECT DISTINCT c.id,s.id,MIN(p.fecha_resolucion),1
FROM _q10_programas p
JOIN carreras c ON c.institucion_id=@institucion_id AND c.deleted_at IS NULL
 AND UPPER(TRIM(c.nombre))=UPPER(TRIM(p.carrera_nombre))
JOIN sedes s ON s.institucion_id=@institucion_id AND s.deleted_at IS NULL
 AND s.codigo=p.sede_codigo
GROUP BY c.id,s.id;

-- Trazabilidad de programas.
INSERT INTO migracion_q10_programas(
 q10_programa_codigo,q10_programa_nombre,q10_nombre_id,carrera_id,sede_id,
 marcador_modalidad_q10,resolucion,fecha_resolucion,estado_q10,categoria_q10
)
SELECT p.q10_codigo,p.q10_nombre,p.q10_nombre_id,c.id,s.id,p.marcador_modalidad,
       p.resolucion,p.fecha_resolucion,p.estado_q10,p.categoria_q10
FROM _q10_programas p
JOIN carreras c ON c.institucion_id=@institucion_id AND c.deleted_at IS NULL
 AND UPPER(TRIM(c.nombre))=UPPER(TRIM(p.carrera_nombre))
LEFT JOIN sedes s ON s.institucion_id=@institucion_id AND s.deleted_at IS NULL
 AND s.codigo=p.sede_codigo
WHERE NOT EXISTS(
 SELECT 1 FROM migracion_q10_programas x
 WHERE x.q10_programa_codigo=p.q10_codigo AND x.q10_programa_nombre=p.q10_nombre
);

DROP TEMPORARY TABLE IF EXISTS _q10_mallas;
CREATE TEMPORARY TABLE _q10_mallas(
 src_programa_id INT NOT NULL,
 q10_malla_orden INT NOT NULL,
 canon_id INT NOT NULL,
 malla_codigo VARCHAR(80) NOT NULL,
 malla_nombre VARCHAR(255) NOT NULL,
 estado_malla_codigo VARCHAR(50) NOT NULL,
 nota_aprobacion DECIMAL(5,2) NULL,
 nota_minima_supletorio DECIMAL(5,2) NULL,
 peso_supletorio DECIMAL(5,2) NULL,
 PRIMARY KEY(src_programa_id,q10_malla_orden)
) ENGINE=InnoDB;


INSERT INTO _q10_mallas (src_programa_id,q10_malla_orden,canon_id,malla_codigo,malla_nombre,estado_malla_codigo,nota_aprobacion,nota_minima_supletorio,peso_supletorio) VALUES

('1','1','1','Q10-01-M01','MALLA CURRICULAR VIGENTE ADMINISTRACIÓN','VIGENTE','7','5','100'),
('2','1','2','Q10-02-M01','MALLA CURRICULAR NO VIGENTE ASISTECIA PEDAGÓGICA CON NIVEL EQUIVALENTE A TECNOLOGÍA SUPERIOR','NO_VIGENTE','7',NULL,NULL),
('3','1','3','Q10-03-M01','MALLA CURRICULAR VIGENTE EDUCACIÓN BÁSICA','VIGENTE','7','5','100'),
('3','2','4','Q10-03-M02','MALLA CURRICULAR NO VIGENTE EDUCACIÓN BÁSICA','NO_VIGENTE','7','5','70'),
('4','1','5','Q10-04-M01','MALLA CURRICULAR DE EDUCACIÓN BILINGÜE-RED-ALP','VIGENTE','7','5','70'),
('4','2','6','Q10-04-M02','MALLA CURRICULAR EDUCACION BILINGÜE','NO_VIGENTE','7','6.99','70'),
('4','3','7','Q10-04-M03','MALLA CURRICULAR DE EDUCACIÓN BILINGÜE-RED','VIGENTE','7','5','70'),
('5','1','7','Q10-05-M01','MALLA CURRICULAR DE EDUCACIÓN BILINGÜE-RED','VIGENTE','7','5','70'),
('5','2','8','Q10-05-M02','PENSUM','NO_VIGENTE','7',NULL,NULL),
('6','1','9','Q10-06-M01','MALLA CURRICULAR REDISEÑO ENFERMERIA VETERINARIA-ALP','VIGENTE','7','5','70'),
('6','2','10','Q10-06-M02','MALLA CURRICULAR ENFERMERIA VETERINARIA','NO_VIGENTE','7','5','100'),
('7','1','11','Q10-07-M01','MALLA CURRICULAR REDISEÑO ENFERMERIA VETERINARIA','VIGENTE','7','5','70'),
('7','2','12','Q10-07-M02','MALLA CURRICULAR VIGENTE ENFERMERÍA VETERINARIA','VIGENTE','7','5','100'),
('8','1','13','Q10-08-M01','PENSUN','VIGENTE','7','5','100'),
('9','1','14','Q10-09-M01','PENSUN','VIGENTE','7',NULL,NULL),
('10','1','15','Q10-10-M01','MALLA CURRICULAR REDISEÑO MINERÍA','VIGENTE','7','5','100'),
('10','2','16','Q10-10-M02','MALLA CURRICULAR MINERÍA','NO_VIGENTE','7','5','100'),
('11','1','17','Q10-11-M01','MALLA CURRICULAR DE PRODUCCIÓN ANIMAL-REDISEÑO','VIGENTE','7','5','70'),
('11','2','18','Q10-11-M02','MALLA CURRICULAR VIGENTE PRODUCCIÓN ANIMAL','VIGENTE','7','5','100'),
('12','1','19','Q10-12-M01','MALLA REDISEÑO SEGURIDAD E HIGIENE DEL TRABAJO','VIGENTE','7','5','70'),
('12','2','20','Q10-12-M02','PENSUM','NO_VIGENTE','7',NULL,NULL),
('13','1','21','Q10-13-M01','MALLA CURRICULAR CARRERA EN SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES','VIGENTE','7','5','100'),
('14','1','22','Q10-14-M01','MALLA CURRICULAR NO VIGENTE ADMINISTRACIÓN','NO_VIGENTE','7',NULL,NULL),
('15','1','23','Q10-15-M01','MALLA CURRICULAR VIGENTE MARKETING DIGITAL','VIGENTE','7','5','70'),
('16','1','24','Q10-16-M01','MALLA CURRICULAR NO VIGENTE CUIDADO CANINO','NO_VIGENTE','7','5','100'),
('17','1','25','Q10-17-M01','MALLA CURRICULAR NO VIGENTE PRODUCCIÓN ANIMAL','NO_VIGENTE','7','5','100'),
('18','1','26','Q10-18-M01','MALLA CURRICULAR REDISEÑO TOPOGRAFÍA','VIGENTE','7','5','100'),
('18','2','27','Q10-18-M02','MALLA CURRICULAR TOPOGRAFÍA','NO_VIGENTE','7','5','100');


DROP TEMPORARY TABLE IF EXISTS _q10_mallas_canon;
CREATE TEMPORARY TABLE _q10_mallas_canon(
 canon_id INT PRIMARY KEY,
 src_programa_id INT NOT NULL,
 q10_malla_orden INT NOT NULL
) ENGINE=InnoDB;


INSERT INTO _q10_mallas_canon (canon_id,src_programa_id,q10_malla_orden) VALUES

('1','1','1'),
('2','2','1'),
('3','3','1'),
('4','3','2'),
('5','4','1'),
('6','4','2'),
('7','4','3'),
('8','5','2'),
('9','6','1'),
('10','6','2'),
('11','7','1'),
('12','7','2'),
('13','8','1'),
('14','9','1'),
('15','10','1'),
('16','10','2'),
('17','11','1'),
('18','11','2'),
('19','12','1'),
('20','12','2'),
('21','13','1'),
('22','14','1'),
('23','15','1'),
('24','16','1'),
('25','17','1'),
('26','18','1'),
('27','18','2');


-- Mallas únicas. La fecha de resolución del programa se usa como fecha técnica
-- de inicio porque la exportación Q10 no trae una fecha de vigencia de cada malla.
INSERT INTO mallas_curriculares(
 carrera_id,estado_malla_id,codigo,nombre,version,descripcion,
 fecha_inicio_vigencia,activo
)
SELECT
 mp.carrera_id,
 em.id,
 CONCAT('Q10-',LPAD(c.canon_id,3,'0')),
 LEFT(m.malla_nombre,180),
 CONCAT('Q10-',LPAD(c.canon_id,3,'0')),
 CONCAT('Importada desde Q10. Programa fuente: ',mp.q10_programa_nombre,
        '. Resolución: ',COALESCE(mp.resolucion,'N/D'),
        '. La exportación Q10 no incluye fecha propia de vigencia de la malla.'),
 COALESCE(mp.fecha_resolucion,'2000-01-01'),
 1
FROM _q10_mallas_canon c
JOIN _q10_mallas m ON m.src_programa_id=c.src_programa_id AND m.q10_malla_orden=c.q10_malla_orden
JOIN _q10_programas p ON p.src_id=c.src_programa_id
JOIN migracion_q10_programas mp ON mp.q10_programa_codigo=p.q10_codigo AND mp.q10_programa_nombre=p.q10_nombre
JOIN estados_malla em ON em.codigo=m.estado_malla_codigo
WHERE NOT EXISTS(
 SELECT 1 FROM mallas_curriculares mc
 WHERE mc.carrera_id=mp.carrera_id AND mc.codigo=CONCAT('Q10-',LPAD(c.canon_id,3,'0'))
);

-- Mapeo de cada pensum Q10 a su malla Orion.
INSERT INTO migracion_q10_mallas(
 migracion_q10_programa_id,q10_malla_orden,q10_malla_nombre,malla_id,
 nota_aprobacion,nota_minima_supletorio,peso_supletorio
)
SELECT mp.id,m.q10_malla_orden,m.malla_nombre,mc.id,
       m.nota_aprobacion,m.nota_minima_supletorio,m.peso_supletorio
FROM _q10_mallas m
JOIN _q10_programas p ON p.src_id=m.src_programa_id
JOIN migracion_q10_programas mp ON mp.q10_programa_codigo=p.q10_codigo AND mp.q10_programa_nombre=p.q10_nombre
JOIN mallas_curriculares mc ON mc.carrera_id=mp.carrera_id
 AND mc.codigo=CONCAT('Q10-',LPAD(m.canon_id,3,'0'))
WHERE NOT EXISTS(
 SELECT 1 FROM migracion_q10_mallas x
 WHERE x.migracion_q10_programa_id=mp.id AND x.q10_malla_orden=m.q10_malla_orden
);

-- Relación malla-sede derivada del programa Q10.
INSERT IGNORE INTO malla_sedes(malla_id,sede_id,activo)
SELECT DISTINCT mm.malla_id,mp.sede_id,1
FROM migracion_q10_mallas mm
JOIN migracion_q10_programas mp ON mp.id=mm.migracion_q10_programa_id
WHERE mp.sede_id IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS _q10_asignaturas;
CREATE TEMPORARY TABLE _q10_asignaturas(
 src_programa_id INT NOT NULL,
 q10_malla_orden INT NOT NULL,
 canon_id INT NOT NULL,
 orden_en_nivel INT NOT NULL,
 codigo VARCHAR(100) NOT NULL,
 nombre VARCHAR(255) NOT NULL,
 nivel_codigo VARCHAR(30) NOT NULL,
 creditos DECIMAL(6,2) NOT NULL,
 ih_semanal DECIMAL(6,2) NULL,
 ih_total DECIMAL(8,2) NULL,
 tipo_codigo VARCHAR(60) NOT NULL,
 KEY idx_q10_asig_codigo(codigo)
) ENGINE=InnoDB;


INSERT INTO _q10_asignaturas (src_programa_id,q10_malla_orden,canon_id,orden_en_nivel,codigo,nombre,nivel_codigo,creditos,ih_semanal,ih_total,tipo_codigo) VALUES

('1','1','1','1','UP01-04-ADM-MN','Administración del Talento Humano y Nómina-ADM-MN-N1','N1','3','9','144','ACADEMICA'),
('1','1','1','2','UP01-05-ADM-MN','Administración Tributaria-ADM-MN-N1','N1','3','9','144','ACADEMICA'),
('1','1','1','3','UP01-02-ADM-MN','Asistencia Administrativa-ADM-MN-N1','N1','2','6','96','ACADEMICA'),
('1','1','1','4','UP01-03-ADM-MN','Contabilidad Computarizada-ADM-MN-N1','N1','3','9','144','ACADEMICA'),
('1','1','1','5','UB01-01-ADM-MN','Fundamentos de la Administración-ADM-MN-N1','N1','2','6','96','ACADEMICA'),
('1','1','1','6','COMP-VINC-ADM-MN','Vinculación con la sociedad-ADM-MN','N1','2','6','96','VINCULACION'),
('1','1','1','7','UP02-02-ADM-MN','Administración de almacenamiento e inventarios-ADM-MN-N2','N2','4','12','192','ACADEMICA'),
('1','1','1','8','UP02-01-ADM-MN','Análisis Financiero-ADM-MN-N2','N2','2','6','96','ACADEMICA'),
('1','1','1','9','UI02-05-ADM-MN','Desarrollo del trabajo de titulación-ADM-MN-N2','N2','2','6','96','TITULACION'),
('1','1','1','10','UP02-03-ADM-MN','Gestión de Costos-ADM-MN-N2','N2','3','9','144','ACADEMICA'),
('1','1','1','11','UP02-04-ADM-MN','Importaciones y Exportaciones-ADM-MN-N2','N2','4','12','192','ACADEMICA'),
('1','1','1','12','PP-ADM-MN','Prácticas Preprofesionales-ADM-MN','N2','4','12','192','PRACTICAS'),
('2','1','2','1','UB01-05-ASISP','Crianza y cuidado de la infancia-ASISP-N1','N1','3','9','144','ACADEMICA'),
('2','1','2','2','UB01-02-ASISP','Desarrollo del lenguaje y del pensamiento-ASISP-N1','N1','2','6','96','ACADEMICA'),
('2','1','2','3','UB01-01-ASISP','Matemática-ASISP-N1','N1','2','6','96','ACADEMICA'),
('2','1','2','4','UB01-03-ASISP','Modelos pedagógicos-ASISP-N1','N1','4','12','192','ACADEMICA'),
('2','1','2','5','UB01-04-ASISP','Psicología del desarrollo I-ASISP-N1','N1','4','12','192','ACADEMICA'),
('2','1','2','6','UP02-02-ASISP','Metodología de la investigación-ASISP-N2','N2','2','6','96','ACADEMICA'),
('2','1','2','7','UP02-05-ASISP','Pedagogías alternativas-ASISP-N2','N2','3','9','144','ACADEMICA'),
('2','1','2','8','UP02-04-ASISP','Psicología del desarrollo II-ASISP-N2','N2','3','9','144','ACADEMICA'),
('2','1','2','9','UP02-03-ASISP','Psicomotricidad-ASISP-N2','N2','3','9','144','ACADEMICA'),
('2','1','2','10','UP02-01-ASISP','Realidad nacional-ASISP-N2','N2','2','6','96','ACADEMICA'),
('2','1','2','11','COMP-VINC-ASISP','Vinculación con la sociedad - ASISP','N2','2','6','96','VINCULACION'),
('2','1','2','12','UP03-04-ASISP','Didáctica I-ASISP-N3','N3','2','6','96','ACADEMICA'),
('2','1','2','13','UP03-05-ASISP','Educomunicación y TICs-ASISP-N3','N3','2','6','96','ACADEMICA'),
('2','1','2','14','UP03-02-ASISP','Estimulación temprana-ASISP-N3','N3','2','6','96','ACADEMICA'),
('2','1','2','15','UP03-01-ASISP','Ética, leyes y conexos-ASISP-N3','N3','2','6','96','ACADEMICA'),
('2','1','2','16','UP03-03-ASISP','Planificación y programación curricular-ASISP-N3','N3','2','6','96','ACADEMICA'),
('2','1','2','17','PP-ASISP','Prácticas Preprofesionales - ASISP','N3','5','15','240','PRACTICAS'),
('2','1','2','18','UI04-05-ASISP','Desarrollo del trabajo de titulación-ASISP-N4','N4','2','6','96','TITULACION'),
('2','1','2','19','UI04-04-ASISP','Didáctica II-ASISP-N4','N4','4','12','192','TITULACION'),
('2','1','2','20','UI04-03-ASISP','Dificultades de aprendizaje e inclusión-ASISP-N4','N4','3','9','144','TITULACION'),
('2','1','2','21','UI04-01-ASISP','Expresión artística y musical-ASISP-N4','N4','3','9','144','TITULACION'),
('2','1','2','22','UI04-02-ASISP','Metodologías lúdicas e innovadoras-ASISP-N4','N4','3','9','144','TITULACION'),
('3','1','3','1','UB01-02-EDUB-RED','Desarrollo del Lenguaje y del Pensamiento-EDUB-RED-N1','N1','2','6','96','ACADEMICA'),
('3','1','3','2','UB01-01-EDUB-RED','Matemáticas-EDUB-RED-N1','N1','2','6','96','ACADEMICA'),
('3','1','3','3','UB01-03-EDUB-RED','Modelos Pedagógicos-EDUB-RED-N1','N1','4','12','192','ACADEMICA'),
('3','1','3','4','UB01-05-EDUB-RED','Normativa y Legislación Aplicada-EDUB-RED-N1','N1','3','9','144','ACADEMICA'),
('3','1','3','5','UB01-04-EDUB-RED','Psicología del desarrollo I-EDUB-RED-N1','N1','4','12','192','ACADEMICA'),
('3','1','3','6','UP02-01-EDUB-RED','Educación Intercultural-EDUB-RED-N2','N2','3','9','144','ACADEMICA'),
('3','1','3','7','UP02-02-EDUB-RED','Metodología de la Investigación-EDUB-RED-N2','N2','2','6','96','ACADEMICA'),
('3','1','3','8','UP02-05-EDUB-RED','Pedagogías Alternativas-EDUB-RED-N2','N2','3','9','144','ACADEMICA'),
('3','1','3','9','UP02-03-EDUB-RED','Planificación y programación curricular I-EDUB-RED-N2','N2','3','9','144','ACADEMICA'),
('3','1','3','10','UP02-04-EDUB-RED','Psicología del desarrollo II-EDUB-RED-N2','N2','3','9','144','ACADEMICA'),
('3','1','3','11','COMP-SC-EDUB-REDS','Servicio Comunitario - EDUB-RED','N2','1','6','96','VINCULACION'),
('3','1','3','12','UP03-01-EDUB-RED','Dificultades del aprendizaje e inclusión-EDUB-RED-N3','N3','2','6','96','ACADEMICA'),
('3','1','3','13','UP03-05-EDUB-RED','Educomunicación e Inteligencia Artificial-EDUB-RED-N3','N3','2','6','96','ACADEMICA'),
('3','1','3','14','UP03-02-EDUB-RED','Evaluación de los aprendizajes-EDUB-RED-N3','N3','2','6','96','ACADEMICA'),
('3','1','3','15','UP03-04-EDUB-RED','Metodologías Lúdicas e Innovadoras-EDUB-RED-N3','N3','2','6','96','ACADEMICA'),
('3','1','3','16','UP03-03-EDUB-RED','Planificación y Programación Curricular II-EDUB-RED-N3','N3','2','6','96','ACADEMICA'),
('3','1','3','17','PL-EDUB-RED','Prácticas Laborales - EDUB-RED','N3','5','16','240','PRACTICAS'),
('3','1','3','18','UP04-03-EDUB-RED','Adaptaciones Curriculares-EDUB-RED-N4','N4','3','9','144','ACADEMICA'),
('3','1','3','19','UT04-05-EDUB-RED','Desarrollo del trabajo de titulación-EDUB-RED-N4','N4','2','6','96','TITULACION'),
('3','1','3','20','UP04-01-EDUB-RED','Didáctica de la enseñanza de la Matemática-EDUB-RED-N4','N4','3','9','144','ACADEMICA'),
('3','1','3','21','UP04-04-EDUB-RED','Didáctica de la enseñanza de las Ciencias (Naturales y Sociales)-EDUB-RED-N4','N4','4','12','192','ACADEMICA'),
('3','1','3','22','UP04-02-EDUB-RED','Didáctica de la enseñanza de Lengua-EDUB-RED-N4','N4','3','9','144','ACADEMICA'),
('3','2','4','1','UB01-02-EDUB','Desarrollo del lenguaje y del pensamiento-EDUB-N1','N1','2','6','96','ACADEMICA'),
('3','2','4','2','UB01-01-EDUB','Matemática-EDUB-N1','N1','2','6','96','ACADEMICA'),
('3','2','4','3','UB01-03-EDUB','Modelos pedagógicas-EDUB-N1','N1','4','12','192','ACADEMICA'),
('3','2','4','4','UB01-05-EDUB','Normativa y Legislación aplicada-EDUB-N1','N1','3','9','144','ACADEMICA'),
('3','2','4','5','UB01-04-EDUB','Psicología del desarrollo I-EDUB-N1','N1','4','12','192','ACADEMICA'),
('3','2','4','6','UP02-01-EDUB','Educación intercultural-EDUB-N2','N2','3','9','144','ACADEMICA'),
('3','2','4','7','UP02-02-EDUB','Metodología de la Investigación-EDUB-N2','N2','2','6','96','ACADEMICA'),
('3','2','4','8','UB02-05-EDUB','Pedagogías alternativas-EDUB-N2','N2','3','9','144','ACADEMICA'),
('3','2','4','9','UP02-04-EDUB','Psicología del desarrollo II-EDUB-N2','N2','3','9','144','ACADEMICA'),
('3','2','4','10','UP02-03-EDUB','Psicomotricidad-EDUB-N2','N2','3','9','144','ACADEMICA'),
('3','2','4','11','COMP-VINC-EDUCBA','Vinculación con la sociedad-EDUCBA','N2','2','6','96','VINCULACION'),
('3','2','4','12','UP03-01-EDUB','Dificultades del aprendizaje e inclusión-EDUB-N3','N3','2','6','96','ACADEMICA'),
('3','2','4','13','UP03-05-EDUB','Educomunicación y TICs-EDUB-N3','N3','2','6','96','ACADEMICA'),
('3','2','4','14','UP03-02-EDUB','Evaluación de los aprendizajes-EDUB-N3','N3','2','6','96','ACADEMICA'),
('3','2','4','15','UP03-04-EDUB','Metodologías lúdicas e innovadoras-EDUB-N3','N3','2','6','96','ACADEMICA'),
('3','2','4','16','UP03-03-EDUB','Planificación y programación curricular-EDUB-N3','N3','2','6','96','ACADEMICA'),
('3','2','4','17','PP-EDUCBA','Prácticas Preprofesionales - EDUCBA','N3','5','15','240','PRACTICAS'),
('3','2','4','18','UP04-03-EDUB','Adaptaciones curriculares-EDUB-N4','N4','3','9','144','ACADEMICA'),
('3','2','4','19','UI04-05-EDUB','Desarrollo del trabajo de titulación-EDUB-N4','N4','2','6','96','TITULACION'),
('3','2','4','20','UP04-02-EDUB','Didáctica de la enseñanza de la Lengua-EDUB-N4','N4','3','9','144','ACADEMICA'),
('3','2','4','21','UP04-01-EDUB','Didáctica de la enseñanza de la matemática-EDUB-N4','N4','3','9','144','ACADEMICA'),
('3','2','4','22','UP04-04-EDUB','Didáctica de la enseñanza de las Ciencias (naturales sociales)-EDUB-N4','N4','4','12','192','ACADEMICA'),
('4','1','5','1','UB01-02-RED-EBLG-ALP','Desarrollo del Lenguaje y del Pensamiento-RED-EBLG-ALP','N1','2','6','96','ACADEMICA'),
('4','1','5','2','UB01-03-RED-EBLG-ALP','English A1-RED-EBLG-ALP','N1','4','12','192','IDIOMA'),
('4','1','5','3','UB01-01-RED-EBLG-ALP','Fundamentos de la Educación-RED-EBLG-ALP','N1','2','6','96','ACADEMICA'),
('4','1','5','4','UB01-06-RED-EBLG-ALP','Matemáticas-RED-EBLG-ALP','N1','2','6','96','ACADEMICA'),
('4','1','5','5','UB01-05-RED-EBLG-ALP','Normativa y Legislación Aplicada-RED-EBLG-ALP','N1','4','9','144','ACADEMICA'),
('4','1','5','6','UB01-04-RED-EBLG-ALP','Psicología del desarrollo I-RED-EBLG-ALP','N1','4','12','192','ACADEMICA'),
('4','1','5','7','UP02-03-RED-EBLG-ALP','Alternative Pedagogies-RED-EBLG-ALP','N2','2','6','96','ACADEMICA'),
('4','1','5','8','UP02-02-RED-EBLG-ALP','Creatividad y Arte-RED-EBLG-ALP','N2','2','6','96','ACADEMICA'),
('4','1','5','9','UP02-04-RED-EBLG-ALP','English A2-RED-EBLG-ALP','N2','3','9','144','IDIOMA'),
('4','1','5','10','UP02-06-RED-EBLG-ALP','Metodología de la Investigación-RED-EBLG-ALP','N2','2','6','96','ACADEMICA'),
('4','1','5','11','UP02-05-RED-EBLG-ALP','Psicología del desarrollo II-RED-EBLG-ALP','N2','3','9','144','ACADEMICA'),
('4','1','5','12','UP02-01-RED-EBLG-ALP','Psicomotricidad-RED-EBLG-ALP','N2','3','9','144','ACADEMICA'),
('4','1','5','13','COMP-VINCEBLGRED-ALP','SERVICIO COMUNITARIO-RED-EBLG-ALP','N2','2','6','96','VINCULACION'),
('4','1','5','14','UP03-04-RED-EBLG-ALP','Dificultades de Aprendizaje e Inclusión-RED-EBLG-ALP','N3','3','9','144','ACADEMICA'),
('4','1','5','15','UP03-05-RED-EBLG-ALP','Educomunicación e Inteligencia Artificial-RED-EBLG-ALP','N3','4','12','192','ACADEMICA'),
('4','1','5','16','UP03-03RED-EBLG-ALP','English B1.1-RED-EBLG-ALP','N3','3','6','144','IDIOMA'),
('4','1','5','17','UP03-01-RED-EBLG-ALP','Innovative and Play-Based Teaching Methodologies-RED-EBLG-ALP','N3','3','6','144','ACADEMICA'),
('4','1','5','18','UP03-02-RED-EBLG-ALP','Planificación y Programación Curricular-RED-EBGL-ALP','N3','3','6','144','ACADEMICA'),
('4','1','5','19','COMP-PP-EBLG-RED-ALP','PRACTICAS PREPROFESIONALES-RED-EBLG-ALP','N3','5','15','240','PRACTICAS'),
('4','1','5','20','UP04-02-RED-EBLG-ALP','Assesment-RED-EBLG-ALP','N4','3','9','144','ACADEMICA'),
('4','1','5','21','UT04-05-RED-EBLG-ALP','Desarrollo del trabajo de titulación-RED-EBLG-ALP','N4','2','6','96','TITULACION'),
('4','1','5','22','UP04-04-RED-EBLG-ALP','Didactics of Teaching-RED-EBLG-ALP','N4','4','12','192','ACADEMICA'),
('4','1','5','23','UP04-03-RED-EBLG-ALP','English B1.2-RED-EBLG-ALP','N4','3','9','144','IDIOMA'),
('4','1','5','24','UP04-01-RED-EBLG-ALP','Metodología STEAM en la educación.RED-EBLG-ALP','N4','4','12','192','ACADEMICA'),
('4','2','6','1','UB01-02-EDUBI-ALP','Desarrollo del lenguaje y del Pensamiento-EDUBI-ALP','N1','2','6','96','ACADEMICA'),
('4','2','6','2','UB01-03-EDUBI-ALP','English A1-EDUBI-ALP','N1','4','12','192','IDIOMA'),
('4','2','6','3','UB01-01-EDUBI-ALP','Fundamentos de la Educación Inicial-EDUBI-ALP','N1','2','6','96','ACADEMICA'),
('4','2','6','4','UB01-06-EDUBI-ALP','Matemática-EDUBI-ALP','N1','2','6','96','ACADEMICA'),
('4','2','6','5','UB01-05-EDUBI-ALP','Normativa y Legislación Aplicada-EDUBI-ALP','N1','3','9','144','ACADEMICA'),
('4','2','6','6','UB01-04-EDUBI-ALP','Psicología del desarrollo I-EDUBI-ALP','N1','4','12','192','ACADEMICA'),
('4','2','6','7','UP02-03-EDUBI-ALP','Alternative Pedagogies-EDUBI-ALP','N2','2','6','96','ACADEMICA'),
('4','2','6','8','UP02-02-EDUBI-ALP','Creatividad y Arte infantil-EDUBI-ALP','N2','2','6','96','ACADEMICA'),
('4','2','6','9','UP02-04-EDUBI-ALP','English A2-EDUBI-ALP','N2','3','9','144','IDIOMA'),
('4','2','6','10','UP02-06-EDUBI-ALP','Metodología de la Investigación-EDUBI-ALP','N2','2','6','96','ACADEMICA'),
('4','2','6','11','UP02-05-EDUBI-ALP','Psicología del desarrollo II-EDUBI-ALP','N2','3','9','144','ACADEMICA'),
('4','2','6','12','UP02-01-EDUBI-ALP','Psicomotricidad-EDUBI-ALP','N2','3','9','144','ACADEMICA'),
('4','2','6','13','COMP-VINC-EDUBI-ALP','Servicio Comunitario-EDUBI-ALP','N2','2','6','96','VINCULACION'),
('4','2','6','14','UP03-04-EDUBI-ALP','Dificultades de Aprendizaje e Inclusión-EDUBI-ALP','N3','3','9','144','ACADEMICA'),
('4','2','6','15','UP03-01-EDUBI-ALP','Early stimulation-EDUBI-ALP','N3','3','9','144','ACADEMICA'),
('4','2','6','16','UP03-05-EDUBI-ALP','Educomunicación e Inteligencia Artificial-EDUBI-ALP','N3','4','12','192','ACADEMICA'),
('4','2','6','17','UP03-03-EDUBI-ALP','English B1.1-EDUBI-ALP','N3','3','9','144','IDIOMA'),
('4','2','6','18','UP03-02-EDUBI-ALP','Planificación y Programación Curricular-EDUBI-ALP','N3','3','9','144','ACADEMICA');

INSERT INTO _q10_asignaturas (src_programa_id,q10_malla_orden,canon_id,orden_en_nivel,codigo,nombre,nivel_codigo,creditos,ih_semanal,ih_total,tipo_codigo) VALUES

('4','2','6','19','PP-EDUBI-ALP','Prácticas pre profesionales-EDUBI-ALP','N3','5','15','240','PRACTICAS'),
('4','2','6','20','UP04-02-EDUBI-ALP','Assesment-EDUBI-ALP','N4','3','9','144','ACADEMICA'),
('4','2','6','21','UT04-05-EDUBI-ALP','Desarrollo del trabajo de titulación-EDUBI-ALP','N4','2','6','96','TITULACION'),
('4','2','6','22','UP04-04-EDUBI-ALP','Didactics and Methodology-EDUBI-ALP','N4','4','12','192','ACADEMICA'),
('4','2','6','23','UP04-03-EDUBI-ALP','English B1.2-EDUBI-ALP','N4','3','9','144','IDIOMA'),
('4','2','6','24','UP04-01-EDUBI-ALP','Metodología STEAM en la educación inicial-EDUBI-ALP','N4','4','12','192','ACADEMICA'),
('4','3','7','1','UB01-02-RED-EBLG','Desarrollo del Lenguaje y del Pensamiento-RED-EBLG','N1','2','6','96','ACADEMICA'),
('4','3','7','2','UB01-03-RED-EBLG','English A1-RED-EBLG','N1','4','12','192','IDIOMA'),
('4','3','7','3','UB01-01-RED-EBLG','Fundamentos de la Educación-RED-EBLG','N1','2','6','96','ACADEMICA'),
('4','3','7','4','UB01-06-RED-EBLG','Matemáticas-RED-EBLG','N1','2','6','96','ACADEMICA'),
('4','3','7','5','UB01-05-RED-EBLG','Normativa y Legislación Aplicada-RED-EBLG','N1','3','9','144','ACADEMICA'),
('4','3','7','6','UB01-04-RED-EBLG','Psicología del desarrollo I-RED-EBLG','N1','4','12','192','ACADEMICA'),
('4','3','7','7','UP02-03-RED-EBLOG','Alternative Pedagogies-RED-EBLG','N2','2','6','96','ACADEMICA'),
('4','3','7','8','UP02-02-RED-EBLG','Creatividad y Arte-RED-EBLG','N2','2','6','96','ACADEMICA'),
('4','3','7','9','UP02-04-RED-EBLG','English A2-RED-EBLG','N2','3','9','144','IDIOMA'),
('4','3','7','10','UP02-06-RED-EBLG','Metodología de la Investigación-RED-EBLG','N2','2','6','96','ACADEMICA'),
('4','3','7','11','UP02-05-RED-EBLG','Psicología del desarrollo II-RED-EBLG','N2','3','9','144','ACADEMICA'),
('4','3','7','12','UP02-01-RED-EBLG','Psicomotricidad-RED-EBLG','N2','3','9','144','ACADEMICA'),
('4','3','7','13','COMP-VIN-EBLG-RED','SERVICIO COMUNITARIO-RED-EBLG','N2','2','6','96','VINCULACION'),
('4','3','7','14','UP03-04-RED-EBLG','Dificultades de Aprendizaje e Inclusión-RED-EBLG','N3','3','9','144','ACADEMICA'),
('4','3','7','15','UP03-05-RED-EBLG','Educomunicación e Inteligencia Artificial-RED-EBLG','N3','4','12','192','ACADEMICA'),
('4','3','7','16','UP03-03-RED-EBLG','English B1.1-RED-EBLG','N3','3','9','144','IDIOMA'),
('4','3','7','17','UP03-01-RED-EBLG','Innovative and Play-Based Teaching Methodologies-RED-EBLG','N3','3','9','144','ACADEMICA'),
('4','3','7','18','UP03-02-RED-EBLG','Planificación y Programación Curricular-RED-EBGL','N3','3','9','144','ACADEMICA'),
('4','3','7','19','COMP-PP-EBLG-RED','PRACTICAS PREPROFESIONALES-RED-EBLG','N3','5','15','240','PRACTICAS'),
('4','3','7','20','UP04-02-RED-EBLG','Assesment-RED-EBLG','N4','3','9','144','ACADEMICA'),
('4','3','7','21','UT04-05-RED-EBLG','Desarrollo del trabajo de titulación-RED-EBLG','N4','2','6','96','TITULACION'),
('4','3','7','22','UP04-04-RED-EBLG','Didactics of Teaching-RED-EBLG','N4','4','12','192','ACADEMICA'),
('4','3','7','23','UP04-03-RED-EBLG','English B1.2-RED-EBLG','N4','3','9','144','IDIOMA'),
('4','3','7','24','UP04-01-RED-EBLG','Metodología STEAM en la educación.RED-EBLG','N4','4','12','192','ACADEMICA'),
('5','1','7','1','UB01-02-RED-EBLG','Desarrollo del Lenguaje y del Pensamiento-RED-EBLG','N1','2','6','96','ACADEMICA'),
('5','1','7','2','UB01-03-RED-EBLG','English A1-RED-EBLG','N1','4','12','192','IDIOMA'),
('5','1','7','3','UB01-01-RED-EBLG','Fundamentos de la Educación-RED-EBLG','N1','2','6','96','ACADEMICA'),
('5','1','7','4','UB01-06-RED-EBLG','Matemáticas-RED-EBLG','N1','2','6','96','ACADEMICA'),
('5','1','7','5','UB01-05-RED-EBLG','Normativa y Legislación Aplicada-RED-EBLG','N1','3','9','144','ACADEMICA'),
('5','1','7','6','UB01-04-RED-EBLG','Psicología del desarrollo I-RED-EBLG','N1','4','12','192','ACADEMICA'),
('5','1','7','7','UP02-03-RED-EBLOG','Alternative Pedagogies-RED-EBLG','N2','2','6','96','ACADEMICA'),
('5','1','7','8','UP02-02-RED-EBLG','Creatividad y Arte-RED-EBLG','N2','2','6','96','ACADEMICA'),
('5','1','7','9','UP02-04-RED-EBLG','English A2-RED-EBLG','N2','3','9','144','IDIOMA'),
('5','1','7','10','UP02-06-RED-EBLG','Metodología de la Investigación-RED-EBLG','N2','2','6','96','ACADEMICA'),
('5','1','7','11','UP02-05-RED-EBLG','Psicología del desarrollo II-RED-EBLG','N2','3','9','144','ACADEMICA'),
('5','1','7','12','UP02-01-RED-EBLG','Psicomotricidad-RED-EBLG','N2','3','9','144','ACADEMICA'),
('5','1','7','13','COMP-VIN-EBLG-RED','SERVICIO COMUNITARIO-RED-EBLG','N2','2','6','96','VINCULACION'),
('5','1','7','14','UP03-04-RED-EBLG','Dificultades de Aprendizaje e Inclusión-RED-EBLG','N3','3','9','144','ACADEMICA'),
('5','1','7','15','UP03-05-RED-EBLG','Educomunicación e Inteligencia Artificial-RED-EBLG','N3','4','12','192','ACADEMICA'),
('5','1','7','16','UP03-03-RED-EBLG','English B1.1-RED-EBLG','N3','3','9','144','IDIOMA'),
('5','1','7','17','UP03-01-RED-EBLG','Innovative and Play-Based Teaching Methodologies-RED-EBLG','N3','3','9','144','ACADEMICA'),
('5','1','7','18','UP03-02-RED-EBLG','Planificación y Programación Curricular-RED-EBGL','N3','3','9','144','ACADEMICA'),
('5','1','7','19','COMP-PP-EBLG-RED','PRACTICAS PREPROFESIONALES-RED-EBLG','N3','5','15','240','PRACTICAS'),
('5','1','7','20','UP04-02-RED-EBLG','Assesment-RED-EBLG','N4','3','9','144','ACADEMICA'),
('5','1','7','21','UT04-05-RED-EBLG','Desarrollo del trabajo de titulación-RED-EBLG','N4','2','6','96','TITULACION'),
('5','1','7','22','UP04-04-RED-EBLG','Didactics of Teaching-RED-EBLG','N4','4','12','192','ACADEMICA'),
('5','1','7','23','UP04-03-RED-EBLG','English B1.2-RED-EBLG','N4','3','9','144','IDIOMA'),
('5','1','7','24','UP04-01-RED-EBLG','Metodología STEAM en la educación.RED-EBLG','N4','4','12','192','ACADEMICA'),
('5','2','8','1','UB01-02-EB','Desarrollo del Lenguaje y del Pensamiento - EB-N1','N1','2','6','96','ACADEMICA'),
('5','2','8','2','UB01-03-EB','English A1 - EB-N1','N1','4','12','192','IDIOMA'),
('5','2','8','3','UB01-01-EB','Fundamentos de la Educación Inicial - EB-N1','N1','2','6','96','ACADEMICA'),
('5','2','8','4','UB-01-06-EB','Matemáticas - EB-N1','N1','2','6','96','ACADEMICA'),
('5','2','8','5','UB01-05-EB','Normativa y Legislación Aplicada - EB-N1','N1','3','9','144','ACADEMICA'),
('5','2','8','6','UB01-04-EB','Psicología del desarrollo I - EB-N1','N1','4','12','192','ACADEMICA'),
('5','2','8','7','UP02-03-EB','Alternative Pedagogies - EB-N2','N2','2','6','96','ACADEMICA'),
('5','2','8','8','UP02-02-EB','Creatividad y Arte infantil - EB-N2','N2','2','6','96','ACADEMICA'),
('5','2','8','9','UP02-04-EB','English A2 - EB-N2','N2','2','6','96','IDIOMA'),
('5','2','8','10','UP02-06-EB','Metodología de la Investigación - EB-N2','N2','2','6','96','ACADEMICA'),
('5','2','8','11','UP02-05-EB','Psicología del desarrollo II - EB-N2','N2','3','9','144','ACADEMICA'),
('5','2','8','12','UP02-01-EB','Psicomotrocidad - EB-N2','N2','3','9','144','ACADEMICA'),
('5','2','8','13','COMP-VINC-EB','Vinculación con la sociedad-EB','N2','2','6','96','VINCULACION'),
('5','2','8','14','UP03-04-EB','Dificultades de Aprendizaje e Inclusión - EB-N3','N3','3','9','144','ACADEMICA'),
('5','2','8','15','UP03-01-EB','Early stimulation - EB-N3','N3','3','9','144','ACADEMICA'),
('5','2','8','16','UP03-05-EB','Educomunicación e Inteligencia Artificial - EB-N3','N3','4','12','192','ACADEMICA'),
('5','2','8','17','UP03-03-EB','English B1.1 - EB-N3','N3','3','9','144','IDIOMA'),
('5','2','8','18','UP03-02-EB','Planificación y Programación Curricular - EB-N3','N3','3','9','144','ACADEMICA'),
('5','2','8','19','PP-EB','Prácticas Preprofesionales - EB','N3','5','15','240','PRACTICAS'),
('5','2','8','20','UP04-02-EB','Assesment - EB-N4','N4','3','9','144','ACADEMICA'),
('5','2','8','21','UT04-05-EB','Desarrollo del trabajo de titulación - EB-N4','N4','2','6','96','TITULACION'),
('5','2','8','22','UP04-04-EB','Didactics and Methodology - EB-N4','N4','4','12','192','ACADEMICA'),
('5','2','8','23','UP04-03-EB','English B1.2 - EB-N4','N4','3','9','144','IDIOMA'),
('5','2','8','24','UP04-01-EB','Metodologiía STEAM en la educación inicial - EB-N4','N4','4','12','192','ACADEMICA'),
('6','1','9','1','UB01-04-RED-EV-ALP','Bioquímica-RED-EV-ALP','N1','3','9','144','ACADEMICA'),
('6','1','9','2','UB01-02-RED-EV-ALP','Comunicación Oral y Escrita-RED-EV-ALP','N1','2','6','96','ACADEMICA'),
('6','1','9','3','UB01-01-RED-EV-ALP','Fundamentos de enfermería veterinaria-RED-EV-ALP','N1','2','6','96','ACADEMICA'),
('6','1','9','4','UB01-03-RED-EV-ALP','Morfofisiología Animal-RED-EV-ALP','N1','4','12','192','ACADEMICA'),
('6','1','9','5','UB01-05-RED-EV-ALP','Principios de equinos deportivos y de trabajo-RED-EV-ALP','N1','4','12','192','ACADEMICA'),
('6','1','9','6','UP02-04-RED-EV-ALP','Fundamentos de farmacología y microbiología-RED-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','1','9','7','UP02-05-RED-EV-ALP','Manejo técnico de equinos-RED-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','1','9','8','UP02-01-RED-EV-ALP','Metodología de la Investigación-RED-EV-ALP','N2','2','6','96','ACADEMICA'),
('6','1','9','9','UP02-03-RED-EV-ALP','Patología veterinaria-RED-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','1','9','10','COMP-VINC-EV-RED-ALP','SERVICIO COMUNITARIO-RED-ALP','N2','1.25','3.75','60','VINCULACION'),
('6','1','9','11','UP02-02-RED-EV-ALP','Técnicas y enfermería veterinaria-RED-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','1','9','12','UP03-03-RED-EV-ALP','Diseño y gestión de instalaciones veterinarias-RED-EV-ALP','N3','2','6','96','ACADEMICA'),
('6','1','9','13','UP03-04-RED-EV-ALP','Estética, etología y adiestramiento Animal-RED-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','1','9','14','UP03-05-RED-EV-ALP','Nutrición y bienestar equino-RED-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','1','9','15','COMP-PP-EV-ALP','PRACTICAS PREPROFESIONALES-RED-EV-ALP','N3','5','15','240','PRACTICAS'),
('6','1','9','16','UP03-01-RED-EV-ALP','Protocolos de enfermería quirúrgica veterinaria-RED-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','1','9','17','UP03-02-RED-EV-ALP','Sostenibilidad y Emprendimiento-RED-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','1','9','18','UP04-02-RED-EV-ALP','Bioética y sanidad animal-RED-EV-ALP','N4','2','6','96','ACADEMICA'),
('6','1','9','19','UI04-05-RED-EV-ALP','Desarrollo del trabajo de titulación-RED-EV-ALP','N4','2','6','96','TITULACION'),
('6','1','9','20','UP04-04-RED-EV-ALP','Desempeño técnico del gestor de Equinos -RED-EV-ALP','N4','4','12','192','ACADEMICA'),
('6','1','9','21','UP04-01-RED-EV-ALP','Emergencia y cuidado de pacientes críticos-RED-EV-ALP','N4','3','9','144','ACADEMICA'),
('6','1','9','22','UP04-03-RED-EV-ALP','Especies Exóticas-RED-EV-ALP','N4','3','9','144','ACADEMICA'),
('6','2','10','1','UB01-05-EV-ALP','Bioestadística-EV-ALP','N1','4','12','192','ACADEMICA'),
('6','2','10','2','UB01-04-EV-ALP','Bioquímica-EV-ALP','N1','3','9','144','ACADEMICA'),
('6','2','10','3','UB01-02-EV-ALP','Comunicación Oral y Escrita-EV-ALP','N1','2','6','96','ACADEMICA'),
('6','2','10','4','UB01-01-EV-ALP','Fundamentos de enfermeria veterinaria-EV-ALP','N1','2','6','96','ACADEMICA'),
('6','2','10','5','UB01-03-EV-ALP','Morfofisiología Animal-EV-ALP','N1','4','12','192','ACADEMICA'),
('6','2','10','6','UP02-04-EV-ALP','Fundamentos de farmacología-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','2','10','7','UP02-01-EV-ALP','Metodología de la Investigación-EV-ALP','N2','2','6','96','ACADEMICA'),
('6','2','10','8','UP02-05-EV-ALP','Microbiología-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','2','10','9','UP02-03-EV-ALP','Patología veterinaria-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','2','10','10','SC-EV-ALP','Servicio Comunitario','N2','1.25','3.75','60','VINCULACION'),
('6','2','10','11','UP02-02-EV-ALP','Técnicas y enfermería veterinaria-EV-ALP','N2','3','9','144','ACADEMICA'),
('6','2','10','12','UP03-03-EV-ALP','Diseño y gestión de instalaciones veterinarias-EV-ALP','N3','2','6','96','ACADEMICA'),
('6','2','10','13','UP03-04-EV-ALP','Estética de animales-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','2','10','14','UP03-05-EV-ALP','Etología y adiestramiento animal-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','2','10','15','PP-EV-ALP','Prácticas Pre Profesionales','N3','5','15','240','PRACTICAS'),
('6','2','10','16','UP03-01-EV-ALP','Protocolos de enfermería quirúrgica veterinaria-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','2','10','17','UP03-02-EV-ALP','Sostenibilidad y emprendimiento-EV-ALP','N3','3','9','144','ACADEMICA'),
('6','2','10','18','UP04-02-EV-ALP','Bioética y sanidad animal-EV-ALP','N4','2','6','96','ACADEMICA'),
('6','2','10','19','UP04-04-EV-ALP','Cuidado y Manejo de Equinos-EV-ALP','N4','4','12','192','ACADEMICA'),
('6','2','10','20','UI04-05-EV-ALP','Desarrollo del trabajo de titulación-EV-ALP','N4','2','6','96','TITULACION');

INSERT INTO _q10_asignaturas (src_programa_id,q10_malla_orden,canon_id,orden_en_nivel,codigo,nombre,nivel_codigo,creditos,ih_semanal,ih_total,tipo_codigo) VALUES

('6','2','10','21','UP04-01-EV-ALP','Emergencia y cuidado de pacientes críticos-EV-ALP','N4','3','9','144','ACADEMICA'),
('6','2','10','22','UP04-03-EV-ALP','Especies exóticas-EV-ALP','N4','3','9','144','ACADEMICA'),
('7','1','11','1','UB01-04-RED','Bioquímica-RED','N1','3','9','144','ACADEMICA'),
('7','1','11','2','UB01-02-RED','Comunicación Oral y Escrita-RED','N1','2','6','96','ACADEMICA'),
('7','1','11','3','UB01-01-RED','Fundamentos de enfermería veterinaria-RED','N1','2','6','96','ACADEMICA'),
('7','1','11','4','UB01-03-RED','Morfofisiología Animal-RED','N1','4','12','192','ACADEMICA'),
('7','1','11','5','UB01-05-RED','Principios de equinos deportivos y de trabajo-RED','N1','4','12','192','ACADEMICA'),
('7','1','11','6','UP02-04-RED','Fundamentos de farmacología y microbiología-RED','N2','3','9','144','ACADEMICA'),
('7','1','11','7','UP02-05-RED','Manejo técnico de equinos-RED','N2','3','9','144','ACADEMICA'),
('7','1','11','8','UP02-01-RED','Metodología de la Investigación-RED','N2','2','6','96','ACADEMICA'),
('7','1','11','9','UP02-03-RED','Patología veterinaria-RED','N2','3','9','144','ACADEMICA'),
('7','1','11','10','COMP-VINC-EV-RED','SERVICIO COMUNITARIO-RED','N2','1.25','3.75','60','VINCULACION'),
('7','1','11','11','UP02-02-RED','Técnicas y enfermería veterinaria-RED','N2','3','9','144','ACADEMICA'),
('7','1','11','12','UP03-03-RED','Diseño y gestión de instalaciones veterinarias-RED','N3','2','6','96','ACADEMICA'),
('7','1','11','13','UP03-04-RED','Estética, etología y adiestramiento Animal-RED','N3','3','9','144','ACADEMICA'),
('7','1','11','14','UP03-05-RED','Nutrición y bienestar equino-RED','N3','3','9','144','ACADEMICA'),
('7','1','11','15','COMP-PP-EV-RED','PRACTICAS PREPROFESIONALES-RED','N3','5','15','240','PRACTICAS'),
('7','1','11','16','UP03-01-RED','Protocolos de enfermería quirúrgica veterinaria-RED','N3','3','9','144','ACADEMICA'),
('7','1','11','17','UP03-02-RED','Sostenibilidad y Emprendimiento-RED','N3','3','9','144','ACADEMICA'),
('7','1','11','18','UP04-02-RED','Bioética y sanidad animal-RED','N4','2','6','96','ACADEMICA'),
('7','1','11','19','UI04-05-RED','Desarrollo del trabajo de titulación-RED','N4','2','6','96','TITULACION'),
('7','1','11','20','UP04-04-RED','Desempeño técnico del gestor de Equinos -RED','N4','4','12','192','ACADEMICA'),
('7','1','11','21','UP04-01-RED','Emergencia y cuidado de pacientes críticos-RED','N4','3','9','144','ACADEMICA'),
('7','1','11','22','UP04-03-RED','Especies Exóticas-RED','N4','3','9','144','ACADEMICA'),
('7','2','12','1','UB01-05-EV','Bioestadística - EV-N1','N1','4','12','192','ACADEMICA'),
('7','2','12','2','UB01-04-EV','Bioquímica-EV-N1','N1','3','9','144','ACADEMICA'),
('7','2','12','3','UB01-02-EV','Comunicación Oral y Escrita-EV-N1','N1','2','6','96','ACADEMICA'),
('7','2','12','4','UB01-01-EV','Fundamentos de enfermería veterinaria-EV-N1','N1','2','6','96','ACADEMICA'),
('7','2','12','5','UB01-03-EV','Morfofisiología Animal-EV-N1','N1','4','12','192','ACADEMICA'),
('7','2','12','6','UP02-04-UV','Fundamentos de farmacología-EV-N2','N2','3','9','144','ACADEMICA'),
('7','2','12','7','UP02-01-EV','Metodología de la Investigación-EV-N2','N2','2','6','96','ACADEMICA'),
('7','2','12','8','UP02-05-EV','Microbiología-EV-N2','N2','3','9','144','ACADEMICA'),
('7','2','12','9','UP02-03-EV','Patología Veterinaria-EV-N2','N2','3','9','144','ACADEMICA'),
('7','2','12','10','UP02-02-EV','Técnicas y enfermería veterinaria-EV-N2','N2','3','9','144','ACADEMICA'),
('7','2','12','11','COMP-VINC-EV','Vinculación con la sociedad - EV','N2','1.25','3.75','60','VINCULACION'),
('7','2','12','12','UP03-03-EV','Diseño y gestión de instalaciones veterinarias-EV-N3','N3','2','6','96','ACADEMICA'),
('7','2','12','13','UP03-04-EV','Estética de animales-EV-N3','N3','3','9','144','ACADEMICA'),
('7','2','12','14','UP03-05-EV','Etología y Adiestramiento Animal-EV-N3','N3','3','9','144','ACADEMICA'),
('7','2','12','15','PP-EV','Prácticas Preprofesionales - EV','N3','5','15','240','PRACTICAS'),
('7','2','12','16','UP03-01-EV','Protocolos de enfermería quirúrgica veterinaria-EV-N3','N3','3','9','144','ACADEMICA'),
('7','2','12','17','UP03-02-EV','Sostenibilidad y Emprendimiento-EV-N3','N3','3','9','144','ACADEMICA'),
('7','2','12','18','UP04-02-EV','Bioética y sanidad animal-EV-N4','N4','2','6','96','ACADEMICA'),
('7','2','12','19','UP04-04-EV','Cuidado y Manejo de Equinos-EV-N4','N4','4','12','192','ACADEMICA'),
('7','2','12','20','UI04-05-EV','Desarrollo del trabajo de titulación-EV-N4','N4','2','6','96','TITULACION'),
('7','2','12','21','UP04-01-EV','Emergencia y cuidado de pacientes críticos-EV-N4','N4','3','9','144','ACADEMICA'),
('7','2','12','22','UP04-03-EV','Especies Exóticas-EV-N4','N4','3','9','144','ACADEMICA'),
('8','1','13','1','UP01-02-MD-MN','Comunicación y narrativas digitales -MD-MN','N1','3','9','144','ACADEMICA'),
('8','1','13','2','UP01-03-MD-MN','Diseño de Marcas y página web-MD-MN','N1','3','9','144','ACADEMICA'),
('8','1','13','3','UP01-05-MD-MN','Estrategias de Marketing Digital y Community Management con IA - MD-MN','N1','3','9','144','ACADEMICA'),
('8','1','13','4','UP01-04-MD-MN','Fundamentos de Diseño gráfico y comunicación visual -MD-MN','N1','2','6','96','ACADEMICA'),
('8','1','13','5','UB01-01-MD-MN','Fundamentos de Marketing Digital -MD-MN','N1','2','6','96','ACADEMICA'),
('8','1','13','6','COMP-VINC-MD-MN','Servicio Comunitario Dentro de la Malla-MD-MN','N1','1','3','48','VINCULACION'),
('8','1','13','7','VINC-FM- MD -MN','Servicio Comunitario Fuera de la Malla','N1','0.25','.75','12','VINCULACION'),
('8','1','13','8','UP02-04-MD-MN','Comercio Digital -MD-MN','N2','3','9','144','ACADEMICA'),
('8','1','13','9','UP02-02-MD-MN','Comunicación e Influencia Digital -MD-MN','N2','2.21','6.63','106','ACADEMICA'),
('8','1','13','10','UP02-05-MD-MN','Desarrollo de trabajo de titulación -MD-MN','N2','2.17','6.5','104','TITULACION'),
('8','1','13','11','UP02-01-MD-MN','Marketing de Buscadores (SEO/SEM) con IA -MD-MN','N2','2.21','6.63','106','ACADEMICA'),
('8','1','13','12','PP-MD-MN','Prácticas Laborales Dentro de Malla - MD - MN','N2','2','6','96','PRACTICAS'),
('8','1','13','13','PP-MD-FM-MN','Prácticas Laborales Fuera de Malla - MD-MN','N2','2','6','96','PRACTICAS'),
('8','1','13','14','UP02-03-MD-MN','Social Media y Publicidad Digital - MD-MN','N2','2.17','6.5','104','ACADEMICA'),
('9','1','14','1','UB01-02-MDDM','Comunicación y narrativas digitales - MDDM','N1','3','9','144','ACADEMICA'),
('9','1','14','2','UP01-03-MDDM','Diseño de Marcas y página web - MDDM','N1','3','9','144','ACADEMICA'),
('9','1','14','3','UP01-05-MDDM','Estrategias de Marketing Digital y Community Management con IA - MDDM','N1','3','9','144','ACADEMICA'),
('9','1','14','4','UP01-04-MDDM','Fundamentos de Diseño gráfico y comunicación visual - MDDM','N1','2','6','96','ACADEMICA'),
('9','1','14','5','UB01-01-MDDM','Fundamentos de Marketing Digital - MDDM','N1','2','6','96','ACADEMICA'),
('9','1','14','6','COMP-VINC-MDDM','Vinculación con la sociedad - Dentro de Malla - MDDM','N1','1.25','3','48','VINCULACION'),
('9','1','14','7','COMP-VINC-FM - MDDM','Vinculación con la sociedad - Fuera de Malla - MDDM','N1','0.25','.75','12','VINCULACION'),
('9','1','14','8','UP02-04-MDDM','Comercio Digital -MDDM','N2','2.75','8.25','132','ACADEMICA'),
('9','1','14','9','UP02-02-MDDM','Comunicación e Influencia Digital -MDDM','N2','2','6','96','ACADEMICA'),
('9','1','14','10','UP02-01-MDDM','Marketing de Buscadores (SEO/SEM) con IA -MDDM','N2','2','6','96','ACADEMICA'),
('9','1','14','11','PP-MDDM','Prácticas Laborales - MDDM - 192','N2','4','12','192','PRACTICAS'),
('9','1','14','12','UP02-05-MDDM','Proyecto profesional Técnico -MDDM','N2','2','6','96','ACADEMICA'),
('9','1','14','13','UP02-03-MDDM','Social Media y Publicidad Digital - MDDM','N2','2','6','96','ACADEMICA'),
('9','1','14','14','UP03-01-MDDM','Analítica y Métricas Digitales -MDDM','N3','2','6','96','ACADEMICA'),
('9','1','14','15','UP03-05-MDDM','Diseño Gráfico Bi y tridimencional -MDDM','N3','3','9','144','ACADEMICA'),
('9','1','14','16','UP03-04-MDDM','Locución y edición de audio -MDDM','N3','2','6','96','ACADEMICA'),
('9','1','14','17','UP03-03-MDDM','Producción Audiovisual y Fotografía Digital -MDDM','N3','3','9','144','ACADEMICA'),
('9','1','14','18','UP03-02-MDDM','Storytelling y Storyboard - MDDM','N3','3','9','144','ACADEMICA'),
('9','1','14','19','UP04-02-MDDM','Composición digital y VFX -MDDM','N4','3','9','144','ACADEMICA'),
('9','1','14','20','UT04-05-MDDM','Desarrollo de trabajo de titulación -MDDM','N4','2','6','96','TITULACION'),
('9','1','14','21','UP04-03-MDDM','Investigación Comercial y Digital -MDDM','N4','3','6','144','ACADEMICA'),
('9','1','14','22','UP04-01-MDDM','Marketing Digital para Emprendedores -MDDM','N4','3','9','144','ACADEMICA'),
('9','1','14','23','UP04-04-MDDM','Producción de Contenido Multimedia -MDDM','N4','4','12','192','ACADEMICA'),
('10','1','15','1','UB01-02-MIN-RED','Comunicación Oral y Escrita-MIN-RED-N1','N1','2','6','96','ACADEMICA'),
('10','1','15','2','UB01-05-MIN-RED','Física-MIN-RED-N1','N1','3','9','144','ACADEMICA'),
('10','1','15','3','UB01-03-MIN-RED','Fundamentos de la Minería I-MIN-RED-N1','N1','4','12','192','ACADEMICA'),
('10','1','15','4','UB01-01-MIN-RED','Matemática-MIN-RED-N1','N1','2','6','96','ACADEMICA'),
('10','1','15','5','UB01-04-MIN-RED','Química Inorgánica-MIN-RED-N1','N1','4','12','192','ACADEMICA'),
('10','1','15','6','UP02-01-MIN-RED','Dibujo Técnico y Topográfico-MIN-RED-N2','N2','2.25','6.75','108','ACADEMICA'),
('10','1','15','7','UP02-03-MIN-RED','Fundamentos de la Minería II-MIN-RED-N2','N2','3.25','9.75','156','ACADEMICA'),
('10','1','15','8','UP02-05-MIN-RED','Introducción a la Geología-MIN-RED-N2','N2','3','9','144','ACADEMICA'),
('10','1','15','9','UP02-02-MIN-RED','Metodología de la Investigación Científica-MIN-RED-N2','N2','2.25','6.75','108','ACADEMICA'),
('10','1','15','10','UP02-04-MIN-RED','Planeamiento y Control de Operaciones Mineras-MIN-RED-N2','N2','3','9','144','ACADEMICA'),
('10','1','15','11','COMP-SP-MIN-RED','Servicio Comunitario-MIN-RED','N2','1','3.75','60','VINCULACION'),
('10','1','15','12','UP03-05-MIN-RED','Explotación de minerales para obras civiles no metálicos-MIN-RED-N3','N3','2','6','96','ACADEMICA'),
('10','1','15','13','UP03-02-MIN-RED','Manejo de Explosivos-MIN-RED-N3','N3','2','6','96','ACADEMICA'),
('10','1','15','14','UP03-04-MIN-RED','Perforación-MIN-RED-N3','N3','2','6','96','ACADEMICA'),
('10','1','15','15','PL-MIN-RED','Prácticas Laborales-MIN-RED','N3','5','15','240','PRACTICAS'),
('10','1','15','16','UP03-01-MIN-RED','Prevención de Riesgos en Obra-MIN-RED-N3','N3','2','6','96','ACADEMICA'),
('10','1','15','17','UP03-03-MIN-RED','Transporte en sistema de explotación-MIN-RED-N3','N3','2','6','96','ACADEMICA'),
('10','1','15','18','UP04-05-MIN-RED','Desarrollo del trabajo de titulación-MIN-RED-N4','N4','2','6','96','TITULACION'),
('10','1','15','19','UP04-01-MIN-RED','Normativa y Legislación Aplicada-MIN-RED-N4','N4','4','12','192','ACADEMICA'),
('10','1','15','20','UP04-04-MIN-RED','Presupuestos y planificación-MIN-RED-N4','N4','4','12','192','ACADEMICA'),
('10','1','15','21','UP04-03-MIN-RED','Supervisión de maquinaria minera-MIN-RED-N4','N4','2','6','96','ACADEMICA'),
('10','1','15','22','UP04-02-MIN-RED','Topografía Subterránea-MIN-RED-N4','N4','3','9','144','ACADEMICA'),
('10','2','16','1','UB01-02-MIN','Comunicación Oral y Escrita-MIN -N1','N1','2','6','96','ACADEMICA'),
('10','2','16','2','UB01-05-MIN','Física-MIN -N1','N1','3','9','144','ACADEMICA'),
('10','2','16','3','UB01-03-MIN','Fundamentos de la Minería I-MIN -N1','N1','4','12','192','ACADEMICA'),
('10','2','16','4','UB01-01-MIN','Matemática-MIN -N1','N1','2','6','96','ACADEMICA'),
('10','2','16','5','UB01-04-MIN','Química Inorgánica-MIN -N1','N1','4','12','192','ACADEMICA'),
('10','2','16','6','UP02-01-MIN','Dibujo Técnico y Topográfico-MIN-N2','N2','3','9','144','ACADEMICA'),
('10','2','16','7','UP02-03-MIN','Fundamentos de la Minería II-MIN-N2','N2','3','9','144','ACADEMICA'),
('10','2','16','8','UP02-05-MIN','Introducción a la Geología-MIN-N2','N2','3','9','144','ACADEMICA'),
('10','2','16','9','UP02-02-MIN','Metodología de la Investigación Científica-MIN-N2','N2','2','6','96','ACADEMICA'),
('10','2','16','10','UP02-04-MIN','Planeamiento y Control de Operaciones Mineras-MIN-N2','N2','3','9','144','ACADEMICA'),
('10','2','16','11','COMP-VINC-MIN','Vinculación con la sociedad - MIN','N2','2','6','96','VINCULACION'),
('10','2','16','12','UP03-05-MIN','Explotación de minerales para obras civiles no metálicos-MIN-N3','N3','2','6','96','ACADEMICA'),
('10','2','16','13','UP03-02-MIN','Manejo de Explosivos-MIN-N3','N3','2','6','96','ACADEMICA'),
('10','2','16','14','UP03-04-MIN','Perforación-MIN-N3','N3','2','6','96','ACADEMICA'),
('10','2','16','15','PP-MIN','Prácticas Preprofesionales - MIN','N3','5','15','240','PRACTICAS');

INSERT INTO _q10_asignaturas (src_programa_id,q10_malla_orden,canon_id,orden_en_nivel,codigo,nombre,nivel_codigo,creditos,ih_semanal,ih_total,tipo_codigo) VALUES

('10','2','16','16','UP03-01-MIN','Prevención de Riesgos en Obra-MIN-N3','N3','2','6','96','ACADEMICA'),
('10','2','16','17','UP03-03-MIN','Transporte en sistema de explotación-MIN-N3','N3','2','6','96','ACADEMICA'),
('10','2','16','18','UI04-05-MIN','Desarrollo del trabajo de titulación-MIN-N4','N4','2','6','96','TITULACION'),
('10','2','16','19','UI04-01-MIN','Normativa y Legislación Aplicada-MIN-N4','N4','4','12','192','TITULACION'),
('10','2','16','20','UI04-04-MIN','Presupuestos y planificación-MIN-N4','N4','4','12','192','TITULACION'),
('10','2','16','21','UI04-03-MIN','Supervisión de maquinaria minera-MIN-N4','N4','2','6','96','TITULACION'),
('10','2','16','22','UI04-02-MIN','Topografía Subterránea-MIN-N4','N4','3','9','144','TITULACION'),
('11','1','17','1','UB01-02-RED-PA','Comunicación Oral y Escrita-RED-PA','N1','2','6','96','ACADEMICA'),
('11','1','17','2','UB01-04-RED-PA','Impacto y sostenibilidad ambiental RED-PA','N1','3','9','144','ACADEMICA'),
('11','1','17','3','UB01-05-RED-PA','Logística y transporte en producción pecuaria-RED-PA','N1','4','12','192','ACADEMICA'),
('11','1','17','4','UB01-01-RED-PA','Manejo técnico de sistemas pecuarios-RED-PA','N1','2','6','96','ACADEMICA'),
('11','1','17','5','UB01-03-RED-PA','Tecnología de Lácteos-RED-PA','N1','4','12','192','ACADEMICA'),
('11','1','17','6','UP02-04-RED-PA','Desarrollo de Balanceados y suplementos alimenticios-RED-PA','N2','3','9','144','ACADEMICA'),
('11','1','17','7','UP02-01-RED-PA','Metodología de la Investigación-RED-PA','N2','2','6','96','ACADEMICA'),
('11','1','17','8','COMP-VINC-PA-RED','SERVICIO COMUNITARIO-RED-PA','N2','1.25','3.75','60','VINCULACION'),
('11','1','17','9','UP02-03-RED-PA','Tecnología de cárnicos-RED-PA','N2','3','9','144','ACADEMICA'),
('11','1','17','10','UP02-05-RED-PA','Tecnología del Faenamiento y cortes-RED-PA','N2','3','9','144','ACADEMICA'),
('11','1','17','11','UP02-02-RED-PA','Tecnologías de la Alimentación y Nutrición -RED-PA','N2','3','9','144','ACADEMICA'),
('11','1','17','12','UP03-04-RED-PA','Juzgamiento de Razas y Bienestar Animal-RED-PA','N3','3','9','144','ACADEMICA'),
('11','1','17','13','COMP-PP-PA-RED','PRACTICAS PREPROFESIONALES-RED-PA','N3','5','15','240','PRACTICAS'),
('11','1','17','14','UP03-02-RED-PA','Sostenibilidad Social y Emprendimiento-RED-PA','N3','3','9','144','ACADEMICA'),
('11','1','17','15','UP03-05-RED-PA','Tecnificación del manejo de residuos-RED-PA','N3','2','6','96','ACADEMICA'),
('11','1','17','16','UP03-01-RED-PA','Tecnología de la Genética y Reproducción-RED-PA','N3','3','9','144','ACADEMICA'),
('11','1','17','17','UP03-03-RED-PA','Tecnología e innovación en alimentos-RED-PA','N3','3','9','144','ACADEMICA'),
('11','1','17','18','UP04-03-RED-PA','Desarrollo de productos para el cuidado pecuario-RED-PA','N4','4','12','192','ACADEMICA'),
('11','1','17','19','UI04-05-RED-PA','Desarrollo del trabajo de titulación-RED-PA','N4','2','6','96','TITULACION'),
('11','1','17','20','UP04-04-RED-PA','Granjas Sostenibles-RED-PA','N4','3','9','144','ACADEMICA'),
('11','1','17','21','UP04-01-RED-PA','Sanidad e Instalaciones-RED-PA','N4','4','12','192','ACADEMICA'),
('11','1','17','22','UP04-02-RED-PA','Tecnología de otros derivados no alimenticios-RED-PA','N4','2','6','96','ACADEMICA'),
('11','2','18','1','UB01-05-PA-MN','Bioestadística-PA-MN-N1','N1','4','12','192','ACADEMICA'),
('11','2','18','2','UB01-04-PA-MN','Bioquímica-PA-MN-N1','N1','3','9','144','ACADEMICA'),
('11','2','18','3','UB01-02-PA-MN','Comunicación Oral y Escrita-PA-MN-N1','N1','2','6','96','ACADEMICA'),
('11','2','18','4','UB01-01-PA-MN','Fundamentos de la producción animal-PA-MN-N1','N1','2','6','96','ACADEMICA'),
('11','2','18','5','UB01-03-PA-MN','Morfofisiología Animal-PA-MN-N1','N1','4','12','192','ACADEMICA'),
('11','2','18','6','UP02-01-PA-MN','Metodología de la Investigación-PA-MN-N2','N2','2','6','96','ACADEMICA'),
('11','2','18','7','UP02-04-PA-MN','Microbiología-PA-MN-N2','N2','3','9','144','ACADEMICA'),
('11','2','18','8','UP02-03-PA-MN','Producción Animal I-PA-MN-N2','N2','3','9','144','ACADEMICA'),
('11','2','18','9','UP02-02-PA-MN','Producción de pastos y forrajes-PA-MN-N2','N2','3','9','144','ACADEMICA'),
('11','2','18','10','COMP-VINC-PA-MN','Vinculación con la sociedad-PA-MN','N2','1.25','3.75','60','VINCULACION'),
('11','2','18','11','UP02-05-PA-MN','Zootecnia de animales de Producción-PA-MN-N2','N2','3','9','144','ACADEMICA'),
('11','2','18','12','UP03-04-PA-MN','Higiene de los alimentos-PA-MN-N3','N3','3','9','144','ACADEMICA'),
('11','2','18','13','UP03-01-PA-MN','Industrialización I-PA-MN-N3','N3','3','9','144','ACADEMICA'),
('11','2','18','14','UP03-05-PA-MN','Nutrición y alimentación animal-PA-MN-N3','N3','2','6','96','ACADEMICA'),
('11','2','18','15','PP-PA','Prácticas Preprofesionales - PA','N3','5','15','240','PRACTICAS'),
('11','2','18','16','UP03-03-PA-MN','Producción Animal II-PA-MN-N3','N3','3','9','144','ACADEMICA'),
('11','2','18','17','UP03-02-PA-MN','Sostenibilidad y Emprendimiento-PA-MN-N3','N3','3','9','144','ACADEMICA'),
('11','2','18','18','UP04-02-PA-MN','Bioética y sanidad animal-PA-MN-N4','N4','2','6','96','ACADEMICA'),
('11','2','18','19','UI04-05-PA-MN','Desarrollo del trabajo de titulación-PA-MN-N4','N4','2','6','96','TITULACION'),
('11','2','18','20','UP04-04-PA-MN','Genética y reproducción animal-PA-MN-N4','N4','3','9','144','ACADEMICA'),
('11','2','18','21','UP04-01-PA-MN','Industrialización II-PA-MN-N4','N4','4','12','192','ACADEMICA'),
('11','2','18','22','UP04-03-PA-MN','Producción Animal III-PA-MN-N4','N4','4','12','192','ACADEMICA'),
('12','1','19','1','UB01-05-RED-SHT','Ergonomía-RED-SHT','N1','3','9','144','ACADEMICA'),
('12','1','19','2','UB01-01-RED-SHT','Fundamentos de la Seguridad y Prevención de Riesgos Laborales-RED-SHT','N1','3','9','144','ACADEMICA'),
('12','1','19','3','UB01-02-RED-SHT','Riesgos de Seguridad, Mecánicos y Físicos-RED-SHT','N1','3','9','144','ACADEMICA'),
('12','1','19','4','UB01-04-RED-SHT','Riesgos Psicosociales-RED-SHT','N1','2','6','96','ACADEMICA'),
('12','1','19','5','UB01-03-RED-SHT','Riesgos Químicos y Biológicos-RED-SHT','N1','2','6','96','ACADEMICA'),
('12','1','19','6','COMP-VINC-RED-SHT','Servicio comunitario dentro de la malla curricular-RED-SHT','N1','1.25','3.75','60','VINCULACION'),
('12','1','19','7','COMPII-VINC-RED-SHT','Servicio comunitario fuera de la malla curricular-RED-SHT','N1','0.75','2.25','36','VINCULACION'),
('12','1','19','8','UP02-02-RED-SHT','Evaluación y prevención de riesgos-RED-SHT','N2','3','6','96','ACADEMICA'),
('12','1','19','9','UP02-01-RED-SHT','Plan de emergencia y conformación de brigadas-RED-SHT','N2','2','6','96','ACADEMICA'),
('12','1','19','10','PP-RED-SHT','Prácticas laborales dentro de la malla-RED-SHT','N2','4','12','192','PRACTICAS'),
('12','1','19','11','PPII-RED-SHT','Prácticas laborales fuera de la malla-RED-SHT','N2','1','3','48','PRACTICAS'),
('12','1','19','12','UP02-03-RED-SHT','Prevención y seguridad en trabajos de alto riesgo-RED-SHT','N2','3','6','96','ACADEMICA'),
('12','1','19','13','UP02-04-RED-SHT','Primeros Auxilios-RED-SHT','N2','2','6','96','ACADEMICA'),
('12','1','19','14','UP02-05-RED-SHT','Proyecto profesional Técnico-RED-SHT','N2','2','6','96','ACADEMICA'),
('12','1','19','15','UP03-01-RED-SHT','Fundamentos de Higiene Industrial-RED-SHT','N3','4','12','192','ACADEMICA'),
('12','1','19','16','UP03-02-RED-SHT','Legislación de seguridad e higiene del trabajo-RED-SHT','N3','2','6','96','ACADEMICA'),
('12','1','19','17','UP03-05-RED-SHT','Metodología de la investigación-RED-SHT','N3','2','6','96','ACADEMICA'),
('12','1','19','18','UP03-04-RED-SHT','Psicología Organizacional-RED-SHT','N3','3','9','144','ACADEMICA'),
('12','1','19','19','UP03-03-RED-SHT','Salud Ocupacional-RED-SHT','N3','3','9','144','ACADEMICA'),
('12','1','19','20','UP04-03-RED-SHT','Análisis Financiero para sistemas de Seguridad Ocupacional-RED-SHT','N4','3','9','144','ACADEMICA'),
('12','1','19','21','UI04-05-RED-SHT','Desarrollo del trabajo de titulación-RED-SHT','N4','2','6','96','TITULACION'),
('12','1','19','22','UP04-04-RED-SHT','Levantamiento y procesos en STH-RED-SHT','N4','2','6','96','ACADEMICA'),
('12','1','19','23','UP04-02-RED-SHT','Manejo de productos peligrosos-RED-SHT','N4','4','12','192','ACADEMICA'),
('12','1','19','24','UP04-01-RED-SHT','Sistema de Gestión Integrado de SHT-RED-SHT','N4','4','12','192','ACADEMICA'),
('12','2','20','1','UB01-02-SHT','Comunicación Oral y Escrita-SHT-N1','N1','2','6','96','ACADEMICA'),
('12','2','20','2','UB01-05-SHT','Fisiología y Anatomía Ocupacional-SHT-N1','N1','4','12','192','ACADEMICA'),
('12','2','20','3','UB01-01-SHT','Fundamentos de la Seguridad y Prevención de Riesgos Laborales-SHT-N1','N1','3','9','144','ACADEMICA'),
('12','2','20','4','UB01-03-SHT','Matemáticas-SHT-N1','N1','2','6','96','ACADEMICA'),
('12','2','20','5','UB01-04-SHT','Química General-SHT-N1','N1','4','12','192','ACADEMICA'),
('12','2','20','6','UP02-03-SHT','Estadística aplicada-SHT-N2','N2','2','6','96','ACADEMICA'),
('12','2','20','7','UP02-01-SHT','Evaluación y prevención de riesgos-SHT-N2','N2','4','12','192','ACADEMICA'),
('12','2','20','8','UP02-04-SHT','Legislación de seguridad e higiene del trabajo-SHT-N2','N2','2','6','96','ACADEMICA'),
('12','2','20','9','UP02-05-SHT','Metodología de la investigación-SHT-N2','N2','2','6','96','ACADEMICA'),
('12','2','20','10','UP02-02-SHT','Plan de emergencia y conformación de brigadas-SHT-N2','N2','3','9','144','ACADEMICA'),
('12','2','20','11','UP03-03-SHT','Ergonomía-SHT-N3','N3','3','9','144','ACADEMICA'),
('12','2','20','12','UP03-01-SHT','Fundamentos de Higiene Industrial-SHT-N3','N3','3','9','144','ACADEMICA'),
('12','2','20','13','UP03-02-SHT','Prevención de Riesgos en obra-SHT-N3','N3','2','6','96','ACADEMICA'),
('12','2','20','14','UP03-05-SHT','Primeros Auxilios -SHT-N3','N3','3','9','144','ACADEMICA'),
('12','2','20','15','UP03-04','Salud Ocupacional-SHT-N3','N3','3','9','144','ACADEMICA'),
('12','2','20','16','UP04-03-SHT','Análisis Financiero para sistemas de Seguridad Ocupacional-SHT-N4','N4','3','9','144','ACADEMICA'),
('12','2','20','17','UI04-05-SHT','Desarrollo del trabajo de titulación-SHT-N4','N4','2','6','96','TITULACION'),
('12','2','20','18','UP04-02-SHT','Manejo de productos peligrosos-SHT-N4','N4','4','12','192','ACADEMICA'),
('12','2','20','19','UP04-04-SHT','Prevención y seguridad en trabajos de alto riesgo-SHT-N4','N4','3','9','144','ACADEMICA'),
('12','2','20','20','UP04-01-SHT','Sistema de Gestión Integrado-SHT-N4','N4','3','9','144','ACADEMICA'),
('12','2','20','21','PP-SHT','Prácticas Preprofesionales - SHT','UNICO','5','15','240','PRACTICAS'),
('12','2','20','22','COMP-VINC-SHT','Vinculación con la sociedad -SHT','UNICO','2','6','96','VINCULACION'),
('13','1','21','1','UP01-05-SPRL','Ergonomía-SPRL-N1','N1','3','9','144','ACADEMICA'),
('13','1','21','2','UB01-01-SPRL','Fundamentos de la Seguridad y Prevención de Riesgos Laborales-SPRL-N1','N1','3','9','144','ACADEMICA'),
('13','1','21','3','UP01-02-SPRL','Riesgos de Seguridad, Mecánicos y Físicos-SPRL-N1','N1','3','9','144','ACADEMICA'),
('13','1','21','4','UP01-04-SPRL','Riesgos Psicosociales-SPRL-N1','N1','2','6','96','ACADEMICA'),
('13','1','21','5','UP01-03-SPRL','Riesgos Químicos y Biológicos-SPRL-N1','N1','2','6','96','ACADEMICA'),
('13','1','21','6','COMP-VINC-SPRL','Vinculación con la sociedad- SPRL','N1','2','6','96','VINCULACION'),
('13','1','21','7','UP02-02-SPRL','Evaluación y prevención de riesgos-SPRL-N2','N2','4','12','192','ACADEMICA'),
('13','1','21','8','UP02-01-SPRL','Plan de emergencia y conformación de brigadas-SPRL-N2','N2','3','9','144','ACADEMICA'),
('13','1','21','9','PP-SPRL','Prácticas Preprofesionales - SPRL','N2','4','12','192','PRACTICAS'),
('13','1','21','10','UP02-03-SPRL','Prevención y seguridad en trabajos de alto riesgo-SPRL-N2','N2','3','9','144','ACADEMICA'),
('13','1','21','11','UP02-04-SPRL','Primeros Auxilios -SPRL-N2','N2','3','9','144','ACADEMICA'),
('13','1','21','12','UT02-05-SPRL','Trabajo de titulación-SPRL-N2','N2','2','6','96','TITULACION'),
('14','1','22','1','UP01-03-ADM','Contabilidad computarizada-ADM-N1','N1','4','12','192','ACADEMICA'),
('14','1','22','2','UB01-02-ADM','Desarrollo del lenguaje y del pensamiento-ADM-N1','N1','2','6','96','ACADEMICA'),
('14','1','22','3','UP01-04-ADM','Fundamentos de administración-ADM-N1','N1','3','9','144','ACADEMICA'),
('14','1','22','4','UP01-05-ADM','Legislación laboral y tributaria-ADM-N1','N1','2','6','96','ACADEMICA'),
('14','1','22','5','UB01-01-ADM','Matemática aplicada a la administración-ADM-N1','N1','2','6','96','ACADEMICA'),
('14','1','22','6','COMP-VINC-ADM','Vinculación con la sociedad - ADM','N1','2','6','96','VINCULACION'),
('14','1','22','7','UI02-05-ADM','Desarrollo del trabajo de titulación-ADM-N2','N2','2','6','96','TITULACION'),
('14','1','22','8','UP02-04-ADM','Gestión de almacenamiento e inventario-ADM-N2','N2','2','6','96','ACADEMICA'),
('14','1','22','9','UP02-03-ADM','Gestión de costos-ADM-N2','N2','2','6','96','ACADEMICA'),
('14','1','22','10','UP02-02-ADM','Gestión de la calidad-ADM-N2','N2','2','6','96','ACADEMICA'),
('14','1','22','11','UP02-01-ADM','Gestión del talento humano-ADM-N2','N2','2','6','96','ACADEMICA');

INSERT INTO _q10_asignaturas (src_programa_id,q10_malla_orden,canon_id,orden_en_nivel,codigo,nombre,nivel_codigo,creditos,ih_semanal,ih_total,tipo_codigo) VALUES

('14','1','22','12','PP-ADM','Prácticas Preprofesionales - ADM','N2','5','15','240','PRACTICAS'),
('15','1','23','1','UB01-02-MKD','Desarrollo del lenguaje y del pensamiento-MKD-N1','N1','2','6','96','ACADEMICA'),
('15','1','23','2','UP01-03-MKD','Diseño de marcas y paginas web-MKD-N1','N1','4','12','192','ACADEMICA'),
('15','1','23','3','UP01-05-MKD','Estrategias de marketing digital-MKD-N1','N1','2','6','96','ACADEMICA'),
('15','1','23','4','UB01-01-MKD','Fundamentos y tendencias de marketing digital-MKD-N1','N1','2','6','96','ACADEMICA'),
('15','1','23','5','UP01-04-MKD','Publicidad digital-MKD-N1','N1','3','9','144','ACADEMICA'),
('15','1','23','6','COMP-VINC-MKD','Vinculación con la sociedad - MKD','N1','2','6','96','VINCULACION'),
('15','1','23','7','UP02-04-MKD','Comercio digital-MKD-N2','N2','2','6','96','ACADEMICA'),
('15','1','23','8','UP02-02-MKD','Comunicación e influencia digital-MKD-N2','N2','2','6','96','ACADEMICA'),
('15','1','23','9','UI02-05-MKD','Desarrollo del trabajo de titulación-MKD-N2','N2','2','6','96','TITULACION'),
('15','1','23','10','UP02-01-MKD','Marketing en buscadores-MKD-N2','N2','2','6','96','ACADEMICA'),
('15','1','23','11','PP-MK','Prácticas Preprofesionales - MK','N2','5','15','240','PRACTICAS'),
('15','1','23','12','UP02-03-MKD','Social media y community management-MKD-N2','N2','2','6','96','ACADEMICA'),
('16','1','24','1','UB01-03-CC','Anatomía animal-CC-N1','N1','4','12','192','ACADEMICA'),
('16','1','24','2','UB01-05-CC','Biología-CC-N1','N1','4','12','192','ACADEMICA'),
('16','1','24','3','UB01-04-CC','Bioquímica-CC-N1','N1','3','9','144','ACADEMICA'),
('16','1','24','4','UB01-02-CC','Comunicación Oral y Escrita-CC-N1','N1','2','6','96','ACADEMICA'),
('16','1','24','5','UB01-01-CC','Matemática-CC-N1','N1','2','96','2','ACADEMICA'),
('16','1','24','6','UB02-01-CC','Bioestadística-CC-N2','N2','2','6','96','ACADEMICA'),
('16','1','24','7','UB02-04-CC','Fisiología animal-CC-N2','N2','3','9','144','ACADEMICA'),
('16','1','24','8','UB02-02-CC','Metodología de la Investigación-CC-N2','N2','2','6','96','ACADEMICA'),
('16','1','24','9','UB02-05-CC','Microbiología-CC-N2','N2','3','9','144','ACADEMICA'),
('16','1','24','10','UB02-03-CC','Técnicas de enfermería veterinaria-CC-N2','N2','3','9','144','ACADEMICA'),
('16','1','24','11','COMP-VINC-CC','Vinculación con la sociedad-CC','N2','2','6','96','VINCULACION'),
('16','1','24','12','UP03-03-CC','Enfermería veterinaria de pequeñas especies-CC-N3','N3','3','9','144','ACADEMICA'),
('16','1','24','13','UP03-05-CC','Estética de y cuidado canino-CC-N3','N3','3','9','144','ACADEMICA'),
('16','1','24','14','UP03-04-CC','Patología en pequeñas especies-CC-N3','N3','3','9','144','ACADEMICA'),
('16','1','24','15','UP03-01-CC','Planificación para el emprendimiento-CC-N3','N3','2','6','96','ACADEMICA'),
('16','1','24','16','PP-CC','Prácticas Preprofesionales - CC','N3','2','6','96','PRACTICAS'),
('16','1','24','17','UP03-02-CC','Realidad nacional-CC-N3','N3','2','6','96','ACADEMICA'),
('16','1','24','18','UP04-05-CC','Adiestramiento canino-CC-N4','N4','2','6','96','ACADEMICA'),
('16','1','24','19','UP04-02-CC','Emergencia y cuidado de pacientes críticos-CC-N4','N4','3','9','144','ACADEMICA'),
('16','1','24','20','UP04-01-CC','Ética, leyes y conexos-CC-N4','N4','2','6','96','ACADEMICA'),
('16','1','24','21','UP04-04-CC','Nutrición de pequeñas especies-CC-N4','N4','2','6','96','ACADEMICA'),
('16','1','24','22','PP-CC-02','Prácticas Preprofesionales Laborales - CC','N4','3','9','144','PRACTICAS'),
('16','1','24','23','UP04-03-CC','Protocolos de enfermería quirúrgica veterinaria-CC-N4','N4','3','9','144','ACADEMICA'),
('16','1','24','24','UI05-05-CC','Desarrollo del trabajo de titulación-CC-N5','N5','2','6','96','TITULACION'),
('16','1','24','25','UI05-03-CC','Diseño y gestión de instalaciones caninas-CC-N5','N5','3','9','144','TITULACION'),
('16','1','24','26','UI05-02-CC','Fauna urbana-CC-N5','N5','3','9','144','TITULACION'),
('16','1','24','27','UI05-01-CC','Genética y reproducción en pequeñas especies-CC-N5','N5','3','9','144','TITULACION'),
('16','1','24','28','UI05-04-CC','Sanidad canina-CC-N5','N5','4','12','192','TITULACION'),
('17','1','25','1','UB01-03-PA','Anatomía animal-PA-N1','N1','4','12','192','ACADEMICA'),
('17','1','25','2','UB01-05-PA','Biología-PA-N1','N1','4','12','192','ACADEMICA'),
('17','1','25','3','UB01-04-PA','Bioquímica-PA-N1','N1','3','9','144','ACADEMICA'),
('17','1','25','4','UB01-02-PA','Comunicación Oral y Escrita-PA-N1','N1','2','6','96','ACADEMICA'),
('17','1','25','5','UB01-01-PA','Matemática-PA-N1','N1','2','6','96','ACADEMICA'),
('17','1','25','6','UB02-01-PA','Bioestadística-PA-N2','N2','2','6','96','ACADEMICA'),
('17','1','25','7','UB02-04-PA','Fisiología animal-PA-N2','N2','3','9','144','ACADEMICA'),
('17','1','25','8','UB02-02-PA','Metodología de la Investigación-PA-N2','N2','2','6','96','ACADEMICA'),
('17','1','25','9','UB02-05-PA','Microbiología-PA-N2','N2','3','9','144','ACADEMICA'),
('17','1','25','10','COMP-VINC-PA','Vinculación con la sociedad - PA','N2','2','6','96','VINCULACION'),
('17','1','25','11','UB02-03-PA','Zootecnia general-PA-N2','N2','3','9','144','ACADEMICA'),
('17','1','25','12','UP03-05-PA','Manejo animal-PA-N3','N3','3','9','144','ACADEMICA'),
('17','1','25','13','UP03-01-PA','Planificación para el emprendimiento-PA-N3','N3','2','6','96','ACADEMICA'),
('17','1','25','14','PP-PA','Prácticas Preprofesionales - PA','N3','2','6','96','PRACTICAS'),
('17','1','25','15','UP03-03-PA','Producción animal I-PA-N3','N3','3','9','144','ACADEMICA'),
('17','1','25','16','UP03-04-PA','Producción de pastos y forrajes-PA-N3','N3','3','9','144','ACADEMICA'),
('17','1','25','17','UP03-02-PA','Realidad nacional-PA-N3','N3','2','6','96','ACADEMICA'),
('17','1','25','18','UP04-01-PA','Ética, leyes y conexos-PA-N4','N4','2','6','96','ACADEMICA'),
('17','1','25','19','UP04-05-PA','Higiene de los alimentos-PA-N4','N4','2','6','96','ACADEMICA'),
('17','1','25','20','UP04-04-PA','Nutrición y alimentación animal-PA-N4','N4','2','6','96','ACADEMICA'),
('17','1','25','21','PP-PA-2','Prácticas Preprofesionales Laborales - PA','N4','3','9','144','PRACTICAS'),
('17','1','25','22','UP04-03-PA','Producción animal II-PA-N4','N4','3','9','144','ACADEMICA'),
('17','1','25','23','UP04-02-PA','Proyectos de inversión pecuaria-PA-N4','N4','3','9','144','ACADEMICA'),
('17','1','25','24','UI05-05-PA','Desarrollo del trabajo de titulación-PA-N5','N5','2','6','96','TITULACION'),
('17','1','25','25','UI05-01-PA','Genética y reproducción animal-PA-N5','N5','3','9','144','TITULACION'),
('17','1','25','26','UI05-02-PA','Industrialización de leche y carne-PA-N5','N5','3','9','144','TITULACION'),
('17','1','25','27','UI05-03-PA','Producción animal III-PA-N5','N5','4','12','192','TITULACION'),
('17','1','25','28','UI05-04-PA','Sanidad animal-PA-N5','N5','3','9','144','TITULACION'),
('18','1','26','1','UB01-02-TOP-RED','Comunicación Oral y Escrita-TOP-RED-N1','N1','2','6','96','ACADEMICA'),
('18','1','26','2','UB01-03-TOP-RED','Dibujo Técnico y Topográfico-TOP-RED-N1','N1','4','12','192','ACADEMICA'),
('18','1','26','3','UB01-05-TOP-RED','Física-TOP-RED-N1','N1','3','9','144','ACADEMICA'),
('18','1','26','4','UB01-04-TOP-RED','Geometría y Trigonometría-TOP-RED-N1','N1','4','12','192','ACADEMICA'),
('18','1','26','5','UB01-01-TOP-RED','Matemática-TOP-RED-N1','N1','2','6','96','ACADEMICA'),
('18','1','26','6','UP02-01-TOP-RED','Estadística-TOP-RED-N2','N2','2.25','6.75','108','ACADEMICA'),
('18','1','26','7','UP02-04-TOP-RED','Fundamentos de estructura urbana-TOP-RED-N2','N2','3','9','144','ACADEMICA'),
('18','1','26','8','UP02-02-TOP-RED','Geología General-TOP-RED-N2','N2','2.25','6.75','108','ACADEMICA'),
('18','1','26','9','UP02-03-TOP-RED','Instrumentación y Fotogrametría-TOP-RED-N2','N2','3.25','9.75','156','ACADEMICA'),
('18','1','26','10','COMP-SP-TOP-RED','Servicio Comunitario-TOP-RED','N2','1','3.75','60','VINCULACION'),
('18','1','26','11','UP02-05-TOP-RED','Topografía de Superficies 1-TOP-RED-N2','N2','3','9','144','ACADEMICA'),
('18','1','26','12','UP03-04-TOP-RED','Cartografía y Geodesia-TOP-RED-N3','N3','2','6','96','ACADEMICA'),
('18','1','26','13','UP03-03-TOP-RED','Normativa y Legislación aplicada-TOP-RED-N3','N3','2','6','96','ACADEMICA'),
('18','1','26','14','PL-TOP-RED','Prácticas Laborales - TOP -RED','N3','5','15','240','PRACTICAS'),
('18','1','26','15','UP03-01-TOP-RED','Prevención de Riesgos en Obra-TOP-RED-N3','N3','2','6','96','ACADEMICA'),
('18','1','26','16','UP03-05-TOP-RED','Topografía de Superficies 2-TOP-RED-N3','N3','2','6','96','ACADEMICA'),
('18','1','26','17','UP03-02-TOP-RED','Topografía digital-TOP-RED-N3','N3','2','6','96','ACADEMICA'),
('18','1','26','18','UI04-05-TOP-RED','Desarrollo del trabajo de titulación-TOP-RED-N4','N4','2','6','96','TITULACION'),
('18','1','26','19','UP04-02-TOP-RED','Fiscalización y Control de Obras-TOP-RED-N4','N4','3','9','144','ACADEMICA'),
('18','1','26','20','UP04-03-TOP-RED','Planificación para el emprendimiento-TOP-RED-N4','N4','2','6','96','ACADEMICA'),
('18','1','26','21','UP04-04-TOP-RED','Topografía en Obras Civiles-TOP-RED-N4','N4','4','12','192','ACADEMICA'),
('18','1','26','22','UP04-01-TOP-RED','Topografía Subterránea-TOP-RED-N4','N4','4','12','192','ACADEMICA'),
('18','2','27','1','UB01-02-TOP','Comunicación Oral y Escrita-TOP -N1','N1','2','6','96','ACADEMICA'),
('18','2','27','2','UB01-03-TOP','Dibujo Técnico y Topográfico-TOP -N1','N1','4','12','192','ACADEMICA'),
('18','2','27','3','UB01-05-TOP','Física-TOP -N1','N1','3','9','144','ACADEMICA'),
('18','2','27','4','UB01-04-TOP','Geometría y Trigonometría-TOP -N1','N1','4','12','192','ACADEMICA'),
('18','2','27','5','UB01-01-TOP','Matemática-TOP -N1','N1','2','6','96','ACADEMICA'),
('18','2','27','6','UP02-01-TOP','Estadística-TOP-N2','N2','2','6','96','ACADEMICA'),
('18','2','27','7','UP02-04-TOP','Fundamentos de estructura urbana-TOP-N2','N2','3','9','144','ACADEMICA'),
('18','2','27','8','UP02-02-TOP','Geología General-TOP-N2','N2','2','6','96','ACADEMICA'),
('18','2','27','9','UP02-03-TOP','Instrumentación y Fotometría-TOP-N2','N2','3','9','144','ACADEMICA'),
('18','2','27','10','UP02-05-TOP','Topografía de Superficies 1-TOP-N2','N2','3','9','144','ACADEMICA'),
('18','2','27','11','COMP-VINC-TOP','Vinculación con la sociedad - TOP','N2','2','6','96','VINCULACION'),
('18','2','27','12','UP03-04-TOP','Cartografía y Geodesia-TOP-N3','N3','2','6','96','ACADEMICA'),
('18','2','27','13','UP03-03-TOP','Normativa y Legislación aplicada-TOP-N3','N3','2','6','96','ACADEMICA'),
('18','2','27','14','PP-TOP','Prácticas Preprofesionales - TOP','N3','5','15','240','PRACTICAS'),
('18','2','27','15','UP03-01-TOP','Prevención de Riesgos en Obra-TOP-N3','N3','2','6','96','ACADEMICA'),
('18','2','27','16','UP03-05-TOP','Topografía de Superficies 2-TOP-N3','N3','2','6','96','ACADEMICA'),
('18','2','27','17','UP03-02-TOP','Topografía digital-TOP-N3','N3','2','6','96','ACADEMICA'),
('18','2','27','18','UI04-05-TOP','Desarrollo del trabajo de titulación-TOP-N4','N4','2','6','96','TITULACION'),
('18','2','27','19','UI04-02-TOP','Fiscalización y Control de Obras-TOP-N4','N4','3','9','144','TITULACION'),
('18','2','27','20','UI04-03-TOP','Planificación para el emprendimiento-TOP-N4','N4','2','6','96','TITULACION'),
('18','2','27','21','UI04-04-TOP','Topografía en Obras Civiles-TOP-N4','N4','4','12','192','TITULACION'),
('18','2','27','22','UI04-01-TOP','Topografía Subterránea-TOP-N4','N4','4','12','192','TITULACION');


-- Catálogo maestro de asignaturas: el código Q10 es la identidad de migración.
INSERT INTO asignaturas(tipo_asignatura_id,codigo,nombre,descripcion,activo)
SELECT ta.id,a.codigo,LEFT(MIN(a.nombre),220),'Importada desde Q10',1
FROM _q10_asignaturas a
JOIN tipos_asignatura ta ON ta.codigo=a.tipo_codigo
WHERE NOT EXISTS(SELECT 1 FROM asignaturas x WHERE x.codigo=a.codigo)
GROUP BY ta.id,a.codigo;

-- Relaciones malla-asignatura. Si el mismo código aparece varias veces en el
-- mismo canon por una duplicación fuente, se toma una sola relación.
INSERT INTO malla_asignaturas(
 malla_id,asignatura_id,nivel_academico_id,creditos,ih_semanal,ih_total,
 orden_en_nivel,obligatoria,evaluable,activa
)
SELECT mc.id,asi.id,n.id,a.creditos,a.ih_semanal,a.ih_total,a.orden_en_nivel,1,1,1
FROM _q10_asignaturas a
JOIN _q10_programas p ON p.src_id=a.src_programa_id
JOIN migracion_q10_programas mp ON mp.q10_programa_codigo=p.q10_codigo AND mp.q10_programa_nombre=p.q10_nombre
JOIN mallas_curriculares mc ON mc.carrera_id=mp.carrera_id
 AND mc.codigo=CONCAT('Q10-',LPAD(a.canon_id,3,'0'))
JOIN asignaturas asi ON asi.codigo=a.codigo
JOIN niveles_academicos n ON n.codigo=a.nivel_codigo
WHERE NOT EXISTS(
 SELECT 1 FROM malla_asignaturas ma
 WHERE ma.malla_id=mc.id AND ma.asignatura_id=asi.id
)
GROUP BY mc.id,asi.id,n.id,a.creditos,a.ih_semanal,a.ih_total,a.orden_en_nivel;

-- Trazabilidad de asignaturas fuente para futura importación del histórico.
INSERT INTO migracion_q10_asignaturas(
 migracion_q10_malla_id,q10_asignatura_codigo,q10_asignatura_nombre,malla_asignatura_id
)
SELECT mm.id,a.codigo,a.nombre,ma.id
FROM _q10_asignaturas a
JOIN _q10_programas p ON p.src_id=a.src_programa_id
JOIN migracion_q10_programas mp ON mp.q10_programa_codigo=p.q10_codigo AND mp.q10_programa_nombre=p.q10_nombre
JOIN migracion_q10_mallas mm ON mm.migracion_q10_programa_id=mp.id AND mm.q10_malla_orden=a.q10_malla_orden
JOIN asignaturas asi ON asi.codigo=a.codigo
JOIN malla_asignaturas ma ON ma.malla_id=mm.malla_id AND ma.asignatura_id=asi.id
WHERE NOT EXISTS(
 SELECT 1 FROM migracion_q10_asignaturas x
 WHERE x.migracion_q10_malla_id=mm.id AND x.q10_asignatura_codigo=a.codigo
);

-- ============================================================
-- VALIDACIONES DE IMPORTACIÓN
-- ============================================================
SELECT 'PROGRAMAS_Q10' indicador, COUNT(*) total FROM migracion_q10_programas
UNION ALL
SELECT 'CARRERAS_Q10_DISTINTAS', COUNT(DISTINCT carrera_id) FROM migracion_q10_programas
UNION ALL
SELECT 'MALLAS_Q10_FUENTE', COUNT(*) FROM migracion_q10_mallas
UNION ALL
SELECT 'MALLAS_ORION_UNICAS', COUNT(DISTINCT malla_id) FROM migracion_q10_mallas
UNION ALL
SELECT 'ASIGNATURAS_Q10_FUENTE', COUNT(*) FROM migracion_q10_asignaturas
UNION ALL
SELECT 'ASIGNATURAS_ORION_UNICAS', COUNT(DISTINCT ma.asignatura_id)
FROM migracion_q10_asignaturas mq
JOIN malla_asignaturas ma ON ma.id=mq.malla_asignatura_id;

-- Debe devolver 0: ningún prerrequisito es creado por esta importación.
SELECT COUNT(*) AS prerrequisitos_creados_por_importacion
FROM malla_asignatura_prerrequisitos pr
JOIN malla_asignaturas ma ON ma.id=pr.malla_asignatura_id
JOIN migracion_q10_mallas mm ON mm.malla_id=ma.malla_id;

COMMIT;
SET SQL_SAFE_UPDATES = @OLD_SQL_SAFE_UPDATES;
