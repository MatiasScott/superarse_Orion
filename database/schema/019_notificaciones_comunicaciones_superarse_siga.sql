-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 019_notificaciones_comunicaciones.sql
-- Requiere bloques 001-018
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Centralizar notificaciones institucionales
--   - Notificaciones internas SIGA
--   - Correo electrónico
--   - Microsoft / Teams / Graph
--   - WhatsApp
--   - Plantillas y variables
--   - Preferencias de usuario
--   - Destinatarios individuales, grupos y audiencias
--   - Cola de envíos, reintentos y errores
--   - Campañas y envíos masivos
--   - Históricos de entrega, lectura, apertura y respuesta
--   - Integración con el motor de automatización
--
-- PRINCIPIOS:
--   - Ningún módulo envía directamente mensajes.
--   - Todos generan solicitudes de notificación.
--   - La entrega real se procesa mediante workers/colas.
--   - Las credenciales se mantienen fuera de la base en secretos.
--   - Todo envío debe ser auditable e idempotente.
--   - Las preferencias de usuario deben respetarse salvo comunicaciones
--     obligatorias institucionales.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE CANALES
-- ============================================================

CREATE TABLE canales_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    permite_asunto BOOLEAN NOT NULL DEFAULT FALSE,
    permite_html BOOLEAN NOT NULL DEFAULT FALSE,
    permite_adjuntos BOOLEAN NOT NULL DEFAULT FALSE,
    permite_respuesta BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_canal_notificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    enviada BOOLEAN NOT NULL DEFAULT FALSE,
    entregada BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_notificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_destinatario_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    enviado BOOLEAN NOT NULL DEFAULT FALSE,
    entregado BOOLEAN NOT NULL DEFAULT FALSE,
    leido BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_dest_notif_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT FALSE,
    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_notificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_destinatario_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_destinatario_notificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_campana_comunicacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    permite_envio BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_campana_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_evento_entrega_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_evento_entrega_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CONFIGURACIONES DE PROVEEDORES / CANALES
-- ============================================================

CREATE TABLE proveedores_comunicacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    canal_notificacion_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    endpoint_base VARCHAR(255) NULL,

    credencial_secret_ref VARCHAR(190) NULL,

    configuracion_json JSON NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    ultima_verificacion_at DATETIME NULL,
    ultimo_error TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_proveedor_comunicacion_codigo UNIQUE (codigo),

    CONSTRAINT fk_pc_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id)
) ENGINE=InnoDB;

CREATE INDEX idx_pc_canal_principal
ON proveedores_comunicacion (canal_notificacion_id, es_principal, activo);

-- ============================================================
-- 03. PLANTILLAS DE NOTIFICACIÓN
-- ============================================================

CREATE TABLE plantillas_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    tipo_notificacion_id BIGINT UNSIGNED NOT NULL,
    canal_notificacion_id BIGINT UNSIGNED NOT NULL,

    asunto_plantilla VARCHAR(255) NULL,
    cuerpo_texto LONGTEXT NULL,
    cuerpo_html LONGTEXT NULL,

    idioma VARCHAR(10) NOT NULL DEFAULT 'es',

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    version_numero INT UNSIGNED NOT NULL DEFAULT 1,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_plantilla_notificacion_codigo_version
        UNIQUE (codigo, version_numero),

    CONSTRAINT fk_pn_tipo
        FOREIGN KEY (tipo_notificacion_id) REFERENCES tipos_notificacion(id),
    CONSTRAINT fk_pn_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id),
    CONSTRAINT fk_pn_usuario
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pn_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_pn_tipo_canal
ON plantillas_notificacion (tipo_notificacion_id, canal_notificacion_id, activa);

-- ============================================================
-- 04. VARIABLES DE PLANTILLA
-- ============================================================

CREATE TABLE variables_plantilla_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    origen_dato VARCHAR(100) NULL,
    descripcion VARCHAR(255) NULL,

    ejemplo VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_variable_plantilla_notif_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE plantilla_notificacion_variables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    plantilla_notificacion_id BIGINT UNSIGNED NOT NULL,
    variable_plantilla_notificacion_id BIGINT UNSIGNED NOT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_pnv
        UNIQUE (plantilla_notificacion_id, variable_plantilla_notificacion_id),

    CONSTRAINT fk_pnv_plantilla
        FOREIGN KEY (plantilla_notificacion_id) REFERENCES plantillas_notificacion(id),
    CONSTRAINT fk_pnv_variable
        FOREIGN KEY (variable_plantilla_notificacion_id) REFERENCES variables_plantilla_notificacion(id)
) ENGINE=InnoDB;

-- ============================================================
-- 05. PREFERENCIAS DE NOTIFICACIÓN
-- ============================================================

CREATE TABLE preferencias_notificacion_usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,
    tipo_notificacion_id BIGINT UNSIGNED NOT NULL,
    canal_notificacion_id BIGINT UNSIGNED NOT NULL,

    permitido BOOLEAN NOT NULL DEFAULT TRUE,

    horario_desde TIME NULL,
    horario_hasta TIME NULL,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_preferencia_notif_usuario
        UNIQUE (usuario_id, tipo_notificacion_id, canal_notificacion_id),

    CONSTRAINT fk_pnu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_pnu_tipo
        FOREIGN KEY (tipo_notificacion_id) REFERENCES tipos_notificacion(id),
    CONSTRAINT fk_pnu_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id)
) ENGINE=InnoDB;

-- Las notificaciones obligatorias ignoran permitido=FALSE.

-- ============================================================
-- 06. GRUPOS DE NOTIFICACIÓN
-- ============================================================

CREATE TABLE grupos_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,

    dinamico BOOLEAN NOT NULL DEFAULT FALSE,
    consulta_logica_json JSON NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_grupo_notificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE grupo_notificacion_usuarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    grupo_notificacion_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_gnu
        UNIQUE (grupo_notificacion_id, usuario_id),

    CONSTRAINT fk_gnu_grupo
        FOREIGN KEY (grupo_notificacion_id) REFERENCES grupos_notificacion(id),
    CONSTRAINT fk_gnu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 07. NOTIFICACIONES
-- ============================================================

CREATE TABLE notificaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_notificacion_id BIGINT UNSIGNED NOT NULL,
    canal_notificacion_id BIGINT UNSIGNED NOT NULL,
    estado_notificacion_id BIGINT UNSIGNED NOT NULL,

    plantilla_notificacion_id BIGINT UNSIGNED NULL,

    workflow_ejecucion_id BIGINT UNSIGNED NULL,

    entidad_origen VARCHAR(80) NULL,
    entidad_origen_id BIGINT UNSIGNED NULL,

    idempotency_key VARCHAR(190) NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    asunto VARCHAR(255) NULL,
    cuerpo_texto LONGTEXT NULL,
    cuerpo_html LONGTEXT NULL,

    programada_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    enviada_at DATETIME NULL,
    finalizada_at DATETIME NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    proximo_reintento_at DATETIME NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_notificacion_idempotency UNIQUE (idempotency_key),

    CONSTRAINT fk_notif_tipo
        FOREIGN KEY (tipo_notificacion_id) REFERENCES tipos_notificacion(id),
    CONSTRAINT fk_notif_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id),
    CONSTRAINT fk_notif_estado
        FOREIGN KEY (estado_notificacion_id) REFERENCES estados_notificacion(id),
    CONSTRAINT fk_notif_plantilla
        FOREIGN KEY (plantilla_notificacion_id) REFERENCES plantillas_notificacion(id),
    CONSTRAINT fk_notif_workflow
        FOREIGN KEY (workflow_ejecucion_id) REFERENCES workflow_ejecuciones(id),
    CONSTRAINT fk_notif_usuario
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_notif_intentos CHECK (
        max_intentos >= 1
    )
) ENGINE=InnoDB;

CREATE INDEX idx_notificaciones_cola
ON notificaciones
(estado_notificacion_id, prioridad, programada_at, proximo_reintento_at);

-- ============================================================
-- 08. DESTINATARIOS DE NOTIFICACIÓN
-- ============================================================

CREATE TABLE notificacion_destinatarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_id BIGINT UNSIGNED NOT NULL,
    tipo_destinatario_notificacion_id BIGINT UNSIGNED NOT NULL,
    estado_destinatario_notificacion_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    persona_id BIGINT UNSIGNED NULL,
    grupo_notificacion_id BIGINT UNSIGNED NULL,

    direccion_destino VARCHAR(255) NULL,

    nombre_destinatario VARCHAR(220) NULL,

    enviado_at DATETIME NULL,
    entregado_at DATETIME NULL,
    leido_at DATETIME NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    provider_message_id VARCHAR(190) NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_nd_notificacion
        FOREIGN KEY (notificacion_id) REFERENCES notificaciones(id),
    CONSTRAINT fk_nd_tipo_destino
        FOREIGN KEY (tipo_destinatario_notificacion_id) REFERENCES tipos_destinatario_notificacion(id),
    CONSTRAINT fk_nd_estado
        FOREIGN KEY (estado_destinatario_notificacion_id) REFERENCES estados_destinatario_notificacion(id),
    CONSTRAINT fk_nd_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_nd_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_nd_grupo
        FOREIGN KEY (grupo_notificacion_id) REFERENCES grupos_notificacion(id)
) ENGINE=InnoDB;

CREATE INDEX idx_nd_estado
ON notificacion_destinatarios (estado_destinatario_notificacion_id, enviado_at);

-- ============================================================
-- 09. ADJUNTOS DE NOTIFICACIONES
-- ============================================================

CREATE TABLE notificacion_adjuntos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_id BIGINT UNSIGNED NOT NULL,
    archivo_id BIGINT UNSIGNED NOT NULL,

    nombre_visible VARCHAR(255) NULL,

    inline_content BOOLEAN NOT NULL DEFAULT FALSE,
    cid VARCHAR(190) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_notificacion_adjunto
        UNIQUE (notificacion_id, archivo_id),

    CONSTRAINT fk_na_notificacion
        FOREIGN KEY (notificacion_id) REFERENCES notificaciones(id),
    CONSTRAINT fk_na_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 10. SNAPSHOT DE VARIABLES DE LA NOTIFICACIÓN
-- ============================================================

CREATE TABLE notificacion_variables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_id BIGINT UNSIGNED NOT NULL,
    variable_codigo VARCHAR(80) NOT NULL,
    valor TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_notificacion_variable
        UNIQUE (notificacion_id, variable_codigo),

    CONSTRAINT fk_nv_notificacion
        FOREIGN KEY (notificacion_id) REFERENCES notificaciones(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. EVENTOS DE ENTREGA / TRACKING
-- ============================================================

CREATE TABLE eventos_entrega_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_destinatario_id BIGINT UNSIGNED NOT NULL,
    tipo_evento_entrega_notificacion_id BIGINT UNSIGNED NOT NULL,

    provider_event_id VARCHAR(190) NULL,

    payload_json JSON NULL,

    event_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_een_destinatario
        FOREIGN KEY (notificacion_destinatario_id) REFERENCES notificacion_destinatarios(id),
    CONSTRAINT fk_een_tipo
        FOREIGN KEY (tipo_evento_entrega_notificacion_id) REFERENCES tipos_evento_entrega_notificacion(id)
) ENGINE=InnoDB;

CREATE INDEX idx_een_destinatario_fecha
ON eventos_entrega_notificacion (notificacion_destinatario_id, event_at);

-- ============================================================
-- 12. NOTIFICACIONES INTERNAS SIGA
-- ============================================================

CREATE TABLE bandeja_notificaciones_usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_destinatario_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,

    titulo VARCHAR(255) NOT NULL,
    resumen VARCHAR(500) NULL,

    url_destino VARCHAR(500) NULL,

    leida BOOLEAN NOT NULL DEFAULT FALSE,
    leida_at DATETIME NULL,

    archivada BOOLEAN NOT NULL DEFAULT FALSE,
    archivada_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_bnu_destinatario UNIQUE (notificacion_destinatario_id),

    CONSTRAINT fk_bnu_destinatario
        FOREIGN KEY (notificacion_destinatario_id) REFERENCES notificacion_destinatarios(id),
    CONSTRAINT fk_bnu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_bnu_usuario_leida
ON bandeja_notificaciones_usuario (usuario_id, leida, created_at);

-- ============================================================
-- 13. RESPUESTAS / INTERACCIONES
-- ============================================================

CREATE TABLE respuestas_notificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_destinatario_id BIGINT UNSIGNED NOT NULL,

    canal_origen VARCHAR(40) NOT NULL,

    mensaje TEXT NULL,
    archivo_id BIGINT UNSIGNED NULL,

    provider_message_id VARCHAR(190) NULL,

    recibido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    procesada BOOLEAN NOT NULL DEFAULT FALSE,
    procesada_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rn_destinatario
        FOREIGN KEY (notificacion_destinatario_id) REFERENCES notificacion_destinatarios(id),
    CONSTRAINT fk_rn_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

CREATE INDEX idx_rn_pendientes
ON respuestas_notificacion (procesada, recibido_at);

-- ============================================================
-- 14. CAMPAÑAS
-- ============================================================

CREATE TABLE campanas_comunicacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,

    estado_campana_comunicacion_id BIGINT UNSIGNED NOT NULL,

    tipo_notificacion_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,

    descripcion TEXT NULL,

    creada_por_usuario_id BIGINT UNSIGNED NULL,
    aprobada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_aprobacion DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_campana_comunicacion_codigo UNIQUE (codigo),

    CONSTRAINT fk_cc_estado
        FOREIGN KEY (estado_campana_comunicacion_id) REFERENCES estados_campana_comunicacion(id),
    CONSTRAINT fk_cc_tipo
        FOREIGN KEY (tipo_notificacion_id) REFERENCES tipos_notificacion(id),
    CONSTRAINT fk_cc_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_cc_aprobada_por
        FOREIGN KEY (aprobada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_cc_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

-- ============================================================
-- 15. AUDIENCIAS DE CAMPAÑA
-- ============================================================

CREATE TABLE campana_audiencias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    campana_comunicacion_id BIGINT UNSIGNED NOT NULL,

    audiencia_tipo VARCHAR(60) NOT NULL,

    grupo_notificacion_id BIGINT UNSIGNED NULL,
    carrera_id BIGINT UNSIGNED NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,
    sede_id BIGINT UNSIGNED NULL,

    criterio_json JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ca_campana
        FOREIGN KEY (campana_comunicacion_id) REFERENCES campanas_comunicacion(id),
    CONSTRAINT fk_ca_grupo
        FOREIGN KEY (grupo_notificacion_id) REFERENCES grupos_notificacion(id),
    CONSTRAINT fk_ca_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_ca_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_ca_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id)
) ENGINE=InnoDB;

-- ============================================================
-- 16. PIEZAS / MENSAJES DE CAMPAÑA
-- ============================================================

CREATE TABLE campana_mensajes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    campana_comunicacion_id BIGINT UNSIGNED NOT NULL,
    canal_notificacion_id BIGINT UNSIGNED NOT NULL,
    plantilla_notificacion_id BIGINT UNSIGNED NULL,

    asunto VARCHAR(255) NULL,
    cuerpo_texto LONGTEXT NULL,
    cuerpo_html LONGTEXT NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_campana_mensaje_canal
        UNIQUE (campana_comunicacion_id, canal_notificacion_id),

    CONSTRAINT fk_cm_campana
        FOREIGN KEY (campana_comunicacion_id) REFERENCES campanas_comunicacion(id),
    CONSTRAINT fk_cm_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id),
    CONSTRAINT fk_cm_plantilla
        FOREIGN KEY (plantilla_notificacion_id) REFERENCES plantillas_notificacion(id)
) ENGINE=InnoDB;

-- ============================================================
-- 17. EJECUCIONES DE CAMPAÑA
-- ============================================================

CREATE TABLE campana_ejecuciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    campana_comunicacion_id BIGINT UNSIGNED NOT NULL,

    execution_uuid CHAR(36) NOT NULL,

    total_destinatarios INT UNSIGNED NOT NULL DEFAULT 0,
    total_generados INT UNSIGNED NOT NULL DEFAULT 0,
    total_enviados INT UNSIGNED NOT NULL DEFAULT 0,
    total_entregados INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE',

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_campana_execution_uuid UNIQUE (execution_uuid),

    CONSTRAINT fk_ce_campana
        FOREIGN KEY (campana_comunicacion_id) REFERENCES campanas_comunicacion(id)
) ENGINE=InnoDB;

-- ============================================================
-- 18. RELACIÓN CAMPAÑA -> NOTIFICACIONES
-- ============================================================

CREATE TABLE campana_notificaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    campana_ejecucion_id BIGINT UNSIGNED NOT NULL,
    notificacion_id BIGINT UNSIGNED NOT NULL,

    CONSTRAINT uq_campana_notificacion
        UNIQUE (campana_ejecucion_id, notificacion_id),

    CONSTRAINT fk_cn_ejecucion
        FOREIGN KEY (campana_ejecucion_id) REFERENCES campana_ejecuciones(id),
    CONSTRAINT fk_cn_notificacion
        FOREIGN KEY (notificacion_id) REFERENCES notificaciones(id)
) ENGINE=InnoDB;

-- ============================================================
-- 19. HISTÓRICO DE CAMBIOS
-- ============================================================

CREATE TABLE historial_notificaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notificacion_id BIGINT UNSIGNED NOT NULL,

    accion VARCHAR(80) NOT NULL,
    detalle TEXT NULL,
    datos_json JSON NULL,

    usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hn_notificacion
        FOREIGN KEY (notificacion_id) REFERENCES notificaciones(id),
    CONSTRAINT fk_hn_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hn_notificacion_fecha
ON historial_notificaciones (notificacion_id, created_at);

-- ============================================================
-- 20. MÉTRICAS DE COMUNICACIÓN
-- ============================================================

CREATE TABLE metricas_comunicacion_diarias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    canal_notificacion_id BIGINT UNSIGNED NOT NULL,
    fecha DATE NOT NULL,

    total_generadas INT UNSIGNED NOT NULL DEFAULT 0,
    total_enviadas INT UNSIGNED NOT NULL DEFAULT 0,
    total_entregadas INT UNSIGNED NOT NULL DEFAULT 0,
    total_leidas INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_mcd_canal_fecha
        UNIQUE (canal_notificacion_id, fecha),

    CONSTRAINT fk_mcd_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id)
) ENGINE=InnoDB;

-- ============================================================
-- 21. DATOS INICIALES
-- ============================================================

INSERT INTO canales_notificacion
(codigo, nombre, permite_asunto, permite_html, permite_adjuntos, permite_respuesta)
VALUES
('SISTEMA', 'Notificación interna SIGA', TRUE, TRUE, TRUE, FALSE),
('EMAIL', 'Correo electrónico', TRUE, TRUE, TRUE, TRUE),
('WHATSAPP', 'WhatsApp', FALSE, FALSE, TRUE, TRUE),
('MICROSOFT', 'Microsoft / Teams / Graph', TRUE, TRUE, TRUE, TRUE);

INSERT INTO estados_notificacion
(codigo, nombre, es_final, enviada, entregada)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE, FALSE),
('PENDIENTE', 'Pendiente', FALSE, FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE, FALSE),
('ENVIADA', 'Enviada', FALSE, TRUE, FALSE),
('ENTREGADA', 'Entregada', TRUE, TRUE, TRUE),
('PARCIAL', 'Parcialmente entregada', FALSE, TRUE, FALSE),
('ERROR', 'Error', FALSE, FALSE, FALSE),
('CANCELADA', 'Cancelada', TRUE, FALSE, FALSE);

INSERT INTO estados_destinatario_notificacion
(codigo, nombre, es_final, enviado, entregado, leido)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE, FALSE, FALSE),
('ENVIADO', 'Enviado', FALSE, TRUE, FALSE, FALSE),
('ENTREGADO', 'Entregado', FALSE, TRUE, TRUE, FALSE),
('LEIDO', 'Leído', TRUE, TRUE, TRUE, TRUE),
('RESPONDIDO', 'Respondido', TRUE, TRUE, TRUE, TRUE),
('ERROR', 'Error', FALSE, FALSE, FALSE, FALSE),
('CANCELADO', 'Cancelado', TRUE, FALSE, FALSE, FALSE);

INSERT INTO tipos_notificacion
(codigo, nombre, descripcion, obligatoria, prioridad)
VALUES
('SISTEMA_GENERAL', 'Notificación general del sistema', 'Notificación general', FALSE, 100),
('ACADEMICA', 'Notificación académica', 'Eventos académicos', TRUE, 50),
('FINANCIERA', 'Notificación financiera', 'Pagos, mora, habilitación', TRUE, 30),
('MATRICULA', 'Notificación de matrícula', 'Matrícula, renovación y secciones', TRUE, 30),
('ASISTENCIA', 'Notificación de asistencia', 'Alertas de inasistencia', TRUE, 30),
('TITULACION', 'Notificación de titulación', 'Estados y requisitos de titulación', TRUE, 40),
('BECA', 'Notificación de beca', 'Estados y renovaciones de beca', TRUE, 40),
('ENCUESTA', 'Notificación de encuesta', 'Encuestas obligatorias o informativas', FALSE, 60),
('MICROSOFT', 'Notificación Microsoft', 'Creación/desactivación de cuenta institucional', TRUE, 20),
('MOODLE', 'Notificación Moodle', 'Eventos de plataforma académica', TRUE, 40),
('CERTIFICADO', 'Notificación de certificado', 'Emisión o revocación de certificados', FALSE, 60),
('CAMPAÑA', 'Campaña institucional', 'Campañas masivas', FALSE, 100);

INSERT INTO tipos_destinatario_notificacion
(codigo, nombre)
VALUES
('USUARIO', 'Usuario SIGA'),
('PERSONA', 'Persona'),
('GRUPO', 'Grupo de notificación'),
('EXTERNO', 'Destinatario externo');

INSERT INTO estados_campana_comunicacion
(codigo, nombre, permite_envio, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('PENDIENTE_APROBACION', 'Pendiente de aprobación', FALSE, FALSE),
('APROBADA', 'Aprobada', TRUE, FALSE),
('EN_EJECUCION', 'En ejecución', TRUE, FALSE),
('FINALIZADA', 'Finalizada', FALSE, TRUE),
('PAUSADA', 'Pausada', FALSE, FALSE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO tipos_evento_entrega_notificacion
(codigo, nombre)
VALUES
('GENERADA', 'Generada'),
('ENVIADA', 'Enviada'),
('ENTREGADA', 'Entregada'),
('ABIERTA', 'Abierta'),
('LEIDA', 'Leída'),
('CLICK', 'Clic'),
('RESPUESTA', 'Respuesta'),
('REBOTADA', 'Rebotada'),
('ERROR', 'Error');

-- ============================================================
-- 22. VARIABLES BASE
-- ============================================================

INSERT INTO variables_plantilla_notificacion
(codigo, nombre, origen_dato, ejemplo)
VALUES
('NOMBRE_COMPLETO', 'Nombre completo', 'PERSONA', 'ERICK EMANUEL MEJIA GUALLE'),
('NOMBRES', 'Nombres', 'PERSONA', 'ERICK EMANUEL'),
('APELLIDOS', 'Apellidos', 'PERSONA', 'MEJIA GUALLE'),
('CEDULA', 'Identificación', 'PERSONA', '1721130217'),
('CORREO_INSTITUCIONAL', 'Correo institucional', 'USUARIO', 'erick.mejia@superarse.edu.ec'),
('CARRERA', 'Carrera', 'ACADEMICO', 'TÉCNICO SUPERIOR EN MARKETING DIGITAL'),
('PERIODO', 'Período académico', 'ACADEMICO', 'PAO MAYO - OCTUBRE 2026'),
('ASIGNATURA', 'Asignatura', 'ACADEMICO', 'Administración Tributaria'),
('DOCENTE', 'Docente', 'ACADEMICO', 'NOMBRE DOCENTE'),
('CUOTA', 'Número de cuota', 'FINANCIERO', '3'),
('MONTO', 'Monto', 'FINANCIERO', '200.00'),
('SALDO', 'Saldo', 'FINANCIERO', '40.00'),
('FECHA_VENCIMIENTO', 'Fecha de vencimiento', 'FINANCIERO', '2026-09-10'),
('URL_SIGA', 'URL SIGA', 'SISTEMA', 'https://siga.superarse.edu.ec'),
('URL_MOODLE', 'URL Moodle', 'SISTEMA', 'https://aulasists.superarse.edu.ec'),
('NUMERO_SOLICITUD', 'Número de solicitud', 'SISTEMA', 'SOL-2026-000001');

-- ============================================================
-- 23. GRUPOS BASE
-- ============================================================

INSERT INTO grupos_notificacion
(codigo, nombre, descripcion, dinamico)
VALUES
('COORDINACION_ACADEMICA', 'Coordinación Académica', 'Usuarios con rol de coordinación académica', TRUE),
('FINANCIERO', 'Financiero', 'Equipo financiero', TRUE),
('TICS', 'TICs', 'Equipo TIC', TRUE),
('SECRETARIA', 'Secretaría General', 'Equipo de Secretaría', TRUE),
('TITULACION', 'Titulación', 'Comisión / equipo de Titulación', TRUE),
('BIENESTAR', 'Bienestar', 'Equipo de Bienestar Estudiantil', TRUE);

-- ============================================================
-- 24. PROVEEDORES BASE
-- ============================================================

INSERT INTO proveedores_comunicacion
(canal_notificacion_id, codigo, nombre, credencial_secret_ref, es_principal)
SELECT id, 'SIGA_INTERNO', 'Bandeja interna SIGA', NULL, TRUE
FROM canales_notificacion WHERE codigo='SISTEMA';

INSERT INTO proveedores_comunicacion
(canal_notificacion_id, codigo, nombre, credencial_secret_ref, es_principal)
SELECT id, 'MICROSOFT_GRAPH_EMAIL', 'Microsoft Graph - Email', 'MICROSOFT_GRAPH_SECRET', TRUE
FROM canales_notificacion WHERE codigo='EMAIL';

INSERT INTO proveedores_comunicacion
(canal_notificacion_id, codigo, nombre, credencial_secret_ref, es_principal)
SELECT id, 'MICROSOFT_GRAPH', 'Microsoft Graph / Teams', 'MICROSOFT_GRAPH_SECRET', TRUE
FROM canales_notificacion WHERE codigo='MICROSOFT';

INSERT INTO proveedores_comunicacion
(canal_notificacion_id, codigo, nombre, credencial_secret_ref, es_principal)
SELECT id, 'WHATSAPP_PROVIDER', 'WhatsApp Business Provider', 'WHATSAPP_API_SECRET', TRUE
FROM canales_notificacion WHERE codigo='WHATSAPP';

-- ============================================================
-- 25. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ARQUITECTURA:
--
-- MÓDULO / WORKFLOW
--      ↓
-- SOLICITUD DE NOTIFICACIÓN
--      ↓
-- notificaciones
--      ↓
-- destinatarios
--      ↓
-- worker_notifications
--      ↓
-- proveedor
--      ↓
-- entrega / error / respuesta
--
-- ------------------------------------------------------------
-- NINGÚN MÓDULO ENVÍA DIRECTAMENTE
-- ------------------------------------------------------------
-- Ejemplo:
--
-- Pago aprobado:
--   FinancieroService
--      -> evento PAGO_APROBADO
--      -> workflow
--      -> crear notificación financiera
--
-- ------------------------------------------------------------
-- CANALES
-- ------------------------------------------------------------
-- SISTEMA:
--   bandeja interna SIGA.
--
-- EMAIL:
--   Microsoft Graph u otro proveedor.
--
-- MICROSOFT:
--   Teams / Graph cuando corresponda.
--
-- WHATSAPP:
--   API Business / proveedor aprobado.
--
-- ------------------------------------------------------------
-- PREFERENCIAS
-- ------------------------------------------------------------
-- Si tipo_notificacion.obligatoria = TRUE:
--   ignorar preferencia de opt-out.
--
-- Si no es obligatoria:
--   respetar preferencias_notificacion_usuario.
--
-- ------------------------------------------------------------
-- IDEMPOTENCIA
-- ------------------------------------------------------------
-- Ejemplo:
--   PAGO_APROBADO:123:EMAIL
--
-- evita enviar dos correos si el evento se procesa dos veces.
--
-- ------------------------------------------------------------
-- ADJUNTOS
-- ------------------------------------------------------------
-- notificacion_adjuntos puede adjuntar:
--   comprobantes
--   certificados
--   documentos
--   PDFs
--
-- inline_content + cid permite imágenes embebidas en correo.
--
-- ------------------------------------------------------------
-- CAMPAÑAS
-- ------------------------------------------------------------
-- Las campañas pueden dirigirse a:
--   grupos
--   carreras
--   sedes
--   períodos
--   criterios dinámicos.
--
-- Se genera una notificación por canal / lote lógico.
--
-- ------------------------------------------------------------
-- TRACKING
-- ------------------------------------------------------------
-- Depende de lo que permita el proveedor.
-- El sistema puede registrar:
--   enviada
--   entregada
--   abierta
--   leída
--   clic
--   respuesta
--   rebote
--
-- ------------------------------------------------------------
-- WHATSAPP
-- ------------------------------------------------------------
-- Debe respetar:
--   plantillas aprobadas
--   ventana de conversación
--   idioma
--   namespace/template cuando el proveedor lo requiera.
--
-- La credencial nunca se guarda en esta base.
--
-- ------------------------------------------------------------
-- MICROSOFT GRAPH
-- ------------------------------------------------------------
-- Correo institucional:
--   enviar desde cuentas autorizadas
--   registrar provider_message_id
--   conservar Message-Id si se requiere hilo.
--
-- ------------------------------------------------------------
-- NOTIFICACIONES INSTITUCIONALES IMPORTANTES
-- ------------------------------------------------------------
-- Ejemplos:
--
-- Financiero:
--   pago recibido
--   pago aprobado
--   pago rechazado
--   abono registrado
--   saldo pendiente
--   inicio de nueva cuota
--   mora / bloqueo
--
-- Académico:
--   matrícula confirmada
--   renovación
--   cambio de sección
--   supletorio
--   tercera matrícula
--
-- Asistencia:
--   acumulación de ausencias
--   umbral alcanzado
--
-- TIC:
--   cuenta institucional creada
--   licencia asignada
--   cuenta programada para desactivación
--
-- Titulación:
--   requisito actualizado
--   solicitud aprobada/rechazada
--   tutor asignado
--   defensa programada
--
-- Becas:
--   solicitud recibida
--   beca aprobada
--   renovación
--   pérdida
--
-- Encuestas:
--   encuesta obligatoria pendiente
--
-- Certificados:
--   certificado emitido
--   firma pendiente
--   certificado revocado
--
-- ------------------------------------------------------------
-- WORKERS SUGERIDOS
-- ------------------------------------------------------------
-- worker_notifications_internal
-- worker_notifications_email
-- worker_notifications_whatsapp
-- worker_notifications_microsoft
-- worker_notification_tracking
--
-- ============================================================
-- FIN 019_notificaciones_comunicaciones.sql
-- ============================================================
