-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 017_integracion_moodle.sql
-- Requiere bloques 001-016
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Integración formal SIGA <-> Moodle
--   - Una instancia Moodle institucional
--   - SSO con Microsoft / Entra ID
--   - Mapeo de usuarios SIGA con usuarios Moodle
--   - Mapeo de secciones SIGA con cursos Moodle
--   - Matrícula automática en Moodle desde matrícula SIGA confirmada
--   - Suspensión/reactivación de matrícula Moodle
--   - Sincronización de recursos evaluables
--   - Sincronización de calificaciones Moodle -> SIGA
--   - Correcciones oficiales SIGA -> Moodle
--   - Colas, reintentos, conflictos y auditoría
--   - No acoplar el SIGA directamente a tablas internas de Moodle
--
-- PRINCIPIOS:
--   - SIGA es maestro de identidad académica, matrícula y nota oficial.
--   - Moodle es el LMS operativo.
--   - Integración por Web Services / API.
--   - NO leer/escribir directamente tablas mdl_*.
--   - NO compartir base de datos funcional entre SIGA y Moodle.
--   - NO almacenar contraseñas Moodle/Microsoft en texto plano.
--   - Los secretos se referencian desde .env / Docker Secret / Secret Manager.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE INTEGRACIÓN
-- ============================================================

CREATE TABLE estados_instancia_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_sincronizacion BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_instancia_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_mapeo_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    sincronizable BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_mapeo_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_operacion_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    direccion VARCHAR(30) NOT NULL, -- SIGA_A_MOODLE / MOODLE_A_SIGA / BIDIRECCIONAL
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_operacion_moodle_codigo UNIQUE (codigo),
    CONSTRAINT chk_tipo_operacion_moodle_direccion CHECK (
        direccion IN ('SIGA_A_MOODLE', 'MOODLE_A_SIGA', 'BIDIRECCIONAL')
    )
) ENGINE=InnoDB;

CREATE TABLE estados_sincronizacion_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_sync_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_entidad_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_entidad_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_matricula_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_acceso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_matricula_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_conflicto_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_conflicto_moodle_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. INSTANCIA MOODLE
-- Aunque hoy existe una sola, se modela escalable.
-- ============================================================

CREATE TABLE instancias_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    estado_instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    base_url VARCHAR(255) NOT NULL,

    -- Referencias seguras, nunca token en texto plano.
    webservice_token_secret_ref VARCHAR(190) NULL,

    servicio_web_nombre VARCHAR(120) NULL,

    version_moodle VARCHAR(60) NULL,

    usar_sso_microsoft BOOLEAN NOT NULL DEFAULT TRUE,
    auth_plugin VARCHAR(100) NULL,

    es_principal BOOLEAN NOT NULL DEFAULT TRUE,

    ultima_verificacion_at DATETIME NULL,
    ultima_sincronizacion_at DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_instancia_moodle_codigo UNIQUE (codigo),

    CONSTRAINT fk_im_estado
        FOREIGN KEY (estado_instancia_moodle_id) REFERENCES estados_instancia_moodle(id)
) ENGINE=InnoDB;

-- La aplicación debe garantizar una sola instancia es_principal=TRUE.

-- ============================================================
-- 03. CONFIGURACIÓN DE SSO MOODLE
-- ============================================================

CREATE TABLE configuraciones_sso_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    proveedor_identidad_id BIGINT UNSIGNED NOT NULL,

    tipo_sso VARCHAR(40) NOT NULL DEFAULT 'OIDC',

    tenant_id VARCHAR(100) NULL,
    client_id_secret_ref VARCHAR(190) NULL,
    client_secret_ref VARCHAR(190) NULL,

    username_claim VARCHAR(120) NULL,
    email_claim VARCHAR(120) NULL,
    object_id_claim VARCHAR(120) NULL,

    crear_usuario_al_primer_login BOOLEAN NOT NULL DEFAULT FALSE,
    permitir_login_local BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_config_sso_moodle_instancia UNIQUE (instancia_moodle_id),

    CONSTRAINT fk_csm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_csm_proveedor
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id),

    CONSTRAINT chk_csm_tipo CHECK (
        tipo_sso IN ('OIDC', 'OAUTH2', 'SAML', 'OTRO')
    )
) ENGINE=InnoDB;

-- Recomendación institucional:
-- Moodle NO debe usar la misma contraseña local de Microsoft.
-- El usuario ingresa con Microsoft SSO.
-- El username institucional se conserva como identificador académico.

-- ============================================================
-- 04. MAPEO DE USUARIOS SIGA <-> MOODLE
-- ============================================================

CREATE TABLE usuario_moodle_mapeos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,
    cuenta_institucional_id BIGINT UNSIGNED NULL,

    estado_mapeo_moodle_id BIGINT UNSIGNED NOT NULL,

    moodle_user_id BIGINT UNSIGNED NOT NULL,

    username_moodle VARCHAR(190) NOT NULL,
    email_moodle VARCHAR(190) NULL,

    auth_moodle VARCHAR(100) NULL,

    fecha_creacion_moodle DATETIME NULL,
    ultima_sincronizacion_at DATETIME NULL,

    suspendido BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_usuario_moodle_usuario
        UNIQUE (instancia_moodle_id, usuario_id),

    CONSTRAINT uq_usuario_moodle_external
        UNIQUE (instancia_moodle_id, moodle_user_id),

    CONSTRAINT fk_umm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_umm_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_umm_cuenta_institucional
        FOREIGN KEY (cuenta_institucional_id) REFERENCES cuentas_institucionales(id),
    CONSTRAINT fk_umm_estado
        FOREIGN KEY (estado_mapeo_moodle_id) REFERENCES estados_mapeo_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_umm_username
ON usuario_moodle_mapeos (username_moodle);

-- ============================================================
-- 05. CATEGORÍAS MOODLE
-- ============================================================

CREATE TABLE categoria_moodle_mapeos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    carrera_id BIGINT UNSIGNED NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    moodle_category_id BIGINT UNSIGNED NOT NULL,

    nombre_moodle VARCHAR(255) NULL,

    estado_mapeo_moodle_id BIGINT UNSIGNED NOT NULL,

    ultima_sincronizacion_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_categoria_moodle_external
        UNIQUE (instancia_moodle_id, moodle_category_id),

    CONSTRAINT fk_cmm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_cmm_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_cmm_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_cmm_estado
        FOREIGN KEY (estado_mapeo_moodle_id) REFERENCES estados_mapeo_moodle(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. MAPEO DE SECCIONES SIGA <-> CURSOS MOODLE
-- ============================================================

CREATE TABLE curso_moodle_mapeos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    seccion_id BIGINT UNSIGNED NOT NULL,

    estado_mapeo_moodle_id BIGINT UNSIGNED NOT NULL,

    moodle_course_id BIGINT UNSIGNED NOT NULL,
    moodle_category_id BIGINT UNSIGNED NULL,

    shortname_moodle VARCHAR(255) NOT NULL,
    fullname_moodle VARCHAR(255) NOT NULL,
    idnumber_moodle VARCHAR(255) NULL,

    fecha_creacion_moodle DATETIME NULL,
    ultima_sincronizacion_at DATETIME NULL,

    visible BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_curso_moodle_seccion
        UNIQUE (instancia_moodle_id, seccion_id),

    CONSTRAINT uq_curso_moodle_external
        UNIQUE (instancia_moodle_id, moodle_course_id),

    CONSTRAINT fk_cmm2_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_cmm2_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_cmm2_estado
        FOREIGN KEY (estado_mapeo_moodle_id) REFERENCES estados_mapeo_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_cmm2_shortname
ON curso_moodle_mapeos (shortname_moodle);

-- ============================================================
-- 07. ROLES MOODLE
-- ============================================================

CREATE TABLE roles_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,

    moodle_role_id BIGINT UNSIGNED NULL,
    moodle_shortname VARCHAR(100) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_rol_moodle_codigo
        UNIQUE (instancia_moodle_id, codigo),

    CONSTRAINT fk_rm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id)
) ENGINE=InnoDB;

-- ============================================================
-- 08. MATRÍCULAS SIGA -> MOODLE
-- ============================================================

CREATE TABLE matricula_moodle_mapeos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    curso_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,
    usuario_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,

    rol_moodle_id BIGINT UNSIGNED NOT NULL,
    estado_matricula_moodle_id BIGINT UNSIGNED NOT NULL,

    moodle_enrolment_id BIGINT UNSIGNED NULL,

    fecha_matricula_moodle DATETIME NULL,
    fecha_suspension_moodle DATETIME NULL,
    fecha_reactivacion_moodle DATETIME NULL,

    ultima_sincronizacion_at DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_matricula_moodle_ma
        UNIQUE (instancia_moodle_id, matricula_asignatura_id),

    CONSTRAINT fk_mmm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_mmm_matricula_asignatura
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_mmm_curso
        FOREIGN KEY (curso_moodle_mapeo_id) REFERENCES curso_moodle_mapeos(id),
    CONSTRAINT fk_mmm_usuario
        FOREIGN KEY (usuario_moodle_mapeo_id) REFERENCES usuario_moodle_mapeos(id),
    CONSTRAINT fk_mmm_rol
        FOREIGN KEY (rol_moodle_id) REFERENCES roles_moodle(id),
    CONSTRAINT fk_mmm_estado
        FOREIGN KEY (estado_matricula_moodle_id) REFERENCES estados_matricula_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_mmm_estado
ON matricula_moodle_mapeos (estado_matricula_moodle_id, activo);

-- ============================================================
-- 09. DOCENTES SIGA -> MOODLE
-- ============================================================

CREATE TABLE docente_moodle_asignaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    seccion_docente_id BIGINT UNSIGNED NOT NULL,
    curso_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,
    usuario_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,
    rol_moodle_id BIGINT UNSIGNED NOT NULL,

    moodle_enrolment_id BIGINT UNSIGNED NULL,

    fecha_asignacion_moodle DATETIME NULL,
    fecha_retiro_moodle DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_docente_moodle_asignacion
        UNIQUE (instancia_moodle_id, seccion_docente_id),

    CONSTRAINT fk_dma_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_dma_seccion_docente
        FOREIGN KEY (seccion_docente_id) REFERENCES seccion_docentes(id),
    CONSTRAINT fk_dma_curso
        FOREIGN KEY (curso_moodle_mapeo_id) REFERENCES curso_moodle_mapeos(id),
    CONSTRAINT fk_dma_usuario
        FOREIGN KEY (usuario_moodle_mapeo_id) REFERENCES usuario_moodle_mapeos(id),
    CONSTRAINT fk_dma_rol
        FOREIGN KEY (rol_moodle_id) REFERENCES roles_moodle(id)
) ENGINE=InnoDB;

-- ============================================================
-- 10. RECURSOS MOODLE
-- Completa el modelo de recursos_evaluables del bloque 008.
-- ============================================================

CREATE TABLE recurso_moodle_mapeos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    recurso_evaluable_id BIGINT UNSIGNED NOT NULL,
    curso_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,

    estado_mapeo_moodle_id BIGINT UNSIGNED NOT NULL,

    moodle_course_module_id BIGINT UNSIGNED NULL,
    moodle_instance_id BIGINT UNSIGNED NULL,
    moodle_grade_item_id BIGINT UNSIGNED NULL,

    modulo_moodle VARCHAR(80) NULL,

    nombre_moodle VARCHAR(255) NULL,

    ultima_sincronizacion_at DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_recurso_moodle_recurso
        UNIQUE (instancia_moodle_id, recurso_evaluable_id),

    CONSTRAINT uq_recurso_moodle_coursemodule
        UNIQUE (instancia_moodle_id, moodle_course_module_id),

    CONSTRAINT fk_rmm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_rmm_recurso
        FOREIGN KEY (recurso_evaluable_id) REFERENCES recursos_evaluables(id),
    CONSTRAINT fk_rmm_curso
        FOREIGN KEY (curso_moodle_mapeo_id) REFERENCES curso_moodle_mapeos(id),
    CONSTRAINT fk_rmm_estado
        FOREIGN KEY (estado_mapeo_moodle_id) REFERENCES estados_mapeo_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_rmm_grade_item
ON recurso_moodle_mapeos (moodle_grade_item_id);

-- ============================================================
-- 11. CALIFICACIONES MOODLE
-- Snapshot técnico de la última nota recibida.
-- La nota oficial sigue en 008.
-- ============================================================

CREATE TABLE calificacion_moodle_snapshots (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    recurso_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,
    usuario_moodle_mapeo_id BIGINT UNSIGNED NOT NULL,
    calificacion_recurso_id BIGINT UNSIGNED NULL,

    moodle_grade_id BIGINT UNSIGNED NULL,

    rawgrade DECIMAL(12,5) NULL,
    finalgrade DECIMAL(12,5) NULL,
    grademax DECIMAL(12,5) NULL,

    feedback TEXT NULL,

    timecreated_moodle BIGINT UNSIGNED NULL,
    timemodified_moodle BIGINT UNSIGNED NULL,

    recibido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    hash_payload CHAR(64) NULL,

    CONSTRAINT uq_calificacion_moodle_snapshot
        UNIQUE (instancia_moodle_id, recurso_moodle_mapeo_id, usuario_moodle_mapeo_id),

    CONSTRAINT fk_cms_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_cms_recurso
        FOREIGN KEY (recurso_moodle_mapeo_id) REFERENCES recurso_moodle_mapeos(id),
    CONSTRAINT fk_cms_usuario
        FOREIGN KEY (usuario_moodle_mapeo_id) REFERENCES usuario_moodle_mapeos(id),
    CONSTRAINT fk_cms_calificacion
        FOREIGN KEY (calificacion_recurso_id) REFERENCES calificaciones_recursos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 12. EVENTOS DE INTEGRACIÓN
-- ============================================================

CREATE TABLE eventos_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_entidad_moodle_id BIGINT UNSIGNED NOT NULL,

    entidad_local_id BIGINT UNSIGNED NULL,
    entidad_moodle_id BIGINT UNSIGNED NULL,

    evento_codigo VARCHAR(80) NOT NULL,

    payload_json JSON NULL,

    recibido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    procesado BOOLEAN NOT NULL DEFAULT FALSE,
    procesado_at DATETIME NULL,

    error_mensaje TEXT NULL,

    CONSTRAINT fk_em_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_em_tipo_entidad
        FOREIGN KEY (tipo_entidad_moodle_id) REFERENCES tipos_entidad_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_eventos_moodle_pendientes
ON eventos_moodle (procesado, recibido_at);

-- ============================================================
-- 13. COLA GENERAL DE SINCRONIZACIÓN
-- ============================================================

CREATE TABLE sincronizaciones_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_operacion_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_entidad_moodle_id BIGINT UNSIGNED NOT NULL,
    estado_sincronizacion_moodle_id BIGINT UNSIGNED NOT NULL,

    entidad_local_id BIGINT UNSIGNED NULL,
    entidad_moodle_id BIGINT UNSIGNED NULL,

    request_uuid CHAR(36) NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 100,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    payload_json JSON NULL,
    respuesta_json JSON NULL,

    http_status SMALLINT UNSIGNED NULL,
    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_sync_moodle_request_uuid UNIQUE (request_uuid),

    CONSTRAINT fk_sm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_sm_operacion
        FOREIGN KEY (tipo_operacion_moodle_id) REFERENCES tipos_operacion_moodle(id),
    CONSTRAINT fk_sm_entidad
        FOREIGN KEY (tipo_entidad_moodle_id) REFERENCES tipos_entidad_moodle(id),
    CONSTRAINT fk_sm_estado
        FOREIGN KEY (estado_sincronizacion_moodle_id) REFERENCES estados_sincronizacion_moodle(id)
) ENGINE=InnoDB;

CREATE INDEX idx_sync_moodle_cola
ON sincronizaciones_moodle
(estado_sincronizacion_moodle_id, prioridad, fecha_programada, proximo_reintento_at);

-- ============================================================
-- 14. CURSORES DE SINCRONIZACIÓN
-- Evita recorrer Moodle completo en cada ejecución.
-- ============================================================

CREATE TABLE cursores_sincronizacion_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_entidad_moodle_id BIGINT UNSIGNED NOT NULL,

    cursor_valor VARCHAR(255) NULL,
    ultima_fecha_externa BIGINT UNSIGNED NULL,

    ultima_ejecucion_at DATETIME NULL,
    ultima_ejecucion_exitosa_at DATETIME NULL,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_cursor_moodle
        UNIQUE (instancia_moodle_id, tipo_entidad_moodle_id),

    CONSTRAINT fk_csm2_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_csm2_entidad
        FOREIGN KEY (tipo_entidad_moodle_id) REFERENCES tipos_entidad_moodle(id)
) ENGINE=InnoDB;

-- ============================================================
-- 15. CONFLICTOS DE INTEGRACIÓN
-- ============================================================

CREATE TABLE conflictos_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_conflicto_moodle_id BIGINT UNSIGNED NOT NULL,
    tipo_entidad_moodle_id BIGINT UNSIGNED NOT NULL,

    entidad_local_id BIGINT UNSIGNED NULL,
    entidad_moodle_id BIGINT UNSIGNED NULL,

    titulo VARCHAR(200) NOT NULL,
    detalle TEXT NOT NULL,

    valor_siga_json JSON NULL,
    valor_moodle_json JSON NULL,

    resuelto BOOLEAN NOT NULL DEFAULT FALSE,

    resuelto_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_resolucion DATETIME NULL,
    observacion_resolucion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cm_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_cm_tipo
        FOREIGN KEY (tipo_conflicto_moodle_id) REFERENCES tipos_conflicto_moodle(id),
    CONSTRAINT fk_cm_entidad
        FOREIGN KEY (tipo_entidad_moodle_id) REFERENCES tipos_entidad_moodle(id),
    CONSTRAINT fk_cm_usuario
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_conflictos_moodle_pendientes
ON conflictos_moodle (resuelto, created_at);

-- ============================================================
-- 16. POLÍTICA DE SINCRONIZACIÓN
-- Versionada para conservar comportamiento histórico.
-- ============================================================

CREATE TABLE politicas_sincronizacion_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    sincronizar_usuarios BOOLEAN NOT NULL DEFAULT TRUE,
    sincronizar_cursos BOOLEAN NOT NULL DEFAULT TRUE,
    sincronizar_matriculas BOOLEAN NOT NULL DEFAULT TRUE,
    sincronizar_docentes BOOLEAN NOT NULL DEFAULT TRUE,
    sincronizar_recursos BOOLEAN NOT NULL DEFAULT TRUE,
    sincronizar_calificaciones BOOLEAN NOT NULL DEFAULT TRUE,

    suspender_matricula_por_bloqueo_financiero BOOLEAN NOT NULL DEFAULT TRUE,

    intervalo_minutos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_politica_sync_moodle_codigo UNIQUE (codigo),

    CONSTRAINT chk_psm_intervalo CHECK (
        intervalo_minutos >= 1
    ),
    CONSTRAINT chk_psm_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 17. AUDITORÍA FUNCIONAL DE CAMBIOS DE INTEGRACIÓN
-- ============================================================

CREATE TABLE historial_integracion_moodle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    instancia_moodle_id BIGINT UNSIGNED NOT NULL,

    entidad VARCHAR(80) NOT NULL,
    entidad_local_id BIGINT UNSIGNED NULL,
    entidad_moodle_id BIGINT UNSIGNED NULL,

    accion VARCHAR(80) NOT NULL,

    ejecutado_por_usuario_id BIGINT UNSIGNED NULL,

    detalle TEXT NULL,
    datos_json JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_him_instancia
        FOREIGN KEY (instancia_moodle_id) REFERENCES instancias_moodle(id),
    CONSTRAINT fk_him_usuario
        FOREIGN KEY (ejecutado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_him_entidad_fecha
ON historial_integracion_moodle (entidad, entidad_local_id, created_at);

-- ============================================================
-- 18. DATOS INICIALES
-- ============================================================

INSERT INTO estados_instancia_moodle
(codigo, nombre, permite_sincronizacion)
VALUES
('ACTIVA', 'Activa', TRUE),
('MANTENIMIENTO', 'Mantenimiento', FALSE),
('INACTIVA', 'Inactiva', FALSE),
('ERROR', 'Error', FALSE);

INSERT INTO estados_mapeo_moodle
(codigo, nombre, sincronizable, es_final)
VALUES
('PENDIENTE', 'Pendiente', TRUE, FALSE),
('SINCRONIZADO', 'Sincronizado', TRUE, FALSE),
('DESACTUALIZADO', 'Desactualizado', TRUE, FALSE),
('ERROR', 'Error', TRUE, FALSE),
('DESVINCULADO', 'Desvinculado', FALSE, TRUE);

INSERT INTO estados_sincronizacion_moodle
(codigo, nombre, es_final, exitoso)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE),
('EXITOSA', 'Exitosa', TRUE, TRUE),
('ERROR', 'Error', FALSE, FALSE),
('REINTENTO', 'Reintento', FALSE, FALSE),
('CONFLICTO', 'Conflicto', FALSE, FALSE),
('CANCELADA', 'Cancelada', TRUE, FALSE);

INSERT INTO tipos_entidad_moodle (codigo, nombre) VALUES
('USUARIO', 'Usuario'),
('CATEGORIA', 'Categoría'),
('CURSO', 'Curso'),
('MATRICULA_ESTUDIANTE', 'Matrícula de estudiante'),
('MATRICULA_DOCENTE', 'Asignación de docente'),
('RECURSO', 'Recurso evaluable'),
('CALIFICACION', 'Calificación'),
('SSO', 'SSO');

INSERT INTO tipos_operacion_moodle
(codigo, nombre, direccion)
VALUES
('CREAR_USUARIO', 'Crear usuario Moodle', 'SIGA_A_MOODLE'),
('ACTUALIZAR_USUARIO', 'Actualizar usuario Moodle', 'SIGA_A_MOODLE'),
('SUSPENDER_USUARIO', 'Suspender usuario Moodle', 'SIGA_A_MOODLE'),
('REACTIVAR_USUARIO', 'Reactivar usuario Moodle', 'SIGA_A_MOODLE'),

('CREAR_CURSO', 'Crear curso Moodle', 'SIGA_A_MOODLE'),
('ACTUALIZAR_CURSO', 'Actualizar curso Moodle', 'SIGA_A_MOODLE'),

('MATRICULAR_ESTUDIANTE', 'Matricular estudiante en Moodle', 'SIGA_A_MOODLE'),
('SUSPENDER_MATRICULA', 'Suspender matrícula Moodle', 'SIGA_A_MOODLE'),
('REACTIVAR_MATRICULA', 'Reactivar matrícula Moodle', 'SIGA_A_MOODLE'),
('RETIRAR_MATRICULA', 'Retirar matrícula Moodle', 'SIGA_A_MOODLE'),

('ASIGNAR_DOCENTE', 'Asignar docente al curso', 'SIGA_A_MOODLE'),
('RETIRAR_DOCENTE', 'Retirar docente del curso', 'SIGA_A_MOODLE'),

('IMPORTAR_RECURSOS', 'Importar recursos Moodle', 'MOODLE_A_SIGA'),
('IMPORTAR_CALIFICACIONES', 'Importar calificaciones Moodle', 'MOODLE_A_SIGA'),
('ACTUALIZAR_CALIFICACION_OFICIAL', 'Enviar corrección oficial a Moodle', 'SIGA_A_MOODLE'),

('VERIFICAR_SSO', 'Verificar configuración SSO', 'BIDIRECCIONAL');

INSERT INTO estados_matricula_moodle
(codigo, nombre, permite_acceso)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('ACTIVA', 'Activa', TRUE),
('SUSPENDIDA_FINANCIERO', 'Suspendida por financiero', FALSE),
('SUSPENDIDA_ACADEMICO', 'Suspendida por académico', FALSE),
('RETIRADA', 'Retirada', FALSE),
('ERROR', 'Error', FALSE);

INSERT INTO tipos_conflicto_moodle (codigo, nombre) VALUES
('USUARIO_DUPLICADO', 'Usuario duplicado'),
('CURSO_DUPLICADO', 'Curso duplicado'),
('MATRICULA_INCONSISTENTE', 'Matrícula inconsistente'),
('RECURSO_NO_ENCONTRADO', 'Recurso no encontrado'),
('NOTA_DIFERENTE_OFICIAL', 'Moodle difiere de nota oficial SIGA'),
('MAPEO_INVALIDO', 'Mapeo inválido'),
('OTRO', 'Otro');

-- Instancia Moodle institucional.
INSERT INTO instancias_moodle
(
    codigo,
    nombre,
    estado_instancia_moodle_id,
    base_url,
    webservice_token_secret_ref,
    servicio_web_nombre,
    usar_sso_microsoft,
    auth_plugin,
    es_principal
)
SELECT
    'MOODLE_SUPERARSE',
    'Moodle Institucional Superarse',
    e.id,
    'https://aulasists.superarse.edu.ec',
    'MOODLE_WEBSERVICE_TOKEN',
    'SIGA Integration',
    TRUE,
    'oidc',
    TRUE
FROM estados_instancia_moodle e
WHERE e.codigo='ACTIVA';

-- Configuración SSO enlazada al proveedor Microsoft ya creado en 002.
INSERT INTO configuraciones_sso_moodle
(
    instancia_moodle_id,
    proveedor_identidad_id,
    tipo_sso,
    username_claim,
    email_claim,
    object_id_claim,
    crear_usuario_al_primer_login,
    permitir_login_local
)
SELECT
    im.id,
    pi.id,
    'OIDC',
    'preferred_username',
    'email',
    'oid',
    FALSE,
    FALSE
FROM instancias_moodle im
JOIN proveedores_identidad pi
  ON pi.codigo='MICROSOFT_ENTRA'
WHERE im.codigo='MOODLE_SUPERARSE';

-- Roles Moodle base.
INSERT INTO roles_moodle
(instancia_moodle_id, codigo, nombre, moodle_shortname)
SELECT id, 'ESTUDIANTE', 'Estudiante', 'student'
FROM instancias_moodle WHERE codigo='MOODLE_SUPERARSE';

INSERT INTO roles_moodle
(instancia_moodle_id, codigo, nombre, moodle_shortname)
SELECT id, 'DOCENTE', 'Docente', 'editingteacher'
FROM instancias_moodle WHERE codigo='MOODLE_SUPERARSE';

-- Política actual.
INSERT INTO politicas_sincronizacion_moodle
(
    codigo,
    nombre,
    sincronizar_usuarios,
    sincronizar_cursos,
    sincronizar_matriculas,
    sincronizar_docentes,
    sincronizar_recursos,
    sincronizar_calificaciones,
    suspender_matricula_por_bloqueo_financiero,
    intervalo_minutos,
    vigente_desde
)
VALUES
(
    'SYNC_MOODLE_GENERAL_2026',
    'Política General de Sincronización Moodle',
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    5,
    '2026-01-01'
);

-- ============================================================
-- 19. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ARQUITECTURA:
--
--       MICROSOFT ENTRA ID
--              ↓ SSO
--          USUARIO
--              ↓
--             SIGA
--              ↓ API
--           MOODLE
--
-- SIGA y Moodle NO comparten tablas.
--
-- ------------------------------------------------------------
-- USUARIO:
-- ------------------------------------------------------------
-- 1. TIC aprueba la creación institucional (002).
-- 2. Se crea cuenta Microsoft y usuario SIGA.
-- 3. SIGA crea/sincroniza usuario Moodle vía Web Services.
-- 4. username_moodle debe corresponder al username institucional:
--      remigio.vargas
-- 5. El acceso se realiza por Microsoft SSO.
-- 6. No copiar la contraseña Microsoft a Moodle.
--
-- ------------------------------------------------------------
-- CURSOS:
-- ------------------------------------------------------------
-- 1. Académico crea oferta y sección en SIGA.
-- 2. SIGA crea o relaciona curso Moodle.
-- 3. curso_moodle_mapeos conserva el ID externo estable.
--
-- ------------------------------------------------------------
-- DOCENTES:
-- ------------------------------------------------------------
-- 1. Docente asignado en seccion_docentes.
-- 2. SIGA crea/valida usuario Moodle.
-- 3. Se matricula con rol editingteacher.
--
-- ------------------------------------------------------------
-- ESTUDIANTES:
-- ------------------------------------------------------------
-- 1. Matrícula confirmada en SIGA.
-- 2. Financiero debe habilitar cuando aplique.
-- 3. SIGA crea operación MATRICULAR_ESTUDIANTE.
-- 4. Moodle recibe matrícula.
--
-- Si Financiero bloquea:
--   SIGA NO elimina la matrícula.
--   Moodle -> SUSPENDIDA_FINANCIERO.
--
-- Cuando regulariza:
--   Moodle -> ACTIVA nuevamente.
--
-- De esta forma se conserva histórico.
--
-- ------------------------------------------------------------
-- RECURSOS:
-- ------------------------------------------------------------
-- 1. Docente crea tarea/cuestionario/etc. en Moodle.
-- 2. Sincronizador obtiene recursos nuevos/modificados.
-- 3. Crea/actualiza recursos_evaluables (008).
-- 4. recurso_moodle_mapeos guarda IDs Moodle.
-- 5. Docente en SIGA:
--
--      Docente
--        -> Mis cursos
--        -> Evaluación
--        -> Recursos Moodle
--        -> Seleccionar recurso
--        -> Seleccionar parámetro disponible
--
-- 6. recurso_parametro_evaluacion impide repetir parámetro.
--
-- ------------------------------------------------------------
-- CALIFICACIONES:
-- ------------------------------------------------------------
-- Flujo ordinario:
--
--      Moodle
--        ↓
--      snapshot técnico
--        ↓
--      calificaciones_recursos
--        ↓
--      consolidación SIGA
--
-- Moodle no se convierte en maestro del histórico oficial.
--
-- ------------------------------------------------------------
-- CAMBIO EXCEPCIONAL DE NOTA:
-- ------------------------------------------------------------
-- 1. Parcial cerrado.
-- 2. Docente solicita cambio en SIGA.
-- 3. Académico aprueba.
-- 4. SIGA cambia nota oficial.
-- 5. Crea operación ACTUALIZAR_CALIFICACION_OFICIAL.
-- 6. SIGA -> Moodle.
--
-- Si Moodle devuelve después una nota diferente:
--   NO sobrescribir la corrección oficial.
--   Crear conflicto NOTA_DIFERENTE_OFICIAL.
--
-- ------------------------------------------------------------
-- SINCRONIZACIÓN:
-- ------------------------------------------------------------
-- - Cron/worker sugerido: cada 5 minutos.
-- - Preferir webhooks/eventos cuando Moodle permita extenderlos.
-- - Usar cursores para sincronización incremental.
-- - Reintentar automáticamente errores transitorios.
-- - Nunca perder matrícula/notas SIGA por una caída de Moodle.
--
-- ------------------------------------------------------------
-- SEGURIDAD:
-- ------------------------------------------------------------
-- - Moodle Web Service token en secreto externo.
-- - Microsoft client secret en secreto externo.
-- - HTTPS obligatorio.
-- - Cuenta de servicio con permisos mínimos.
-- - Registrar toda operación administrativa.
--
-- ------------------------------------------------------------
-- UNA SOLA INSTANCIA:
-- ------------------------------------------------------------
-- Actualmente Superarse utiliza una única instancia Moodle.
-- El modelo permite crecer a más instancias en el futuro sin migrar
-- toda la base, pero la aplicación tratará MOODLE_SUPERARSE como principal.
--
-- ============================================================
-- FIN 017_integracion_moodle.sql
-- ============================================================
