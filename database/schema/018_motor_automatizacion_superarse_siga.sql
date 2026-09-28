-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 018_motor_automatizacion.sql
-- Requiere bloques 001-017
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Motor transversal de automatización / workflows
--   - Eventos, disparadores, condiciones, acciones y ejecuciones
--   - Colas, reintentos, cron y tareas diferidas
--   - Automatizaciones institucionales entre módulos
--   - Trazabilidad completa de cada workflow
--   - Integración con Microsoft, Moodle, Financiero, Matrícula,
--     Asistencia, Encuestas, Titulación, Becas y Notificaciones
--
-- PRINCIPIOS:
--   - La base guarda definición, estado y trazabilidad del workflow.
--   - La lógica ejecutable vive en servicios/workers de aplicación.
--   - No usar triggers complejos para procesos de negocio.
--   - Toda automatización crítica debe ser idempotente.
--   - Toda acción externa debe poder reintentarse sin duplicar efectos.
--   - Los workflows deben ser versionables y auditables.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DEL MOTOR
-- ============================================================

CREATE TABLE estados_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_ejecucion BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_disparador_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_disparador_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_condicion_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_condicion_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_accion_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    requiere_servicio_externo BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_accion_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_ejecucion_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_ejecucion_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_paso_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_paso_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_programacion_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_programacion_workflow_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE prioridades_workflow (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    valor SMALLINT UNSIGNED NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_prioridad_workflow_codigo UNIQUE (codigo),
    CONSTRAINT uq_prioridad_workflow_valor UNIQUE (valor)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CATÁLOGO DE EVENTOS DE DOMINIO
-- ============================================================

CREATE TABLE eventos_dominio_catalogo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    modulo VARCHAR(80) NOT NULL,
    descripcion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_evento_dominio_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 03. DEFINICIÓN DE WORKFLOWS
-- ============================================================

CREATE TABLE workflows (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    estado_workflow_id BIGINT UNSIGNED NOT NULL,

    modulo_principal VARCHAR(80) NULL,

    version_actual INT UNSIGNED NOT NULL DEFAULT 1,

    prioridad_workflow_id BIGINT UNSIGNED NULL,

    idempotente BOOLEAN NOT NULL DEFAULT TRUE,
    permite_reintento BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    publicado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_publicacion DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_workflow_codigo UNIQUE (codigo),

    CONSTRAINT fk_workflow_estado
        FOREIGN KEY (estado_workflow_id) REFERENCES estados_workflow(id),
    CONSTRAINT fk_workflow_prioridad
        FOREIGN KEY (prioridad_workflow_id) REFERENCES prioridades_workflow(id),
    CONSTRAINT fk_workflow_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_workflow_publicado_por
        FOREIGN KEY (publicado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_workflow_estado_activo
ON workflows (estado_workflow_id, activo);

-- ============================================================
-- 04. VERSIONES DE WORKFLOW
-- ============================================================

CREATE TABLE workflow_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_id BIGINT UNSIGNED NOT NULL,
    numero_version INT UNSIGNED NOT NULL,

    nombre_version VARCHAR(180) NULL,
    descripcion_cambio TEXT NULL,

    vigente_desde DATETIME NOT NULL,
    vigente_hasta DATETIME NULL,

    definicion_json JSON NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_workflow_version
        UNIQUE (workflow_id, numero_version),

    CONSTRAINT fk_wv_workflow
        FOREIGN KEY (workflow_id) REFERENCES workflows(id),
    CONSTRAINT fk_wv_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_wv_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 05. DISPARADORES
-- ============================================================

CREATE TABLE workflow_disparadores (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_version_id BIGINT UNSIGNED NOT NULL,
    tipo_disparador_workflow_id BIGINT UNSIGNED NOT NULL,

    evento_dominio_catalogo_id BIGINT UNSIGNED NULL,

    entidad VARCHAR(80) NULL,
    campo VARCHAR(120) NULL,

    expresion_cron VARCHAR(120) NULL,
    intervalo_segundos INT UNSIGNED NULL,

    configuracion_json JSON NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wd_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_wd_tipo
        FOREIGN KEY (tipo_disparador_workflow_id) REFERENCES tipos_disparador_workflow(id),
    CONSTRAINT fk_wd_evento
        FOREIGN KEY (evento_dominio_catalogo_id) REFERENCES eventos_dominio_catalogo(id)
) ENGINE=InnoDB;

CREATE INDEX idx_wd_evento
ON workflow_disparadores (evento_dominio_catalogo_id, activo);

-- ============================================================
-- 06. CONDICIONES
-- ============================================================

CREATE TABLE workflow_condiciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_version_id BIGINT UNSIGNED NOT NULL,
    tipo_condicion_workflow_id BIGINT UNSIGNED NOT NULL,

    grupo_condicion SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    orden_condicion SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    operador_logico VARCHAR(10) NOT NULL DEFAULT 'AND',

    campo_origen VARCHAR(190) NULL,
    operador VARCHAR(30) NULL,
    valor_comparacion TEXT NULL,

    expresion_json JSON NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wc_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_wc_tipo
        FOREIGN KEY (tipo_condicion_workflow_id) REFERENCES tipos_condicion_workflow(id),

    CONSTRAINT chk_wc_operador_logico CHECK (
        operador_logico IN ('AND', 'OR')
    )
) ENGINE=InnoDB;

CREATE INDEX idx_wc_version_orden
ON workflow_condiciones (workflow_version_id, grupo_condicion, orden_condicion);

-- ============================================================
-- 07. ACCIONES DEL WORKFLOW
-- ============================================================

CREATE TABLE workflow_acciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_version_id BIGINT UNSIGNED NOT NULL,
    tipo_accion_workflow_id BIGINT UNSIGNED NOT NULL,

    orden_ejecucion SMALLINT UNSIGNED NOT NULL,

    nombre VARCHAR(180) NOT NULL,

    configuracion_json JSON NULL,

    continuar_si_falla BOOLEAN NOT NULL DEFAULT FALSE,
    requiere_confirmacion_manual BOOLEAN NOT NULL DEFAULT FALSE,

    timeout_segundos INT UNSIGNED NULL,

    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_wa_orden
        UNIQUE (workflow_version_id, orden_ejecucion),

    CONSTRAINT fk_wa_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_wa_tipo
        FOREIGN KEY (tipo_accion_workflow_id) REFERENCES tipos_accion_workflow(id),

    CONSTRAINT chk_wa_max_intentos CHECK (
        max_intentos >= 1
    )
) ENGINE=InnoDB;

-- ============================================================
-- 08. PROGRAMACIONES / CRON
-- ============================================================

CREATE TABLE workflow_programaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_version_id BIGINT UNSIGNED NOT NULL,
    tipo_programacion_workflow_id BIGINT UNSIGNED NOT NULL,

    expresion_cron VARCHAR(120) NULL,
    intervalo_segundos INT UNSIGNED NULL,

    timezone VARCHAR(80) NOT NULL DEFAULT 'America/Guayaquil',

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,

    proxima_ejecucion_at DATETIME NULL,
    ultima_ejecucion_at DATETIME NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_wp_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_wp_tipo
        FOREIGN KEY (tipo_programacion_workflow_id) REFERENCES tipos_programacion_workflow(id),

    CONSTRAINT chk_wp_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_wp_proxima_ejecucion
ON workflow_programaciones (activa, proxima_ejecucion_at);

-- ============================================================
-- 09. EVENTOS DE DOMINIO GENERADOS
-- ============================================================

CREATE TABLE eventos_dominio (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    evento_dominio_catalogo_id BIGINT UNSIGNED NOT NULL,

    entidad VARCHAR(80) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    agregado_raiz VARCHAR(80) NULL,
    agregado_raiz_id BIGINT UNSIGNED NULL,

    payload_json JSON NULL,

    idempotency_key VARCHAR(190) NULL,

    generado_por_usuario_id BIGINT UNSIGNED NULL,

    generado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    procesado BOOLEAN NOT NULL DEFAULT FALSE,
    procesado_at DATETIME NULL,

    CONSTRAINT uq_evento_dominio_idempotency UNIQUE (idempotency_key),

    CONSTRAINT fk_ed_catalogo
        FOREIGN KEY (evento_dominio_catalogo_id) REFERENCES eventos_dominio_catalogo(id),
    CONSTRAINT fk_ed_usuario
        FOREIGN KEY (generado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ed_pendientes
ON eventos_dominio (procesado, generado_at);

-- ============================================================
-- 10. EJECUCIONES DE WORKFLOW
-- ============================================================

CREATE TABLE workflow_ejecuciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_id BIGINT UNSIGNED NOT NULL,
    workflow_version_id BIGINT UNSIGNED NOT NULL,
    estado_ejecucion_workflow_id BIGINT UNSIGNED NOT NULL,

    evento_dominio_id BIGINT UNSIGNED NULL,

    entidad VARCHAR(80) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    execution_uuid CHAR(36) NOT NULL,
    idempotency_key VARCHAR(190) NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    contexto_json JSON NULL,
    resultado_json JSON NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_we_execution_uuid UNIQUE (execution_uuid),
    CONSTRAINT uq_we_idempotency UNIQUE (idempotency_key),

    CONSTRAINT fk_we_workflow
        FOREIGN KEY (workflow_id) REFERENCES workflows(id),
    CONSTRAINT fk_we_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_we_estado
        FOREIGN KEY (estado_ejecucion_workflow_id) REFERENCES estados_ejecucion_workflow(id),
    CONSTRAINT fk_we_evento
        FOREIGN KEY (evento_dominio_id) REFERENCES eventos_dominio(id)
) ENGINE=InnoDB;

CREATE INDEX idx_we_cola
ON workflow_ejecuciones
(estado_ejecucion_workflow_id, prioridad, fecha_programada, proximo_reintento_at);

-- ============================================================
-- 11. PASOS DE EJECUCIÓN
-- ============================================================

CREATE TABLE workflow_ejecucion_pasos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_ejecucion_id BIGINT UNSIGNED NOT NULL,
    workflow_accion_id BIGINT UNSIGNED NOT NULL,
    estado_paso_workflow_id BIGINT UNSIGNED NOT NULL,

    orden_ejecucion SMALLINT UNSIGNED NOT NULL,

    intento_numero SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    entrada_json JSON NULL,
    salida_json JSON NULL,

    http_status SMALLINT UNSIGNED NULL,
    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_wep_ejecucion_accion
        UNIQUE (workflow_ejecucion_id, workflow_accion_id, intento_numero),

    CONSTRAINT fk_wep_ejecucion
        FOREIGN KEY (workflow_ejecucion_id) REFERENCES workflow_ejecuciones(id),
    CONSTRAINT fk_wep_accion
        FOREIGN KEY (workflow_accion_id) REFERENCES workflow_acciones(id),
    CONSTRAINT fk_wep_estado
        FOREIGN KEY (estado_paso_workflow_id) REFERENCES estados_paso_workflow(id)
) ENGINE=InnoDB;

CREATE INDEX idx_wep_reintentos
ON workflow_ejecucion_pasos (estado_paso_workflow_id, proximo_reintento_at);

-- ============================================================
-- 12. TAREAS DIFERIDAS
-- ============================================================

CREATE TABLE tareas_diferidas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,

    workflow_ejecucion_id BIGINT UNSIGNED NULL,

    entidad VARCHAR(80) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    ejecutar_at DATETIME NOT NULL,

    accion_codigo VARCHAR(100) NOT NULL,
    payload_json JSON NULL,

    ejecutada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_ejecucion DATETIME NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    proximo_reintento_at DATETIME NULL,

    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_td_workflow_ejecucion
        FOREIGN KEY (workflow_ejecucion_id) REFERENCES workflow_ejecuciones(id),

    CONSTRAINT chk_td_intentos CHECK (
        max_intentos >= 1
    )
) ENGINE=InnoDB;

CREATE INDEX idx_td_pendientes
ON tareas_diferidas (ejecutada, ejecutar_at, proximo_reintento_at);

-- ============================================================
-- 13. BLOQUEOS / LOCKS DISTRIBUIDOS
-- ============================================================

CREATE TABLE workflow_locks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    lock_key VARCHAR(190) NOT NULL,

    owner_uuid CHAR(36) NOT NULL,

    adquirido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_at DATETIME NOT NULL,

    released_at DATETIME NULL,

    CONSTRAINT uq_workflow_lock_key UNIQUE (lock_key),

    CONSTRAINT chk_workflow_lock_fechas CHECK (
        expira_at > adquirido_at
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. DEAD LETTER QUEUE
-- ============================================================

CREATE TABLE workflow_dead_letters (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_ejecucion_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NOT NULL,
    payload_json JSON NULL,

    movido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    resuelto BOOLEAN NOT NULL DEFAULT FALSE,
    resuelto_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_resolucion DATETIME NULL,
    observacion_resolucion TEXT NULL,

    CONSTRAINT uq_wdl_ejecucion UNIQUE (workflow_ejecucion_id),

    CONSTRAINT fk_wdl_ejecucion
        FOREIGN KEY (workflow_ejecucion_id) REFERENCES workflow_ejecuciones(id),
    CONSTRAINT fk_wdl_usuario
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_wdl_pendientes
ON workflow_dead_letters (resuelto, movido_at);

-- ============================================================
-- 15. AUDITORÍA DE CAMBIOS EN WORKFLOWS
-- ============================================================

CREATE TABLE historial_workflows (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_id BIGINT UNSIGNED NOT NULL,
    workflow_version_id BIGINT UNSIGNED NULL,

    accion VARCHAR(80) NOT NULL,
    detalle TEXT NULL,
    datos_json JSON NULL,

    usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hw_workflow
        FOREIGN KEY (workflow_id) REFERENCES workflows(id),
    CONSTRAINT fk_hw_version
        FOREIGN KEY (workflow_version_id) REFERENCES workflow_versiones(id),
    CONSTRAINT fk_hw_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hw_workflow_fecha
ON historial_workflows (workflow_id, created_at);

-- ============================================================
-- 16. NOTIFICACIONES DEL MOTOR
-- ============================================================

CREATE TABLE workflow_notificaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_ejecucion_id BIGINT UNSIGNED NULL,

    canal VARCHAR(30) NOT NULL, -- SISTEMA / EMAIL / WHATSAPP / MICROSOFT / OTRO

    destinatario_tipo VARCHAR(60) NOT NULL,
    destinatario_id BIGINT UNSIGNED NULL,
    destinatario_externo VARCHAR(190) NULL,

    asunto VARCHAR(255) NULL,
    mensaje TEXT NOT NULL,

    enviada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_envio DATETIME NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wn_ejecucion
        FOREIGN KEY (workflow_ejecucion_id) REFERENCES workflow_ejecuciones(id),

    CONSTRAINT chk_wn_canal CHECK (
        canal IN ('SISTEMA','EMAIL','WHATSAPP','MICROSOFT','OTRO')
    )
) ENGINE=InnoDB;

CREATE INDEX idx_wn_pendientes
ON workflow_notificaciones (enviada, created_at);

-- ============================================================
-- 17. MÉTRICAS DE EJECUCIÓN
-- ============================================================

CREATE TABLE workflow_metricas_diarias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    workflow_id BIGINT UNSIGNED NOT NULL,
    fecha DATE NOT NULL,

    total_ejecuciones INT UNSIGNED NOT NULL DEFAULT 0,
    total_exitosas INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,
    total_reintentos INT UNSIGNED NOT NULL DEFAULT 0,

    tiempo_promedio_ms BIGINT UNSIGNED NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_wmd_workflow_fecha UNIQUE (workflow_id, fecha),

    CONSTRAINT fk_wmd_workflow
        FOREIGN KEY (workflow_id) REFERENCES workflows(id)
) ENGINE=InnoDB;

-- ============================================================
-- 18. DATOS INICIALES
-- ============================================================

INSERT INTO estados_workflow
(codigo, nombre, permite_ejecucion)
VALUES
('BORRADOR', 'Borrador', FALSE),
('ACTIVO', 'Activo', TRUE),
('PAUSADO', 'Pausado', FALSE),
('INACTIVO', 'Inactivo', FALSE),
('ARCHIVADO', 'Archivado', FALSE);

INSERT INTO tipos_disparador_workflow
(codigo, nombre)
VALUES
('EVENTO_DOMINIO', 'Evento de dominio'),
('CRON', 'Programación cron'),
('INTERVALO', 'Intervalo'),
('MANUAL', 'Ejecución manual'),
('CAMBIO_ESTADO', 'Cambio de estado'),
('FECHA_FUTURA', 'Fecha futura'),
('WEBHOOK', 'Webhook externo');

INSERT INTO tipos_condicion_workflow
(codigo, nombre)
VALUES
('COMPARACION', 'Comparación de campo'),
('EXISTENCIA', 'Existencia de dato'),
('ESTADO', 'Validación de estado'),
('FECHA', 'Condición de fecha'),
('PORCENTAJE', 'Condición de porcentaje'),
('EXPRESION', 'Expresión compuesta'),
('PERMISO', 'Validación de permiso'),
('OTRA', 'Otra condición');

INSERT INTO tipos_accion_workflow
(codigo, nombre, requiere_servicio_externo)
VALUES
('ACTUALIZAR_ESTADO', 'Actualizar estado interno', FALSE),
('CREAR_REGISTRO', 'Crear registro interno', FALSE),
('GENERAR_EVENTO', 'Generar evento de dominio', FALSE),
('CREAR_TAREA_DIFERIDA', 'Crear tarea diferida', FALSE),
('ENVIAR_NOTIFICACION', 'Enviar notificación', TRUE),
('MICROSOFT_CREAR_CUENTA', 'Crear cuenta Microsoft 365', TRUE),
('MICROSOFT_ASIGNAR_LICENCIA', 'Asignar licencia Microsoft 365', TRUE),
('MICROSOFT_RETIRAR_LICENCIA', 'Retirar licencia Microsoft 365', TRUE),
('MICROSOFT_DESACTIVAR_CUENTA', 'Desactivar cuenta Microsoft 365', TRUE),
('MOODLE_CREAR_USUARIO', 'Crear usuario Moodle', TRUE),
('MOODLE_CREAR_CURSO', 'Crear curso Moodle', TRUE),
('MOODLE_MATRICULAR_ESTUDIANTE', 'Matricular estudiante en Moodle', TRUE),
('MOODLE_SUSPENDER_MATRICULA', 'Suspender matrícula Moodle', TRUE),
('MOODLE_REACTIVAR_MATRICULA', 'Reactivar matrícula Moodle', TRUE),
('MOODLE_ACTUALIZAR_NOTA', 'Actualizar nota oficial Moodle', TRUE),
('FINANCIERO_RECALCULAR_HABILITACION', 'Recalcular habilitación financiera', FALSE),
('ACADEMICO_GENERAR_MATRICULA', 'Generar matrícula académica', FALSE),
('ENCUESTA_GENERAR_BLOQUEO', 'Generar bloqueo por encuesta', FALSE),
('ENCUESTA_LEVANTAR_BLOQUEO', 'Levantar bloqueo por encuesta', FALSE),
('TITULACION_REVALIDAR_REQUISITOS', 'Revalidar requisitos de titulación', FALSE),
('CERTIFICADO_GENERAR', 'Generar certificado', FALSE),
('OTRA', 'Otra acción', FALSE);

INSERT INTO estados_ejecucion_workflow
(codigo, nombre, es_final, exitoso)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE),
('EXITOSA', 'Exitosa', TRUE, TRUE),
('ERROR', 'Error', FALSE, FALSE),
('REINTENTO', 'Reintento', FALSE, FALSE),
('CANCELADA', 'Cancelada', TRUE, FALSE),
('DEAD_LETTER', 'Dead Letter', TRUE, FALSE);

INSERT INTO estados_paso_workflow
(codigo, nombre, es_final, exitoso)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE),
('EXITOSO', 'Exitoso', TRUE, TRUE),
('ERROR', 'Error', FALSE, FALSE),
('OMITIDO', 'Omitido', TRUE, TRUE),
('CANCELADO', 'Cancelado', TRUE, FALSE);

INSERT INTO tipos_programacion_workflow
(codigo, nombre)
VALUES
('CRON', 'Cron'),
('INTERVALO', 'Intervalo'),
('UNA_VEZ', 'Una sola vez');

INSERT INTO prioridades_workflow
(codigo, nombre, valor)
VALUES
('CRITICA', 'Crítica', 10),
('ALTA', 'Alta', 30),
('MEDIA', 'Media', 50),
('BAJA', 'Baja', 100);

-- ============================================================
-- 19. EVENTOS DE DOMINIO INICIALES
-- ============================================================

INSERT INTO eventos_dominio_catalogo
(codigo, nombre, modulo, descripcion)
VALUES
('ADMISION_APROBADA', 'Admisión aprobada', 'ADMISIONES', 'Dispara provisión de estudiante y cuenta'),
('PERSONAL_REGISTRADO', 'Personal registrado', 'TTHH', 'Dispara solicitud de cuenta a TIC'),
('PERSONAL_DESVINCULADO', 'Personal desvinculado', 'TTHH', 'Dispara desactivación de accesos'),
('CUENTA_TIC_APROBADA', 'Cuenta aprobada por TIC', 'TIC', 'Dispara provisión Microsoft/SIGA/Moodle'),
('PAGO_APROBADO', 'Pago aprobado', 'FINANCIERO', 'Dispara recalculo de habilitación'),
('ABONO_APROBADO', 'Abono aprobado', 'FINANCIERO', 'Dispara regla del porcentaje de habilitación'),
('ESTUDIANTE_HABILITADO_FINANCIERO', 'Estudiante habilitado financieramente', 'FINANCIERO', 'Permite matrícula y plataformas'),
('ESTUDIANTE_BLOQUEADO_FINANCIERO', 'Estudiante bloqueado financieramente', 'FINANCIERO', 'Suspende accesos académicos'),
('MATRICULA_CONFIRMADA', 'Matrícula confirmada', 'ACADEMICO', 'Dispara matrícula Moodle'),
('MATRICULA_ANULADA', 'Matrícula anulada', 'ACADEMICO', 'Suspende/retira matrícula Moodle'),
('SECCION_PUBLICADA', 'Sección publicada', 'ACADEMICO', 'Dispara creación/sincronización Moodle'),
('DOCENTE_ASIGNADO_SECCION', 'Docente asignado a sección', 'ACADEMICO', 'Dispara matrícula docente Moodle'),
('PARCIAL_CERRADO', 'Parcial cerrado', 'EVALUACION', 'Oficializa resultados'),
('CAMBIO_NOTA_APROBADO', 'Cambio de nota aprobado', 'EVALUACION', 'Dispara actualización oficial Moodle'),
('UMBRAL_INASISTENCIAS_ALCANZADO', 'Umbral de inasistencias alcanzado', 'ASISTENCIA', 'Dispara alertas y acciones institucionales'),
('ENCUESTA_OBLIGATORIA_ASIGNADA', 'Encuesta obligatoria asignada', 'ENCUESTAS', 'Genera bloqueo'),
('ENCUESTA_COMPLETADA', 'Encuesta completada', 'ENCUESTAS', 'Levanta bloqueo'),
('ESTUDIANTE_EGRESADO', 'Estudiante egresado', 'ACADEMICO', 'Programa retiro de licencia a 180 días'),
('ESTUDIANTE_GRADUADO', 'Estudiante graduado', 'ACADEMICO', 'Programa retiro de licencia a 90 días'),
('TITULACION_REQUISITO_CAMBIO', 'Cambio de requisito de titulación', 'TITULACION', 'Revalida proceso'),
('BECA_APROBADA', 'Beca aprobada', 'BIENESTAR', 'Aplica efecto financiero'),
('CERTIFICADO_SOLICITADO', 'Certificado solicitado', 'CERTIFICADOS', 'Genera certificado');

-- ============================================================
-- 20. WORKFLOWS INSTITUCIONALES BASE
-- ============================================================

-- 20.1 Cuenta institucional después de aprobación TIC
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_CUENTA_INSTITUCIONAL_APROBADA',
    'Aprovisionar cuenta institucional aprobada',
    'Crea cuenta Microsoft, asigna licencia y prepara acceso SIGA/Moodle',
    ew.id,
    'TIC',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_CUENTA_INSTITUCIONAL_APROBADA';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT
    wv.id,
    td.id,
    ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CUENTA_INSTITUCIONAL_APROBADA'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='CUENTA_TIC_APROBADA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Crear cuenta Microsoft 365'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CUENTA_INSTITUCIONAL_APROBADA'
JOIN tipos_accion_workflow ta ON ta.codigo='MICROSOFT_CREAR_CUENTA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 2, 'Asignar licencia Microsoft 365'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CUENTA_INSTITUCIONAL_APROBADA'
JOIN tipos_accion_workflow ta ON ta.codigo='MICROSOFT_ASIGNAR_LICENCIA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 3, 'Crear/sincronizar usuario Moodle'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CUENTA_INSTITUCIONAL_APROBADA'
JOIN tipos_accion_workflow ta ON ta.codigo='MOODLE_CREAR_USUARIO';

-- 20.2 Pago aprobado -> habilitación
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_PAGO_APROBADO_HABILITACION',
    'Recalcular habilitación tras pago',
    'Recalcula estado financiero y habilitación académica',
    ew.id,
    'FINANCIERO',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_PAGO_APROBADO_HABILITACION';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_PAGO_APROBADO_HABILITACION'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='PAGO_APROBADO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Recalcular habilitación financiera'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_PAGO_APROBADO_HABILITACION'
JOIN tipos_accion_workflow ta ON ta.codigo='FINANCIERO_RECALCULAR_HABILITACION';

-- 20.3 Matrícula confirmada -> Moodle
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_MATRICULA_CONFIRMADA_MOODLE',
    'Matricular estudiante en Moodle',
    'Sincroniza matrícula confirmada desde SIGA hacia Moodle',
    ew.id,
    'ACADEMICO',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_MATRICULA_CONFIRMADA_MOODLE';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_MATRICULA_CONFIRMADA_MOODLE'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='MATRICULA_CONFIRMADA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Matricular estudiante en Moodle'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_MATRICULA_CONFIRMADA_MOODLE'
JOIN tipos_accion_workflow ta ON ta.codigo='MOODLE_MATRICULAR_ESTUDIANTE';

-- 20.4 Bloqueo financiero -> suspender Moodle
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_BLOQUEO_FINANCIERO_MOODLE',
    'Suspender acceso Moodle por bloqueo financiero',
    'Suspende matrícula Moodle sin eliminar histórico',
    ew.id,
    'FINANCIERO',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_BLOQUEO_FINANCIERO_MOODLE';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_BLOQUEO_FINANCIERO_MOODLE'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ESTUDIANTE_BLOQUEADO_FINANCIERO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Suspender matrícula Moodle'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_BLOQUEO_FINANCIERO_MOODLE'
JOIN tipos_accion_workflow ta ON ta.codigo='MOODLE_SUSPENDER_MATRICULA';

-- 20.5 Regularización financiera -> reactivar Moodle
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_HABILITACION_FINANCIERA_MOODLE',
    'Reactivar acceso Moodle por habilitación financiera',
    'Reactiva matrícula Moodle cuando el estudiante regulariza su estado',
    ew.id,
    'FINANCIERO',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_HABILITACION_FINANCIERA_MOODLE';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_HABILITACION_FINANCIERA_MOODLE'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ESTUDIANTE_HABILITADO_FINANCIERO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Reactivar matrícula Moodle'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_HABILITACION_FINANCIERA_MOODLE'
JOIN tipos_accion_workflow ta ON ta.codigo='MOODLE_REACTIVAR_MATRICULA';

-- 20.6 Cambio de nota aprobado -> Moodle
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_CAMBIO_NOTA_OFICIAL_MOODLE',
    'Sincronizar cambio oficial de nota',
    'Envía corrección oficial desde SIGA hacia Moodle',
    ew.id,
    'EVALUACION',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='CRITICA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_CAMBIO_NOTA_OFICIAL_MOODLE';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CAMBIO_NOTA_OFICIAL_MOODLE'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='CAMBIO_NOTA_APROBADO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Actualizar nota oficial en Moodle'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_CAMBIO_NOTA_OFICIAL_MOODLE'
JOIN tipos_accion_workflow ta ON ta.codigo='MOODLE_ACTUALIZAR_NOTA';

-- 20.7 Encuesta obligatoria
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_ENCUESTA_OBLIGATORIA_BLOQUEO',
    'Bloquear acciones por encuesta obligatoria',
    'Genera bloqueo al asignar una encuesta obligatoria',
    ew.id,
    'ENCUESTAS',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='MEDIA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_ENCUESTA_OBLIGATORIA_BLOQUEO';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_ENCUESTA_OBLIGATORIA_BLOQUEO'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ENCUESTA_OBLIGATORIA_ASIGNADA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Crear bloqueo por encuesta'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_ENCUESTA_OBLIGATORIA_BLOQUEO'
JOIN tipos_accion_workflow ta ON ta.codigo='ENCUESTA_GENERAR_BLOQUEO';

-- 20.8 Encuesta completada
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_ENCUESTA_COMPLETADA_DESBLOQUEO',
    'Levantar bloqueo de encuesta completada',
    'Levanta bloqueo cuando la encuesta obligatoria se completa',
    ew.id,
    'ENCUESTAS',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='MEDIA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_ENCUESTA_COMPLETADA_DESBLOQUEO';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_ENCUESTA_COMPLETADA_DESBLOQUEO'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ENCUESTA_COMPLETADA';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre)
SELECT wv.id, ta.id, 1, 'Levantar bloqueo por encuesta'
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_ENCUESTA_COMPLETADA_DESBLOQUEO'
JOIN tipos_accion_workflow ta ON ta.codigo='ENCUESTA_LEVANTAR_BLOQUEO';

-- 20.9 Egresado -> retiro licencia 180 días
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_EGRESADO_RETIRO_LICENCIA_180',
    'Programar retiro de licencia de egresado',
    'Programa retiro de licencia y desactivación a 180 días',
    ew.id,
    'TIC',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='MEDIA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_EGRESADO_RETIRO_LICENCIA_180';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_EGRESADO_RETIRO_LICENCIA_180'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ESTUDIANTE_EGRESADO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre, configuracion_json)
SELECT
    wv.id,
    ta.id,
    1,
    'Programar retiro de licencia a 180 días',
    JSON_OBJECT('offset_days', 180, 'action', 'MICROSOFT_RETIRAR_LICENCIA')
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_EGRESADO_RETIRO_LICENCIA_180'
JOIN tipos_accion_workflow ta ON ta.codigo='CREAR_TAREA_DIFERIDA';

-- 20.10 Graduado -> retiro licencia 90 días
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_GRADUADO_RETIRO_LICENCIA_90',
    'Programar retiro de licencia de graduado',
    'Programa retiro de licencia y desactivación a 90 días',
    ew.id,
    'TIC',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='MEDIA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_GRADUADO_RETIRO_LICENCIA_90';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_GRADUADO_RETIRO_LICENCIA_90'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='ESTUDIANTE_GRADUADO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre, configuracion_json)
SELECT
    wv.id,
    ta.id,
    1,
    'Programar retiro de licencia a 90 días',
    JSON_OBJECT('offset_days', 90, 'action', 'MICROSOFT_RETIRAR_LICENCIA')
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_GRADUADO_RETIRO_LICENCIA_90'
JOIN tipos_accion_workflow ta ON ta.codigo='CREAR_TAREA_DIFERIDA';

-- 20.11 Inasistencias continuas
INSERT INTO workflows
(codigo, nombre, descripcion, estado_workflow_id, modulo_principal, prioridad_workflow_id)
SELECT
    'WF_UMBRAL_INASISTENCIAS',
    'Gestionar umbral de inasistencias',
    'Genera notificaciones y acciones institucionales al alcanzar el umbral',
    ew.id,
    'ASISTENCIA',
    pw.id
FROM estados_workflow ew
JOIN prioridades_workflow pw ON pw.codigo='ALTA'
WHERE ew.codigo='ACTIVO';

INSERT INTO workflow_versiones
(workflow_id, numero_version, nombre_version, vigente_desde)
SELECT id, 1, 'Versión 1', CURRENT_TIMESTAMP
FROM workflows
WHERE codigo='WF_UMBRAL_INASISTENCIAS';

INSERT INTO workflow_disparadores
(workflow_version_id, tipo_disparador_workflow_id, evento_dominio_catalogo_id)
SELECT wv.id, td.id, ed.id
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_UMBRAL_INASISTENCIAS'
JOIN tipos_disparador_workflow td ON td.codigo='EVENTO_DOMINIO'
JOIN eventos_dominio_catalogo ed ON ed.codigo='UMBRAL_INASISTENCIAS_ALCANZADO';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre, configuracion_json)
SELECT
    wv.id,
    ta.id,
    1,
    'Notificar coordinación académica',
    JSON_OBJECT('canal', 'SISTEMA', 'destino', 'COORDINACION_ACADEMICA')
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_UMBRAL_INASISTENCIAS'
JOIN tipos_accion_workflow ta ON ta.codigo='ENVIAR_NOTIFICACION';

INSERT INTO workflow_acciones
(workflow_version_id, tipo_accion_workflow_id, orden_ejecucion, nombre, configuracion_json)
SELECT
    wv.id,
    ta.id,
    2,
    'Generar acción para revisión de cuenta institucional',
    JSON_OBJECT('action', 'REVISAR_DESACTIVACION_CUENTA')
FROM workflow_versiones wv
JOIN workflows w ON w.id=wv.workflow_id AND w.codigo='WF_UMBRAL_INASISTENCIAS'
JOIN tipos_accion_workflow ta ON ta.codigo='CREAR_REGISTRO';

-- ============================================================
-- 21. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ARQUITECTURA:
--
--    EVENTO DE DOMINIO
--           ↓
--       WORKFLOW
--           ↓
--      CONDICIONES
--           ↓
--        ACCIONES
--           ↓
--      COLA / WORKER
--           ↓
--       RESULTADO
--
-- ------------------------------------------------------------
-- IDEMPOTENCIA
-- ------------------------------------------------------------
-- Cada evento/ejecución crítica debe utilizar idempotency_key.
--
-- Ejemplo:
--   "MATRICULA_CONFIRMADA:matricula_asignatura:12345"
--
-- Si el evento se recibe dos veces, el motor no duplica:
--   - matrícula Moodle
--   - licencia Microsoft
--   - certificado
--   - notificación crítica
--
-- ------------------------------------------------------------
-- NO TRIGGERS COMPLEJOS
-- ------------------------------------------------------------
-- Las tablas del dominio generan eventos desde la capa de servicio.
-- Ejemplo:
--
--   PagoController / PagoService
--      -> aprueba pago
--      -> transacción BD
--      -> crea evento PAGO_APROBADO
--
-- Worker:
--      -> procesa evento
--      -> ejecuta WF_PAGO_APROBADO_HABILITACION
--
-- ------------------------------------------------------------
-- PAGOS
-- ------------------------------------------------------------
-- PAGO_APROBADO
--      -> recalcular saldo
--      -> recalcular habilitación
--      -> si queda habilitado:
--             evento ESTUDIANTE_HABILITADO_FINANCIERO
--      -> si queda bloqueado:
--             evento ESTUDIANTE_BLOQUEADO_FINANCIERO
--
-- ------------------------------------------------------------
-- MATRÍCULA
-- ------------------------------------------------------------
-- ESTUDIANTE_HABILITADO_FINANCIERO
--      -> habilitaciones_matricula
--      -> si corresponde, generar/confirmar matrícula
--
-- MATRÍCULA_CONFIRMADA
--      -> Moodle
--
-- ------------------------------------------------------------
-- MICROSOFT
-- ------------------------------------------------------------
-- CUENTA_TIC_APROBADA
--      -> crear cuenta
--      -> asignar licencia
--      -> crear/sincronizar Moodle
--
-- PERSONAL_DESVINCULADO
--      -> revisar otros vínculos activos
--      -> si no hay vínculo válido:
--             retirar licencia
--             desactivar cuenta
--
-- ------------------------------------------------------------
-- EGRESADOS / GRADUADOS
-- ------------------------------------------------------------
-- ESTUDIANTE_EGRESADO
--      -> tarea diferida +180 días
--
-- ESTUDIANTE_GRADUADO
--      -> tarea diferida +90 días
--
-- Antes de ejecutar la tarea diferida:
--      revalidar estado actual.
-- Si la persona volvió a tener vínculo válido:
--      cancelar desactivación.
--
-- ------------------------------------------------------------
-- INASISTENCIAS
-- ------------------------------------------------------------
-- UMBRAL_INASISTENCIAS_ALCANZADO
--      -> notificar
--      -> generar revisión
--      -> NO desactivar automáticamente sin revalidación.
--
-- ------------------------------------------------------------
-- ENCUESTAS
-- ------------------------------------------------------------
-- ENCUESTA_OBLIGATORIA_ASIGNADA
--      -> bloqueo
--
-- ENCUESTA_COMPLETADA
--      -> desbloqueo
--
-- ------------------------------------------------------------
-- CAMBIO DE NOTA
-- ------------------------------------------------------------
-- CAMBIO_NOTA_APROBADO
--      -> proteger nota oficial
--      -> recalcular
--      -> SIGA -> Moodle
--      -> si falla, reintentar
--
-- ------------------------------------------------------------
-- DEAD LETTER QUEUE
-- ------------------------------------------------------------
-- Si una ejecución supera max_intentos:
--      estado = DEAD_LETTER
--      workflow_dead_letters
--      alerta administrativa
--
-- ------------------------------------------------------------
-- WORKERS SUGERIDOS
-- ------------------------------------------------------------
-- worker_domain_events
-- worker_workflows
-- worker_moodle
-- worker_microsoft
-- worker_notifications
-- worker_scheduled_tasks
--
-- Se pueden ejecutar en contenedores independientes.
--
-- ------------------------------------------------------------
-- ESCALABILIDAD
-- ------------------------------------------------------------
-- El motor permite:
--   - nuevos eventos
--   - nuevas condiciones
--   - nuevas acciones
--   - workflows versionados
-- sin modificar tablas de cada módulo.
--
-- ============================================================
-- FIN 018_motor_automatizacion.sql
-- ============================================================
