-- Orion v0.8.0 - Base de migración histórica Q10
-- Ejecutar UNA vez después de 010_orion_importacion_academica_q10.sql.
SET NAMES utf8mb4;
SET @db = DATABASE();

-- Orden histórico explícito de Q10. No se usa el ID para ordenar periodos.
SET @sql = IF(
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=@db AND table_name='periodos_academicos' AND column_name='ordenamiento'),
  'SELECT 1',
  'ALTER TABLE periodos_academicos ADD COLUMN ordenamiento SMALLINT UNSIGNED NULL AFTER fecha_fin_calificaciones'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
  EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema=@db AND table_name='periodos_academicos' AND index_name='idx_periodos_ordenamiento'),
  'SELECT 1',
  'CREATE INDEX idx_periodos_ordenamiento ON periodos_academicos(institucion_id, ordenamiento)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS migracion_q10_historico_ejecuciones (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(80) NOT NULL UNIQUE,
 estado ENUM('INICIADA','COMPLETADA','ERROR') NOT NULL,
 iniciada_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 finalizada_at DATETIME NULL,
 resumen_json JSON NULL,
 error_text TEXT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migracion_q10_historico_cursos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 source_course_id INT UNSIGNED NOT NULL UNIQUE,
 archivo VARCHAR(700) NOT NULL,
 periodo_q10 VARCHAR(180) NOT NULL,
 programa_q10 VARCHAR(255) NOT NULL,
 asignatura_q10 VARCHAR(255) NOT NULL,
 curso_q10 VARCHAR(255) NULL,
 docente_q10 VARCHAR(255) NULL,
 esquema_fuente VARCHAR(60) NOT NULL,
 periodo_academico_id BIGINT UNSIGNED NULL,
 carrera_id BIGINT UNSIGNED NULL,
 malla_id BIGINT UNSIGNED NULL,
 malla_asignatura_id BIGINT UNSIGNED NULL,
 oferta_academica_id BIGINT UNSIGNED NULL,
 seccion_id BIGINT UNSIGNED NULL,
 estado VARCHAR(40) NOT NULL DEFAULT 'PENDIENTE',
 detalle VARCHAR(500) NULL,
 imported_at DATETIME NULL,
 CONSTRAINT fk_mqh_curso_periodo FOREIGN KEY(periodo_academico_id) REFERENCES periodos_academicos(id),
 CONSTRAINT fk_mqh_curso_carrera FOREIGN KEY(carrera_id) REFERENCES carreras(id),
 CONSTRAINT fk_mqh_curso_malla FOREIGN KEY(malla_id) REFERENCES mallas_curriculares(id),
 CONSTRAINT fk_mqh_curso_ma FOREIGN KEY(malla_asignatura_id) REFERENCES malla_asignaturas(id),
 CONSTRAINT fk_mqh_curso_oferta FOREIGN KEY(oferta_academica_id) REFERENCES ofertas_academicas(id),
 CONSTRAINT fk_mqh_curso_seccion FOREIGN KEY(seccion_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migracion_q10_historico_notas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 source_grade_id INT UNSIGNED NOT NULL UNIQUE,
 source_course_id INT UNSIGNED NOT NULL,
 fila_excel INT UNSIGNED NOT NULL,
 estudiante_q10 VARCHAR(255) NOT NULL,
 identificacion VARCHAR(30) NULL,
 match_status VARCHAR(50) NOT NULL,
 matricula_asignatura_id BIGINT UNSIGNED NULL,
 nota_ordinaria DECIMAL(8,4) NULL,
 nota_supletorio DECIMAL(8,4) NULL,
 nota_final DECIMAL(8,4) NULL,
 inasistencias_acumuladas DECIMAL(10,2) NULL,
 observaciones TEXT NULL,
 estado VARCHAR(40) NOT NULL DEFAULT 'PENDIENTE',
 detalle VARCHAR(500) NULL,
 imported_at DATETIME NULL,
 CONSTRAINT fk_mqh_nota_curso FOREIGN KEY(source_course_id) REFERENCES migracion_q10_historico_cursos(source_course_id),
 CONSTRAINT fk_mqh_nota_ma FOREIGN KEY(matricula_asignatura_id) REFERENCES matricula_asignaturas(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migracion_q10_historico_incidentes (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tipo VARCHAR(80) NOT NULL,
 severidad ENUM('INFO','ADVERTENCIA','ERROR') NOT NULL,
 referencia VARCHAR(255) NULL,
 detalle TEXT NOT NULL,
 resuelto BOOLEAN NOT NULL DEFAULT FALSE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_mqh_incidente(tipo,referencia)
) ENGINE=InnoDB;

-- Esquemas históricos separados de la versión operativa 2026.
INSERT INTO esquemas_evaluacion(codigo,nombre,descripcion,activo)
SELECT 'Q10_HIST_FINAL','Q10 histórico - Nota final','Migración de reportes antiguos que solo conservan resultado final.',1
WHERE NOT EXISTS(SELECT 1 FROM esquemas_evaluacion WHERE codigo='Q10_HIST_FINAL');
INSERT INTO esquemas_evaluacion(codigo,nombre,descripcion,activo)
SELECT 'Q10_HIST_GENERAL','Q10 histórico - Dos parciales','Dos parciales de 50% con nueve parámetros por parcial, preservados desde Q10.',1
WHERE NOT EXISTS(SELECT 1 FROM esquemas_evaluacion WHERE codigo='Q10_HIST_GENERAL');
INSERT INTO esquemas_evaluacion(codigo,nombre,descripcion,activo)
SELECT 'Q10_HIST_PRACTICAS','Q10 histórico - Prácticas','Evaluación Tutor Académico / Entidad Formadora, 50% cada parcial.',1
WHERE NOT EXISTS(SELECT 1 FROM esquemas_evaluacion WHERE codigo='Q10_HIST_PRACTICAS');

SET @estado_hist=(SELECT id FROM estados_esquema_evaluacion WHERE codigo='HISTORICO' LIMIT 1);
INSERT INTO esquema_evaluacion_versiones(esquema_evaluacion_id,estado_esquema_id,numero_version,nombre_version,descripcion_cambio,vigente_desde,fecha_publicacion)
SELECT e.id,@estado_hist,1,'Migración histórica Q10','Reconstruida desde exportaciones oficiales Q10.','2019-01-01',NOW()
FROM esquemas_evaluacion e WHERE e.codigo IN ('Q10_HIST_FINAL','Q10_HIST_GENERAL','Q10_HIST_PRACTICAS')
AND NOT EXISTS(SELECT 1 FROM esquema_evaluacion_versiones v WHERE v.esquema_evaluacion_id=e.id AND v.numero_version=1);

-- Final histórico: 1 parcial / 1 parámetro.
SET @vf=(SELECT v.id FROM esquema_evaluacion_versiones v JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE e.codigo='Q10_HIST_FINAL' AND v.numero_version=1);
INSERT INTO parciales_evaluacion(esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual)
SELECT @vf,'FINAL','Resultado final histórico',100,1 WHERE NOT EXISTS(SELECT 1 FROM parciales_evaluacion WHERE esquema_version_id=@vf AND codigo='FINAL');
SET @pf=(SELECT id FROM parciales_evaluacion WHERE esquema_version_id=@vf AND codigo='FINAL');
INSERT INTO parametros_evaluacion(parcial_id,codigo,nombre,ponderacion_parcial,orden_visual)
SELECT @pf,'NOTA_FINAL','Nota final histórica',100,1 WHERE NOT EXISTS(SELECT 1 FROM parametros_evaluacion WHERE parcial_id=@pf AND codigo='NOTA_FINAL');

-- General Q10: 2 parciales de 50%.
SET @vg=(SELECT v.id FROM esquema_evaluacion_versiones v JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE e.codigo='Q10_HIST_GENERAL' AND v.numero_version=1);
INSERT INTO parciales_evaluacion(esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual)
SELECT @vg,'P1','Parcial 1',50,1 WHERE NOT EXISTS(SELECT 1 FROM parciales_evaluacion WHERE esquema_version_id=@vg AND codigo='P1');
INSERT INTO parciales_evaluacion(esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual)
SELECT @vg,'P2','Parcial 2',50,2 WHERE NOT EXISTS(SELECT 1 FROM parciales_evaluacion WHERE esquema_version_id=@vg AND codigo='P2');
SET @p1=(SELECT id FROM parciales_evaluacion WHERE esquema_version_id=@vg AND codigo='P1');
SET @p2=(SELECT id FROM parciales_evaluacion WHERE esquema_version_id=@vg AND codigo='P2');
INSERT IGNORE INTO parametros_evaluacion(parcial_id,codigo,nombre,ponderacion_parcial,orden_visual) VALUES
(@p1,'U1_AUTONOMA_1','U1 Actividad Autónoma 1',10,1),
(@p1,'U1_PRACTICO_1_1','U1 Práctico Experimental 1.1',8.75,2),
(@p1,'U1_PRACTICO_EF_1_2','U1 Práctico Experimental EF 1.2',8.75,3),
(@p1,'U2_AUTONOMA_2','U2 Actividad Autónoma 2',10,4),
(@p1,'U2_PRACTICO_2_1','U2 Práctico Experimental 2.1',8.75,5),
(@p1,'U2_PRACTICO_EF_2_2','U2 Práctico Experimental EF 2.2',8.75,6),
(@p1,'P1_CONTACTO_DOCENTE','P1 Contacto con el Docente',10,7),
(@p1,'P1_EVAL_FINAL_TEORICO','P1 Evaluación Final Teórico 1.1',17.5,8),
(@p1,'P1_EVAL_FINAL_PRACTICO','P1 Evaluación Final Práctico 1.2',17.5,9),
(@p2,'U3_AUTONOMA_1','U3 Actividad Autónoma 1',10,1),
(@p2,'U3_PRACTICO_1_1','U3 Práctico Experimental 1.1',8.75,2),
(@p2,'U3_PRACTICO_EF_1_2','U3 Práctico Experimental EF 1.2',8.75,3),
(@p2,'U4_AUTONOMA_2','U4 Actividad Autónoma 2',10,4),
(@p2,'U4_PRACTICO_2_1','U4 Práctico Experimental 2.1',8.75,5),
(@p2,'U4_PRACTICO_EF_2_2','U4 Práctico Experimental EF 2.2',8.75,6),
(@p2,'P2_CONTACTO_DOCENTE','P2 Contacto con el Docente',10,7),
(@p2,'P2_EVAL_FINAL_TEORICO','P2 Evaluación Final Teórico 1.1',17.5,8),
(@p2,'P2_EVAL_FINAL_PRACTICO','P2 Evaluación Final Práctico 1.2',17.5,9);

-- Prácticas: 2 parciales de 50%, un parámetro 100% en cada parcial.
SET @vp=(SELECT v.id FROM esquema_evaluacion_versiones v JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE e.codigo='Q10_HIST_PRACTICAS' AND v.numero_version=1);
INSERT INTO parciales_evaluacion(esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual)
SELECT @vp,'P1','Evaluación Tutor Académico',50,1 WHERE NOT EXISTS(SELECT 1 FROM parciales_evaluacion WHERE esquema_version_id=@vp AND codigo='P1');
INSERT INTO parciales_evaluacion(esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual)
SELECT @vp,'P2','Evaluación Tutor Empresarial / Entidad Formadora',50,2 WHERE NOT EXISTS(SELECT 1 FROM parciales_evaluacion WHERE esquema_version_id=@vp AND codigo='P2');
SET @pp1=(SELECT id FROM parciales_evaluacion WHERE esquema_version_id=@vp AND codigo='P1');
SET @pp2=(SELECT id FROM parciales_evaluacion WHERE esquema_version_id=@vp AND codigo='P2');
INSERT INTO parametros_evaluacion(parcial_id,codigo,nombre,ponderacion_parcial,orden_visual)
SELECT @pp1,'INFORME_ACTIVIDADES','Informe de Actividades / Evaluación Tutor Académico',100,1 WHERE NOT EXISTS(SELECT 1 FROM parametros_evaluacion WHERE parcial_id=@pp1 AND codigo='INFORME_ACTIVIDADES');
INSERT INTO parametros_evaluacion(parcial_id,codigo,nombre,ponderacion_parcial,orden_visual)
SELECT @pp2,'ENTIDAD_FORMADORA','Evaluación Entidad Formadora / Tutor Empresarial',100,1 WHERE NOT EXISTS(SELECT 1 FROM parametros_evaluacion WHERE parcial_id=@pp2 AND codigo='ENTIDAD_FORMADORA');

-- Política histórica separada; mismos umbrales institucionales cargados en Orion.
INSERT INTO politicas_resultado_academico(codigo,nombre,descripcion,activo)
SELECT 'Q10_HISTORICO','Política histórica Q10','Política usada únicamente para resultados migrados; no altera la política operativa.',1
WHERE NOT EXISTS(SELECT 1 FROM politicas_resultado_academico WHERE codigo='Q10_HISTORICO');
SET @pol=(SELECT id FROM politicas_resultado_academico WHERE codigo='Q10_HISTORICO');
INSERT INTO politica_resultado_versiones(politica_resultado_id,numero_version,vigente_desde)
SELECT @pol,1,'2019-01-01' WHERE NOT EXISTS(SELECT 1 FROM politica_resultado_versiones WHERE politica_resultado_id=@pol AND numero_version=1);
SET @polv=(SELECT id FROM politica_resultado_versiones WHERE politica_resultado_id=@pol AND numero_version=1);
INSERT IGNORE INTO reglas_resultado_academico(politica_version_id,resultado_academico_id,nota_minima,nota_maxima,orden_evaluacion)
SELECT @polv,id,0,4.99,1 FROM resultados_academicos_catalogo WHERE codigo='REPROBADO_SIN_SUPLETORIO';
INSERT IGNORE INTO reglas_resultado_academico(politica_version_id,resultado_academico_id,nota_minima,nota_maxima,orden_evaluacion)
SELECT @polv,id,5,6.99,2 FROM resultados_academicos_catalogo WHERE codigo='HABILITADO_SUPLETORIO';
INSERT IGNORE INTO reglas_resultado_academico(politica_version_id,resultado_academico_id,nota_minima,nota_maxima,orden_evaluacion)
SELECT @polv,id,7,10,3 FROM resultados_academicos_catalogo WHERE codigo='APROBADO';

SELECT '011_OK' AS estado,
 (SELECT COUNT(*) FROM esquemas_evaluacion WHERE codigo LIKE 'Q10_HIST_%') AS esquemas_historicos,
 (SELECT COUNT(*) FROM parametros_evaluacion p JOIN parciales_evaluacion pa ON pa.id=p.parcial_id JOIN esquema_evaluacion_versiones v ON v.id=pa.esquema_version_id JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE e.codigo LIKE 'Q10_HIST_%') AS parametros_historicos;
