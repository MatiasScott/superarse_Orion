-- Orion v0.10.3.1
-- Reparacion segura de la migracion 019 parcialmente ejecutada.
-- Puede ejecutarse mas de una vez.

SET @OLD_SQL_SAFE_UPDATES := @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

-- 1. tarifas_academicas.periodo_academico_id
SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'tarifas_academicas'
          AND COLUMN_NAME = 'periodo_academico_id'
    ),
    'SELECT 1',
    'ALTER TABLE tarifas_academicas ADD COLUMN periodo_academico_id BIGINT UNSIGNED NULL AFTER id'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- FK tarifa -> periodo, solo si aun no existe.
SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND TABLE_NAME = 'tarifas_academicas'
          AND CONSTRAINT_NAME = 'fk_ta_periodo'
          AND CONSTRAINT_TYPE = 'FOREIGN KEY'
    ),
    'SELECT 1',
    'ALTER TABLE tarifas_academicas ADD CONSTRAINT fk_ta_periodo FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Indice de busqueda de tarifario por PAO.
SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'tarifas_academicas'
          AND INDEX_NAME = 'idx_ta_periodo_carrera_malla_nivel'
    ),
    'SELECT 1',
    'CREATE INDEX idx_ta_periodo_carrera_malla_nivel ON tarifas_academicas(periodo_academico_id,carrera_id,malla_id,nivel_academico_id,activo)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Vinculacion conservadora: solo cuando el PAO completo cae dentro de la vigencia
-- de un tarifario publicado que coincide con la malla y las mismas fechas de tarifa.
UPDATE tarifas_academicas ta
JOIN mallas_curriculares mc ON mc.id = ta.malla_id
JOIN tarifarios_publicados tp
  ON tp.malla_codigo_sugerida = mc.codigo
 AND tp.vigente_desde = ta.vigente_desde
 AND tp.vigente_hasta = ta.vigente_hasta
JOIN periodos_academicos pa
  ON pa.fecha_inicio >= tp.vigente_desde
 AND pa.fecha_fin <= tp.vigente_hasta
SET ta.periodo_academico_id = pa.id
WHERE ta.periodo_academico_id IS NULL
  AND ta.activo = 1;

-- 2. Datos de anulacion en ordenes_pago.
SET @sql := IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND COLUMN_NAME='anulada_at'),
    'SELECT 1',
    'ALTER TABLE ordenes_pago ADD COLUMN anulada_at DATETIME NULL AFTER observacion'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND COLUMN_NAME='anulada_por_usuario_id'),
    'SELECT 1',
    'ALTER TABLE ordenes_pago ADD COLUMN anulada_por_usuario_id BIGINT UNSIGNED NULL AFTER anulada_at'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND COLUMN_NAME='motivo_anulacion'),
    'SELECT 1',
    'ALTER TABLE ordenes_pago ADD COLUMN motivo_anulacion VARCHAR(500) NULL AFTER anulada_por_usuario_id'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago'
          AND CONSTRAINT_NAME='fk_op_anulada_por' AND CONSTRAINT_TYPE='FOREIGN KEY'
    ),
    'SELECT 1',
    'ALTER TABLE ordenes_pago ADD CONSTRAINT fk_op_anulada_por FOREIGN KEY (anulada_por_usuario_id) REFERENCES usuarios(id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. IMPORTANTE: crear primero el indice no unico de reemplazo.
-- De esta manera las FK que usaban uq_orden_estudiante_periodo siguen teniendo
-- un indice valido antes de retirar el UNIQUE anterior.
SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago'
          AND INDEX_NAME='idx_op_estudiante_periodo'
    ),
    'SELECT 1',
    'CREATE INDEX idx_op_estudiante_periodo ON ordenes_pago(estudiante_carrera_id,periodo_academico_id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Retirar el UNIQUE anterior solo si todavia existe.
SET @sql := IF(
    EXISTS(
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago'
          AND INDEX_NAME='uq_orden_estudiante_periodo'
    ),
    'ALTER TABLE ordenes_pago DROP INDEX uq_orden_estudiante_periodo',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET SQL_SAFE_UPDATES = @OLD_SQL_SAFE_UPDATES;

-- Verificacion final visible en Workbench.
SELECT
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='periodo_academico_id') AS columna_pao_ok,
    (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND INDEX_NAME='idx_op_estudiante_periodo') AS indice_reemplazo_ok,
    (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND INDEX_NAME='uq_orden_estudiante_periodo') AS unique_anterior_restante,
    (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ordenes_pago' AND COLUMN_NAME='anulada_at') AS anulacion_ok;

SELECT
    COUNT(*) AS tarifas_totales,
    SUM(periodo_academico_id IS NOT NULL) AS vinculadas_pao,
    SUM(periodo_academico_id IS NULL) AS sin_pao
FROM tarifas_academicas;
