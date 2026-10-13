-- Orion v0.10.6 - Calendario de cuotas por PAO + snapshot financiero
USE superarse_siga;

CREATE TABLE calendarios_pago_pao (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 periodo_academico_id BIGINT UNSIGNED NOT NULL,
 primera_cuota_inicio DATE NOT NULL,
 primera_cuota_fin DATE NOT NULL,
 dia_inicio_recurrente TINYINT UNSIGNED NOT NULL DEFAULT 1,
 dia_fin_recurrente TINYINT UNSIGNED NOT NULL DEFAULT 10,
 actualizado_por_usuario_id BIGINT UNSIGNED NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 CONSTRAINT uq_calendario_pago_pao UNIQUE(periodo_academico_id),
 CONSTRAINT fk_cpp_periodo FOREIGN KEY(periodo_academico_id) REFERENCES periodos_academicos(id),
 CONSTRAINT fk_cpp_usuario FOREIGN KEY(actualizado_por_usuario_id) REFERENCES usuarios(id),
 CONSTRAINT chk_cpp_primera CHECK(primera_cuota_fin >= primera_cuota_inicio),
 CONSTRAINT chk_cpp_dias CHECK(dia_inicio_recurrente BETWEEN 1 AND 28 AND dia_fin_recurrente BETWEEN dia_inicio_recurrente AND 28)
) ENGINE=InnoDB;

ALTER TABLE ordenes_pago
 ADD COLUMN snapshot_creditos DECIMAL(8,2) NULL AFTER saldo_pendiente,
 ADD COLUMN snapshot_valor_credito DECIMAL(12,2) NULL AFTER snapshot_creditos,
 ADD COLUMN snapshot_arancel_oficial DECIMAL(12,2) NULL AFTER snapshot_valor_credito,
 ADD COLUMN snapshot_matricula DECIMAL(12,2) NULL AFTER snapshot_arancel_oficial,
 ADD COLUMN snapshot_total_oficial DECIMAL(12,2) NULL AFTER snapshot_matricula,
 ADD COLUMN snapshot_numero_cuotas SMALLINT UNSIGNED NULL AFTER snapshot_total_oficial,
 ADD COLUMN snapshot_tarifario_codigo VARCHAR(100) NULL AFTER snapshot_numero_cuotas;
