-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 011_becas_bienestar.sql
-- Requiere bloques 001-010
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión integral de becas y bienestar estudiantil
--   - Tipos de beca, razones, financiamiento, porcentajes y montos
--   - Solicitudes, evaluaciones, adjudicación, renovación y pérdida
--   - Ficha socioeconómica e histórico
--   - Documentos y evidencias
--   - Acompañamiento psicopedagógico cuando aplique
--   - Integración financiera con ordenes_pago / orden_pago_detalles
--   - Reportabilidad por carrera, período, sede y estado
--
-- PRINCIPIOS:
--   - La beca es una entidad institucional, no solo un descuento financiero.
--   - El efecto monetario se aplica en 010_financiero.sql.
--   - Los estados y porcentajes se mantienen históricamente.
--   - No se sobrescribe la beca anterior al renovar; se crea un nuevo período.
--   - La documentación se enlaza al repositorio de archivos.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE BECAS
-- ============================================================

CREATE TABLE tipos_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    permite_porcentaje BOOLEAN NOT NULL DEFAULT TRUE,
    permite_monto_fijo BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE razones_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_razon_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_financiamiento_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_fin_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_aplicacion_financiera BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_solicitud_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_solicitud_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_documento_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_documento_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_evento_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_evento_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE motivos_perdida_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_motivo_perdida_beca_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_acompanamiento_bienestar (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_acompanamiento_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CONFIGURACIÓN INSTITUCIONAL DE BECAS
-- ============================================================

CREATE TABLE programas_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    tipo_beca_id BIGINT UNSIGNED NOT NULL,
    tipo_financiamiento_beca_id BIGINT UNSIGNED NULL,

    descripcion TEXT NULL,

    porcentaje_maximo DECIMAL(5,2) NULL,
    monto_maximo DECIMAL(12,2) NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_programa_beca_codigo UNIQUE (codigo),

    CONSTRAINT fk_pb_tipo
        FOREIGN KEY (tipo_beca_id) REFERENCES tipos_beca(id),
    CONSTRAINT fk_pb_financiamiento
        FOREIGN KEY (tipo_financiamiento_beca_id) REFERENCES tipos_financiamiento_beca(id),

    CONSTRAINT chk_pb_porcentaje CHECK (
        porcentaje_maximo IS NULL OR (porcentaje_maximo >= 0 AND porcentaje_maximo <= 100)
    ),
    CONSTRAINT chk_pb_monto CHECK (
        monto_maximo IS NULL OR monto_maximo >= 0
    ),
    CONSTRAINT chk_pb_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE TABLE programa_beca_razones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    programa_beca_id BIGINT UNSIGNED NOT NULL,
    razon_beca_id BIGINT UNSIGNED NOT NULL,
    orden_prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_programa_beca_razon
        UNIQUE (programa_beca_id, razon_beca_id),

    CONSTRAINT fk_pbr_programa
        FOREIGN KEY (programa_beca_id) REFERENCES programas_beca(id),
    CONSTRAINT fk_pbr_razon
        FOREIGN KEY (razon_beca_id) REFERENCES razones_beca(id)
) ENGINE=InnoDB;

-- ============================================================
-- 03. SOLICITUDES DE BECA
-- ============================================================

CREATE TABLE solicitudes_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    programa_beca_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_beca_id BIGINT UNSIGNED NOT NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    fecha_resolucion DATETIME NULL,

    solicitada_por_usuario_id BIGINT UNSIGNED NULL,
    revisada_por_usuario_id BIGINT UNSIGNED NULL,
    resuelta_por_usuario_id BIGINT UNSIGNED NULL,

    porcentaje_solicitado DECIMAL(5,2) NULL,
    monto_solicitado DECIMAL(12,2) NULL,

    observacion TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitud_beca_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_sb_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_sb_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_sb_programa
        FOREIGN KEY (programa_beca_id) REFERENCES programas_beca(id),
    CONSTRAINT fk_sb_estado
        FOREIGN KEY (estado_solicitud_beca_id) REFERENCES estados_solicitud_beca(id),
    CONSTRAINT fk_sb_solicitada_por
        FOREIGN KEY (solicitada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sb_revisada_por
        FOREIGN KEY (revisada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sb_resuelta_por
        FOREIGN KEY (resuelta_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_sb_porcentaje CHECK (
        porcentaje_solicitado IS NULL OR (porcentaje_solicitado >= 0 AND porcentaje_solicitado <= 100)
    ),
    CONSTRAINT chk_sb_monto CHECK (
        monto_solicitado IS NULL OR monto_solicitado >= 0
    )
) ENGINE=InnoDB;

CREATE INDEX idx_sb_periodo_estado
ON solicitudes_beca (periodo_academico_id, estado_solicitud_beca_id);

-- ============================================================
-- 04. RAZONES DECLARADAS EN LA SOLICITUD
-- Permite hasta múltiples razones, manteniendo orden.
-- ============================================================

CREATE TABLE solicitud_beca_razones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_beca_id BIGINT UNSIGNED NOT NULL,
    razon_beca_id BIGINT UNSIGNED NOT NULL,
    orden SMALLINT UNSIGNED NOT NULL,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_solicitud_beca_razon_orden
        UNIQUE (solicitud_beca_id, orden),

    CONSTRAINT uq_solicitud_beca_razon
        UNIQUE (solicitud_beca_id, razon_beca_id),

    CONSTRAINT fk_sbr_solicitud
        FOREIGN KEY (solicitud_beca_id) REFERENCES solicitudes_beca(id),
    CONSTRAINT fk_sbr_razon
        FOREIGN KEY (razon_beca_id) REFERENCES razones_beca(id)
) ENGINE=InnoDB;

-- ============================================================
-- 05. DOCUMENTOS DE SOLICITUD / BECA
-- ============================================================

CREATE TABLE solicitud_beca_documentos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_beca_id BIGINT UNSIGNED NOT NULL,
    tipo_documento_beca_id BIGINT UNSIGNED NOT NULL,
    archivo_id BIGINT UNSIGNED NOT NULL,

    nombre_documento VARCHAR(255) NULL,
    observacion VARCHAR(255) NULL,

    cargado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    vigente BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_sbd_solicitud
        FOREIGN KEY (solicitud_beca_id) REFERENCES solicitudes_beca(id),
    CONSTRAINT fk_sbd_tipo_documento
        FOREIGN KEY (tipo_documento_beca_id) REFERENCES tipos_documento_beca(id),
    CONSTRAINT fk_sbd_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_sbd_usuario
        FOREIGN KEY (cargado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_sbd_solicitud_tipo
ON solicitud_beca_documentos (solicitud_beca_id, tipo_documento_beca_id, vigente);

-- ============================================================
-- 06. EVALUACIÓN SOCIOECONÓMICA PARA BECA
-- Snapshot específico del proceso de beca.
-- ============================================================

CREATE TABLE evaluaciones_socioeconomicas_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_beca_id BIGINT UNSIGNED NOT NULL,

    ingresos_hogar DECIMAL(12,2) NULL,
    numero_miembros_hogar SMALLINT UNSIGNED NULL,
    ingreso_per_capita DECIMAL(12,2) NULL,

    recibe_bono_desarrollo_humano BOOLEAN NULL,
    tiene_ayuda_economica BOOLEAN NULL,
    valor_ayuda_economica DECIMAL(12,2) NULL,

    observacion_social TEXT NULL,

    evaluada_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_evaluacion DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_esb_solicitud UNIQUE (solicitud_beca_id),

    CONSTRAINT fk_esb_solicitud
        FOREIGN KEY (solicitud_beca_id) REFERENCES solicitudes_beca(id),
    CONSTRAINT fk_esb_evaluada_por
        FOREIGN KEY (evaluada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_esb_montos CHECK (
        (ingresos_hogar IS NULL OR ingresos_hogar >= 0)
        AND
        (numero_miembros_hogar IS NULL OR numero_miembros_hogar >= 1)
        AND
        (ingreso_per_capita IS NULL OR ingreso_per_capita >= 0)
        AND
        (valor_ayuda_economica IS NULL OR valor_ayuda_economica >= 0)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 07. ADJUDICACIÓN DE BECA
-- ============================================================

CREATE TABLE becas_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_beca VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    programa_beca_id BIGINT UNSIGNED NOT NULL,
    solicitud_beca_id BIGINT UNSIGNED NULL,
    estado_beca_id BIGINT UNSIGNED NOT NULL,

    porcentaje_beca DECIMAL(5,2) NULL,
    monto_beca DECIMAL(12,2) NULL,

    porcentaje_manutencion DECIMAL(5,2) NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    es_renovacion BOOLEAN NOT NULL DEFAULT FALSE,
    beca_origen_id BIGINT UNSIGNED NULL,

    aprobada_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_aprobacion DATETIME NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_beca_numero UNIQUE (numero_beca),

    CONSTRAINT uq_beca_estudiante_periodo_programa
        UNIQUE (estudiante_carrera_id, periodo_academico_id, programa_beca_id),

    CONSTRAINT fk_be_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_be_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_be_programa
        FOREIGN KEY (programa_beca_id) REFERENCES programas_beca(id),
    CONSTRAINT fk_be_solicitud
        FOREIGN KEY (solicitud_beca_id) REFERENCES solicitudes_beca(id),
    CONSTRAINT fk_be_estado
        FOREIGN KEY (estado_beca_id) REFERENCES estados_beca(id),
    CONSTRAINT fk_be_origen
        FOREIGN KEY (beca_origen_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_be_aprobada_por
        FOREIGN KEY (aprobada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_be_porcentaje CHECK (
        porcentaje_beca IS NULL OR (porcentaje_beca >= 0 AND porcentaje_beca <= 100)
    ),
    CONSTRAINT chk_be_monto CHECK (
        monto_beca IS NULL OR monto_beca >= 0
    ),
    CONSTRAINT chk_be_manutencion CHECK (
        porcentaje_manutencion IS NULL OR (porcentaje_manutencion >= 0 AND porcentaje_manutencion <= 100)
    ),
    CONSTRAINT chk_be_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_be_periodo_estado
ON becas_estudiante (periodo_academico_id, estado_beca_id);

-- ============================================================
-- 08. HISTÓRICO DE ESTADOS DE BECA
-- ============================================================

CREATE TABLE historial_estado_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    beca_estudiante_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_heb_beca
        FOREIGN KEY (beca_estudiante_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_heb_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_beca(id),
    CONSTRAINT fk_heb_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_beca(id),
    CONSTRAINT fk_heb_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_heb_beca_fecha
ON historial_estado_beca (beca_estudiante_id, changed_at);

-- ============================================================
-- 09. PÉRDIDA / SUSPENSIÓN DE BECA
-- ============================================================

CREATE TABLE perdidas_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    beca_estudiante_id BIGINT UNSIGNED NOT NULL,
    motivo_perdida_beca_id BIGINT UNSIGNED NOT NULL,

    fecha_perdida DATE NOT NULL,

    detalle TEXT NULL,

    certificado_archivo_id BIGINT UNSIGNED NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion DATETIME NULL,

    CONSTRAINT uq_perdida_beca UNIQUE (beca_estudiante_id),

    CONSTRAINT fk_pb_beca
        FOREIGN KEY (beca_estudiante_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_pb_motivo
        FOREIGN KEY (motivo_perdida_beca_id) REFERENCES motivos_perdida_beca(id),
    CONSTRAINT fk_pb_certificado
        FOREIGN KEY (certificado_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_pb_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_pb_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 10. RENOVACIONES
-- ============================================================

CREATE TABLE renovaciones_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    beca_origen_id BIGINT UNSIGNED NOT NULL,
    periodo_destino_id BIGINT UNSIGNED NOT NULL,

    solicitud_beca_id BIGINT UNSIGNED NULL,
    beca_destino_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_resolucion DATETIME NULL,

    aprobada BOOLEAN NULL,

    resuelta_por_usuario_id BIGINT UNSIGNED NULL,
    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_renovacion_beca_periodo
        UNIQUE (beca_origen_id, periodo_destino_id),

    CONSTRAINT fk_rb_origen
        FOREIGN KEY (beca_origen_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_rb_periodo
        FOREIGN KEY (periodo_destino_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rb_solicitud
        FOREIGN KEY (solicitud_beca_id) REFERENCES solicitudes_beca(id),
    CONSTRAINT fk_rb_destino
        FOREIGN KEY (beca_destino_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_rb_usuario
        FOREIGN KEY (resuelta_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. ACOMPAÑAMIENTO DE BIENESTAR / PSICOPEDAGÓGICO
-- ============================================================

CREATE TABLE acompanamientos_bienestar (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,
    beca_estudiante_id BIGINT UNSIGNED NULL,

    estado_acompanamiento_id BIGINT UNSIGNED NOT NULL,

    tipo_acompanamiento VARCHAR(100) NOT NULL,
    motivo TEXT NULL,

    responsable_usuario_id BIGINT UNSIGNED NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_ab_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_ab_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_ab_beca
        FOREIGN KEY (beca_estudiante_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_ab_estado
        FOREIGN KEY (estado_acompanamiento_id) REFERENCES estados_acompanamiento_bienestar(id),
    CONSTRAINT fk_ab_responsable
        FOREIGN KEY (responsable_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ab_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE TABLE sesiones_acompanamiento_bienestar (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    acompanamiento_bienestar_id BIGINT UNSIGNED NOT NULL,

    fecha_sesion DATETIME NOT NULL,
    detalle TEXT NOT NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,
    archivo_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sab_acompanamiento
        FOREIGN KEY (acompanamiento_bienestar_id) REFERENCES acompanamientos_bienestar(id),
    CONSTRAINT fk_sab_usuario
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sab_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 12. EVENTOS DE BECA
-- ============================================================

CREATE TABLE eventos_beca (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    beca_estudiante_id BIGINT UNSIGNED NOT NULL,
    tipo_evento_beca_id BIGINT UNSIGNED NOT NULL,

    descripcion TEXT NULL,

    ejecutado_por_usuario_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_eb_beca
        FOREIGN KEY (beca_estudiante_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_eb_tipo
        FOREIGN KEY (tipo_evento_beca_id) REFERENCES tipos_evento_beca(id),
    CONSTRAINT fk_eb_usuario
        FOREIGN KEY (ejecutado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_eb_beca_fecha
ON eventos_beca (beca_estudiante_id, created_at);

-- ============================================================
-- 13. INTEGRACIÓN CON FINANCIERO
-- El efecto monetario de la beca se aplica a la orden de pago.
-- ============================================================

CREATE TABLE beca_aplicaciones_financieras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    beca_estudiante_id BIGINT UNSIGNED NOT NULL,
    orden_pago_id BIGINT UNSIGNED NOT NULL,
    orden_pago_detalle_id BIGINT UNSIGNED NULL,

    monto_aplicado DECIMAL(12,2) NOT NULL,
    porcentaje_aplicado DECIMAL(5,2) NULL,

    fecha_aplicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    aplicada_por_usuario_id BIGINT UNSIGNED NULL,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_beca_aplicacion_orden
        UNIQUE (beca_estudiante_id, orden_pago_id),

    CONSTRAINT fk_baf_beca
        FOREIGN KEY (beca_estudiante_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_baf_orden
        FOREIGN KEY (orden_pago_id) REFERENCES ordenes_pago(id),
    CONSTRAINT fk_baf_detalle
        FOREIGN KEY (orden_pago_detalle_id) REFERENCES orden_pago_detalles(id),
    CONSTRAINT fk_baf_usuario
        FOREIGN KEY (aplicada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_baf_monto CHECK (
        monto_aplicado >= 0
    ),
    CONSTRAINT chk_baf_porcentaje CHECK (
        porcentaje_aplicado IS NULL OR (porcentaje_aplicado >= 0 AND porcentaje_aplicado <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. INDICADORES / SNAPSHOT DE ESTADO DE BECA
-- ============================================================

CREATE TABLE resumen_beca_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,

    tiene_beca_activa BOOLEAN NOT NULL DEFAULT FALSE,
    beca_activa_id BIGINT UNSIGNED NULL,

    porcentaje_beca_actual DECIMAL(5,2) NULL,
    monto_beca_actual DECIMAL(12,2) NULL,

    ultimo_periodo_beca_id BIGINT UNSIGNED NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_resumen_beca_estudiante UNIQUE (estudiante_carrera_id),

    CONSTRAINT fk_rbe_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_rbe_beca
        FOREIGN KEY (beca_activa_id) REFERENCES becas_estudiante(id),
    CONSTRAINT fk_rbe_periodo
        FOREIGN KEY (ultimo_periodo_beca_id) REFERENCES periodos_academicos(id),

    CONSTRAINT chk_rbe_porcentaje CHECK (
        porcentaje_beca_actual IS NULL OR (porcentaje_beca_actual >= 0 AND porcentaje_beca_actual <= 100)
    ),
    CONSTRAINT chk_rbe_monto CHECK (
        monto_beca_actual IS NULL OR monto_beca_actual >= 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 15. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_beca
(codigo, nombre, descripcion, permite_porcentaje, permite_monto_fijo)
VALUES
('TOTAL', 'Beca total', 'Cubre hasta el 100% según resolución institucional', TRUE, TRUE),
('PARCIAL', 'Beca parcial', 'Cubre un porcentaje o monto parcial', TRUE, TRUE),
('AYUDA_ECONOMICA', 'Ayuda económica', 'Apoyo económico institucional', TRUE, TRUE),
('OTRA', 'Otra', 'Otro tipo de beneficio', TRUE, TRUE);

INSERT INTO razones_beca (codigo, nombre) VALUES
('SOCIOECONOMICA', 'Socioeconómica'),
('ACADEMICA', 'Académica / mérito'),
('DEPORTIVA', 'Deportiva'),
('CULTURAL', 'Cultural'),
('DISCAPACIDAD', 'Discapacidad'),
('CONVENIO', 'Convenio'),
('SENESCYT', 'SENESCYT'),
('TEC', 'Programa TEC'),
('OTRA', 'Otra'),
('NA', 'N/A');

INSERT INTO tipos_financiamiento_beca
(codigo, nombre)
VALUES
('FONDOS_PROPIOS', 'Fondos propios'),
('CONVENIO', 'Convenio'),
('TERCEROS', 'Financiamiento de terceros'),
('MIXTO', 'Mixto'),
('OTRO', 'Otro');

INSERT INTO estados_beca
(codigo, nombre, permite_aplicacion_financiera, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('APROBADA', 'Aprobada', TRUE, FALSE),
('ACTIVA', 'Activa', TRUE, FALSE),
('SUSPENDIDA', 'Suspendida', FALSE, FALSE),
('PERDIDA', 'Pérdida de beca', FALSE, TRUE),
('FINALIZADA', 'Finalizada', FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO estados_solicitud_beca
(codigo, nombre, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE),
('ENVIADA', 'Enviada', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('OBSERVADA', 'Observada', FALSE),
('APROBADA', 'Aprobada', TRUE),
('RECHAZADA', 'Rechazada', TRUE),
('ANULADA', 'Anulada', TRUE);

INSERT INTO tipos_documento_beca
(codigo, nombre, obligatorio)
VALUES
('SOLICITUD_BECA', 'Ficha de solicitud de beca', TRUE),
('FICHA_SOCIOECONOMICA', 'Ficha socioeconómica', TRUE),
('CONTRATO_BECA', 'Contrato de beca', TRUE),
('CERTIFICADO_PERDIDA', 'Certificado de pérdida de beca', FALSE),
('ACOMPANAMIENTO_PSICOPEDAGOGICO', 'Acompañamiento psicopedagógico', FALSE),
('OTRO', 'Otro documento', FALSE);

INSERT INTO tipos_evento_beca (codigo, nombre) VALUES
('SOLICITADA', 'Beca solicitada'),
('APROBADA', 'Beca aprobada'),
('ACTIVADA', 'Beca activada'),
('RENOVADA', 'Beca renovada'),
('SUSPENDIDA', 'Beca suspendida'),
('PERDIDA', 'Beca perdida'),
('FINALIZADA', 'Beca finalizada'),
('APLICADA_FINANCIERO', 'Beca aplicada financieramente');

INSERT INTO motivos_perdida_beca (codigo, nombre) VALUES
('BAJO_RENDIMIENTO', 'Bajo rendimiento académico'),
('INCUMPLIMIENTO', 'Incumplimiento de condiciones'),
('RETIRO', 'Retiro del estudiante'),
('CAMBIO_CONDICION', 'Cambio de condición socioeconómica'),
('RENUNCIA', 'Renuncia voluntaria'),
('OTRO', 'Otro');

INSERT INTO estados_acompanamiento_bienestar
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_PROCESO', 'En proceso', FALSE),
('CERRADO', 'Cerrado', TRUE),
('ANULADO', 'Anulado', TRUE);

-- Programa institucional de ejemplo.
INSERT INTO programas_beca
(codigo, nombre, tipo_beca_id, tipo_financiamiento_beca_id, descripcion, porcentaje_maximo, vigente_desde)
SELECT
    'BECA_SOCIOECONOMICA',
    'BECA SOCIOECONÓMICA',
    tb.id,
    tf.id,
    'Programa institucional de beca socioeconómica',
    100.00,
    '2026-01-01'
FROM tipos_beca tb
JOIN tipos_financiamiento_beca tf
    ON tf.codigo = 'FONDOS_PROPIOS'
WHERE tb.codigo = 'TOTAL';

-- ============================================================
-- 16. REGLAS DE APLICACIÓN
-- ============================================================
--
-- DATOS DEL ESTUDIANTE:
-- En /perfil y módulos administrativos se podrá conocer:
--   - Tiene beca: sí/no
--   - Tipo de beca
--   - Razones 1..N
--   - Monto
--   - Porcentaje
--   - % manutención
--   - Tipo de financiamiento
--   - Nombre institucional
--   - Estado
--   - Período
--
-- No se crean columnas "primera_razon", "segunda_razon", etc.
-- Las razones se normalizan en solicitud_beca_razones.
--
-- SOLICITUD:
-- 1. Bienestar/usuario autorizado crea o recibe solicitud.
-- 2. Se adjuntan documentos requeridos.
-- 3. Se realiza evaluación socioeconómica.
-- 4. Estado -> APROBADA / RECHAZADA.
-- 5. Si se aprueba, se crea becas_estudiante.
--
-- APLICACIÓN FINANCIERA:
-- 1. Solo becas con estado que permita aplicación financiera.
-- 2. El servicio calcula el valor según porcentaje/monto y reglas.
-- 3. Se agrega línea BECA en orden_pago_detalles.
-- 4. Se actualiza ordenes_pago.total_becas y total_pagar.
-- 5. Se registra beca_aplicaciones_financieras.
-- 6. Kardex recibe el crédito tipo BECA.
--
-- RENOVACIÓN:
-- - No se modifica la beca anterior.
-- - Se crea una nueva beca para el nuevo período con beca_origen_id.
-- - renovaciones_beca vincula ambos registros.
--
-- PÉRDIDA:
-- - Se registra perdidas_beca.
-- - Se cambia estado a PERDIDA.
-- - Se conserva certificado/documento si existe.
-- - No se borran aplicaciones financieras históricas.
--
-- ACOMPAÑAMIENTO:
-- - Puede vincularse o no a una beca.
-- - Permite seguimiento psicopedagógico / bienestar.
--
-- REPORTES:
-- - Becados por período
-- - Becados por carrera
-- - Tipo de beca
-- - Razón
-- - Monto total otorgado
-- - Porcentaje promedio
-- - Becas activas / perdidas / renovadas
-- - Seguimientos de bienestar
--
-- ============================================================
-- FIN 011_becas_bienestar.sql
-- ============================================================
