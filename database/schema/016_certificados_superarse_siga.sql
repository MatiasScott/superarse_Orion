-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 016_certificados.sql
-- Requiere bloques 001-015
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión integral de certificados institucionales
--   - Plantillas reutilizables con variables
--   - Generación individual y masiva
--   - Certificados académicos, congresos, talleres y cursos cortos
--   - Elegibilidad por carrera, asignatura, curso o listado Excel
--   - QR / código de validación pública
--   - Firma manuscrita digitalizada y preparación para firma electrónica
--   - Múltiples firmantes y orden de firma
--   - Versionado y revocación de certificados
--   - Integración con expediente documental del estudiante
--   - Generación de PDF final y almacenamiento en archivos
--
-- PRINCIPIOS:
--   - El certificado emitido es inmutable; si cambia algo, se emite una nueva versión.
--   - No se almacena la contraseña de una firma electrónica.
--   - La firma electrónica debe ejecutarse en tiempo real o mediante proveedor seguro.
--   - La validación pública no expone información sensible innecesaria.
--   - El QR apunta a un código/token verificable, no a datos crudos.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS
-- ============================================================

CREATE TABLE tipos_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_emitido BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_firma_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    requiere_interaccion_usuario BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_firma_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_firma_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_firmado BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_firma_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_origen_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_origen_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_destinatario_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_destinatario_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_validacion_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_validacion_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CATÁLOGO DE VARIABLES DE PLANTILLA
-- ============================================================

CREATE TABLE variables_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,

    tipo_dato VARCHAR(30) NOT NULL,
    origen_dato VARCHAR(80) NOT NULL,

    ejemplo VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_variable_certificado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- Ejemplos:
-- {{NOMBRES}}
-- {{APELLIDOS}}
-- {{NOMBRE_COMPLETO}}
-- {{CEDULA}}
-- {{CARRERA}}
-- {{CURSO}}
-- {{NOTA}}
-- {{HORAS}}
-- {{FECHA_EMISION}}
-- {{NUMERO_CERTIFICADO}}
-- {{QR_URL}}

-- ============================================================
-- 03. PLANTILLAS DE CERTIFICADO
-- ============================================================

CREATE TABLE plantillas_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    tipo_certificado_id BIGINT UNSIGNED NOT NULL,

    descripcion TEXT NULL,

    archivo_plantilla_id BIGINT UNSIGNED NULL,
    html_plantilla LONGTEXT NULL,
    css_plantilla LONGTEXT NULL,

    orientacion VARCHAR(20) NOT NULL DEFAULT 'HORIZONTAL',
    tamano_pagina VARCHAR(30) NOT NULL DEFAULT 'A4',

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_plantilla_certificado_codigo UNIQUE (codigo),

    CONSTRAINT fk_pc_tipo
        FOREIGN KEY (tipo_certificado_id) REFERENCES tipos_certificado(id),
    CONSTRAINT fk_pc_archivo
        FOREIGN KEY (archivo_plantilla_id) REFERENCES archivos(id),
    CONSTRAINT fk_pc_usuario
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pc_orientacion CHECK (
        orientacion IN ('HORIZONTAL', 'VERTICAL')
    ),
    CONSTRAINT chk_pc_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE TABLE plantilla_certificado_variables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    plantilla_certificado_id BIGINT UNSIGNED NOT NULL,
    variable_certificado_id BIGINT UNSIGNED NOT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
    valor_defecto VARCHAR(500) NULL,

    CONSTRAINT uq_pcv
        UNIQUE (plantilla_certificado_id, variable_certificado_id),

    CONSTRAINT fk_pcv_plantilla
        FOREIGN KEY (plantilla_certificado_id) REFERENCES plantillas_certificado(id),
    CONSTRAINT fk_pcv_variable
        FOREIGN KEY (variable_certificado_id) REFERENCES variables_certificado(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. CURSOS CORTOS / ACTIVIDADES CERTIFICABLES
-- ============================================================

CREATE TABLE actividades_certificables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,

    tipo_certificado_id BIGINT UNSIGNED NOT NULL,

    descripcion TEXT NULL,

    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,

    horas DECIMAL(8,2) NULL,
    nota_minima_aprobacion DECIMAL(5,2) NULL,

    requiere_aprobacion BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_actividad_certificable_codigo UNIQUE (codigo),

    CONSTRAINT fk_ac_tipo_certificado
        FOREIGN KEY (tipo_certificado_id) REFERENCES tipos_certificado(id),

    CONSTRAINT chk_ac_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    ),
    CONSTRAINT chk_ac_horas CHECK (
        horas IS NULL OR horas >= 0
    ),
    CONSTRAINT chk_ac_nota CHECK (
        nota_minima_aprobacion IS NULL OR
        (nota_minima_aprobacion >= 0 AND nota_minima_aprobacion <= 100)
    )
) ENGINE=InnoDB;

CREATE TABLE actividad_certificable_participantes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    actividad_certificable_id BIGINT UNSIGNED NOT NULL,

    persona_id BIGINT UNSIGNED NOT NULL,
    estudiante_carrera_id BIGINT UNSIGNED NULL,
    usuario_id BIGINT UNSIGNED NULL,

    nota DECIMAL(5,2) NULL,
    aprobado BOOLEAN NULL,

    horas_cumplidas DECIMAL(8,2) NULL,

    elegible_certificado BOOLEAN NOT NULL DEFAULT FALSE,

    observacion VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_acp_actividad_persona
        UNIQUE (actividad_certificable_id, persona_id),

    CONSTRAINT fk_acp_actividad
        FOREIGN KEY (actividad_certificable_id) REFERENCES actividades_certificables(id),
    CONSTRAINT fk_acp_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_acp_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_acp_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_acp_nota CHECK (
        nota IS NULL OR (nota >= 0 AND nota <= 100)
    ),
    CONSTRAINT chk_acp_horas CHECK (
        horas_cumplidas IS NULL OR horas_cumplidas >= 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 05. LOTES DE GENERACIÓN
-- ============================================================

CREATE TABLE lotes_certificados (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_lote VARCHAR(60) NOT NULL,

    plantilla_certificado_id BIGINT UNSIGNED NOT NULL,
    tipo_origen_certificado_id BIGINT UNSIGNED NOT NULL,

    origen_referencia_id BIGINT UNSIGNED NULL,

    nombre_lote VARCHAR(220) NOT NULL,

    generado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    total_destinatarios INT UNSIGNED NOT NULL DEFAULT 0,
    total_generados INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,

    archivo_excel_origen_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_lote_certificado_numero UNIQUE (numero_lote),

    CONSTRAINT fk_lc_plantilla
        FOREIGN KEY (plantilla_certificado_id) REFERENCES plantillas_certificado(id),
    CONSTRAINT fk_lc_tipo_origen
        FOREIGN KEY (tipo_origen_certificado_id) REFERENCES tipos_origen_certificado(id),
    CONSTRAINT fk_lc_usuario
        FOREIGN KEY (generado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_lc_excel
        FOREIGN KEY (archivo_excel_origen_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. CERTIFICADOS EMITIDOS
-- ============================================================

CREATE TABLE certificados_emitidos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_certificado VARCHAR(80) NOT NULL,

    tipo_certificado_id BIGINT UNSIGNED NOT NULL,
    plantilla_certificado_id BIGINT UNSIGNED NOT NULL,
    estado_certificado_id BIGINT UNSIGNED NOT NULL,
    tipo_destinatario_certificado_id BIGINT UNSIGNED NOT NULL,

    lote_certificado_id BIGINT UNSIGNED NULL,

    persona_id BIGINT UNSIGNED NOT NULL,
    estudiante_carrera_id BIGINT UNSIGNED NULL,
    usuario_id BIGINT UNSIGNED NULL,

    actividad_certificable_id BIGINT UNSIGNED NULL,

    periodo_academico_id BIGINT UNSIGNED NULL,
    carrera_id BIGINT UNSIGNED NULL,
    seccion_id BIGINT UNSIGNED NULL,

    titulo_certificado VARCHAR(255) NOT NULL,

    fecha_emision DATE NOT NULL,

    archivo_pdf_id BIGINT UNSIGNED NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    token_validacion CHAR(64) NOT NULL,
    codigo_qr VARCHAR(255) NULL,

    version_numero INT UNSIGNED NOT NULL DEFAULT 1,
    certificado_origen_id BIGINT UNSIGNED NULL,

    emitido_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_certificado_emitido_numero UNIQUE (numero_certificado),
    CONSTRAINT uq_certificado_emitido_token UNIQUE (token_validacion),

    CONSTRAINT fk_ce_tipo
        FOREIGN KEY (tipo_certificado_id) REFERENCES tipos_certificado(id),
    CONSTRAINT fk_ce_plantilla
        FOREIGN KEY (plantilla_certificado_id) REFERENCES plantillas_certificado(id),
    CONSTRAINT fk_ce_estado
        FOREIGN KEY (estado_certificado_id) REFERENCES estados_certificado(id),
    CONSTRAINT fk_ce_tipo_destinatario
        FOREIGN KEY (tipo_destinatario_certificado_id) REFERENCES tipos_destinatario_certificado(id),
    CONSTRAINT fk_ce_lote
        FOREIGN KEY (lote_certificado_id) REFERENCES lotes_certificados(id),
    CONSTRAINT fk_ce_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_ce_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_ce_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ce_actividad
        FOREIGN KEY (actividad_certificable_id) REFERENCES actividades_certificables(id),
    CONSTRAINT fk_ce_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_ce_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_ce_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_ce_pdf
        FOREIGN KEY (archivo_pdf_id) REFERENCES archivos(id),
    CONSTRAINT fk_ce_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_ce_origen
        FOREIGN KEY (certificado_origen_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_ce_emitido_por
        FOREIGN KEY (emitido_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ce_persona_fecha
ON certificados_emitidos (persona_id, fecha_emision);

CREATE INDEX idx_ce_estado
ON certificados_emitidos (estado_certificado_id, fecha_emision);

-- ============================================================
-- 07. SNAPSHOT DE VARIABLES USADAS
-- ============================================================

CREATE TABLE certificado_valores_variables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    certificado_emitido_id BIGINT UNSIGNED NOT NULL,
    variable_certificado_id BIGINT UNSIGNED NOT NULL,

    valor TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_cvv
        UNIQUE (certificado_emitido_id, variable_certificado_id),

    CONSTRAINT fk_cvv_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_cvv_variable
        FOREIGN KEY (variable_certificado_id) REFERENCES variables_certificado(id)
) ENGINE=InnoDB;

-- Este snapshot asegura que una modificación posterior de nombres/carrera
-- no altere el contenido histórico del certificado ya emitido.

-- ============================================================
-- 08. FIRMANTES CONFIGURADOS EN LA PLANTILLA
-- ============================================================

CREATE TABLE plantilla_certificado_firmantes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    plantilla_certificado_id BIGINT UNSIGNED NOT NULL,

    orden_firma SMALLINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    nombre_firmante VARCHAR(220) NOT NULL,
    cargo_firmante VARCHAR(180) NULL,

    tipo_firma_certificado_id BIGINT UNSIGNED NOT NULL,

    imagen_firma_archivo_id BIGINT UNSIGNED NULL,

    certificado_digital_referencia VARCHAR(255) NULL,

    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_pcf_orden
        UNIQUE (plantilla_certificado_id, orden_firma),

    CONSTRAINT fk_pcf_plantilla
        FOREIGN KEY (plantilla_certificado_id) REFERENCES plantillas_certificado(id),
    CONSTRAINT fk_pcf_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_pcf_tipo_firma
        FOREIGN KEY (tipo_firma_certificado_id) REFERENCES tipos_firma_certificado(id),
    CONSTRAINT fk_pcf_imagen_firma
        FOREIGN KEY (imagen_firma_archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

-- certificado_digital_referencia puede apuntar a:
-- - alias de almacén seguro
-- - identificador de certificado
-- - proveedor externo de firma
--
-- Nunca almacenar la contraseña del certificado digital.

-- ============================================================
-- 09. FIRMAS POR CERTIFICADO
-- ============================================================

CREATE TABLE firmas_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    certificado_emitido_id BIGINT UNSIGNED NOT NULL,
    plantilla_certificado_firmante_id BIGINT UNSIGNED NOT NULL,

    estado_firma_certificado_id BIGINT UNSIGNED NOT NULL,

    firmado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NULL,
    fecha_firma DATETIME NULL,

    hash_documento_antes_firma CHAR(64) NULL,
    hash_documento_despues_firma CHAR(64) NULL,

    proveedor_firma VARCHAR(120) NULL,
    referencia_transaccion VARCHAR(190) NULL,

    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_firma_certificado_firmante
        UNIQUE (certificado_emitido_id, plantilla_certificado_firmante_id),

    CONSTRAINT fk_fc_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_fc_firmante
        FOREIGN KEY (plantilla_certificado_firmante_id) REFERENCES plantilla_certificado_firmantes(id),
    CONSTRAINT fk_fc_estado
        FOREIGN KEY (estado_firma_certificado_id) REFERENCES estados_firma_certificado(id),
    CONSTRAINT fk_fc_usuario
        FOREIGN KEY (firmado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_fc_estado
ON firmas_certificado (estado_firma_certificado_id, fecha_solicitud);

-- ============================================================
-- 10. SOLICITUDES DE FIRMA ELECTRÓNICA
-- ============================================================

CREATE TABLE solicitudes_firma_electronica (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    firma_certificado_id BIGINT UNSIGNED NOT NULL,

    solicitud_uuid CHAR(36) NOT NULL,

    estado VARCHAR(40) NOT NULL,

    iniciado_por_usuario_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    proveedor VARCHAR(120) NULL,

    certificado_alias VARCHAR(190) NULL,

    -- NO guardar contraseña ni PIN.
    requiere_password_en_tiempo_real BOOLEAN NOT NULL DEFAULT TRUE,

    resultado_json JSON NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_sfe_uuid UNIQUE (solicitud_uuid),

    CONSTRAINT fk_sfe_firma
        FOREIGN KEY (firma_certificado_id) REFERENCES firmas_certificado(id),
    CONSTRAINT fk_sfe_usuario
        FOREIGN KEY (iniciado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. VALIDACIÓN PÚBLICA
-- ============================================================

CREATE TABLE validaciones_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    certificado_emitido_id BIGINT UNSIGNED NOT NULL,
    tipo_validacion_certificado_id BIGINT UNSIGNED NOT NULL,

    codigo_publico VARCHAR(100) NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_activacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NULL,

    CONSTRAINT uq_validacion_cert_codigo UNIQUE (codigo_publico),

    CONSTRAINT fk_vc_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_vc_tipo
        FOREIGN KEY (tipo_validacion_certificado_id) REFERENCES tipos_validacion_certificado(id)
) ENGINE=InnoDB;

CREATE TABLE consultas_validacion_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    validacion_certificado_id BIGINT UNSIGNED NOT NULL,

    fecha_consulta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    resultado VARCHAR(60) NOT NULL,

    CONSTRAINT fk_cvc_validacion
        FOREIGN KEY (validacion_certificado_id) REFERENCES validaciones_certificado(id)
) ENGINE=InnoDB;

-- ============================================================
-- 12. REVOCACIONES / ANULACIONES
-- ============================================================

CREATE TABLE revocaciones_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    certificado_emitido_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NOT NULL,

    revocado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    fecha_revocacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    certificado_reemplazo_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_revocacion_certificado
        UNIQUE (certificado_emitido_id),

    CONSTRAINT fk_rc_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_rc_usuario
        FOREIGN KEY (revocado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_rc_reemplazo
        FOREIGN KEY (certificado_reemplazo_id) REFERENCES certificados_emitidos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 13. IMPORTACIÓN MASIVA / MAPEO EXCEL -> PDF
-- ============================================================

CREATE TABLE importaciones_certificados (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    lote_certificado_id BIGINT UNSIGNED NOT NULL,

    archivo_excel_id BIGINT UNSIGNED NOT NULL,

    columna_identificacion VARCHAR(100) NULL,
    columna_nombre_archivo VARCHAR(100) NULL,
    columna_correo VARCHAR(100) NULL,

    total_filas INT UNSIGNED NOT NULL DEFAULT 0,
    total_validas INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,

    procesada BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ic_lote UNIQUE (lote_certificado_id),

    CONSTRAINT fk_ic_lote
        FOREIGN KEY (lote_certificado_id) REFERENCES lotes_certificados(id),
    CONSTRAINT fk_ic_excel
        FOREIGN KEY (archivo_excel_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

CREATE TABLE importacion_certificado_detalles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    importacion_certificado_id BIGINT UNSIGNED NOT NULL,

    numero_fila INT UNSIGNED NOT NULL,

    identificacion VARCHAR(50) NULL,
    nombre_archivo VARCHAR(255) NULL,
    correo VARCHAR(190) NULL,

    persona_id BIGINT UNSIGNED NULL,

    valida BOOLEAN NOT NULL DEFAULT FALSE,
    procesada BOOLEAN NOT NULL DEFAULT FALSE,

    error_mensaje TEXT NULL,

    certificado_emitido_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_icd_fila
        UNIQUE (importacion_certificado_id, numero_fila),

    CONSTRAINT fk_icd_importacion
        FOREIGN KEY (importacion_certificado_id) REFERENCES importaciones_certificados(id),
    CONSTRAINT fk_icd_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_icd_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 14. HISTÓRICO DE ESTADOS
-- ============================================================

CREATE TABLE historial_estado_certificado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    certificado_emitido_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NULL,

    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hec_certificado
        FOREIGN KEY (certificado_emitido_id) REFERENCES certificados_emitidos(id),
    CONSTRAINT fk_hec_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_certificado(id),
    CONSTRAINT fk_hec_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_certificado(id),
    CONSTRAINT fk_hec_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 15. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_certificado
(codigo, nombre, descripcion)
VALUES
('ACADEMICO', 'Certificado académico', 'Certificado relacionado con procesos académicos'),
('CURSO_CORTO', 'Certificado de curso corto', 'Certificado por aprobación/completitud de curso'),
('CONGRESO', 'Certificado de congreso', 'Certificado de participación o aprobación en congreso'),
('TALLER', 'Certificado de taller', 'Certificado por taller'),
('PRACTICAS', 'Certificado de prácticas', 'Certificado de prácticas preprofesionales'),
('VINCULACION', 'Certificado de vinculación', 'Certificado de vinculación con la sociedad'),
('TITULACION', 'Certificado de titulación', 'Certificado asociado a titulación'),
('OTRO', 'Otro certificado', 'Otro tipo de certificado');

INSERT INTO estados_certificado
(codigo, nombre, es_emitido, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('GENERADO', 'Generado', FALSE, FALSE),
('PENDIENTE_FIRMA', 'Pendiente de firma', FALSE, FALSE),
('FIRMADO', 'Firmado', FALSE, FALSE),
('EMITIDO', 'Emitido', TRUE, TRUE),
('REVOCADO', 'Revocado', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE),
('ERROR', 'Error', FALSE, FALSE);

INSERT INTO tipos_firma_certificado
(codigo, nombre, requiere_interaccion_usuario)
VALUES
('SIN_FIRMA', 'Sin firma', FALSE),
('IMAGEN_FIRMA', 'Firma digitalizada / imagen', FALSE),
('FIRMA_ELECTRONICA', 'Firma electrónica', TRUE),
('PROVEEDOR_EXTERNO', 'Proveedor externo de firma', TRUE);

INSERT INTO estados_firma_certificado
(codigo, nombre, es_firmado, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('SOLICITADA', 'Solicitada', FALSE, FALSE),
('FIRMADA', 'Firmada', TRUE, TRUE),
('RECHAZADA', 'Rechazada', FALSE, TRUE),
('ERROR', 'Error', FALSE, FALSE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO tipos_origen_certificado
(codigo, nombre)
VALUES
('INDIVIDUAL', 'Generación individual'),
('MASIVO_CARRERA', 'Masivo por carrera'),
('MASIVO_ASIGNATURA', 'Masivo por asignatura'),
('MASIVO_CURSO', 'Masivo por curso/actividad'),
('EXCEL', 'Importación desde Excel'),
('MODULO', 'Generado desde otro módulo');

INSERT INTO tipos_destinatario_certificado
(codigo, nombre)
VALUES
('ESTUDIANTE', 'Estudiante'),
('DOCENTE', 'Docente'),
('ADMINISTRATIVO', 'Administrativo'),
('EXTERNO', 'Persona externa'),
('OTRO', 'Otro');

INSERT INTO tipos_validacion_certificado
(codigo, nombre)
VALUES
('QR_PUBLICO', 'Validación pública mediante QR'),
('CODIGO_PUBLICO', 'Validación por código'),
('HASH', 'Validación por hash');

-- Variables base
INSERT INTO variables_certificado
(codigo, nombre, tipo_dato, origen_dato, ejemplo)
VALUES
('NOMBRES', 'Nombres', 'TEXTO', 'PERSONA', 'ERICK EMANUEL'),
('APELLIDOS', 'Apellidos', 'TEXTO', 'PERSONA', 'MEJIA GUALLE'),
('NOMBRE_COMPLETO', 'Nombre completo', 'TEXTO', 'PERSONA', 'ERICK EMANUEL MEJIA GUALLE'),
('CEDULA', 'Identificación', 'TEXTO', 'PERSONA', '1721130217'),
('CARRERA', 'Carrera', 'TEXTO', 'ACADEMICO', 'TÉCNICO SUPERIOR EN MARKETING DIGITAL'),
('ASIGNATURA', 'Asignatura', 'TEXTO', 'ACADEMICO', 'Administración Tributaria'),
('CURSO', 'Curso / actividad', 'TEXTO', 'ACTIVIDAD', 'Curso de Excel'),
('HORAS', 'Horas', 'DECIMAL', 'ACTIVIDAD', '40'),
('NOTA', 'Nota', 'DECIMAL', 'ACTIVIDAD', '90'),
('FECHA_INICIO', 'Fecha inicio', 'FECHA', 'ACTIVIDAD', '2026-09-01'),
('FECHA_FIN', 'Fecha fin', 'FECHA', 'ACTIVIDAD', '2026-09-30'),
('FECHA_EMISION', 'Fecha de emisión', 'FECHA', 'CERTIFICADO', '2026-10-01'),
('NUMERO_CERTIFICADO', 'Número de certificado', 'TEXTO', 'CERTIFICADO', 'CERT-2026-000001'),
('QR_URL', 'URL de validación QR', 'TEXTO', 'CERTIFICADO', 'https://...'),
('CODIGO_VALIDACION', 'Código de validación', 'TEXTO', 'CERTIFICADO', 'ABC123XYZ');

-- ============================================================
-- 16. REGLAS DE APLICACIÓN
-- ============================================================
--
-- PLANTILLAS:
-- - Una plantilla puede definirse con archivo base o HTML/CSS.
-- - Las variables se reemplazan al generar el certificado.
-- - El sistema guarda snapshot en certificado_valores_variables.
--
-- GENERACIÓN INDIVIDUAL:
-- - Seleccionar persona/estudiante.
-- - Seleccionar tipo/plantilla.
-- - Validar elegibilidad.
-- - Generar PDF.
--
-- GENERACIÓN MASIVA:
-- - Por carrera.
-- - Por asignatura.
-- - Por curso/actividad.
-- - Por archivo Excel.
--
-- EXCEL:
-- Se recomienda usar IDENTIFICACIÓN como llave principal.
-- El nombre del PDF NO debería ser la única llave.
-- Flujo:
--   Excel:
--      identificacion | nombre_archivo | correo ...
--   Sistema:
--      identifica persona por cédula/pasaporte
--      valida correspondencia
--      genera/asocia certificado
--
-- Esto es más robusto que comparar solo "nombre del Excel" vs "nombre del PDF".
--
-- CURSOS CORTOS:
-- - actividades_certificables define duración y nota mínima.
-- - participante puede tener nota/horas.
-- - elegible_certificado=TRUE cuando cumple reglas.
--
-- FIRMA ELECTRÓNICA:
-- - No guardar contraseña/PIN.
-- - El usuario firmante introduce la contraseña en el momento de firmar.
-- - La contraseña vive únicamente en memoria durante la operación.
-- - solicitudes_firma_electronica guarda solo estado, alias y resultado.
-- - Si se integra Firmador EC/proveedor compatible, hacerlo mediante
--   servicio separado y seguro.
--
-- MÚLTIPLES FIRMAS:
-- - plantilla_certificado_firmantes define orden.
-- - firmas_certificado controla cada firma.
-- - El PDF final se considera emitible cuando todas las firmas obligatorias
--   estén completadas.
--
-- QR:
-- - token_validacion es aleatorio/no predecible.
-- - validaciones_certificado.codigo_publico permite consulta pública.
-- - La página pública debe mostrar solo datos mínimos:
--      estado del certificado
--      nombre
--      tipo
--      fecha
--      institución
--      número de certificado
--
-- REVOCACIÓN:
-- - Un certificado emitido no se edita.
-- - Si existe error:
--      revocar
--      emitir nueva versión
--      enlazar certificado_origen_id / certificado_reemplazo_id.
--
-- EXPEDIENTE:
-- - Certificados académicos del estudiante pueden vincularse a
--   documentos_expediente.
--
-- ============================================================
-- FIN 016_certificados.sql
-- ============================================================
