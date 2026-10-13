-- Orion v0.10.4.1
-- Reparación idempotente del motor de tarifario oficial.
-- Diseñada para una BD donde 021 pudo quedar parcialmente aplicada.

SET @ORION_OLD_SAFE_UPDATES := @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

-- 1. Garantizar columnas antes de cualquier UPDATE.
SET @sql := IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='valor_credito'),
  'SELECT 1',
  'ALTER TABLE tarifas_academicas ADD COLUMN valor_credito DECIMAL(12,2) NULL AFTER creditos_totales_nivel'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='total_nivel_oficial'),
  'SELECT 1',
  'ALTER TABLE tarifas_academicas ADD COLUMN total_nivel_oficial DECIMAL(12,2) NULL AFTER valor_matricula'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='tarifario_publicado_id'),
  'SELECT 1',
  'ALTER TABLE tarifas_academicas ADD COLUMN tarifario_publicado_id BIGINT UNSIGNED NULL AFTER periodo_academico_id'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. Garantizar índice/FK del documento publicado.
SET @sql := IF(
  EXISTS(SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='tarifario_publicado_id'),
  'SELECT 1',
  'ALTER TABLE tarifas_academicas ADD INDEX idx_ta_tarifario_publicado (tarifario_publicado_id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  EXISTS(SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND CONSTRAINT_NAME='fk_ta_tarifario_publicado' AND CONSTRAINT_TYPE='FOREIGN KEY'),
  'SELECT 1',
  'ALTER TABLE tarifas_academicas ADD CONSTRAINT fk_ta_tarifario_publicado FOREIGN KEY (tarifario_publicado_id) REFERENCES tarifarios_publicados(id)'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. Enriquecer ÚNICAMENTE coincidencias exactas con el documento oficial.
-- Una tarifa errónea donde 44.92 fue guardado como arancel NO coincide con
-- valor_arancel oficial (p.ej. 763.64), por lo que queda incompleta/bloqueada.
UPDATE tarifas_academicas ta
JOIN mallas_curriculares mc ON mc.id = ta.malla_id
JOIN niveles_academicos na ON na.id = ta.nivel_academico_id
JOIN tarifarios_publicados tp
  ON tp.malla_codigo_sugerida = mc.codigo
 AND tp.vigente_desde = ta.vigente_desde
 AND tp.vigente_hasta = ta.vigente_hasta
 AND tp.estado_vinculacion = 'VINCULADO'
JOIN tarifario_publicado_niveles tpn
  ON tpn.tarifario_publicado_id = tp.id
 AND tpn.numero_nivel = na.orden_nivel
SET ta.valor_credito = tpn.valor_credito,
    ta.total_nivel_oficial = tpn.total_nivel,
    ta.tarifario_publicado_id = tp.id
WHERE ta.activo = 1
  AND ABS(ta.creditos_totales_nivel - tpn.creditos) <= 0.01
  AND ABS(ta.arancel_base - tpn.valor_arancel) <= 0.01
  AND ABS(ta.valor_matricula - tpn.valor_matricula) <= 0.01;

-- 4. Si una tarifa oficial quedó asociada a un PAO que no está completamente
-- cubierto por la vigencia del documento, retirar solo la asociación al PAO.
UPDATE tarifas_academicas ta
JOIN periodos_academicos pa ON pa.id = ta.periodo_academico_id
JOIN tarifarios_publicados tp ON tp.id = ta.tarifario_publicado_id
SET ta.periodo_academico_id = NULL
WHERE pa.fecha_inicio < tp.vigente_desde
   OR pa.fecha_fin > tp.vigente_hasta;

SET SQL_SAFE_UPDATES = @ORION_OLD_SAFE_UPDATES;

-- 5. Validación estructural.
SELECT
  SUM(COLUMN_NAME='valor_credito') AS valor_credito_ok,
  SUM(COLUMN_NAME='total_nivel_oficial') AS total_nivel_oficial_ok,
  SUM(COLUMN_NAME='tarifario_publicado_id') AS tarifario_publicado_id_ok
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE()
  AND TABLE_NAME='tarifas_academicas'
  AND COLUMN_NAME IN ('valor_credito','total_nivel_oficial','tarifario_publicado_id');

-- 6. Estado del motor. Una tarifa solo es utilizable cuando está vinculada al
-- PAO y contiene los valores oficiales completos y consistentes.
SELECT
  COUNT(*) AS tarifas_activas,
  SUM(periodo_academico_id IS NOT NULL) AS vinculadas_pao,
  SUM(periodo_academico_id IS NOT NULL
      AND valor_credito IS NOT NULL
      AND total_nivel_oficial IS NOT NULL
      AND ABS(total_nivel_oficial-(arancel_base+valor_matricula))<=0.02) AS utilizables_motor_v0104,
  SUM(periodo_academico_id IS NOT NULL
      AND (valor_credito IS NULL
           OR total_nivel_oficial IS NULL
           OR ABS(total_nivel_oficial-(arancel_base+valor_matricula))>0.02)) AS vinculadas_incompletas_bloqueadas
FROM tarifas_academicas
WHERE activo=1;

-- 7. Diagnóstico de tarifas vinculadas pero bloqueadas.
SELECT
  ta.id,
  pa.codigo AS pao,
  c.nombre AS carrera,
  mc.codigo AS malla,
  na.nombre AS nivel,
  ta.creditos_totales_nivel,
  ta.valor_credito,
  ta.arancel_base,
  ta.valor_matricula,
  ta.total_nivel_oficial,
  ta.vigente_desde,
  ta.vigente_hasta
FROM tarifas_academicas ta
JOIN carreras c ON c.id=ta.carrera_id
JOIN mallas_curriculares mc ON mc.id=ta.malla_id
JOIN niveles_academicos na ON na.id=ta.nivel_academico_id
LEFT JOIN periodos_academicos pa ON pa.id=ta.periodo_academico_id
WHERE ta.activo=1
  AND ta.periodo_academico_id IS NOT NULL
  AND (ta.valor_credito IS NULL
       OR ta.total_nivel_oficial IS NULL
       OR ABS(ta.total_nivel_oficial-(ta.arancel_base+ta.valor_matricula))>0.02)
ORDER BY pa.fecha_inicio DESC,c.nombre,na.orden_nivel;
