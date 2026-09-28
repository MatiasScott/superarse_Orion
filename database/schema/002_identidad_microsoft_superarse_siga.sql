-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 002_identidad_microsoft.sql
-- Requiere: 001_core_definitivo_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Integración de identidad con Microsoft Entra ID / Microsoft 365
--   - Solicitudes automáticas de creación, reactivación y baja
--   - Aprobación por TIC antes de crear cuentas
--   - Creación del usuario SIGA al completarse la cuenta institucional
--   - Gestión de licencias e histórico
--   - Reglas de ciclo de vida (graduado, egresado, baja, etc.)
--   - Cola/reintentos de sincronización con Microsoft Graph
--
-- IMPORTANTE:
--   - NO almacena contraseñas de Microsoft.
--   - NO almacena access tokens/refresh tokens en texto plano.
--   - Los secretos se obtienen desde .env / Docker Secret / Secret Manager.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. PROVEEDOR DE IDENTIDAD
-- ============================================================

CREATE TABLE proveedores_identidad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_proveedores_identidad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE configuraciones_proveedor_identidad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    proveedor_identidad_id BIGINT UNSIGNED NOT NULL,

    tenant_id VARCHAR(100) NULL,
    dominio_principal VARCHAR(190) NULL,

    -- Referencias a secretos; nunca los secretos reales.
    client_id_secret_ref VARCHAR(190) NULL,
    client_secret_ref VARCHAR(190) NULL,

    ubicacion_predeterminada VARCHAR(10) NULL,
    habilitar_sso BOOLEAN NOT NULL DEFAULT TRUE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_config_proveedor UNIQUE (proveedor_identidad_id),
    CONSTRAINT fk_config_proveedor
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id)
) ENGINE=InnoDB;

-- ============================================================
-- 02. ESTADOS DE CUENTA INSTITUCIONAL
-- ============================================================

CREATE TABLE estados_cuenta_institucional (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_login BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 03. CUENTA INSTITUCIONAL
-- ============================================================

CREATE TABLE cuentas_institucionales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,
    proveedor_identidad_id BIGINT UNSIGNED NOT NULL,
    estado_cuenta_id BIGINT UNSIGNED NOT NULL,

    -- Identificador estable devuelto por Microsoft Entra ID (Object ID).
    identificador_externo VARCHAR(190) NOT NULL,

    username VARCHAR(190) NOT NULL,
    email_institucional VARCHAR(190) NOT NULL,

    tenant_id VARCHAR(100) NULL,
    dominio VARCHAR(190) NOT NULL,
    ubicacion_uso VARCHAR(10) NULL,

    fecha_creacion_externa DATETIME NULL,
    fecha_activacion DATETIME NULL,
    fecha_suspension DATETIME NULL,
    fecha_desactivacion DATETIME NULL,
    ultima_sincronizacion_at DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_cuentas_externo
        UNIQUE (proveedor_identidad_id, identificador_externo),
    CONSTRAINT uq_cuentas_email
        UNIQUE (email_institucional),
    CONSTRAINT uq_cuentas_username_dominio
        UNIQUE (username, dominio),

    CONSTRAINT fk_cuentas_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_cuentas_proveedor
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id),
    CONSTRAINT fk_cuentas_estado
        FOREIGN KEY (estado_cuenta_id) REFERENCES estados_cuenta_institucional(id)
) ENGINE=InnoDB;

CREATE INDEX idx_cuentas_usuario_activa
ON cuentas_institucionales (usuario_id, activo);

-- ============================================================
-- 04. LICENCIAS MICROSOFT 365
-- ============================================================

CREATE TABLE tipos_licencia_institucional (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proveedor_identidad_id BIGINT UNSIGNED NOT NULL,
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    sku_externo VARCHAR(190) NULL,
    descripcion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_tipo_licencia_codigo
        UNIQUE (proveedor_identidad_id, codigo),

    CONSTRAINT fk_tipo_licencia_proveedor
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id)
) ENGINE=InnoDB;

CREATE TABLE cuenta_licencias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NOT NULL,
    tipo_licencia_id BIGINT UNSIGNED NOT NULL,

    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_retiro DATETIME NULL,

    asignada_por_usuario_id BIGINT UNSIGNED NULL,
    retirada_por_usuario_id BIGINT UNSIGNED NULL,

    motivo_retiro VARCHAR(255) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cuenta_licencias_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_cuenta_licencias_tipo
        FOREIGN KEY (tipo_licencia_id) REFERENCES tipos_licencia_institucional(id),
    CONSTRAINT fk_cuenta_licencias_asignada_por
        FOREIGN KEY (asignada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_cuenta_licencias_retirada_por
        FOREIGN KEY (retirada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_cuenta_licencias_activas
ON cuenta_licencias (cuenta_institucional_id, activa);

-- ============================================================
-- 05. SOLICITUDES DE CUENTA A TIC
-- ============================================================

CREATE TABLE tipos_solicitud_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_solicitud_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_solicitud_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_solicitud_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE origenes_solicitud_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_origenes_solicitud_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE solicitudes_cuentas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(40) NOT NULL,

    persona_id BIGINT UNSIGNED NOT NULL,
    tipo_solicitud_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_id BIGINT UNSIGNED NOT NULL,
    origen_solicitud_id BIGINT UNSIGNED NOT NULL,

    -- Perfil que debe quedar disponible al completar el proceso.
    perfil_solicitado_id BIGINT UNSIGNED NULL,

    -- Licencia sugerida para el alta.
    tipo_licencia_solicitada_id BIGINT UNSIGNED NULL,

    -- Referencia al registro que originó la solicitud.
    -- Ej.: aspirante/admitido, empleado, desvinculación, etc.
    origen_registro_id BIGINT UNSIGNED NULL,

    solicitado_por_usuario_id BIGINT UNSIGNED NULL,
    revisado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    rechazado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    fecha_aprobacion DATETIME NULL,
    fecha_rechazo DATETIME NULL,
    fecha_ejecucion DATETIME NULL,

    observacion TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitudes_cuentas_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_solicitudes_cuentas_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_solicitudes_cuentas_tipo
        FOREIGN KEY (tipo_solicitud_id) REFERENCES tipos_solicitud_cuenta(id),
    CONSTRAINT fk_solicitudes_cuentas_estado
        FOREIGN KEY (estado_solicitud_id) REFERENCES estados_solicitud_cuenta(id),
    CONSTRAINT fk_solicitudes_cuentas_origen
        FOREIGN KEY (origen_solicitud_id) REFERENCES origenes_solicitud_cuenta(id),
    CONSTRAINT fk_solicitudes_cuentas_perfil
        FOREIGN KEY (perfil_solicitado_id) REFERENCES perfiles(id),
    CONSTRAINT fk_solicitudes_cuentas_licencia
        FOREIGN KEY (tipo_licencia_solicitada_id) REFERENCES tipos_licencia_institucional(id),
    CONSTRAINT fk_solicitudes_cuentas_solicitado_por
        FOREIGN KEY (solicitado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_solicitudes_cuentas_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_solicitudes_cuentas_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_solicitudes_cuentas_rechazado_por
        FOREIGN KEY (rechazado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_solicitudes_cuentas_estado_fecha
ON solicitudes_cuentas (estado_solicitud_id, fecha_solicitud);

CREATE INDEX idx_solicitudes_cuentas_persona
ON solicitudes_cuentas (persona_id, fecha_solicitud);

-- ============================================================
-- 06. CANDIDATOS DE NOMBRE DE USUARIO
-- ============================================================

CREATE TABLE estados_candidato_username (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_candidato_username_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE solicitud_cuenta_usernames (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_cuenta_id BIGINT UNSIGNED NOT NULL,
    estado_candidato_id BIGINT UNSIGNED NOT NULL,

    orden_intento SMALLINT UNSIGNED NOT NULL,
    username VARCHAR(190) NOT NULL,
    email_propuesto VARCHAR(190) NOT NULL,

    fecha_validacion DATETIME NULL,
    detalle_validacion VARCHAR(255) NULL,

    seleccionado BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitud_username_orden
        UNIQUE (solicitud_cuenta_id, orden_intento),
    CONSTRAINT uq_solicitud_username
        UNIQUE (solicitud_cuenta_id, username),

    CONSTRAINT fk_solicitud_usernames_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id),
    CONSTRAINT fk_solicitud_usernames_estado
        FOREIGN KEY (estado_candidato_id) REFERENCES estados_candidato_username(id)
) ENGINE=InnoDB;

-- El backend generará candidatos según la regla institucional:
-- 1. primer_nombre.primer_apellido
-- 2. segundo_nombre.primer_apellido
-- 3. primer_nombre.segundo_apellido
-- 4. segundo_nombre.segundo_apellido
-- y validará disponibilidad en Microsoft antes de seleccionar.

-- ============================================================
-- 07. EJECUCIONES / SAGA DE PROVISIONAMIENTO
-- ============================================================

CREATE TABLE estados_provisionamiento_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_provisionamiento_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE provisionamientos_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_cuenta_id BIGINT UNSIGNED NOT NULL,
    estado_provisionamiento_id BIGINT UNSIGNED NOT NULL,

    cuenta_institucional_id BIGINT UNSIGNED NULL,
    usuario_siga_id BIGINT UNSIGNED NULL,

    intento_actual SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    ultimo_error_codigo VARCHAR(100) NULL,
    ultimo_error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_provisionamiento_solicitud UNIQUE (solicitud_cuenta_id),

    CONSTRAINT fk_provisionamientos_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id),
    CONSTRAINT fk_provisionamientos_estado
        FOREIGN KEY (estado_provisionamiento_id) REFERENCES estados_provisionamiento_cuenta(id),
    CONSTRAINT fk_provisionamientos_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_provisionamientos_usuario
        FOREIGN KEY (usuario_siga_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE pasos_provisionamiento_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    provisionamiento_id BIGINT UNSIGNED NOT NULL,

    codigo_paso VARCHAR(80) NOT NULL,
    orden_paso SMALLINT UNSIGNED NOT NULL,

    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,

    mensaje_error TEXT NULL,
    datos_resultado JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_paso_provisionamiento
        UNIQUE (provisionamiento_id, codigo_paso),

    CONSTRAINT fk_pasos_provisionamiento
        FOREIGN KEY (provisionamiento_id) REFERENCES provisionamientos_cuenta(id)
) ENGINE=InnoDB;

-- Pasos esperados para CREACIÓN:
-- VALIDAR_PERSONA
-- GENERAR_USERNAME
-- CREAR_CUENTA_MICROSOFT
-- ASIGNAR_UBICACION
-- ASIGNAR_LICENCIA
-- CREAR_USUARIO_SIGA (si no existe)
-- ASIGNAR_PERFIL
-- REGISTRAR_CUENTA_INSTITUCIONAL
-- FINALIZAR

-- ============================================================
-- 08. EVENTOS E HISTÓRICO DE CUENTAS
-- ============================================================

CREATE TABLE tipos_evento_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_evento_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE cuenta_eventos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NOT NULL,
    tipo_evento_id BIGINT UNSIGNED NOT NULL,

    ejecutado_por_usuario_id BIGINT UNSIGNED NULL,

    origen VARCHAR(80) NULL,
    detalle TEXT NULL,
    datos_json JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cuenta_eventos_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_cuenta_eventos_tipo
        FOREIGN KEY (tipo_evento_id) REFERENCES tipos_evento_cuenta(id),
    CONSTRAINT fk_cuenta_eventos_usuario
        FOREIGN KEY (ejecutado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_cuenta_eventos_fecha
ON cuenta_eventos (cuenta_institucional_id, created_at);

-- ============================================================
-- 09. POLÍTICAS HISTÓRICAS DE CICLO DE VIDA
-- ============================================================

CREATE TABLE causas_ciclo_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_causas_ciclo_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE politicas_ciclo_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    causa_ciclo_id BIGINT UNSIGNED NOT NULL,

    dias_gracia INT UNSIGNED NOT NULL DEFAULT 0,

    desactivar_cuenta BOOLEAN NOT NULL DEFAULT TRUE,
    retirar_licencias BOOLEAN NOT NULL DEFAULT TRUE,
    desactivar_acceso_siga BOOLEAN NOT NULL DEFAULT TRUE,

    requiere_revision_manual BOOLEAN NOT NULL DEFAULT FALSE,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    creada_por_usuario_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_politicas_ciclo_causa
        FOREIGN KEY (causa_ciclo_id) REFERENCES causas_ciclo_cuenta(id),
    CONSTRAINT fk_politicas_ciclo_usuario
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_politicas_ciclo_vigencia
ON politicas_ciclo_cuenta (causa_ciclo_id, vigente_desde, vigente_hasta);

-- ============================================================
-- 10. PROGRAMACIÓN DE ACCIONES DE CICLO DE VIDA
-- ============================================================

CREATE TABLE estados_accion_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_accion_cuenta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE acciones_programadas_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NOT NULL,
    causa_ciclo_id BIGINT UNSIGNED NOT NULL,
    politica_ciclo_id BIGINT UNSIGNED NOT NULL,
    estado_accion_id BIGINT UNSIGNED NOT NULL,

    fecha_evento_origen DATE NOT NULL,
    fecha_ejecucion_programada DATETIME NOT NULL,
    fecha_ejecucion_real DATETIME NULL,

    origen_modulo VARCHAR(80) NOT NULL,
    origen_registro_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,
    ultimo_error TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_acciones_programadas_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_acciones_programadas_causa
        FOREIGN KEY (causa_ciclo_id) REFERENCES causas_ciclo_cuenta(id),
    CONSTRAINT fk_acciones_programadas_politica
        FOREIGN KEY (politica_ciclo_id) REFERENCES politicas_ciclo_cuenta(id),
    CONSTRAINT fk_acciones_programadas_estado
        FOREIGN KEY (estado_accion_id) REFERENCES estados_accion_cuenta(id)
) ENGINE=InnoDB;

CREATE INDEX idx_acciones_programadas_pendientes
ON acciones_programadas_cuenta (estado_accion_id, fecha_ejecucion_programada);

-- Ejemplos de uso posterior:
-- GRADUADO  -> +3 meses
-- EGRESADO  -> +6 meses
-- BAJA      -> 0 días
-- INASISTENCIAS_CONTINUAS_7 -> política institucional;
--                               se recomienda revisión/confirmación antes de ejecutar.

-- ============================================================
-- 11. COLA DE SINCRONIZACIÓN MICROSOFT GRAPH
-- ============================================================

CREATE TABLE estados_sincronizacion_identidad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_sync_identidad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE sincronizaciones_identidad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proveedor_identidad_id BIGINT UNSIGNED NOT NULL,
    cuenta_institucional_id BIGINT UNSIGNED NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NULL,

    operacion VARCHAR(80) NOT NULL,
    entidad VARCHAR(80) NOT NULL,

    estado_sincronizacion_id BIGINT UNSIGNED NOT NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    request_uuid CHAR(36) NULL,
    payload_hash CHAR(64) NULL,

    respuesta_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sync_identidad_proveedor
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id),
    CONSTRAINT fk_sync_identidad_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_sync_identidad_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id),
    CONSTRAINT fk_sync_identidad_estado
        FOREIGN KEY (estado_sincronizacion_id) REFERENCES estados_sincronizacion_identidad(id)
) ENGINE=InnoDB;

CREATE INDEX idx_sync_identidad_cola
ON sincronizaciones_identidad (estado_sincronizacion_id, fecha_programada, proximo_reintento_at);

-- ============================================================
-- 12. DATOS INICIALES
-- ============================================================

INSERT INTO proveedores_identidad
(codigo, nombre, descripcion)
VALUES
('MICROSOFT_ENTRA', 'Microsoft Entra ID', 'Proveedor institucional de identidad y SSO');

INSERT INTO configuraciones_proveedor_identidad
(proveedor_identidad_id, dominio_principal, ubicacion_predeterminada, habilitar_sso)
SELECT id, 'superarse.edu.ec', 'EC', TRUE
FROM proveedores_identidad
WHERE codigo = 'MICROSOFT_ENTRA';

INSERT INTO estados_cuenta_institucional
(codigo, nombre, permite_login, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('ACTIVA', 'Activa', TRUE, FALSE),
('SUSPENDIDA', 'Suspendida', FALSE, FALSE),
('DESACTIVADA', 'Desactivada', FALSE, TRUE),
('ERROR', 'Error', FALSE, FALSE);

INSERT INTO tipos_licencia_institucional
(proveedor_identidad_id, codigo, nombre)
SELECT id, 'A1_ESTUDIANTE', 'Office 365 A1 para estudiantes'
FROM proveedores_identidad WHERE codigo = 'MICROSOFT_ENTRA';

INSERT INTO tipos_licencia_institucional
(proveedor_identidad_id, codigo, nombre)
SELECT id, 'A1_PROFESOR', 'Office 365 A1 para profesores'
FROM proveedores_identidad WHERE codigo = 'MICROSOFT_ENTRA';

-- La licencia exacta de personal administrativo se configurará
-- cuando la institución confirme cuál SKU corresponde.

INSERT INTO tipos_solicitud_cuenta (codigo, nombre) VALUES
('CREACION', 'Creación de cuenta institucional'),
('REACTIVACION', 'Reactivación de cuenta institucional'),
('DESACTIVACION', 'Desactivación de cuenta institucional'),
('AGREGAR_PERFIL', 'Agregar perfil a usuario existente'),
('CAMBIO_LICENCIA', 'Cambio de licencia');

INSERT INTO estados_solicitud_cuenta
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_REVISION', 'En revisión por TIC', FALSE),
('APROBADA', 'Aprobada', FALSE),
('RECHAZADA', 'Rechazada', TRUE),
('EJECUTANDO', 'Ejecutando', FALSE),
('EJECUTADA', 'Ejecutada', TRUE),
('ERROR', 'Error de ejecución', FALSE),
('ANULADA', 'Anulada', TRUE);

INSERT INTO origenes_solicitud_cuenta (codigo, nombre) VALUES
('ADMISIONES', 'Admisiones'),
('TTHH', 'Talento Humano'),
('TIC', 'TIC'),
('AUTOMATIZACION', 'Motor de automatización'),
('OTRO', 'Otro');

INSERT INTO estados_candidato_username (codigo, nombre) VALUES
('PENDIENTE', 'Pendiente de validación'),
('DISPONIBLE', 'Disponible'),
('OCUPADO', 'Ocupado'),
('SELECCIONADO', 'Seleccionado'),
('ERROR', 'Error de validación');

INSERT INTO estados_provisionamiento_cuenta
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('PROCESANDO', 'Procesando', FALSE),
('COMPLETADO', 'Completado', TRUE),
('ERROR', 'Error', FALSE),
('REINTENTO', 'Pendiente de reintento', FALSE),
('CANCELADO', 'Cancelado', TRUE);

INSERT INTO tipos_evento_cuenta (codigo, nombre) VALUES
('CREADA', 'Cuenta creada'),
('ACTIVADA', 'Cuenta activada'),
('SUSPENDIDA', 'Cuenta suspendida'),
('DESACTIVADA', 'Cuenta desactivada'),
('REACTIVADA', 'Cuenta reactivada'),
('USERNAME_ASIGNADO', 'Nombre de usuario asignado'),
('PERFIL_ASIGNADO', 'Perfil asignado'),
('LICENCIA_ASIGNADA', 'Licencia asignada'),
('LICENCIA_RETIRADA', 'Licencia retirada'),
('SINCRONIZADA', 'Cuenta sincronizada'),
('ERROR_SINCRONIZACION', 'Error de sincronización');

INSERT INTO causas_ciclo_cuenta
(codigo, nombre, descripcion)
VALUES
('GRADUADO', 'Graduación', 'Estudiante graduado'),
('EGRESADO', 'Egreso', 'Estudiante egresado'),
('BAJA_ESTUDIANTE', 'Baja de estudiante', 'Estudiante dado de baja'),
('DESVINCULACION_PERSONAL', 'Desvinculación de personal', 'Docente o administrativo desvinculado'),
('INASISTENCIAS_CONTINUAS_7', 'Siete inasistencias continuas', 'Alerta por siete inasistencias continuas'),
('MANUAL', 'Desactivación manual', 'Proceso manual autorizado');

-- Políticas iniciales conocidas.
INSERT INTO politicas_ciclo_cuenta
(causa_ciclo_id, dias_gracia, desactivar_cuenta, retirar_licencias,
 desactivar_acceso_siga, requiere_revision_manual, vigente_desde)
SELECT id, 90, TRUE, TRUE, TRUE, FALSE, '2026-01-01'
FROM causas_ciclo_cuenta WHERE codigo = 'GRADUADO';

INSERT INTO politicas_ciclo_cuenta
(causa_ciclo_id, dias_gracia, desactivar_cuenta, retirar_licencias,
 desactivar_acceso_siga, requiere_revision_manual, vigente_desde)
SELECT id, 180, TRUE, TRUE, TRUE, FALSE, '2026-01-01'
FROM causas_ciclo_cuenta WHERE codigo = 'EGRESADO';

INSERT INTO politicas_ciclo_cuenta
(causa_ciclo_id, dias_gracia, desactivar_cuenta, retirar_licencias,
 desactivar_acceso_siga, requiere_revision_manual, vigente_desde)
SELECT id, 0, TRUE, TRUE, TRUE, FALSE, '2026-01-01'
FROM causas_ciclo_cuenta WHERE codigo = 'BAJA_ESTUDIANTE';

INSERT INTO politicas_ciclo_cuenta
(causa_ciclo_id, dias_gracia, desactivar_cuenta, retirar_licencias,
 desactivar_acceso_siga, requiere_revision_manual, vigente_desde)
SELECT id, 0, TRUE, TRUE, TRUE, FALSE, '2026-01-01'
FROM causas_ciclo_cuenta WHERE codigo = 'DESVINCULACION_PERSONAL';

-- Para 7 inasistencias se deja revisión manual por seguridad.
INSERT INTO politicas_ciclo_cuenta
(causa_ciclo_id, dias_gracia, desactivar_cuenta, retirar_licencias,
 desactivar_acceso_siga, requiere_revision_manual, vigente_desde)
SELECT id, 0, TRUE, TRUE, TRUE, TRUE, '2026-01-01'
FROM causas_ciclo_cuenta WHERE codigo = 'INASISTENCIAS_CONTINUAS_7';

INSERT INTO estados_accion_cuenta
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('PROGRAMADA', 'Programada', FALSE),
('EJECUTANDO', 'Ejecutando', FALSE),
('EJECUTADA', 'Ejecutada', TRUE),
('CANCELADA', 'Cancelada', TRUE),
('ERROR', 'Error', FALSE);

INSERT INTO estados_sincronizacion_identidad
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('PROCESANDO', 'Procesando', FALSE),
('EXITOSA', 'Exitosa', TRUE),
('ERROR', 'Error', FALSE),
('REINTENTO', 'Reintento', FALSE),
('CANCELADA', 'Cancelada', TRUE);

-- ============================================================
-- FIN 002_identidad_microsoft.sql
-- ============================================================
