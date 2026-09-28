-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 022_integracion_microsoft_365_superarse_siga.sql
-- Requiere bloques 001-021
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- REVISIÓN V2
--
-- Objetivo:
--   - Extender el modelo maestro de identidad del bloque 002
--     con capacidades específicas de Microsoft Graph.
--   - Evitar duplicar solicitudes, cuentas, licencias y ciclo de vida.
--
-- FUENTE DE VERDAD:
--   002_identidad_microsoft_superarse_siga.sql
--     solicitudes_cuentas
--     cuentas_institucionales
--     tipos_licencia_institucional
--     cuenta_licencias
--     politicas_ciclo_cuenta
--     acciones_programadas_cuenta
--
-- ESTE BLOQUE AGREGA:
--   - vínculos activos que justifican conservar la cuenta
--   - operaciones HTTP/Graph detalladas e idempotentes
--   - snapshot técnico de perfil Microsoft
--   - conflictos SIGA vs Microsoft
--   - resumen operativo TIC
--   - aplicabilidad de licencias por perfil
--
-- No se almacenan contraseñas, access tokens, refresh tokens
-- ni client secrets.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS ESPECÍFICOS DE MICROSOFT GRAPH
-- ============================================================

CREATE TABLE tipos_operacion_microsoft (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_operacion_m365_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_operacion_microsoft (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_operacion_m365_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_vinculo_microsoft (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_vinculo_m365_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. APLICABILIDAD DE LICENCIAS POR PERFIL
-- ============================================================

CREATE TABLE licencia_microsoft_perfiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_licencia_id BIGINT UNSIGNED NOT NULL,
    perfil_id BIGINT UNSIGNED NOT NULL,

    es_predeterminada BOOLEAN NOT NULL DEFAULT FALSE,
    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_licencia_microsoft_perfil
        UNIQUE (tipo_licencia_id, perfil_id),

    CONSTRAINT fk_lmp_licencia
        FOREIGN KEY (tipo_licencia_id) REFERENCES tipos_licencia_institucional(id),
    CONSTRAINT fk_lmp_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfiles(id)
) ENGINE=InnoDB;

-- ============================================================
-- 03. VÍNCULOS QUE JUSTIFICAN CONSERVAR UNA CUENTA
-- ============================================================

CREATE TABLE cuenta_microsoft_vinculos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NOT NULL,
    tipo_vinculo_microsoft_id BIGINT UNSIGNED NOT NULL,

    referencia_tipo VARCHAR(80) NOT NULL,
    referencia_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_cuenta_microsoft_vinculo
        UNIQUE (
            cuenta_institucional_id,
            tipo_vinculo_microsoft_id,
            referencia_tipo,
            referencia_id
        ),

    CONSTRAINT fk_cmv_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_cmv_tipo
        FOREIGN KEY (tipo_vinculo_microsoft_id) REFERENCES tipos_vinculo_microsoft(id),

    CONSTRAINT chk_cmv_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_cmv_cuenta_activo
ON cuenta_microsoft_vinculos (cuenta_institucional_id, activo, fecha_fin);

-- ============================================================
-- 04. OPERACIONES MICROSOFT GRAPH
-- ============================================================

CREATE TABLE operaciones_microsoft_365 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NULL,

    tipo_operacion_microsoft_id BIGINT UNSIGNED NOT NULL,
    estado_operacion_microsoft_id BIGINT UNSIGNED NOT NULL,

    request_uuid CHAR(36) NOT NULL,
    idempotency_key VARCHAR(190) NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    endpoint VARCHAR(500) NULL,
    metodo_http VARCHAR(10) NULL,

    request_json JSON NULL,
    response_json JSON NULL,

    http_status SMALLINT UNSIGNED NULL,
    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_om365_request_uuid UNIQUE (request_uuid),
    CONSTRAINT uq_om365_idempotency UNIQUE (idempotency_key),

    CONSTRAINT fk_om365_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_om365_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id),
    CONSTRAINT fk_om365_tipo
        FOREIGN KEY (tipo_operacion_microsoft_id) REFERENCES tipos_operacion_microsoft(id),
    CONSTRAINT fk_om365_estado
        FOREIGN KEY (estado_operacion_microsoft_id) REFERENCES estados_operacion_microsoft(id)
) ENGINE=InnoDB;

CREATE INDEX idx_om365_cola
ON operaciones_microsoft_365
(estado_operacion_microsoft_id, prioridad, fecha_programada, proximo_reintento_at);

-- ============================================================
-- 05. SNAPSHOT TÉCNICO DEL PERFIL EN MICROSOFT
-- ============================================================

CREATE TABLE sincronizacion_perfil_microsoft (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NOT NULL,

    display_name_microsoft VARCHAR(255) NULL,
    mail_microsoft VARCHAR(255) NULL,
    user_principal_name_microsoft VARCHAR(255) NULL,
    account_enabled_microsoft BOOLEAN NULL,
    usage_location_microsoft VARCHAR(10) NULL,

    licencias_json JSON NULL,

    hash_snapshot CHAR(64) NULL,

    sincronizado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_spm_cuenta UNIQUE (cuenta_institucional_id),

    CONSTRAINT fk_spm_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. CONFLICTOS SIGA <-> MICROSOFT
-- ============================================================

CREATE TABLE conflictos_microsoft_365 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cuenta_institucional_id BIGINT UNSIGNED NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NULL,

    codigo VARCHAR(80) NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    detalle TEXT NOT NULL,

    valor_siga_json JSON NULL,
    valor_microsoft_json JSON NULL,

    resuelto BOOLEAN NOT NULL DEFAULT FALSE,
    resuelto_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_resolucion DATETIME NULL,
    observacion_resolucion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_confm365_cuenta
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_confm365_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id),
    CONSTRAINT fk_confm365_usuario
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_confm365_pendientes
ON conflictos_microsoft_365 (resuelto, created_at);

-- ============================================================
-- 07. RESUMEN OPERATIVO PARA DASHBOARD TIC
-- ============================================================

CREATE TABLE resumen_microsoft_365 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    fecha DATE NOT NULL,

    cuentas_activas INT UNSIGNED NOT NULL DEFAULT 0,
    cuentas_inactivas INT UNSIGNED NOT NULL DEFAULT 0,
    solicitudes_pendientes INT UNSIGNED NOT NULL DEFAULT 0,

    licencias_estudiantes_asignadas INT UNSIGNED NOT NULL DEFAULT 0,
    licencias_docentes_asignadas INT UNSIGNED NOT NULL DEFAULT 0,
    licencias_administrativas_asignadas INT UNSIGNED NOT NULL DEFAULT 0,

    operaciones_error INT UNSIGNED NOT NULL DEFAULT 0,
    conflictos_pendientes INT UNSIGNED NOT NULL DEFAULT 0,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_resumen_m365_fecha UNIQUE (fecha)
) ENGINE=InnoDB;

-- ============================================================
-- 08. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_operacion_microsoft (codigo, nombre) VALUES
('VERIFICAR_USERNAME', 'Verificar disponibilidad de username'),
('CREAR_USUARIO', 'Crear usuario'),
('ACTUALIZAR_USUARIO', 'Actualizar usuario'),
('HABILITAR_USUARIO', 'Habilitar usuario'),
('DESHABILITAR_USUARIO', 'Deshabilitar usuario'),
('ASIGNAR_LICENCIA', 'Asignar licencia'),
('RETIRAR_LICENCIA', 'Retirar licencia'),
('CONSULTAR_USUARIO', 'Consultar usuario'),
('CONSULTAR_LICENCIAS', 'Consultar licencias'),
('CAMBIAR_UPN', 'Cambiar User Principal Name'),
('RESET_PASSWORD_TEMPORAL', 'Generar contraseña temporal'),
('OTRA', 'Otra operación');

INSERT INTO estados_operacion_microsoft
(codigo, nombre, es_final, exitoso)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE),
('EXITOSA', 'Exitosa', TRUE, TRUE),
('ERROR', 'Error', FALSE, FALSE),
('REINTENTO', 'Reintento', FALSE, FALSE),
('CANCELADA', 'Cancelada', TRUE, FALSE);

INSERT INTO tipos_vinculo_microsoft (codigo, nombre) VALUES
('ESTUDIANTE', 'Vínculo de estudiante'),
('DOCENTE', 'Vínculo de docente'),
('ADMINISTRATIVO', 'Vínculo administrativo'),
('OTRO', 'Otro vínculo');

-- A1 Estudiante -> perfil ESTUDIANTE
INSERT INTO licencia_microsoft_perfiles
(tipo_licencia_id, perfil_id, es_predeterminada, prioridad)
SELECT l.id, p.id, TRUE, 10
FROM tipos_licencia_institucional l
JOIN proveedores_identidad pi
    ON pi.id = l.proveedor_identidad_id
JOIN perfiles p
    ON p.codigo = 'ESTUDIANTE'
WHERE pi.codigo = 'MICROSOFT_ENTRA'
  AND l.codigo = 'A1_ESTUDIANTE';

-- A1 Profesor -> perfil DOCENTE
INSERT INTO licencia_microsoft_perfiles
(tipo_licencia_id, perfil_id, es_predeterminada, prioridad)
SELECT l.id, p.id, TRUE, 10
FROM tipos_licencia_institucional l
JOIN proveedores_identidad pi
    ON pi.id = l.proveedor_identidad_id
JOIN perfiles p
    ON p.codigo = 'DOCENTE'
WHERE pi.codigo = 'MICROSOFT_ENTRA'
  AND l.codigo = 'A1_PROFESOR';

-- Administrativo:
-- no se fija licencia predeterminada hasta que la institución confirme
-- el SKU/política correspondiente.

-- ============================================================
-- 09. REGLAS DE APLICACIÓN
-- ============================================================
--
-- MODELO MAESTRO:
-- 002 controla identidad y ciclo de vida.
-- 022 NO crea una segunda solicitud/cuenta/licencia.
--
-- FLUJO:
--
-- RRHH / Académico
--      ↓
-- solicitudes_cuentas (002)
--      ↓
-- aprobación TIC
--      ↓
-- provisionamientos_cuenta (002)
--      ↓
-- operaciones_microsoft_365 (022)
--      ↓
-- Microsoft Graph
--      ↓
-- cuentas_institucionales + cuenta_licencias (002)
--
-- USERNAME:
-- solicitud_cuenta_usernames (002) es la única fuente de candidatos.
--
-- LICENCIAS:
-- tipos_licencia_institucional y cuenta_licencias (002) son maestros.
-- licencia_microsoft_perfiles solo define qué licencia corresponde
-- normalmente a cada perfil.
--
-- CICLO DE VIDA:
-- politicas_ciclo_cuenta y acciones_programadas_cuenta (002) son maestros.
--
-- Antes de ejecutar una desactivación:
--   consultar cuenta_microsoft_vinculos.
-- Si existe cualquier vínculo institucional vigente:
--   cancelar o posponer la baja.
--
-- GRADUADO:
-- 90 días (política 002).
--
-- EGRESADO:
-- 180 días (política 002).
--
-- INASISTENCIAS:
-- requiere revisión/revalidación antes de la baja.
--
-- PERSONA CON VARIOS PERFILES:
-- una cuenta institucional puede conservar múltiples vínculos activos.
-- Ejemplo estudiante + docente.
--
-- CONTRASEÑA:
-- no almacenar contraseña temporal.
-- forceChangePasswordNextSignIn se envía a Graph durante CREATE/RESET.
--
-- SECRETS:
-- tenant/client refs viven en configuraciones_proveedor_identidad (002)
-- y/o parámetros SECRET_REF del bloque 023.
--
-- ============================================================
-- FIN 022_integracion_microsoft_365_superarse_siga.sql
-- ============================================================
