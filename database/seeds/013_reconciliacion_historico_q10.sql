-- ORION v0.8.0 - Reconciliacion historica Q10
-- Corrige asociaciones trayectoria/malla detectadas por auditoria funcional.
-- No modifica notas ni calificaciones; conserva matricula_asignatura.id.
-- Precondicion auditada: 14,632 notas; 4,400 misma carrera/malla distinta; 29 carrera cruzada.

SET @orion_recon_run := 'HIST_Q10_V080_RECON_001';

CREATE TABLE IF NOT EXISTS migracion_q10_reconciliacion_trayectorias_backup (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_code VARCHAR(80) NOT NULL,
  estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
  malla_id_anterior BIGINT UNSIGNED NOT NULL,
  malla_id_objetivo BIGINT UNSIGNED NOT NULL,
  respaldado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mq10_recon_tray (run_code, estudiante_carrera_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS migracion_q10_reconciliacion_matriculas_backup (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_code VARCHAR(80) NOT NULL,
  matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
  matricula_id_anterior BIGINT UNSIGNED NOT NULL,
  trayectoria_anterior_id BIGINT UNSIGNED NOT NULL,
  trayectoria_objetivo_id BIGINT UNSIGNED NOT NULL,
  periodo_academico_id BIGINT UNSIGNED NOT NULL,
  carrera_objetivo_id BIGINT UNSIGNED NOT NULL,
  malla_objetivo_id BIGINT UNSIGNED NOT NULL,
  oferta_objetivo_id BIGINT UNSIGNED NOT NULL,
  respaldado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mq10_recon_ma (run_code, matricula_asignatura_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TEMPORARY TABLE IF EXISTS tmp_q10_recon;
CREATE TEMPORARY TABLE tmp_q10_recon AS
SELECT
  qn.matricula_asignatura_id,
  qn.source_grade_id,
  qc.periodo_academico_id,
  qc.carrera_id AS carrera_objetivo_id,
  qc.malla_id AS malla_objetivo_id,
  qc.oferta_academica_id AS oferta_objetivo_id,
  m.id AS matricula_actual_id,
  ec.id AS trayectoria_actual_id,
  ec.estudiante_id,
  ec.carrera_id AS carrera_actual_id,
  ec.malla_id AS malla_actual_id
FROM migracion_q10_historico_notas qn
JOIN migracion_q10_historico_cursos qc ON qc.source_course_id=qn.source_course_id
JOIN matricula_asignaturas ma ON ma.id=qn.matricula_asignatura_id
JOIN matriculas m ON m.id=ma.matricula_id
JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id
WHERE qn.estado='IMPORTADO';

ALTER TABLE tmp_q10_recon
  ADD PRIMARY KEY (matricula_asignatura_id),
  ADD KEY idx_tmp_tray (trayectoria_actual_id),
  ADD KEY idx_tmp_target (estudiante_id,carrera_objetivo_id,malla_objetivo_id,periodo_academico_id);

DROP PROCEDURE IF EXISTS orion_assert_q10_recon;
DELIMITER $$
CREATE PROCEDURE orion_assert_q10_recon()
BEGIN
  DECLARE v_total INT DEFAULT 0;
  DECLARE v_same INT DEFAULT 0;
  DECLARE v_cross INT DEFAULT 0;
  DECLARE v_ambiguous INT DEFAULT 0;
  DECLARE v_missing_traj INT DEFAULT 0;
  DECLARE v_ambiguous_target_traj INT DEFAULT 0;

  SELECT COUNT(*) INTO v_total FROM tmp_q10_recon;
  SELECT COUNT(*) INTO v_same FROM tmp_q10_recon WHERE carrera_actual_id=carrera_objetivo_id AND malla_actual_id<>malla_objetivo_id;
  SELECT COUNT(*) INTO v_cross FROM tmp_q10_recon WHERE carrera_actual_id<>carrera_objetivo_id;

  SELECT COUNT(*) INTO v_ambiguous
  FROM (
    SELECT trayectoria_actual_id
    FROM tmp_q10_recon
    WHERE carrera_actual_id=carrera_objetivo_id
    GROUP BY trayectoria_actual_id
    HAVING COUNT(DISTINCT malla_objetivo_id)>1
  ) x;

  SELECT COUNT(*) INTO v_missing_traj
  FROM tmp_q10_recon t
  WHERE t.carrera_actual_id<>t.carrera_objetivo_id
    AND NOT EXISTS (
      SELECT 1 FROM estudiante_carreras ec2
      WHERE ec2.estudiante_id=t.estudiante_id
        AND ec2.carrera_id=t.carrera_objetivo_id
        AND ec2.deleted_at IS NULL
    );

  SELECT COUNT(*) INTO v_ambiguous_target_traj
  FROM (
    SELECT t.matricula_asignatura_id
    FROM tmp_q10_recon t
    JOIN estudiante_carreras ec2
      ON ec2.estudiante_id=t.estudiante_id
     AND ec2.carrera_id=t.carrera_objetivo_id
     AND ec2.deleted_at IS NULL
    WHERE t.carrera_actual_id<>t.carrera_objetivo_id
    GROUP BY t.matricula_asignatura_id
    HAVING COUNT(*)<>1
  ) z;

  IF v_total <> 14632 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: total historico Q10 distinto de 14632';
  END IF;
  IF v_same NOT IN (4400,0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: diferencias de malla no coinciden con preflight 4400/0';
  END IF;
  IF v_cross NOT IN (29,0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: cruces de carrera no coinciden con preflight 29/0';
  END IF;
  IF (v_same=0 AND v_cross<>0) OR (v_same<>0 AND v_cross=0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: estado parcial de reconciliacion detectado';
  END IF;
  IF v_ambiguous <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: una trayectoria apunta a multiples mallas Q10';
  END IF;
  IF v_missing_traj <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: falta trayectoria correcta para algun cruce de carrera';
  END IF;
  IF v_ambiguous_target_traj <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ABORT: cruce de carrera con trayectoria objetivo ambigua';
  END IF;
END$$
DELIMITER ;

CALL orion_assert_q10_recon();
DROP PROCEDURE orion_assert_q10_recon;

SELECT
  COUNT(*) AS total_historico,
  SUM(carrera_actual_id=carrera_objetivo_id AND malla_actual_id=malla_objetivo_id) AS consistentes_antes,
  SUM(carrera_actual_id=carrera_objetivo_id AND malla_actual_id<>malla_objetivo_id) AS misma_carrera_malla_distinta_antes,
  SUM(carrera_actual_id<>carrera_objetivo_id) AS carrera_cruzada_antes
FROM tmp_q10_recon;

DROP TEMPORARY TABLE IF EXISTS tmp_q10_assert_post;
CREATE TEMPORARY TABLE tmp_q10_assert_post (
  errores INT NOT NULL,
  CONSTRAINT chk_q10_assert_post CHECK (errores=0)
);

START TRANSACTION;

-- 1. Respaldar las trayectorias cuya malla sera corregida.
INSERT IGNORE INTO migracion_q10_reconciliacion_trayectorias_backup
(run_code,estudiante_carrera_id,malla_id_anterior,malla_id_objetivo)
SELECT
  @orion_recon_run,
  trayectoria_actual_id,
  MIN(malla_actual_id),
  MIN(malla_objetivo_id)
FROM tmp_q10_recon
WHERE carrera_actual_id=carrera_objetivo_id
  AND malla_actual_id<>malla_objetivo_id
GROUP BY trayectoria_actual_id;

-- 2. Respaldar las 29 matricula_asignatura antes de moverlas.
INSERT IGNORE INTO migracion_q10_reconciliacion_matriculas_backup
(run_code,matricula_asignatura_id,matricula_id_anterior,trayectoria_anterior_id,
 trayectoria_objetivo_id,periodo_academico_id,carrera_objetivo_id,malla_objetivo_id,oferta_objetivo_id)
SELECT
  @orion_recon_run,
  t.matricula_asignatura_id,
  t.matricula_actual_id,
  t.trayectoria_actual_id,
  ec2.id,
  t.periodo_academico_id,
  t.carrera_objetivo_id,
  t.malla_objetivo_id,
  t.oferta_objetivo_id
FROM tmp_q10_recon t
JOIN estudiante_carreras ec2
  ON ec2.estudiante_id=t.estudiante_id
 AND ec2.carrera_id=t.carrera_objetivo_id
 AND ec2.deleted_at IS NULL
WHERE t.carrera_actual_id<>t.carrera_objetivo_id;

-- 3. Crear las matriculas historicas faltantes en la trayectoria correcta.
--    Se clonan tipo/estado/fechas de la matricula historica origen,
--    pero la oferta es la del curso Q10 correcto.
INSERT INTO matriculas
(numero_matricula,estudiante_carrera_id,periodo_academico_id,oferta_academica_id,
 tipo_matricula_id,estado_matricula_id,fecha_solicitud,fecha_matricula,fecha_confirmacion,
 fecha_anulacion,generada_automaticamente,creada_por_usuario_id,confirmada_por_usuario_id,
 anulada_por_usuario_id,observacion,motivo_anulacion,activo)
SELECT DISTINCT
  CONCAT('Q10R-', t.estudiante_id, '-', t.periodo_academico_id, '-', ec2.id),
  ec2.id,
  t.periodo_academico_id,
  t.oferta_objetivo_id,
  mo.tipo_matricula_id,
  mo.estado_matricula_id,
  mo.fecha_solicitud,
  mo.fecha_matricula,
  mo.fecha_confirmacion,
  mo.fecha_anulacion,
  1,
  NULL,
  NULL,
  NULL,
  'Reconciliación histórica Q10 v0.8.0: carrera corregida según curso fuente',
  mo.motivo_anulacion,
  mo.activo
FROM tmp_q10_recon t
JOIN estudiante_carreras ec2
  ON ec2.estudiante_id=t.estudiante_id
 AND ec2.carrera_id=t.carrera_objetivo_id
 AND ec2.deleted_at IS NULL
JOIN matriculas mo ON mo.id=t.matricula_actual_id
WHERE t.carrera_actual_id<>t.carrera_objetivo_id
  AND NOT EXISTS (
    SELECT 1 FROM matriculas mx
    WHERE mx.estudiante_carrera_id=ec2.id
      AND mx.periodo_academico_id=t.periodo_academico_id
  );

-- 4. Mover la matricula_asignatura conservando su ID y, por tanto,
--    todas sus calificaciones, resultados y trazabilidad.
UPDATE matricula_asignaturas ma
JOIN migracion_q10_reconciliacion_matriculas_backup b
  ON b.run_code=@orion_recon_run
 AND b.matricula_asignatura_id=ma.id
JOIN matriculas md
  ON md.estudiante_carrera_id=b.trayectoria_objetivo_id
 AND md.periodo_academico_id=b.periodo_academico_id
SET ma.matricula_id=md.id,
    ma.updated_at=NOW();

-- 5. Corregir malla de trayectorias que, dentro de la misma carrera,
--    apuntaban de forma univoca a otra malla Q10 real.
UPDATE estudiante_carreras ec
JOIN migracion_q10_reconciliacion_trayectorias_backup b
  ON b.run_code=@orion_recon_run
 AND b.estudiante_carrera_id=ec.id
SET ec.malla_id=b.malla_id_objetivo,
    ec.updated_at=NOW();

-- 6. Validacion dentro de la misma transaccion.
DROP TEMPORARY TABLE IF EXISTS tmp_q10_post;
CREATE TEMPORARY TABLE tmp_q10_post AS
SELECT
  qn.matricula_asignatura_id,
  ec.carrera_id AS carrera_actual_id,
  ec.malla_id AS malla_actual_id,
  qc.carrera_id AS carrera_objetivo_id,
  qc.malla_id AS malla_objetivo_id
FROM migracion_q10_historico_notas qn
JOIN migracion_q10_historico_cursos qc ON qc.source_course_id=qn.source_course_id
JOIN matricula_asignaturas ma ON ma.id=qn.matricula_asignatura_id
JOIN matriculas m ON m.id=ma.matricula_id
JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id
WHERE qn.estado='IMPORTADO';

INSERT INTO tmp_q10_assert_post(errores)
SELECT
  (CASE WHEN COUNT(*)<>14632 THEN 1 ELSE 0 END)
  + SUM(CASE WHEN carrera_actual_id<>carrera_objetivo_id THEN 1 ELSE 0 END)
  + SUM(CASE WHEN carrera_actual_id=carrera_objetivo_id AND malla_actual_id<>malla_objetivo_id THEN 1 ELSE 0 END)
FROM tmp_q10_post;

SELECT
  COUNT(*) AS total_historico,
  SUM(carrera_actual_id=carrera_objetivo_id AND malla_actual_id=malla_objetivo_id) AS consistentes_despues,
  SUM(carrera_actual_id=carrera_objetivo_id AND malla_actual_id<>malla_objetivo_id) AS misma_carrera_malla_distinta_despues,
  SUM(carrera_actual_id<>carrera_objetivo_id) AS carrera_cruzada_despues
FROM tmp_q10_post;

SELECT COUNT(*) AS respaldos_trayectorias
FROM migracion_q10_reconciliacion_trayectorias_backup
WHERE run_code=@orion_recon_run;

SELECT COUNT(*) AS respaldos_matriculas_asignatura
FROM migracion_q10_reconciliacion_matriculas_backup
WHERE run_code=@orion_recon_run;

COMMIT;
