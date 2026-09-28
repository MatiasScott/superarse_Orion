-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 010_financiero.sql
-- Requiere bloques 001-009
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Configuración de aranceles por carrera/malla/nivel
--   - Créditos con 2 decimales
--   - Órdenes de pago / prematrícula
--   - Fórmula:
--       Arancel base
--       + matrícula
--       + otros conceptos
--       - descuentos
--       - beca
--       = total a pagar
--   - Planes de cuotas: 6 ordinarias / 8 en último nivel cuando aplique
--   - Pagos, abonos, comprobantes y saldos
--   - Estados: pendiente, aprobado, rechazado, abono
--   - Regla de abono >=80% para habilitación temporal
--   - Pagos ordinarios del día 1 al 10
--   - Después del día 10: solo Financiero registra pagos de morosos
--   - Kardex financiero
--   - Integración con habilitaciones_matricula (bloque 007)
--
-- PRINCIPIOS:
--   - No se borra histórico financiero.
--   - Montos siempre DECIMAL, nunca FLOAT.
--   - Las políticas son versionadas.
--   - Los comprobantes se guardan en archivos, no como BLOB.
--   - La matrícula académica y Moodle se habilitan desde SIGA según
--     el estado financiero, nunca desde la base de datos de Moodle.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS FINANCIEROS
-- ============================================================

CREATE TABLE tipos_concepto_financiero (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    suma_total BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_concepto_fin_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE conceptos_financieros (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_concepto_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion VARCHAR(255) NULL,

    requiere_pago BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_conceptos_fin_codigo UNIQUE (codigo),
    CONSTRAINT fk_cf_tipo
        FOREIGN KEY (tipo_concepto_id) REFERENCES tipos_concepto_financiero(id)
) ENGINE=InnoDB;

CREATE TABLE estados_orden_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    permite_pago BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_orden_pago_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_cuota (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    saldo_pendiente BOOLEAN NOT NULL DEFAULT TRUE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_cuota_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    es_abono BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_pago_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE origenes_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_origen_pago_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE medios_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_medio_pago_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_movimiento_kardex (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    naturaleza VARCHAR(10) NOT NULL, -- DEBITO / CREDITO
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_mov_kardex_codigo UNIQUE (codigo),
    CONSTRAINT chk_tipo_mov_kardex_naturaleza CHECK (
        naturaleza IN ('DEBITO', 'CREDITO')
    )
) ENGINE=InnoDB;

CREATE TABLE estados_aplicacion_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_aplicacion_pago_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. POLÍTICAS FINANCIERAS VERSIONADAS
-- ============================================================

CREATE TABLE politicas_financieras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_politica_fin_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE politica_financiera_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    politica_financiera_id BIGINT UNSIGNED NOT NULL,
    numero_version INT UNSIGNED NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    dia_inicio_pago TINYINT UNSIGNED NOT NULL DEFAULT 1,
    dia_fin_pago TINYINT UNSIGNED NOT NULL DEFAULT 10,

    porcentaje_abono_habilita DECIMAL(5,2) NOT NULL DEFAULT 80.00,
    porcentaje_abono_bloquea_menor DECIMAL(5,2) NOT NULL DEFAULT 79.00,

    cuotas_ordinarias SMALLINT UNSIGNED NOT NULL DEFAULT 6,
    cuotas_ultimo_nivel SMALLINT UNSIGNED NOT NULL DEFAULT 8,

    primer_pago_habilita_matricula BOOLEAN NOT NULL DEFAULT TRUE,
    abono_habilitante_permite_matricula BOOLEAN NOT NULL DEFAULT TRUE,

    bloqueo_al_iniciar_siguiente_cuota_si_incompleta BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_pfv_version
        UNIQUE (politica_financiera_id, numero_version),

    CONSTRAINT fk_pfv_politica
        FOREIGN KEY (politica_financiera_id) REFERENCES politicas_financieras(id),
    CONSTRAINT fk_pfv_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pfv_dias CHECK (
        dia_inicio_pago BETWEEN 1 AND 31
        AND dia_fin_pago BETWEEN 1 AND 31
        AND dia_fin_pago >= dia_inicio_pago
    ),
    CONSTRAINT chk_pfv_porcentajes CHECK (
        porcentaje_abono_habilita >= 0 AND porcentaje_abono_habilita <= 100
        AND porcentaje_abono_bloquea_menor >= 0 AND porcentaje_abono_bloquea_menor <= 100
    ),
    CONSTRAINT chk_pfv_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 03. ARANCELES / TARIFAS POR NIVEL
-- ============================================================

CREATE TABLE tarifas_academicas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    carrera_id BIGINT UNSIGNED NOT NULL,
    malla_id BIGINT UNSIGNED NOT NULL,
    nivel_academico_id BIGINT UNSIGNED NOT NULL,

    politica_financiera_version_id BIGINT UNSIGNED NOT NULL,

    creditos_totales_nivel DECIMAL(8,2) NOT NULL,

    arancel_base DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    valor_matricula DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    numero_cuotas SMALLINT UNSIGNED NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    es_ultimo_nivel BOOLEAN NOT NULL DEFAULT FALSE,

    aprobado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_tarifa_academica_vigencia
        UNIQUE (carrera_id, malla_id, nivel_academico_id, vigente_desde),

    CONSTRAINT fk_ta_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_ta_malla
        FOREIGN KEY (malla_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_ta_nivel
        FOREIGN KEY (nivel_academico_id) REFERENCES niveles_academicos(id),
    CONSTRAINT fk_ta_politica
        FOREIGN KEY (politica_financiera_version_id) REFERENCES politica_financiera_versiones(id),
    CONSTRAINT fk_ta_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ta_montos CHECK (
        creditos_totales_nivel >= 0
        AND arancel_base >= 0
        AND valor_matricula >= 0
        AND numero_cuotas >= 1
    ),
    CONSTRAINT chk_ta_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_ta_carrera_malla_nivel
ON tarifas_academicas (carrera_id, malla_id, nivel_academico_id, activo);

CREATE TABLE tarifa_conceptos_adicionales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tarifa_academica_id BIGINT UNSIGNED NOT NULL,
    concepto_financiero_id BIGINT UNSIGNED NOT NULL,

    monto DECIMAL(12,2) NOT NULL,
    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_tarifa_concepto
        UNIQUE (tarifa_academica_id, concepto_financiero_id),

    CONSTRAINT fk_tca_tarifa
        FOREIGN KEY (tarifa_academica_id) REFERENCES tarifas_academicas(id),
    CONSTRAINT fk_tca_concepto
        FOREIGN KEY (concepto_financiero_id) REFERENCES conceptos_financieros(id),

    CONSTRAINT chk_tca_monto CHECK (monto >= 0)
) ENGINE=InnoDB;

-- ============================================================
-- 04. ÓRDENES DE PAGO / PREMATRÍCULA
-- ============================================================

CREATE TABLE ordenes_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_orden VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    nivel_academico_id BIGINT UNSIGNED NOT NULL,
    tarifa_academica_id BIGINT UNSIGNED NOT NULL,

    estado_orden_pago_id BIGINT UNSIGNED NOT NULL,

    -- Primer nivel: generada por Académico (individual/masiva)
    -- Nivel 2+: puede generarla el estudiante.
    generada_por_tipo VARCHAR(30) NOT NULL, -- ACADEMICO / ESTUDIANTE / SISTEMA
    generada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento DATE NULL,

    -- Snapshot contable de la fórmula aplicada.
    subtotal_arancel DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    subtotal_matricula DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    subtotal_otros DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_descuentos DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_becas DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_pagar DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    saldo_pendiente DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_orden_pago_numero UNIQUE (numero_orden),
    CONSTRAINT uq_orden_estudiante_periodo
        UNIQUE (estudiante_carrera_id, periodo_academico_id),

    CONSTRAINT fk_op_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_op_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_op_nivel
        FOREIGN KEY (nivel_academico_id) REFERENCES niveles_academicos(id),
    CONSTRAINT fk_op_tarifa
        FOREIGN KEY (tarifa_academica_id) REFERENCES tarifas_academicas(id),
    CONSTRAINT fk_op_estado
        FOREIGN KEY (estado_orden_pago_id) REFERENCES estados_orden_pago(id),
    CONSTRAINT fk_op_generada_por
        FOREIGN KEY (generada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_op_generada_tipo CHECK (
        generada_por_tipo IN ('ACADEMICO', 'ESTUDIANTE', 'SISTEMA')
    ),
    CONSTRAINT chk_op_totales CHECK (
        subtotal_arancel >= 0
        AND subtotal_matricula >= 0
        AND subtotal_otros >= 0
        AND total_descuentos >= 0
        AND total_becas >= 0
        AND total_pagar >= 0
        AND saldo_pendiente >= 0
    )
) ENGINE=InnoDB;

CREATE INDEX idx_op_periodo_estado
ON ordenes_pago (periodo_academico_id, estado_orden_pago_id);

-- ============================================================
-- 05. DETALLE DE ORDEN
-- ============================================================

CREATE TABLE tipos_linea_orden_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    signo SMALLINT NOT NULL, -- 1 suma / -1 resta
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_linea_orden_codigo UNIQUE (codigo),
    CONSTRAINT chk_tipo_linea_signo CHECK (signo IN (-1, 1))
) ENGINE=InnoDB;

CREATE TABLE orden_pago_detalles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    orden_pago_id BIGINT UNSIGNED NOT NULL,
    tipo_linea_id BIGINT UNSIGNED NOT NULL,
    concepto_financiero_id BIGINT UNSIGNED NULL,

    descripcion VARCHAR(255) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL DEFAULT 1.00,
    valor_unitario DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    monto_total DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    fuente_tipo VARCHAR(60) NULL,
    fuente_id BIGINT UNSIGNED NULL,

    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_opd_orden
        FOREIGN KEY (orden_pago_id) REFERENCES ordenes_pago(id),
    CONSTRAINT fk_opd_tipo_linea
        FOREIGN KEY (tipo_linea_id) REFERENCES tipos_linea_orden_pago(id),
    CONSTRAINT fk_opd_concepto
        FOREIGN KEY (concepto_financiero_id) REFERENCES conceptos_financieros(id),

    CONSTRAINT chk_opd_valores CHECK (
        cantidad > 0
        AND valor_unitario >= 0
        AND monto_total >= 0
    )
) ENGINE=InnoDB;

CREATE INDEX idx_opd_orden
ON orden_pago_detalles (orden_pago_id, orden_visual);

-- fuente_tipo permitirá integrar:
-- DESCUENTO, BECA, DERECHO, AJUSTE, etc.
-- El módulo 011_becas_bienestar añadirá el vínculo formal con becas.

-- ============================================================
-- 06. CUOTAS
-- ============================================================

CREATE TABLE cuotas_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    orden_pago_id BIGINT UNSIGNED NOT NULL,
    estado_cuota_id BIGINT UNSIGNED NOT NULL,

    numero_cuota SMALLINT UNSIGNED NOT NULL,

    fecha_inicio_pago DATE NOT NULL,
    fecha_fin_pago DATE NOT NULL,

    monto_cuota DECIMAL(12,2) NOT NULL,
    monto_pagado_aprobado DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    saldo_cuota DECIMAL(12,2) NOT NULL,

    porcentaje_pagado DECIMAL(6,2) NOT NULL DEFAULT 0.00,

    habilita_plataformas BOOLEAN NOT NULL DEFAULT FALSE,
    bloqueada_por_mora BOOLEAN NOT NULL DEFAULT FALSE,

    fecha_pago_completo DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_cuota_orden_numero
        UNIQUE (orden_pago_id, numero_cuota),

    CONSTRAINT fk_cp_orden
        FOREIGN KEY (orden_pago_id) REFERENCES ordenes_pago(id),
    CONSTRAINT fk_cp_estado
        FOREIGN KEY (estado_cuota_id) REFERENCES estados_cuota(id),

    CONSTRAINT chk_cp_numero CHECK (numero_cuota >= 1),
    CONSTRAINT chk_cp_fechas CHECK (fecha_fin_pago >= fecha_inicio_pago),
    CONSTRAINT chk_cp_montos CHECK (
        monto_cuota >= 0
        AND monto_pagado_aprobado >= 0
        AND saldo_cuota >= 0
        AND porcentaje_pagado >= 0
        AND porcentaje_pagado <= 100
    )
) ENGINE=InnoDB;

CREATE INDEX idx_cp_vencimiento_estado
ON cuotas_pago (fecha_fin_pago, estado_cuota_id, bloqueada_por_mora);

-- ============================================================
-- 07. PAGOS / COMPROBANTES
-- ============================================================

CREATE TABLE pagos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_pago VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    orden_pago_id BIGINT UNSIGNED NOT NULL,
    cuota_pago_id BIGINT UNSIGNED NULL,

    estado_pago_id BIGINT UNSIGNED NOT NULL,
    origen_pago_id BIGINT UNSIGNED NOT NULL,
    medio_pago_id BIGINT UNSIGNED NULL,

    monto_reportado DECIMAL(12,2) NOT NULL,

    fecha_pago DATE NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    comprobante_archivo_id BIGINT UNSIGNED NOT NULL,

    referencia_bancaria VARCHAR(150) NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    revisado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_revision DATETIME NULL,

    observacion TEXT NULL,
    motivo_rechazo TEXT NULL,

    registrado_fuera_ventana BOOLEAN NOT NULL DEFAULT FALSE,
    registrado_por_financiero BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_pagos_numero UNIQUE (numero_pago),

    CONSTRAINT fk_pago_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_pago_orden
        FOREIGN KEY (orden_pago_id) REFERENCES ordenes_pago(id),
    CONSTRAINT fk_pago_cuota
        FOREIGN KEY (cuota_pago_id) REFERENCES cuotas_pago(id),
    CONSTRAINT fk_pago_estado
        FOREIGN KEY (estado_pago_id) REFERENCES estados_pago(id),
    CONSTRAINT fk_pago_origen
        FOREIGN KEY (origen_pago_id) REFERENCES origenes_pago(id),
    CONSTRAINT fk_pago_medio
        FOREIGN KEY (medio_pago_id) REFERENCES medios_pago(id),
    CONSTRAINT fk_pago_comprobante
        FOREIGN KEY (comprobante_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_pago_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_pago_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pago_monto CHECK (monto_reportado > 0)
) ENGINE=InnoDB;

CREATE INDEX idx_pagos_orden_estado
ON pagos (orden_pago_id, estado_pago_id);

CREATE INDEX idx_pagos_revision
ON pagos (estado_pago_id, fecha_registro);

-- ============================================================
-- 08. ABONOS / COMPLETAR SALDO
-- ============================================================

CREATE TABLE pagos_abonos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pago_id BIGINT UNSIGNED NOT NULL,
    cuota_pago_id BIGINT UNSIGNED NOT NULL,

    monto_abono DECIMAL(12,2) NOT NULL,
    porcentaje_cuota DECIMAL(6,2) NOT NULL,

    saldo_restante_al_aprobar DECIMAL(12,2) NOT NULL,

    habilita_temporalmente BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_pago_abono UNIQUE (pago_id),

    CONSTRAINT fk_pa_pago
        FOREIGN KEY (pago_id) REFERENCES pagos(id),
    CONSTRAINT fk_pa_cuota
        FOREIGN KEY (cuota_pago_id) REFERENCES cuotas_pago(id),

    CONSTRAINT chk_pa_valores CHECK (
        monto_abono > 0
        AND porcentaje_cuota >= 0
        AND porcentaje_cuota <= 100
        AND saldo_restante_al_aprobar >= 0
    )
) ENGINE=InnoDB;

-- Cada nuevo comprobante para completar el saldo se registra como OTRO pago,
-- no se reemplaza el archivo anterior. Así se conserva todo el histórico.

-- ============================================================
-- 09. APLICACIÓN DE PAGOS
-- Un pago puede aplicarse a una o varias cuotas/conceptos.
-- ============================================================

CREATE TABLE aplicaciones_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pago_id BIGINT UNSIGNED NOT NULL,
    cuota_pago_id BIGINT UNSIGNED NOT NULL,
    estado_aplicacion_id BIGINT UNSIGNED NOT NULL,

    monto_aplicado DECIMAL(12,2) NOT NULL,

    aplicado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_aplicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_aplicacion_pago_cuota
        UNIQUE (pago_id, cuota_pago_id),

    CONSTRAINT fk_ap_pago
        FOREIGN KEY (pago_id) REFERENCES pagos(id),
    CONSTRAINT fk_ap_cuota
        FOREIGN KEY (cuota_pago_id) REFERENCES cuotas_pago(id),
    CONSTRAINT fk_ap_estado
        FOREIGN KEY (estado_aplicacion_id) REFERENCES estados_aplicacion_pago(id),
    CONSTRAINT fk_ap_usuario
        FOREIGN KEY (aplicado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ap_monto CHECK (monto_aplicado > 0)
) ENGINE=InnoDB;

-- ============================================================
-- 10. HISTÓRICO DE ESTADOS DE PAGO
-- ============================================================

CREATE TABLE historial_estado_pago (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pago_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    observacion TEXT NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hep_pago
        FOREIGN KEY (pago_id) REFERENCES pagos(id),
    CONSTRAINT fk_hep_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_pago(id),
    CONSTRAINT fk_hep_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_pago(id),
    CONSTRAINT fk_hep_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hep_pago_fecha
ON historial_estado_pago (pago_id, changed_at);

-- ============================================================
-- 11. KARDEX FINANCIERO
-- ============================================================

CREATE TABLE kardex_financiero (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    tipo_movimiento_id BIGINT UNSIGNED NOT NULL,

    concepto_financiero_id BIGINT UNSIGNED NULL,

    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    descripcion VARCHAR(255) NOT NULL,

    referencia_tipo VARCHAR(60) NULL,
    referencia_id BIGINT UNSIGNED NULL,

    debito DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    credito DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    saldo_resultante DECIMAL(12,2) NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_kf_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_kf_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_kf_tipo_movimiento
        FOREIGN KEY (tipo_movimiento_id) REFERENCES tipos_movimiento_kardex(id),
    CONSTRAINT fk_kf_concepto
        FOREIGN KEY (concepto_financiero_id) REFERENCES conceptos_financieros(id),
    CONSTRAINT fk_kf_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_kf_valores CHECK (
        debito >= 0 AND credito >= 0
        AND NOT (debito > 0 AND credito > 0)
    )
) ENGINE=InnoDB;

CREATE INDEX idx_kf_estudiante_fecha
ON kardex_financiero (estudiante_carrera_id, fecha_movimiento);

-- ============================================================
-- 12. MOROSIDAD
-- ============================================================

CREATE TABLE estados_morosidad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_moroso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_morosidad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE morosidades (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuota_pago_id BIGINT UNSIGNED NOT NULL,
    estado_morosidad_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio_mora DATE NOT NULL,
    fecha_regularizacion DATE NULL,

    dias_mora INT UNSIGNED NOT NULL DEFAULT 0,
    saldo_en_mora DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    regularizada_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_morosidad_cuota UNIQUE (cuota_pago_id),

    CONSTRAINT fk_mora_cuota
        FOREIGN KEY (cuota_pago_id) REFERENCES cuotas_pago(id),
    CONSTRAINT fk_mora_estado
        FOREIGN KEY (estado_morosidad_id) REFERENCES estados_morosidad(id),
    CONSTRAINT fk_mora_regularizada_por
        FOREIGN KEY (regularizada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_mora_valores CHECK (
        saldo_en_mora >= 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 13. HABILITACIÓN DE PLATAFORMAS POR FINANCIERO
-- ============================================================

CREATE TABLE estados_habilitacion_financiera (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    habilita_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    habilita_moodle BOOLEAN NOT NULL DEFAULT FALSE,
    habilita_asistencia BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_hab_fin_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE habilitaciones_financieras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    estado_habilitacion_financiera_id BIGINT UNSIGNED NOT NULL,

    cuota_referencia_id BIGINT UNSIGNED NULL,
    pago_referencia_id BIGINT UNSIGNED NULL,

    fecha_desde DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_hasta DATETIME NULL,

    motivo VARCHAR(255) NULL,

    actualizado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_hf_estudiante_periodo
        UNIQUE (estudiante_carrera_id, periodo_academico_id),

    CONSTRAINT fk_hf_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_hf_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_hf_estado
        FOREIGN KEY (estado_habilitacion_financiera_id) REFERENCES estados_habilitacion_financiera(id),
    CONSTRAINT fk_hf_cuota
        FOREIGN KEY (cuota_referencia_id) REFERENCES cuotas_pago(id),
    CONSTRAINT fk_hf_pago
        FOREIGN KEY (pago_referencia_id) REFERENCES pagos(id),
    CONSTRAINT fk_hf_usuario
        FOREIGN KEY (actualizado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_hf_fechas CHECK (
        fecha_hasta IS NULL OR fecha_hasta >= fecha_desde
    )
) ENGINE=InnoDB;

-- El servicio financiero sincroniza esta condición con habilitaciones_matricula
-- del bloque 007. No se crean triggers cruzados para mantener lógica de dominio
-- en la aplicación.

-- ============================================================
-- 14. CAMBIOS / AJUSTES MANUALES DE FINANCIERO
-- ============================================================

CREATE TABLE ajustes_financieros (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_ajuste VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    concepto_financiero_id BIGINT UNSIGNED NULL,

    tipo_ajuste VARCHAR(20) NOT NULL, -- DEBITO / CREDITO
    monto DECIMAL(12,2) NOT NULL,

    motivo TEXT NOT NULL,

    creado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion DATETIME NULL,

    aplicado BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ajuste_fin_numero UNIQUE (numero_ajuste),

    CONSTRAINT fk_af_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_af_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_af_concepto
        FOREIGN KEY (concepto_financiero_id) REFERENCES conceptos_financieros(id),
    CONSTRAINT fk_af_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_af_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_af_tipo CHECK (tipo_ajuste IN ('DEBITO','CREDITO')),
    CONSTRAINT chk_af_monto CHECK (monto > 0)
) ENGINE=InnoDB;

-- ============================================================
-- 15. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_concepto_financiero
(codigo, nombre, suma_total)
VALUES
('ARANCEL', 'Arancel', TRUE),
('MATRICULA', 'Matrícula', TRUE),
('OTRO_CARGO', 'Otro cargo', TRUE),
('DESCUENTO', 'Descuento', FALSE),
('BECA', 'Beca', FALSE),
('DERECHO', 'Derecho / trámite', TRUE),
('AJUSTE', 'Ajuste', TRUE);

INSERT INTO conceptos_financieros
(tipo_concepto_id, codigo, nombre)
SELECT id, 'ARANCEL_BASE', 'Arancel base'
FROM tipos_concepto_financiero WHERE codigo='ARANCEL';

INSERT INTO conceptos_financieros
(tipo_concepto_id, codigo, nombre)
SELECT id, 'MATRICULA_ACADEMICA', 'Matrícula'
FROM tipos_concepto_financiero WHERE codigo='MATRICULA';

INSERT INTO estados_orden_pago
(codigo, nombre, permite_pago, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('GENERADA', 'Generada', TRUE, FALSE),
('PARCIALMENTE_PAGADA', 'Parcialmente pagada', TRUE, FALSE),
('PAGADA', 'Pagada', FALSE, TRUE),
('VENCIDA', 'Vencida', TRUE, FALSE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO estados_cuota
(codigo, nombre, saldo_pendiente, es_final)
VALUES
('PENDIENTE', 'Pendiente', TRUE, FALSE),
('ABONO', 'Abono', TRUE, FALSE),
('PAGADA', 'Pagada', FALSE, TRUE),
('VENCIDA', 'Vencida', TRUE, FALSE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO estados_pago
(codigo, nombre, es_aprobado, es_abono, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE, FALSE),
('APROBADO', 'Aprobado', TRUE, FALSE, TRUE),
('ABONO', 'Abono', TRUE, TRUE, TRUE),
('RECHAZADO', 'Rechazado', FALSE, FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, FALSE, TRUE);

INSERT INTO origenes_pago (codigo, nombre) VALUES
('ESTUDIANTE', 'Registrado por estudiante'),
('FINANCIERO', 'Registrado por Financiero'),
('IMPORTACION', 'Importación'),
('MIGRACION', 'Migración histórica'),
('OTRO', 'Otro');

INSERT INTO medios_pago (codigo, nombre) VALUES
('TRANSFERENCIA', 'Transferencia bancaria'),
('DEPOSITO', 'Depósito bancario'),
('TARJETA', 'Tarjeta'),
('EFECTIVO', 'Efectivo'),
('OTRO', 'Otro');

INSERT INTO tipos_movimiento_kardex
(codigo, nombre, naturaleza)
VALUES
('CARGO', 'Cargo', 'DEBITO'),
('PAGO', 'Pago', 'CREDITO'),
('ABONO', 'Abono', 'CREDITO'),
('DESCUENTO', 'Descuento', 'CREDITO'),
('BECA', 'Beca', 'CREDITO'),
('AJUSTE_DEBITO', 'Ajuste débito', 'DEBITO'),
('AJUSTE_CREDITO', 'Ajuste crédito', 'CREDITO');

INSERT INTO estados_aplicacion_pago
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('APLICADA', 'Aplicada', TRUE),
('REVERSADA', 'Reversada', TRUE);

INSERT INTO tipos_linea_orden_pago
(codigo, nombre, signo)
VALUES
('ARANCEL', 'Arancel base', 1),
('MATRICULA', 'Matrícula', 1),
('OTRO_CARGO', 'Otros conceptos', 1),
('DESCUENTO', 'Descuento', -1),
('BECA', 'Beca', -1),
('AJUSTE_DEBITO', 'Ajuste débito', 1),
('AJUSTE_CREDITO', 'Ajuste crédito', -1);

INSERT INTO estados_morosidad
(codigo, nombre, es_moroso)
VALUES
('AL_DIA', 'Al día', FALSE),
('MOROSO', 'Moroso', TRUE),
('REGULARIZADO', 'Regularizado', FALSE);

INSERT INTO estados_habilitacion_financiera
(codigo, nombre, habilita_matricula, habilita_moodle, habilita_asistencia)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE, FALSE),
('HABILITADA', 'Habilitada', TRUE, TRUE, TRUE),
('HABILITADA_ABONO_80', 'Habilitada temporalmente por abono >= 80%', TRUE, TRUE, TRUE),
('BLOQUEADA_MENOR_80', 'Bloqueada por abono menor al umbral', FALSE, FALSE, FALSE),
('BLOQUEADA_MORA', 'Bloqueada por mora', FALSE, FALSE, FALSE),
('BLOQUEADA_RECHAZO', 'Bloqueada por pago rechazado', FALSE, FALSE, FALSE);

-- ============================================================
-- 16. POLÍTICA FINANCIERA ACTUAL
-- ============================================================

INSERT INTO politicas_financieras
(codigo, nombre, descripcion)
VALUES
(
    'POLITICA_GENERAL_PAGOS',
    'Política General de Pagos',
    'Reglas institucionales de ventana de pago, abonos, cuotas y habilitación'
);

INSERT INTO politica_financiera_versiones
(
    politica_financiera_id,
    numero_version,
    vigente_desde,
    dia_inicio_pago,
    dia_fin_pago,
    porcentaje_abono_habilita,
    porcentaje_abono_bloquea_menor,
    cuotas_ordinarias,
    cuotas_ultimo_nivel,
    primer_pago_habilita_matricula,
    abono_habilitante_permite_matricula,
    bloqueo_al_iniciar_siguiente_cuota_si_incompleta
)
SELECT
    id,
    1,
    '2026-01-01',
    1,
    10,
    80.00,
    79.00,
    6,
    8,
    TRUE,
    TRUE,
    TRUE
FROM politicas_financieras
WHERE codigo='POLITICA_GENERAL_PAGOS';

-- ============================================================
-- 17. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ORDEN DE PAGO:
--
-- Primer nivel:
--   Académico genera individual o masivamente.
--
-- Nivel 2+:
--   El estudiante puede generar su propia orden.
--
-- Fórmula:
--   subtotal_arancel
-- + subtotal_matricula
-- + subtotal_otros
-- - total_descuentos
-- - total_becas
-- = total_pagar
--
-- Los totales en ordenes_pago son SNAPSHOTS contables para conservar
-- exactamente cuánto debía pagar el estudiante en ese período.
--
-- CUOTAS:
-- - Regla actual general: 6 cuotas.
-- - Último nivel/titulación: 8 cuotas cuando la tarifa lo defina.
-- - tarifas_academicas.numero_cuotas es el valor efectivo histórico.
--
-- VENTANA DE PAGO:
-- - Día 1 al 10: el estudiante puede registrar su comprobante.
-- - Desde día 11:
--      el estudiante NO puede registrar pago ordinario.
--      solo Financiero puede registrar el pago del moroso.
-- - Esto se controla en el servicio, usando politica_financiera_versiones.
--
-- ESTADOS DE PAGO:
-- PENDIENTE:
--   aún no revisado.
--
-- APROBADO:
--   se aplica a la cuota y actualiza Kardex.
--
-- ABONO:
--   observación obligatoria.
--   se guarda pagos_abonos.
--   el próximo pago/comprobante para completar la cuota es un nuevo registro.
--
-- RECHAZADO:
--   motivo/observación obligatorios.
--   no afecta saldo como pago aplicado.
--
-- REGLA DEL 80%:
-- - porcentaje >= 80%:
--      HABILITADA_ABONO_80
--      puede matricularse/cursar temporalmente.
--
-- - porcentaje < 80%:
--      BLOQUEADA_MENOR_80
--      no matricular / no Moodle / no asistencia.
--
-- - Si inicia la siguiente ventana/cuota y la anterior no está completa:
--      BLOQUEADA_MORA
--   aunque la cuota anterior hubiese alcanzado 80%.
--
-- PRIMER PAGO:
-- - APROBADO o abono habilitante >=80%:
--      financiero actualiza habilitaciones_financieras
--      servicio actualiza habilitaciones_matricula (007)
--      matrícula automática puede ejecutarse.
--
-- PAGOS DE VARIOS MESES:
-- - Un pago puede aplicarse a varias cuotas mediante aplicaciones_pago.
-- - Financiero selecciona cuáles cuotas quedan pagadas/aprobadas.
--
-- PAGO TOTAL:
-- - Si cubre todo el saldo:
--      todas las cuotas aplicables -> PAGADA
--      orden -> PAGADA
--      habilitación completa.
--
-- KARDEX:
-- - Orden/cargos: DEBITO
-- - Pago/abono/descuento/beca: CREDITO
-- - Nunca borrar movimientos.
--
-- BECAS:
-- - En este bloque se registra el efecto financiero (línea BECA).
-- - 011_becas_bienestar.sql guardará la beca institucional y enlazará
--   su origen al detalle de la orden.
--
-- MOODLE / ASISTENCIA:
-- - No se escriben tablas Moodle.
-- - habilitaciones_financieras controla si el servicio puede:
--      matricular en Moodle,
--      permitir asistencia,
--      mantener acceso académico.
--
-- ============================================================
-- FIN 010_financiero.sql
-- ============================================================
