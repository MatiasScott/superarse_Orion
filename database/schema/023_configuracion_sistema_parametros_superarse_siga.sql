-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 023_configuracion_sistema_parametros.sql
-- Requiere bloques 001-022
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Centralizar configuraciones generales del ERP
--   - Evitar valores críticos escritos directamente en PHP
--   - Parámetros por módulo, institución, sede y período
--   - Versionado histórico de parámetros
--   - Secuencias y numeraciones institucionales
--   - Feature flags / activación de funcionalidades
--   - Ventanas operativas y reglas configurables
--   - Configuración de archivos, exportaciones y límites
--   - Parámetros de seguridad, notificaciones e integraciones
--
-- PRINCIPIOS:
--   - Todo valor que pueda cambiar debe ser configurable o versionado.
--   - Los parámetros críticos deben tener histórico.
--   - Los secretos NO se guardan aquí; solo referencias a secretos externos.
--   - La aplicación debe validar tipo de dato y alcance antes de aplicar un valor.
--   - Un parámetro puede tener valor global y override por sede/período/módulo.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE CONFIGURACIÓN
-- ============================================================

CREATE TABLE tipos_parametro_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    permite_json BOOLEAN NOT NULL DEFAULT FALSE,
    permite_secreto_ref BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_parametro_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE alcances_parametro_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(140) NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_alcance_parametro_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_configuracion_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    aplicable BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_configuracion_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE categorias_configuracion_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,

    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_categoria_config_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_secuencia_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,

    reinicia_anual BOOLEAN NOT NULL DEFAULT FALSE,
    reinicia_periodo BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_secuencia_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_feature_flag (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    habilitado BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_feature_flag_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. PARÁMETROS DEL SISTEMA
-- ============================================================

CREATE TABLE parametros_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    categoria_configuracion_sistema_id BIGINT UNSIGNED NOT NULL,
    tipo_parametro_sistema_id BIGINT UNSIGNED NOT NULL,
    alcance_parametro_sistema_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    modulo VARCHAR(80) NULL,

    valor_defecto_texto TEXT NULL,
    valor_defecto_json JSON NULL,
    secreto_ref_defecto VARCHAR(190) NULL,

    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,
    editable_desde_ui BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_reinicio BOOLEAN NOT NULL DEFAULT FALSE,
    sensible BOOLEAN NOT NULL DEFAULT FALSE,

    validacion_json JSON NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_parametro_sistema_codigo UNIQUE (codigo),

    CONSTRAINT fk_ps_categoria
        FOREIGN KEY (categoria_configuracion_sistema_id) REFERENCES categorias_configuracion_sistema(id),
    CONSTRAINT fk_ps_tipo
        FOREIGN KEY (tipo_parametro_sistema_id) REFERENCES tipos_parametro_sistema(id),
    CONSTRAINT fk_ps_alcance
        FOREIGN KEY (alcance_parametro_sistema_id) REFERENCES alcances_parametro_sistema(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ps_modulo_activo
ON parametros_sistema (modulo, activo);

-- ============================================================
-- 03. VALORES VERSIONADOS DE PARÁMETROS
-- ============================================================

CREATE TABLE parametro_sistema_valores (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    parametro_sistema_id BIGINT UNSIGNED NOT NULL,
    estado_configuracion_sistema_id BIGINT UNSIGNED NOT NULL,

    numero_version INT UNSIGNED NOT NULL,

    sede_id BIGINT UNSIGNED NULL,
    sede_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(sede_id, 0)) STORED,
    periodo_academico_id BIGINT UNSIGNED NULL,
    periodo_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(periodo_academico_id, 0)) STORED,
    carrera_id BIGINT UNSIGNED NULL,
    carrera_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(carrera_id, 0)) STORED,

    valor_texto TEXT NULL,
    valor_json JSON NULL,
    secreto_ref VARCHAR(190) NULL,

    vigente_desde DATETIME NOT NULL,
    vigente_hasta DATETIME NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_aprobacion DATETIME NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_psv_version
        UNIQUE (
            parametro_sistema_id,
            numero_version,
            sede_key,
            periodo_key,
            carrera_key
        ),

    CONSTRAINT fk_psv_parametro
        FOREIGN KEY (parametro_sistema_id) REFERENCES parametros_sistema(id),
    CONSTRAINT fk_psv_estado
        FOREIGN KEY (estado_configuracion_sistema_id) REFERENCES estados_configuracion_sistema(id),
    CONSTRAINT fk_psv_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_psv_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_psv_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_psv_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_psv_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_psv_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_psv_contexto_vigencia
ON parametro_sistema_valores
(parametro_sistema_id, sede_id, periodo_academico_id, carrera_id, vigente_desde);

-- ============================================================
-- 04. RESOLUCIÓN EFECTIVA DE PARÁMETROS
-- Cache del valor vigente resuelto por contexto.
-- ============================================================

CREATE TABLE parametros_sistema_resueltos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    parametro_sistema_id BIGINT UNSIGNED NOT NULL,

    sede_id BIGINT UNSIGNED NULL,
    sede_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(sede_id, 0)) STORED,
    periodo_academico_id BIGINT UNSIGNED NULL,
    periodo_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(periodo_academico_id, 0)) STORED,
    carrera_id BIGINT UNSIGNED NULL,
    carrera_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(carrera_id, 0)) STORED,

    valor_texto TEXT NULL,
    valor_json JSON NULL,
    secreto_ref VARCHAR(190) NULL,

    fuente_valor VARCHAR(50) NOT NULL, -- DEFAULT / GLOBAL / SEDE / PERIODO / CARRERA / COMBINADO

    parametro_sistema_valor_id BIGINT UNSIGNED NULL,

    resuelto_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psr_parametro
        FOREIGN KEY (parametro_sistema_id) REFERENCES parametros_sistema(id),
    CONSTRAINT fk_psr_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_psr_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_psr_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_psr_valor
        FOREIGN KEY (parametro_sistema_valor_id) REFERENCES parametro_sistema_valores(id),

    CONSTRAINT uq_psr_contexto
        UNIQUE (parametro_sistema_id, sede_key, periodo_key, carrera_key)
) ENGINE=InnoDB;

CREATE INDEX idx_psr_contexto
ON parametros_sistema_resueltos
(parametro_sistema_id, sede_id, periodo_academico_id, carrera_id);

-- ============================================================
-- 05. SECUENCIAS / NUMERACIONES
-- ============================================================

CREATE TABLE secuencias_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_secuencia_sistema_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    prefijo VARCHAR(50) NULL,
    sufijo VARCHAR(50) NULL,

    longitud_numero SMALLINT UNSIGNED NOT NULL DEFAULT 6,

    siguiente_valor BIGINT UNSIGNED NOT NULL DEFAULT 1,

    anio_actual SMALLINT UNSIGNED NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    formato VARCHAR(190) NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_secuencia_sistema_codigo UNIQUE (codigo),

    CONSTRAINT fk_ss_tipo
        FOREIGN KEY (tipo_secuencia_sistema_id) REFERENCES tipos_secuencia_sistema(id),
    CONSTRAINT fk_ss_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),

    CONSTRAINT chk_ss_longitud CHECK (
        longitud_numero BETWEEN 1 AND 18
    )
) ENGINE=InnoDB;

-- Ejemplos:
-- SOL-{YYYY}-{SEQ}
-- CERT-{YYYY}-{SEQ}
-- MAT-{PERIODO}-{SEQ}
-- TIT-{YYYY}-{SEQ}

CREATE TABLE historial_secuencias_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    secuencia_sistema_id BIGINT UNSIGNED NOT NULL,

    valor_generado BIGINT UNSIGNED NOT NULL,
    numero_formateado VARCHAR(190) NOT NULL,

    entidad VARCHAR(80) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    generado_por_usuario_id BIGINT UNSIGNED NULL,

    generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_historial_secuencia_numero UNIQUE (numero_formateado),

    CONSTRAINT fk_hss_secuencia
        FOREIGN KEY (secuencia_sistema_id) REFERENCES secuencias_sistema(id),
    CONSTRAINT fk_hss_usuario
        FOREIGN KEY (generado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. FEATURE FLAGS
-- ============================================================

CREATE TABLE feature_flags (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,

    estado_feature_flag_id BIGINT UNSIGNED NOT NULL,

    modulo VARCHAR(80) NULL,

    porcentaje_rollout DECIMAL(5,2) NOT NULL DEFAULT 100.00,

    vigente_desde DATETIME NULL,
    vigente_hasta DATETIME NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_feature_flag_codigo UNIQUE (codigo),

    CONSTRAINT fk_ff_estado
        FOREIGN KEY (estado_feature_flag_id) REFERENCES estados_feature_flag(id),
    CONSTRAINT fk_ff_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ff_rollout CHECK (
        porcentaje_rollout >= 0 AND porcentaje_rollout <= 100
    ),
    CONSTRAINT chk_ff_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_desde IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE TABLE feature_flag_roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    feature_flag_id BIGINT UNSIGNED NOT NULL,
    rol_id BIGINT UNSIGNED NOT NULL,

    habilitado BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_ffr UNIQUE (feature_flag_id, rol_id),

    CONSTRAINT fk_ffr_flag
        FOREIGN KEY (feature_flag_id) REFERENCES feature_flags(id),
    CONSTRAINT fk_ffr_rol
        FOREIGN KEY (rol_id) REFERENCES roles(id)
) ENGINE=InnoDB;

CREATE TABLE feature_flag_usuarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    feature_flag_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,

    habilitado BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_ffu UNIQUE (feature_flag_id, usuario_id),

    CONSTRAINT fk_ffu_flag
        FOREIGN KEY (feature_flag_id) REFERENCES feature_flags(id),
    CONSTRAINT fk_ffu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 07. CONFIGURACIÓN DE ARCHIVOS
-- ============================================================

CREATE TABLE configuraciones_archivos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    almacenamiento_tipo VARCHAR(40) NOT NULL, -- LOCAL / S3 / MINIO / AZURE / OTRO
    storage_secret_ref VARCHAR(190) NULL,

    base_path VARCHAR(500) NULL,

    max_archivo_mb INT UNSIGNED NOT NULL DEFAULT 20,

    extensiones_permitidas_json JSON NULL,
    mime_types_permitidos_json JSON NULL,

    antivirus_habilitado BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_config_archivos_codigo UNIQUE (codigo),

    CONSTRAINT chk_ca_tipo CHECK (
        almacenamiento_tipo IN ('LOCAL','S3','MINIO','AZURE','OTRO')
    ),
    CONSTRAINT chk_ca_max_archivo CHECK (
        max_archivo_mb >= 1
    )
) ENGINE=InnoDB;

-- ============================================================
-- 08. CONFIGURACIÓN DE EXPORTACIONES
-- ============================================================

CREATE TABLE configuraciones_exportacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    max_filas_sync INT UNSIGNED NOT NULL DEFAULT 5000,
    max_filas_background INT UNSIGNED NOT NULL DEFAULT 100000,

    timeout_sync_segundos INT UNSIGNED NOT NULL DEFAULT 30,

    formatos_habilitados_json JSON NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_config_exportacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 09. CONFIGURACIÓN DE PAGINACIÓN / UI OPERATIVA
-- ============================================================

CREATE TABLE configuraciones_ui (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    items_por_pagina_default SMALLINT UNSIGNED NOT NULL DEFAULT 25,
    items_por_pagina_max SMALLINT UNSIGNED NOT NULL DEFAULT 200,

    locale VARCHAR(20) NOT NULL DEFAULT 'es_EC',
    timezone VARCHAR(80) NOT NULL DEFAULT 'America/Guayaquil',
    moneda VARCHAR(10) NOT NULL DEFAULT 'USD',

    formato_fecha VARCHAR(40) NOT NULL DEFAULT 'd/m/Y',
    formato_hora VARCHAR(40) NOT NULL DEFAULT 'H:i',

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_config_ui_codigo UNIQUE (codigo),

    CONSTRAINT chk_cui_items CHECK (
        items_por_pagina_default >= 1
        AND items_por_pagina_max >= items_por_pagina_default
    )
) ENGINE=InnoDB;

-- ============================================================
-- 10. VENTANAS OPERATIVAS CONFIGURABLES
-- ============================================================

CREATE TABLE ventanas_operativas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    modulo VARCHAR(80) NOT NULL,

    tipo_ventana VARCHAR(50) NOT NULL, -- DIAS_MES / FECHAS / PERIODO / HORARIO

    dia_inicio SMALLINT UNSIGNED NULL,
    dia_fin SMALLINT UNSIGNED NULL,

    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,

    hora_inicio TIME NULL,
    hora_fin TIME NULL,

    permite_excepcion BOOLEAN NOT NULL DEFAULT FALSE,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ventana_operativa_codigo UNIQUE (codigo),

    CONSTRAINT chk_vo_tipo CHECK (
        tipo_ventana IN ('DIAS_MES','FECHAS','PERIODO','HORARIO')
    ),
    CONSTRAINT chk_vo_dias CHECK (
        (dia_inicio IS NULL AND dia_fin IS NULL)
        OR
        (
            dia_inicio BETWEEN 1 AND 31
            AND dia_fin BETWEEN 1 AND 31
            AND dia_fin >= dia_inicio
        )
    ),
    CONSTRAINT chk_vo_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    ),
    CONSTRAINT chk_vo_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 11. EXCEPCIONES DE VENTANA
-- ============================================================

CREATE TABLE excepciones_ventana_operativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    ventana_operativa_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    rol_id BIGINT UNSIGNED NULL,

    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,

    motivo TEXT NOT NULL,

    aprobada_por_usuario_id BIGINT UNSIGNED NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_evo_ventana
        FOREIGN KEY (ventana_operativa_id) REFERENCES ventanas_operativas(id),
    CONSTRAINT fk_evo_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_evo_rol
        FOREIGN KEY (rol_id) REFERENCES roles(id),
    CONSTRAINT fk_evo_aprobada_por
        FOREIGN KEY (aprobada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_evo_fechas CHECK (
        fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

-- ============================================================
-- 12. CONFIGURACIÓN DE REINTENTOS
-- ============================================================

CREATE TABLE configuraciones_reintento (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    modulo VARCHAR(80) NOT NULL,

    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    estrategia VARCHAR(40) NOT NULL DEFAULT 'EXPONENCIAL',

    espera_inicial_segundos INT UNSIGNED NOT NULL DEFAULT 30,
    espera_maxima_segundos INT UNSIGNED NOT NULL DEFAULT 3600,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_config_reintento_codigo UNIQUE (codigo),

    CONSTRAINT chk_cr_estrategia CHECK (
        estrategia IN ('FIJA','LINEAL','EXPONENCIAL')
    ),
    CONSTRAINT chk_cr_intentos CHECK (
        max_intentos >= 1
    )
) ENGINE=InnoDB;

-- ============================================================
-- 13. CONFIGURACIÓN DE HEALTH CHECKS
-- ============================================================

CREATE TABLE configuraciones_healthcheck (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    servicio VARCHAR(100) NOT NULL,

    endpoint VARCHAR(500) NULL,

    intervalo_segundos INT UNSIGNED NOT NULL DEFAULT 300,
    timeout_segundos INT UNSIGNED NOT NULL DEFAULT 15,

    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_config_healthcheck_codigo UNIQUE (codigo),

    CONSTRAINT chk_ch_intervalo CHECK (
        intervalo_segundos >= 30
    )
) ENGINE=InnoDB;

CREATE TABLE resultados_healthcheck (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    configuracion_healthcheck_id BIGINT UNSIGNED NOT NULL,

    exitoso BOOLEAN NOT NULL,

    http_status SMALLINT UNSIGNED NULL,

    tiempo_respuesta_ms BIGINT UNSIGNED NULL,

    detalle VARCHAR(500) NULL,

    ejecutado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rh_healthcheck
        FOREIGN KEY (configuracion_healthcheck_id) REFERENCES configuraciones_healthcheck(id)
) ENGINE=InnoDB;

CREATE INDEX idx_rh_healthcheck_fecha
ON resultados_healthcheck (configuracion_healthcheck_id, ejecutado_at);

-- ============================================================
-- 14. CONFIGURACIÓN DE TAREAS DEL SISTEMA
-- ============================================================

CREATE TABLE tareas_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    modulo VARCHAR(80) NOT NULL,

    expresion_cron VARCHAR(120) NULL,
    intervalo_segundos INT UNSIGNED NULL,

    comando_logico VARCHAR(180) NOT NULL,

    timeout_segundos INT UNSIGNED NOT NULL DEFAULT 300,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    ultima_ejecucion_at DATETIME NULL,
    proxima_ejecucion_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_tarea_sistema_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 15. EJECUCIONES DE TAREAS DEL SISTEMA
-- ============================================================

CREATE TABLE ejecuciones_tarea_sistema (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tarea_sistema_id BIGINT UNSIGNED NOT NULL,

    execution_uuid CHAR(36) NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    exitosa BOOLEAN NULL,

    resultado_json JSON NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ets_execution_uuid UNIQUE (execution_uuid),

    CONSTRAINT fk_ets_tarea
        FOREIGN KEY (tarea_sistema_id) REFERENCES tareas_sistema(id)
) ENGINE=InnoDB;

-- ============================================================
-- 16. DATOS INICIALES - CATÁLOGOS
-- ============================================================

INSERT INTO tipos_parametro_sistema
(codigo, nombre, permite_json, permite_secreto_ref)
VALUES
('STRING', 'Texto', FALSE, FALSE),
('INTEGER', 'Entero', FALSE, FALSE),
('DECIMAL', 'Decimal', FALSE, FALSE),
('BOOLEAN', 'Booleano', FALSE, FALSE),
('DATE', 'Fecha', FALSE, FALSE),
('DATETIME', 'Fecha y hora', FALSE, FALSE),
('JSON', 'JSON', TRUE, FALSE),
('SECRET_REF', 'Referencia a secreto', FALSE, TRUE);

INSERT INTO alcances_parametro_sistema
(codigo, nombre)
VALUES
('GLOBAL', 'Global'),
('MODULO', 'Por módulo'),
('SEDE', 'Por sede'),
('PERIODO', 'Por período académico'),
('CARRERA', 'Por carrera'),
('SEDE_PERIODO', 'Por sede y período'),
('CARRERA_PERIODO', 'Por carrera y período');

INSERT INTO estados_configuracion_sistema
(codigo, nombre, aplicable, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('PENDIENTE_APROBACION', 'Pendiente de aprobación', FALSE, FALSE),
('APROBADA', 'Aprobada', TRUE, FALSE),
('VIGENTE', 'Vigente', TRUE, FALSE),
('REEMPLAZADA', 'Reemplazada', FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO categorias_configuracion_sistema
(codigo, nombre, descripcion, orden_visual)
VALUES
('GENERAL', 'General', 'Configuración general institucional', 1),
('ACADEMICO', 'Académico', 'Parámetros académicos', 2),
('FINANCIERO', 'Financiero', 'Parámetros financieros', 3),
('ASISTENCIA', 'Asistencia', 'Reglas de asistencia', 4),
('EVALUACION', 'Evaluación', 'Parámetros de evaluación', 5),
('TITULACION', 'Titulación', 'Parámetros de titulación', 6),
('MICROSOFT', 'Microsoft 365', 'Integración Microsoft', 7),
('MOODLE', 'Moodle', 'Integración Moodle', 8),
('NOTIFICACIONES', 'Notificaciones', 'Comunicaciones', 9),
('ARCHIVOS', 'Archivos', 'Repositorio documental', 10),
('SEGURIDAD', 'Seguridad', 'Seguridad y auditoría', 11),
('REPORTES', 'Reportes', 'Reportería e indicadores', 12);

INSERT INTO tipos_secuencia_sistema
(codigo, nombre, reinicia_anual, reinicia_periodo)
VALUES
('ANUAL', 'Secuencia anual', TRUE, FALSE),
('PERIODO', 'Secuencia por período', FALSE, TRUE),
('CONTINUA', 'Secuencia continua', FALSE, FALSE);

INSERT INTO estados_feature_flag
(codigo, nombre, habilitado)
VALUES
('HABILITADO', 'Habilitado', TRUE),
('DESHABILITADO', 'Deshabilitado', FALSE),
('PRUEBA', 'En prueba', TRUE);

-- ============================================================
-- 17. PARÁMETROS INSTITUCIONALES BASE
-- ============================================================

-- General
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    descripcion,
    modulo,
    valor_defecto_texto,
    obligatorio,
    editable_desde_ui
)
SELECT
    c.id, t.id, a.id,
    'INSTITUCION_NOMBRE',
    'Nombre de la institución',
    'Nombre oficial utilizado en documentos y pantallas',
    'GENERAL',
    'Instituto Superior Tecnológico Superarse',
    TRUE,
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='STRING'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='GENERAL';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'TIMEZONE',
    'Zona horaria institucional',
    'GENERAL',
    'America/Guayaquil',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='STRING'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='GENERAL';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'MONEDA',
    'Moneda institucional',
    'GENERAL',
    'USD',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='STRING'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='GENERAL';

-- Financiero
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'PAGO_DIA_INICIO',
    'Día inicial de ventana de pago',
    'FINANCIERO',
    '1',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='FINANCIERO';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'PAGO_DIA_FIN',
    'Día final de ventana de pago',
    'FINANCIERO',
    '10',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='FINANCIERO';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'ABONO_PORCENTAJE_HABILITA',
    'Porcentaje de abono que habilita temporalmente',
    'FINANCIERO',
    '80.00',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='DECIMAL'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='FINANCIERO';

-- Asistencia
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'INASISTENCIAS_CONTINUAS_UMBRAL',
    'Umbral de inasistencias continuas',
    'ASISTENCIA',
    '7',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='ASISTENCIA';

-- Evaluación
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'NOTA_MINIMA_APROBACION',
    'Nota mínima de aprobación',
    'EVALUACION',
    '7.00',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='DECIMAL'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='EVALUACION';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_json,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'RANGOS_SUPLETORIO',
    'Rangos de supletorio',
    'EVALUACION',
    JSON_OBJECT(
        'no_supletorio_max', 4.99,
        'supletorio_min', 5.00,
        'supletorio_max', 6.99,
        'aprobado_min', 7.00
    ),
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='JSON'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='EVALUACION';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'MAX_INTENTOS_ASIGNATURA',
    'Máximo de intentos por asignatura',
    'EVALUACION',
    '3',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='EVALUACION';

-- Microsoft
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'MICROSOFT_GRADUADO_DIAS_GRACIA',
    'Días de gracia para graduados',
    'MICROSOFT',
    '90',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='MICROSOFT';

INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'MICROSOFT_EGRESADO_DIAS_GRACIA',
    'Días de gracia para egresados',
    'MICROSOFT',
    '180',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='MICROSOFT';

-- Moodle
INSERT INTO parametros_sistema
(
    categoria_configuracion_sistema_id,
    tipo_parametro_sistema_id,
    alcance_parametro_sistema_id,
    codigo,
    nombre,
    modulo,
    valor_defecto_texto,
    obligatorio
)
SELECT
    c.id, t.id, a.id,
    'MOODLE_SYNC_INTERVAL_MINUTES',
    'Intervalo de sincronización Moodle',
    'MOODLE',
    '5',
    TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='MOODLE';

-- ============================================================
-- 18. SECUENCIAS BASE
-- ============================================================

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_SOLICITUD_GENERAL', 'Solicitudes generales', 'SOL', 6, 1, 'SOL-{YYYY}-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='ANUAL';

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_CERTIFICADO', 'Certificados', 'CERT', 6, 1, 'CERT-{YYYY}-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='ANUAL';

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_ORDEN_PAGO', 'Órdenes de pago', 'OP', 6, 1, 'OP-{YYYY}-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='ANUAL';

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_PAGO', 'Pagos', 'PAG', 6, 1, 'PAG-{YYYY}-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='ANUAL';

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_TITULACION', 'Procesos de titulación', 'TIT', 6, 1, 'TIT-{YYYY}-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='ANUAL';

INSERT INTO secuencias_sistema
(tipo_secuencia_sistema_id, codigo, nombre, prefijo, longitud_numero, siguiente_valor, formato)
SELECT id, 'SEQ_EXPEDIENTE', 'Expedientes', 'EXP', 7, 1, 'EXP-{SEQ}'
FROM tipos_secuencia_sistema WHERE codigo='CONTINUA';

-- ============================================================
-- 19. FEATURE FLAGS BASE
-- ============================================================

INSERT INTO feature_flags
(codigo, nombre, descripcion, estado_feature_flag_id, modulo, porcentaje_rollout)
SELECT
    'FF_CAMBIO_NOTA_APROBACION_DOBLE',
    'Doble aprobación para cambio de nota',
    'Requiere doble control para modificar nota cerrada',
    e.id,
    'EVALUACION',
    100.00
FROM estados_feature_flag e
WHERE e.codigo='HABILITADO';

INSERT INTO feature_flags
(codigo, nombre, descripcion, estado_feature_flag_id, modulo, porcentaje_rollout)
SELECT
    'FF_MOODLE_SYNC',
    'Sincronización Moodle',
    'Habilita integración automática SIGA-Moodle',
    e.id,
    'MOODLE',
    100.00
FROM estados_feature_flag e
WHERE e.codigo='HABILITADO';

INSERT INTO feature_flags
(codigo, nombre, descripcion, estado_feature_flag_id, modulo, porcentaje_rollout)
SELECT
    'FF_MICROSOFT_PROVISIONING',
    'Aprovisionamiento Microsoft',
    'Habilita aprovisionamiento automático de cuentas',
    e.id,
    'MICROSOFT',
    100.00
FROM estados_feature_flag e
WHERE e.codigo='HABILITADO';

INSERT INTO feature_flags
(codigo, nombre, descripcion, estado_feature_flag_id, modulo, porcentaje_rollout)
SELECT
    'FF_WHATSAPP_NOTIFICATIONS',
    'Notificaciones WhatsApp',
    'Habilita comunicaciones WhatsApp institucionales',
    e.id,
    'NOTIFICACIONES',
    100.00
FROM estados_feature_flag e
WHERE e.codigo='DESHABILITADO';

-- ============================================================
-- 20. CONFIGURACIONES BASE DE ARCHIVOS / EXPORTACIÓN / UI
-- ============================================================

INSERT INTO configuraciones_archivos
(
    codigo,
    nombre,
    almacenamiento_tipo,
    base_path,
    max_archivo_mb,
    extensiones_permitidas_json,
    mime_types_permitidos_json,
    antivirus_habilitado
)
VALUES
(
    'ARCHIVOS_GENERAL',
    'Configuración general de archivos',
    'LOCAL',
    '/data/siga/uploads',
    25,
    JSON_ARRAY('pdf','jpg','jpeg','png','doc','docx','xlsx','csv'),
    JSON_ARRAY(
        'application/pdf',
        'image/jpeg',
        'image/png',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv'
    ),
    FALSE
);

INSERT INTO configuraciones_exportacion
(
    codigo,
    nombre,
    max_filas_sync,
    max_filas_background,
    timeout_sync_segundos,
    formatos_habilitados_json
)
VALUES
(
    'EXPORTACION_GENERAL',
    'Configuración general de exportaciones',
    5000,
    100000,
    30,
    JSON_ARRAY('PDF','XLSX','CSV')
);

INSERT INTO configuraciones_ui
(
    codigo,
    nombre,
    items_por_pagina_default,
    items_por_pagina_max,
    locale,
    timezone,
    moneda,
    formato_fecha,
    formato_hora
)
VALUES
(
    'UI_GENERAL',
    'Configuración general de interfaz',
    25,
    200,
    'es_EC',
    'America/Guayaquil',
    'USD',
    'd/m/Y',
    'H:i'
);

-- ============================================================
-- 21. VENTANAS OPERATIVAS BASE
-- ============================================================

INSERT INTO ventanas_operativas
(
    codigo,
    nombre,
    modulo,
    tipo_ventana,
    dia_inicio,
    dia_fin,
    permite_excepcion,
    vigente_desde
)
VALUES
(
    'VENTANA_PAGO_ESTUDIANTE',
    'Ventana normal para carga de pagos de estudiantes',
    'FINANCIERO',
    'DIAS_MES',
    1,
    10,
    TRUE,
    '2026-01-01'
);

-- ============================================================
-- 22. REINTENTOS BASE
-- ============================================================

INSERT INTO configuraciones_reintento
(codigo, nombre, modulo, max_intentos, estrategia, espera_inicial_segundos, espera_maxima_segundos)
VALUES
('RETRY_MOODLE', 'Reintentos Moodle', 'MOODLE', 5, 'EXPONENCIAL', 30, 3600),
('RETRY_MICROSOFT', 'Reintentos Microsoft', 'MICROSOFT', 5, 'EXPONENCIAL', 30, 3600),
('RETRY_EMAIL', 'Reintentos Email', 'NOTIFICACIONES', 5, 'EXPONENCIAL', 30, 1800),
('RETRY_WHATSAPP', 'Reintentos WhatsApp', 'NOTIFICACIONES', 5, 'EXPONENCIAL', 30, 1800),
('RETRY_REPORTES', 'Reintentos Reportes', 'REPORTES', 3, 'LINEAL', 60, 900);

-- ============================================================
-- 23. HEALTH CHECKS BASE
-- ============================================================

INSERT INTO configuraciones_healthcheck
(codigo, nombre, servicio, endpoint, intervalo_segundos, timeout_segundos, obligatorio)
VALUES
('HC_DATABASE', 'Base de datos SIGA', 'MYSQL', NULL, 60, 5, TRUE),
('HC_MOODLE', 'Moodle institucional', 'MOODLE', 'https://aulasists.superarse.edu.ec', 300, 15, TRUE),
('HC_MICROSOFT_GRAPH', 'Microsoft Graph', 'MICROSOFT_GRAPH', 'https://graph.microsoft.com/v1.0', 300, 15, TRUE),
('HC_STORAGE', 'Almacenamiento de archivos', 'STORAGE', NULL, 300, 15, TRUE);

-- ============================================================
-- 24. TAREAS BASE DEL SISTEMA
-- ============================================================

INSERT INTO tareas_sistema
(codigo, nombre, modulo, expresion_cron, comando_logico, timeout_segundos)
VALUES
('TASK_WORKFLOW_EVENTS', 'Procesar eventos de dominio', 'AUTOMATIZACION', '* * * * *', 'worker:domain-events', 60),
('TASK_WORKFLOWS', 'Procesar workflows', 'AUTOMATIZACION', '* * * * *', 'worker:workflows', 60),
('TASK_MOODLE_SYNC', 'Sincronizar Moodle', 'MOODLE', '*/5 * * * *', 'worker:moodle-sync', 300),
('TASK_MICROSOFT', 'Procesar Microsoft Graph', 'MICROSOFT', '* * * * *', 'worker:microsoft', 120),
('TASK_NOTIFICATIONS', 'Procesar notificaciones', 'NOTIFICACIONES', '* * * * *', 'worker:notifications', 120),
('TASK_SCHEDULED', 'Procesar tareas diferidas', 'AUTOMATIZACION', '* * * * *', 'worker:scheduled-tasks', 60),
('TASK_REPORTS', 'Procesar reportes en background', 'REPORTES', '* * * * *', 'worker:reports', 300),
('TASK_HEALTHCHECKS', 'Ejecutar health checks', 'SISTEMA', '*/5 * * * *', 'worker:healthchecks', 120);

-- ============================================================
-- 25. REGLAS DE RESOLUCIÓN DE PARÁMETROS
-- ============================================================
--
-- La aplicación debe resolver el valor efectivo en este orden:
--
-- 1. CARRERA + PERIODO
-- 2. SEDE + PERIODO
-- 3. CARRERA
-- 4. PERIODO
-- 5. SEDE
-- 6. GLOBAL / MODULO
-- 7. valor_defecto
--
-- Ejemplo:
--
-- NOTA_MINIMA_APROBACION
--
-- Global = 7.00
--
-- Si en una carrera/período existiera una política aprobada distinta:
--   esa versión prevalece solo en ese contexto.
--
-- ------------------------------------------------------------
-- PARÁMETROS CRÍTICOS
-- ------------------------------------------------------------
-- No deben quedar escritos directamente en PHP:
--
--   pago día 1-10
--   umbral de abono 80%
--   nota mínima 7
--   rangos de supletorio
--   máximo de 3 intentos
--   7 inasistencias continuas
--   90 días graduado
--   180 días egresado
--   intervalos Moodle
--   tamaños máximos de archivo
--   límites de exportación
--
-- ------------------------------------------------------------
-- SECUENCIAS
-- ------------------------------------------------------------
-- La generación debe hacerse dentro de transacción/lock:
--
-- SELECT ... FOR UPDATE
-- incrementar siguiente_valor
-- insertar historial
-- commit
--
-- Nunca:
--   SELECT MAX(numero)+1
--
-- porque genera colisiones bajo concurrencia.
--
-- ------------------------------------------------------------
-- FEATURE FLAGS
-- ------------------------------------------------------------
-- Permiten activar una funcionalidad sin redeploy:
--
-- FF_MOODLE_SYNC
-- FF_MICROSOFT_PROVISIONING
-- FF_WHATSAPP_NOTIFICATIONS
--
-- También permiten rollout progresivo y activación por rol/usuario.
--
-- ------------------------------------------------------------
-- ARCHIVOS
-- ------------------------------------------------------------
-- configuraciones_archivos define política global.
-- Los secretos de S3/MinIO/Azure deben vivir en secret manager.
--
-- ------------------------------------------------------------
-- HEALTH CHECKS
-- ------------------------------------------------------------
-- Dashboard TIC puede mostrar:
--   MySQL OK/ERROR
--   Moodle OK/ERROR
--   Microsoft Graph OK/ERROR
--   Storage OK/ERROR
--
-- ------------------------------------------------------------
-- TAREAS
-- ------------------------------------------------------------
-- tareas_sistema sirve como catálogo/control operativo.
-- Los cron reales pueden ejecutarse por:
--   supervisor
--   systemd
--   cron
--   Docker workers
--
-- La BD no reemplaza al scheduler del sistema operativo.
--
-- ------------------------------------------------------------
-- AUDITORÍA
-- ------------------------------------------------------------
-- Todo cambio de parámetro debe generar:
--   CAMBIO_CONFIGURACION
-- en 020_auditoria_seguridad.sql.
--
-- Parámetros críticos deberían pasar:
--   BORRADOR
--   -> PENDIENTE_APROBACION
--   -> APROBADA/VIGENTE
--
-- ============================================================
-- FIN 023_configuracion_sistema_parametros.sql
-- ============================================================
