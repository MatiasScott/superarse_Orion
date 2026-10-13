
SET @sql := IF(EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='total_nivel_oficial'),'SELECT 1','ALTER TABLE tarifas_academicas ADD COLUMN total_nivel_oficial DECIMAL(12,2) NULL AFTER valor_matricula');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND COLUMN_NAME='tarifario_publicado_id'),'SELECT 1','ALTER TABLE tarifas_academicas ADD COLUMN tarifario_publicado_id BIGINT UNSIGNED NULL AFTER periodo_academico_id');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(EXISTS(SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='tarifas_academicas' AND CONSTRAINT_NAME='fk_ta_tarifario_publicado'),'SELECT 1','ALTER TABLE tarifas_academicas ADD CONSTRAINT fk_ta_tarifario_publicado FOREIGN KEY (tarifario_publicado_id) REFERENCES tarifarios_publicados(id)');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Solo enriquece tarifas que coinciden EXACTAMENTE con el documento oficial:
-- malla, nivel, vigencia, créditos, arancel y matrícula. Esto evita convertir
-- tarifas manuales/erróneas en tarifarios oficiales por aproximación.
UPDATE tarifas_academicas ta
JOIN mallas_curriculares mc ON mc.id=ta.malla_id
JOIN niveles_academicos na ON na.id=ta.nivel_academico_id
JOIN tarifarios_publicados tp
  ON tp.malla_codigo_sugerida=mc.codigo
 AND tp.vigente_desde=ta.vigente_desde
 AND tp.vigente_hasta=ta.vigente_hasta
 AND tp.estado_vinculacion='VINCULADO'
JOIN tarifario_publicado_niveles tpn
  ON tpn.tarifario_publicado_id=tp.id
 AND tpn.numero_nivel=na.orden_nivel
SET ta.valor_credito=tpn.valor_credito,
    ta.total_nivel_oficial=tpn.total_nivel,
    ta.tarifario_publicado_id=tp.id
WHERE ta.activo=1
  AND ABS(ta.creditos_totales_nivel-tpn.creditos)<=0.01
  AND ABS(ta.arancel_base-tpn.valor_arancel)<=0.01
  AND ABS(ta.valor_matricula-tpn.valor_matricula)<=0.01;

-- Desvincula automáticamente un PAO si fue asignado a una tarifa cuyo documento
-- oficial no cubre ese PAO completo. No borra la tarifa ni órdenes históricas.
UPDATE tarifas_academicas ta
JOIN periodos_academicos pa ON pa.id=ta.periodo_academico_id
JOIN tarifarios_publicados tp ON tp.id=ta.tarifario_publicado_id
SET ta.periodo_academico_id=NULL
WHERE pa.fecha_inicio < tp.vigente_desde OR pa.fecha_fin > tp.vigente_hasta;

SET SQL_SAFE_UPDATES = @OLD_SQL_SAFE_UPDATES;

SELECT
 COUNT(*) tarifas_activas,
 SUM(periodo_academico_id IS NOT NULL) vinculadas_pao,
 SUM(valor_credito IS NOT NULL AND total_nivel_oficial IS NOT NULL) completas_motor_v0104,
 SUM(periodo_academico_id IS NOT NULL AND (valor_credito IS NULL OR total_nivel_oficial IS NULL)) vinculadas_incompletas_bloqueadas
FROM tarifas_academicas WHERE activo=1;

SELECT ta.id,pa.codigo pao,c.nombre carrera,mc.codigo malla,na.nombre nivel,
       ta.creditos_totales_nivel,ta.valor_credito,ta.arancel_base,ta.valor_matricula,
       ta.total_nivel_oficial,ta.numero_cuotas,tp.codigo_fuente
FROM tarifas_academicas ta
JOIN carreras c ON c.id=ta.carrera_id
JOIN mallas_curriculares mc ON mc.id=ta.malla_id
JOIN niveles_academicos na ON na.id=ta.nivel_academico_id
LEFT JOIN periodos_academicos pa ON pa.id=ta.periodo_academico_id
LEFT JOIN tarifarios_publicados tp ON tp.id=ta.tarifario_publicado_id
WHERE ta.activo=1
ORDER BY pa.fecha_inicio DESC,c.nombre,na.orden_nivel;
