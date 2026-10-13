-- Orion v0.10.3 - Tarifario explícito por PAO y anulación auditable de órdenes
START TRANSACTION;

ALTER TABLE tarifas_academicas
    ADD COLUMN periodo_academico_id BIGINT UNSIGNED NULL AFTER id,
    ADD CONSTRAINT fk_ta_periodo FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id);
CREATE INDEX idx_ta_periodo_carrera_malla_nivel
    ON tarifas_academicas(periodo_academico_id,carrera_id,malla_id,nivel_academico_id,activo);

-- Vincula SOLO tarifas publicadas cuando un PAO completo cae dentro de la vigencia oficial.
UPDATE tarifas_academicas ta
JOIN mallas_curriculares mc ON mc.id=ta.malla_id
JOIN tarifarios_publicados tp ON tp.malla_codigo_sugerida=mc.codigo
    AND tp.vigente_desde=ta.vigente_desde
    AND tp.vigente_hasta=ta.vigente_hasta
JOIN periodos_academicos pa ON pa.fecha_inicio>=tp.vigente_desde AND pa.fecha_fin<=tp.vigente_hasta
SET ta.periodo_academico_id=pa.id
WHERE ta.periodo_academico_id IS NULL AND ta.activo=1;

ALTER TABLE ordenes_pago
    ADD COLUMN anulada_at DATETIME NULL AFTER observacion,
    ADD COLUMN anulada_por_usuario_id BIGINT UNSIGNED NULL AFTER anulada_at,
    ADD COLUMN motivo_anulacion VARCHAR(500) NULL AFTER anulada_por_usuario_id,
    ADD CONSTRAINT fk_op_anulada_por FOREIGN KEY (anulada_por_usuario_id) REFERENCES usuarios(id);

-- La unicidad anterior impedía conservar una orden anulada y generar posteriormente la correcta.
ALTER TABLE ordenes_pago DROP INDEX uq_orden_estudiante_periodo;
CREATE INDEX idx_op_estudiante_periodo ON ordenes_pago(estudiante_carrera_id,periodo_academico_id);

COMMIT;
