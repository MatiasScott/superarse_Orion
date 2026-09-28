-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 014_titulacion.sql
-- Requiere bloques 001-013
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión integral del proceso de titulación
--   - Solicitudes y certificados previos
--   - Solicitud de ingreso a titulación
--   - Modalidades: Examen Complexivo / Trabajo de Titulación
--   - Submodalidades: Proyecto, Prototipo, Emprendimiento
--   - Plan de trabajo y plantillas descargables
--   - Tutor, tribunal, defensa y actas
--   - Oportunidades e intentos
--   - Regla: Trabajo de Titulación máximo 2 oportunidades;
--            tercera oportunidad únicamente Examen Complexivo
--   - Requisitos pendientes al inicio (malla / financiero)
--   - Integración con expediente documental
--   - Trazabilidad y estados históricos
--
-- PRINCIPIOS:
--   - El estudiante puede iniciar parte del proceso aunque aún no haya
--     terminado completamente la malla o los requisitos financieros.
--   - Los requisitos "culminación de malla" y "cumplimiento financiero"
--     pueden permanecer PENDIENTES hasta ser verificables.
--   - No se borra histórico de intentos, documentos, tutores, tribunales ni actas.
--   - Los comprobantes de pago y documentos se guardan en archivos.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS GENERALES
-- ============================================================

CREATE TABLE estados_proceso_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_gestion BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_proceso_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_solicitud_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    valor_referencial DECIMAL(12,2) NULL,
    requiere_pago BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_solicitud_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_solicitud_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_solicitud_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE modalidades_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_submodalidad BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_modalidad_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE submodalidades_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    modalidad_titulacion_id BIGINT UNSIGNED NOT NULL,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_submodalidad_titulacion_codigo UNIQUE (codigo),

    CONSTRAINT fk_smt_modalidad
        FOREIGN KEY (modalidad_titulacion_id) REFERENCES modalidades_titulacion(id)
) ENGINE=InnoDB;

CREATE TABLE tipos_requisito_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    bloqueante BOOLEAN NOT NULL DEFAULT FALSE,
    verificable_automaticamente BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_requisito_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_requisito_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    cumplido BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_requisito_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_rol_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_rol_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_intento_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    aprobado BOOLEAN NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_intento_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_defensa_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_defensa_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_documento_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_documento_titulacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. PROCESO DE TITULACIÓN DEL ESTUDIANTE
-- ============================================================

CREATE TABLE procesos_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_proceso VARCHAR(60) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,
    estado_proceso_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre DATETIME NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_proceso_titulacion_numero UNIQUE (numero_proceso),

    CONSTRAINT fk_pt_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_pt_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_pt_estado
        FOREIGN KEY (estado_proceso_titulacion_id) REFERENCES estados_proceso_titulacion(id),

    CONSTRAINT chk_pt_fechas CHECK (
        fecha_cierre IS NULL OR fecha_cierre >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_pt_estudiante_estado
ON procesos_titulacion (estudiante_carrera_id, estado_proceso_titulacion_id);

-- ============================================================
-- 03. REQUISITOS DEL PROCESO
-- ============================================================

CREATE TABLE proceso_titulacion_requisitos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    tipo_requisito_titulacion_id BIGINT UNSIGNED NOT NULL,
    estado_requisito_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_verificacion DATETIME NULL,
    verificado_por_usuario_id BIGINT UNSIGNED NULL,

    referencia_modulo VARCHAR(80) NULL,
    referencia_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_ptr_requisito
        UNIQUE (proceso_titulacion_id, tipo_requisito_titulacion_id),

    CONSTRAINT fk_ptr_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_ptr_tipo
        FOREIGN KEY (tipo_requisito_titulacion_id) REFERENCES tipos_requisito_titulacion(id),
    CONSTRAINT fk_ptr_estado
        FOREIGN KEY (estado_requisito_titulacion_id) REFERENCES estados_requisito_titulacion(id),
    CONSTRAINT fk_ptr_verificado_por
        FOREIGN KEY (verificado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. SOLICITUDES Y CERTIFICADOS PREVIOS
-- ============================================================

CREATE TABLE solicitudes_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(60) NOT NULL,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    tipo_solicitud_titulacion_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    texto_solicitud TEXT NULL,

    comprobante_pago_archivo_id BIGINT UNSIGNED NULL,

    solicitado_por_usuario_id BIGINT UNSIGNED NULL,
    revisado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_revision DATETIME NULL,

    observacion TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitud_titulacion_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_st_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_st_tipo
        FOREIGN KEY (tipo_solicitud_titulacion_id) REFERENCES tipos_solicitud_titulacion(id),
    CONSTRAINT fk_st_estado
        FOREIGN KEY (estado_solicitud_titulacion_id) REFERENCES estados_solicitud_titulacion(id),
    CONSTRAINT fk_st_comprobante
        FOREIGN KEY (comprobante_pago_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_st_solicitado_por
        FOREIGN KEY (solicitado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_st_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_st_proceso_tipo
ON solicitudes_titulacion (proceso_titulacion_id, tipo_solicitud_titulacion_id);

CREATE TABLE certificados_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_titulacion_id BIGINT UNSIGNED NOT NULL,

    numero_certificado VARCHAR(80) NOT NULL,
    archivo_id BIGINT UNSIGNED NOT NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    fecha_emision DATE NOT NULL,

    emitido_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_cert_titulacion_numero UNIQUE (numero_certificado),
    CONSTRAINT uq_cert_titulacion_solicitud UNIQUE (solicitud_titulacion_id),

    CONSTRAINT fk_ct_solicitud
        FOREIGN KEY (solicitud_titulacion_id) REFERENCES solicitudes_titulacion(id),
    CONSTRAINT fk_ct_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_ct_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_ct_emitido_por
        FOREIGN KEY (emitido_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 05. INSCRIPCIÓN / MODALIDAD DE TITULACIÓN
-- ============================================================

CREATE TABLE inscripciones_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    modalidad_titulacion_id BIGINT UNSIGNED NOT NULL,
    submodalidad_titulacion_id BIGINT UNSIGNED NULL,

    fecha_inscripcion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    comprobante_pago_archivo_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_inscripcion_titulacion_proceso UNIQUE (proceso_titulacion_id),

    CONSTRAINT fk_it_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_it_modalidad
        FOREIGN KEY (modalidad_titulacion_id) REFERENCES modalidades_titulacion(id),
    CONSTRAINT fk_it_submodalidad
        FOREIGN KEY (submodalidad_titulacion_id) REFERENCES submodalidades_titulacion(id),
    CONSTRAINT fk_it_comprobante
        FOREIGN KEY (comprobante_pago_archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. PLANTILLAS / FORMATOS DESCARGABLES
-- ============================================================

CREATE TABLE plantillas_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    modalidad_titulacion_id BIGINT UNSIGNED NULL,
    submodalidad_titulacion_id BIGINT UNSIGNED NULL,

    archivo_id BIGINT UNSIGNED NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_plantilla_titulacion_codigo UNIQUE (codigo),

    CONSTRAINT fk_plt_modalidad
        FOREIGN KEY (modalidad_titulacion_id) REFERENCES modalidades_titulacion(id),
    CONSTRAINT fk_plt_submodalidad
        FOREIGN KEY (submodalidad_titulacion_id) REFERENCES submodalidades_titulacion(id),
    CONSTRAINT fk_plt_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),

    CONSTRAINT chk_plt_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 07. DOCUMENTOS DEL PROCESO
-- ============================================================

CREATE TABLE documentos_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    tipo_documento_titulacion_id BIGINT UNSIGNED NOT NULL,

    archivo_id BIGINT UNSIGNED NOT NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    nombre_documento VARCHAR(255) NULL,

    version_numero INT UNSIGNED NOT NULL DEFAULT 1,
    aprobado BOOLEAN NOT NULL DEFAULT FALSE,

    cargado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion DATETIME NULL,

    observacion TEXT NULL,

    vigente BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_dt_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_dt_tipo
        FOREIGN KEY (tipo_documento_titulacion_id) REFERENCES tipos_documento_titulacion(id),
    CONSTRAINT fk_dt_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_dt_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_dt_cargado_por
        FOREIGN KEY (cargado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_dt_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_dt_proceso_tipo
ON documentos_titulacion (proceso_titulacion_id, tipo_documento_titulacion_id, vigente);

-- ============================================================
-- 08. PLAN DE TRABAJO / TEMA
-- ============================================================

CREATE TABLE planes_trabajo_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,

    titulo VARCHAR(300) NOT NULL,
    resumen TEXT NULL,

    archivo_plan_id BIGINT UNSIGNED NOT NULL,

    version_numero INT UNSIGNED NOT NULL DEFAULT 1,

    aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_aprobacion DATETIME NULL,

    observacion TEXT NULL,

    vigente BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ptt_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_ptt_archivo
        FOREIGN KEY (archivo_plan_id) REFERENCES archivos(id),
    CONSTRAINT fk_ptt_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ptt_proceso_vigente
ON planes_trabajo_titulacion (proceso_titulacion_id, vigente);

-- ============================================================
-- 09. TUTOR / RESPONSABLES
-- ============================================================

CREATE TABLE asignaciones_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    tipo_rol_titulacion_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NULL,

    nombre_externo VARCHAR(220) NULL,
    correo_externo VARCHAR(190) NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_at_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_at_tipo_rol
        FOREIGN KEY (tipo_rol_titulacion_id) REFERENCES tipos_rol_titulacion(id),
    CONSTRAINT fk_at_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_at_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_at_proceso_activo
ON asignaciones_titulacion (proceso_titulacion_id, activo);

-- ============================================================
-- 10. INTENTOS / OPORTUNIDADES
-- ============================================================

CREATE TABLE intentos_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,

    numero_intento SMALLINT UNSIGNED NOT NULL,

    modalidad_titulacion_id BIGINT UNSIGNED NOT NULL,
    submodalidad_titulacion_id BIGINT UNSIGNED NULL,

    estado_intento_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    resultado_nota DECIMAL(5,2) NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_intento_titulacion
        UNIQUE (proceso_titulacion_id, numero_intento),

    CONSTRAINT fk_int_tit_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_int_tit_modalidad
        FOREIGN KEY (modalidad_titulacion_id) REFERENCES modalidades_titulacion(id),
    CONSTRAINT fk_int_tit_submodalidad
        FOREIGN KEY (submodalidad_titulacion_id) REFERENCES submodalidades_titulacion(id),
    CONSTRAINT fk_int_tit_estado
        FOREIGN KEY (estado_intento_titulacion_id) REFERENCES estados_intento_titulacion(id),

    CONSTRAINT chk_int_tit_numero CHECK (
        numero_intento BETWEEN 1 AND 3
    ),
    CONSTRAINT chk_int_tit_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    ),
    CONSTRAINT chk_int_tit_nota CHECK (
        resultado_nota IS NULL OR (resultado_nota >= 0 AND resultado_nota <= 10)
    )
) ENGINE=InnoDB;

-- Regla de aplicación:
-- - Intentos 1 y 2 pueden ser Trabajo de Titulación o Complexivo según proceso.
-- - Si Trabajo de Titulación falla dos veces:
--      intento 3 DEBE ser EXAMEN_COMPLEXIVO.
-- - Nunca más de 3 intentos.

-- ============================================================
-- 11. EXAMEN COMPLEXIVO
-- ============================================================

CREATE TABLE examenes_complexivos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    intento_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_examen DATETIME NULL,
    lugar VARCHAR(255) NULL,

    nota DECIMAL(5,2) NULL,
    aprobado BOOLEAN NULL,

    acta_archivo_id BIGINT UNSIGNED NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_examen_complexivo_intento UNIQUE (intento_titulacion_id),

    CONSTRAINT fk_ec_intento
        FOREIGN KEY (intento_titulacion_id) REFERENCES intentos_titulacion(id),
    CONSTRAINT fk_ec_acta
        FOREIGN KEY (acta_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_ec_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_ec_usuario
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ec_nota CHECK (
        nota IS NULL OR (nota >= 0 AND nota <= 10)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 12. TRIBUNAL
-- ============================================================

CREATE TABLE tribunales_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    fecha_designacion DATE NOT NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_tribunal_proceso UNIQUE (proceso_titulacion_id),

    CONSTRAINT fk_tt_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id)
) ENGINE=InnoDB;

CREATE TABLE tribunal_miembros (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tribunal_titulacion_id BIGINT UNSIGNED NOT NULL,
    tipo_rol_titulacion_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    nombre_externo VARCHAR(220) NULL,
    correo_externo VARCHAR(190) NULL,

    orden SMALLINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tribunal_miembro_orden
        UNIQUE (tribunal_titulacion_id, orden),

    CONSTRAINT fk_tm_tribunal
        FOREIGN KEY (tribunal_titulacion_id) REFERENCES tribunales_titulacion(id),
    CONSTRAINT fk_tm_tipo_rol
        FOREIGN KEY (tipo_rol_titulacion_id) REFERENCES tipos_rol_titulacion(id),
    CONSTRAINT fk_tm_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 13. DEFENSA
-- ============================================================

CREATE TABLE defensas_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    intento_titulacion_id BIGINT UNSIGNED NULL,
    estado_defensa_titulacion_id BIGINT UNSIGNED NOT NULL,

    fecha_programada DATETIME NULL,
    fecha_real DATETIME NULL,

    lugar VARCHAR(255) NULL,

    nota DECIMAL(5,2) NULL,
    aprobado BOOLEAN NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_def_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_def_intento
        FOREIGN KEY (intento_titulacion_id) REFERENCES intentos_titulacion(id),
    CONSTRAINT fk_def_estado
        FOREIGN KEY (estado_defensa_titulacion_id) REFERENCES estados_defensa_titulacion(id),

    CONSTRAINT chk_def_nota CHECK (
        nota IS NULL OR (nota >= 0 AND nota <= 10)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. ACTAS
-- ============================================================

CREATE TABLE actas_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,

    tipo_acta VARCHAR(60) NOT NULL,
    numero_acta VARCHAR(80) NULL,

    archivo_id BIGINT UNSIGNED NOT NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    fecha_emision DATE NOT NULL,

    emitida_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_act_tit_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_act_tit_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_act_tit_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_act_tit_usuario
        FOREIGN KEY (emitida_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 15. HISTÓRICO DE ESTADOS DEL PROCESO
-- ============================================================

CREATE TABLE historial_estado_proceso_titulacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proceso_titulacion_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,

    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hept_proceso
        FOREIGN KEY (proceso_titulacion_id) REFERENCES procesos_titulacion(id),
    CONSTRAINT fk_hept_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_proceso_titulacion(id),
    CONSTRAINT fk_hept_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_proceso_titulacion(id),
    CONSTRAINT fk_hept_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hept_proceso_fecha
ON historial_estado_proceso_titulacion (proceso_titulacion_id, changed_at);

-- ============================================================
-- 16. DATOS INICIALES
-- ============================================================

INSERT INTO estados_proceso_titulacion
(codigo, nombre, permite_gestion, es_final)
VALUES
('INICIADO', 'Iniciado', TRUE, FALSE),
('EN_REQUISITOS', 'En requisitos', TRUE, FALSE),
('EN_DESARROLLO', 'En desarrollo', TRUE, FALSE),
('EN_EVALUACION', 'En evaluación', TRUE, FALSE),
('APROBADO', 'Aprobado', FALSE, TRUE),
('REPROBADO', 'Reprobado', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE);

INSERT INTO tipos_solicitud_titulacion
(codigo, nombre, valor_referencial, requiere_pago)
VALUES
('CERT_CULMINACION_MALLA', 'Certificado de Culminación de Malla Curricular', 5.00, TRUE),
('CERT_CUMPLIMIENTO_FINANCIERO', 'Certificado de Cumplimiento Financiero', 5.00, TRUE),
('CERT_IDIOMA_EXTRANJERO', 'Certificado de Idioma Extranjero', 5.00, TRUE),
('INGRESO_PROCESO_TITULACION', 'Solicitud de Ingreso al Proceso de Titulación', 7.00, TRUE);

INSERT INTO estados_solicitud_titulacion
(codigo, nombre, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE),
('ENVIADA', 'Enviada', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('OBSERVADA', 'Observada', FALSE),
('APROBADA', 'Aprobada', TRUE),
('RECHAZADA', 'Rechazada', TRUE),
('ANULADA', 'Anulada', TRUE);

INSERT INTO modalidades_titulacion
(codigo, nombre, permite_submodalidad)
VALUES
('EXAMEN_COMPLEXIVO', 'Examen Complexivo', FALSE),
('TRABAJO_TITULACION', 'Trabajo de Titulación', TRUE);

INSERT INTO submodalidades_titulacion
(modalidad_titulacion_id, codigo, nombre)
SELECT id, 'PROYECTO_TITULACION', 'Proyecto de Titulación'
FROM modalidades_titulacion WHERE codigo='TRABAJO_TITULACION';

INSERT INTO submodalidades_titulacion
(modalidad_titulacion_id, codigo, nombre)
SELECT id, 'PROTOTIPO', 'Prototipo'
FROM modalidades_titulacion WHERE codigo='TRABAJO_TITULACION';

INSERT INTO submodalidades_titulacion
(modalidad_titulacion_id, codigo, nombre)
SELECT id, 'EMPRENDIMIENTO', 'Proyecto de Emprendimiento'
FROM modalidades_titulacion WHERE codigo='TRABAJO_TITULACION';

INSERT INTO tipos_requisito_titulacion
(codigo, nombre, bloqueante, verificable_automaticamente)
VALUES
('CULMINACION_MALLA', 'Culminación de malla curricular', TRUE, TRUE),
('CUMPLIMIENTO_FINANCIERO', 'Cumplimiento financiero', TRUE, TRUE),
('IDIOMA_EXTRANJERO', 'Certificado de idioma extranjero', TRUE, FALSE),
('PRACTICAS', 'Prácticas preprofesionales cumplidas', TRUE, TRUE),
('VINCULACION', 'Vinculación con la sociedad cumplida', TRUE, TRUE),
('DOCUMENTACION_COMPLETA', 'Expediente documental completo', TRUE, TRUE);

INSERT INTO estados_requisito_titulacion
(codigo, nombre, cumplido, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('EN_REVISION', 'En revisión', FALSE, FALSE),
('CUMPLIDO', 'Cumplido', TRUE, TRUE),
('NO_CUMPLE', 'No cumple', FALSE, TRUE),
('NO_APLICA', 'No aplica', TRUE, TRUE);

INSERT INTO tipos_rol_titulacion
(codigo, nombre)
VALUES
('TUTOR', 'Tutor'),
('PRESIDENTE_TRIBUNAL', 'Presidente del tribunal'),
('MIEMBRO_TRIBUNAL', 'Miembro del tribunal'),
('SECRETARIO_TRIBUNAL', 'Secretario del tribunal'),
('LECTOR', 'Lector'),
('OTRO', 'Otro');

INSERT INTO estados_intento_titulacion
(codigo, nombre, aprobado, es_final)
VALUES
('PENDIENTE', 'Pendiente', NULL, FALSE),
('EN_DESARROLLO', 'En desarrollo', NULL, FALSE),
('APROBADO', 'Aprobado', TRUE, TRUE),
('REPROBADO', 'Reprobado', FALSE, TRUE),
('ANULADO', 'Anulado', NULL, TRUE);

INSERT INTO estados_defensa_titulacion
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('PROGRAMADA', 'Programada', FALSE),
('REALIZADA', 'Realizada', FALSE),
('APROBADA', 'Aprobada', TRUE),
('REPROBADA', 'Reprobada', TRUE),
('CANCELADA', 'Cancelada', TRUE);

INSERT INTO tipos_documento_titulacion
(codigo, nombre, obligatorio)
VALUES
('PLAN_TRABAJO', 'Plan de trabajo de titulación', TRUE),
('ANEXO_A', 'Anexo A', FALSE),
('ANEXO_B', 'Anexo B', FALSE),
('ACTA_DEFENSA', 'Acta de defensa', FALSE),
('ACTA_GRADO', 'Acta de grado', FALSE),
('OTRO', 'Otro documento', FALSE);

-- ============================================================
-- 17. REGLAS DE APLICACIÓN
-- ============================================================
--
-- INICIO DEL PROCESO:
-- - El estudiante puede iniciar aunque:
--      CULMINACION_MALLA = PENDIENTE
--      CUMPLIMIENTO_FINANCIERO = PENDIENTE
-- - Esto responde al proceso real de último nivel.
--
-- SOLICITUDES:
-- - Certificado Culminación de Malla: comprobante $5.
-- - Certificado Cumplimiento Financiero: comprobante $5.
-- - Certificado Idioma Extranjero: comprobante $5.
-- - Ingreso al proceso: comprobante $7.
-- - Los valores son referenciales y podrían pasar a configuración financiera.
--
-- MODALIDAD:
-- - EXAMEN_COMPLEXIVO
-- - TRABAJO_TITULACION
--      -> Proyecto
--      -> Prototipo
--      -> Emprendimiento
--
-- PLAN DE TRABAJO:
-- - Debe poder descargarse la plantilla correcta según submodalidad.
-- - Se guarda versión del plan.
--
-- OPORTUNIDADES:
-- - Máximo 3 intentos.
-- - Si el estudiante eligió TRABAJO_TITULACION:
--      intento 1 -> trabajo
--      intento 2 -> trabajo
--      si reprueba ambos:
--          intento 3 -> SOLO EXAMEN_COMPLEXIVO
-- - La aplicación debe impedir guardar intento 3 de tipo trabajo.
-- - Las notas de titulación usan la escala institucional 0 a 10.
--
-- TUTOR / TRIBUNAL:
-- - Se asignan usuarios internos o externos.
-- - Se conserva histórico de vigencia.
--
-- DEFENSA:
-- - Se programa, registra nota/resultado y acta.
--
-- EXPEDIENTE:
-- - Los archivos oficiales deben vincularse con documentos_expediente:
--      TIT_EXAMEN_COMPLEXIVO_ANEXO_A
--      TIT_TRABAJO_ANEXO_A_B
--      ACTA_DEFENSA_TITULACION
--      ACTA_GRADO
--
-- CIERRE:
-- - Solo puede marcarse APROBADO cuando todos los requisitos obligatorios
--   estén CUMPLIDOS y el intento final resulte aprobado.
--
-- ============================================================
-- FIN 014_titulacion.sql
-- ============================================================
