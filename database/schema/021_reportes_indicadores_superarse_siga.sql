-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 021_reportes_indicadores.sql
-- Requiere bloques 001-020
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Capa transversal de reportes, indicadores y KPIs
--   - Catálogo de reportes institucionales
--   - Consultas parametrizadas y exportaciones
--   - Indicadores académicos, financieros, asistencia, matrícula,
--     docentes, becas, titulación y eficiencia institucional
--   - Snapshots históricos para dashboards
--   - Programación de reportes periódicos
--   - Suscripciones y distribución automática
--   - Cache de resultados agregados
--   - Trazabilidad de ejecuciones
--
-- PRINCIPIOS:
--   - Los reportes no deben depender de consultas ad hoc dispersas.
--   - Los KPIs deben tener definición, fórmula, unidad y periodicidad.
--   - Los snapshots históricos preservan el valor observado en el tiempo.
--   - Los reportes pesados deben ejecutarse en background.
--   - Exportaciones deben quedar auditadas mediante 020_auditoria_seguridad.sql.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE REPORTES
-- ============================================================

CREATE TABLE tipos_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE formatos_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    extension VARCHAR(20) NULL,
    mime_type VARCHAR(100) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_formato_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_ejecucion BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_ejecucion_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_ejec_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_parametro_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_param_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_visualizacion_kpi (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_visualizacion_kpi_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_unidad_indicador (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    simbolo VARCHAR(30) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_unidad_indicador_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE frecuencias_indicador (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_frecuencia_indicador_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_suscripcion_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_suscripcion_reporte_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CATÁLOGO DE REPORTES
-- ============================================================

CREATE TABLE reportes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    tipo_reporte_id BIGINT UNSIGNED NOT NULL,
    estado_reporte_id BIGINT UNSIGNED NOT NULL,

    modulo VARCHAR(80) NOT NULL,

    consulta_sql LONGTEXT NULL,
    consulta_logica_json JSON NULL,

    requiere_background BOOLEAN NOT NULL DEFAULT FALSE,
    cacheable BOOLEAN NOT NULL DEFAULT TRUE,

    tiempo_cache_minutos INT UNSIGNED NOT NULL DEFAULT 15,

    max_filas_exportacion INT UNSIGNED NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_reporte_codigo UNIQUE (codigo),

    CONSTRAINT fk_reporte_tipo
        FOREIGN KEY (tipo_reporte_id) REFERENCES tipos_reporte(id),
    CONSTRAINT fk_reporte_estado
        FOREIGN KEY (estado_reporte_id) REFERENCES estados_reporte(id),
    CONSTRAINT fk_reporte_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_reporte_cache CHECK (
        tiempo_cache_minutos >= 0
    )
) ENGINE=InnoDB;

CREATE INDEX idx_reportes_modulo_estado
ON reportes (modulo, estado_reporte_id, activo);

-- ============================================================
-- 03. FORMATOS PERMITIDOS POR REPORTE
-- ============================================================

CREATE TABLE reporte_formatos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    formato_reporte_id BIGINT UNSIGNED NOT NULL,

    permitido BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_reporte_formato
        UNIQUE (reporte_id, formato_reporte_id),

    CONSTRAINT fk_rf_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_rf_formato
        FOREIGN KEY (formato_reporte_id) REFERENCES formatos_reporte(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. PARÁMETROS DE REPORTES
-- ============================================================

CREATE TABLE reporte_parametros (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    tipo_parametro_reporte_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,

    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    valor_defecto TEXT NULL,
    opciones_json JSON NULL,

    origen_catalogo VARCHAR(100) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_reporte_parametro_codigo
        UNIQUE (reporte_id, codigo),

    CONSTRAINT fk_rp_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_rp_tipo
        FOREIGN KEY (tipo_parametro_reporte_id) REFERENCES tipos_parametro_reporte(id)
) ENGINE=InnoDB;

CREATE INDEX idx_rp_reporte_orden
ON reporte_parametros (reporte_id, orden_visual);

-- ============================================================
-- 05. PERMISOS DE REPORTES
-- ============================================================

CREATE TABLE reporte_roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    rol_id BIGINT UNSIGNED NOT NULL,

    puede_ver BOOLEAN NOT NULL DEFAULT TRUE,
    puede_exportar BOOLEAN NOT NULL DEFAULT FALSE,
    puede_programar BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_reporte_rol
        UNIQUE (reporte_id, rol_id),

    CONSTRAINT fk_rr_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_rr_rol
        FOREIGN KEY (rol_id) REFERENCES roles(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. EJECUCIONES DE REPORTES
-- ============================================================

CREATE TABLE ejecuciones_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    estado_ejecucion_reporte_id BIGINT UNSIGNED NOT NULL,
    formato_reporte_id BIGINT UNSIGNED NULL,

    execution_uuid CHAR(36) NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,

    parametros_json JSON NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,

    total_filas INT UNSIGNED NULL,

    archivo_id BIGINT UNSIGNED NULL,

    cache_hit BOOLEAN NOT NULL DEFAULT FALSE,

    tiempo_ejecucion_ms BIGINT UNSIGNED NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ejecucion_reporte_uuid UNIQUE (execution_uuid),

    CONSTRAINT fk_er_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_er_estado
        FOREIGN KEY (estado_ejecucion_reporte_id) REFERENCES estados_ejecucion_reporte(id),
    CONSTRAINT fk_er_formato
        FOREIGN KEY (formato_reporte_id) REFERENCES formatos_reporte(id),
    CONSTRAINT fk_er_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_er_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

CREATE INDEX idx_er_reporte_fecha
ON ejecuciones_reporte (reporte_id, fecha_solicitud);

CREATE INDEX idx_er_estado
ON ejecuciones_reporte (estado_ejecucion_reporte_id, fecha_solicitud);

-- ============================================================
-- 07. CACHE DE REPORTES
-- ============================================================

CREATE TABLE cache_reportes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,

    clave_cache CHAR(64) NOT NULL,

    parametros_json JSON NULL,

    resultado_json JSON NULL,
    archivo_id BIGINT UNSIGNED NULL,

    total_filas INT UNSIGNED NULL,

    generado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_at DATETIME NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_cache_reporte_clave UNIQUE (clave_cache),

    CONSTRAINT fk_cr_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_cr_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),

    CONSTRAINT chk_cache_reportes_fechas CHECK (
        expira_at > generado_at
    )
) ENGINE=InnoDB;

CREATE INDEX idx_cache_reportes_expira
ON cache_reportes (activo, expira_at);

-- ============================================================
-- 08. INDICADORES / KPIs
-- ============================================================

CREATE TABLE indicadores (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    modulo VARCHAR(80) NOT NULL,

    tipo_unidad_indicador_id BIGINT UNSIGNED NOT NULL,
    frecuencia_indicador_id BIGINT UNSIGNED NOT NULL,
    tipo_visualizacion_kpi_id BIGINT UNSIGNED NOT NULL,

    formula_descripcion TEXT NOT NULL,
    consulta_sql LONGTEXT NULL,
    consulta_logica_json JSON NULL,

    meta_objetivo DECIMAL(18,4) NULL,
    valor_minimo_aceptable DECIMAL(18,4) NULL,
    valor_maximo_aceptable DECIMAL(18,4) NULL,

    mayor_es_mejor BOOLEAN NULL,

    requiere_snapshot BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_indicador_codigo UNIQUE (codigo),

    CONSTRAINT fk_ind_unidad
        FOREIGN KEY (tipo_unidad_indicador_id) REFERENCES tipos_unidad_indicador(id),
    CONSTRAINT fk_ind_frecuencia
        FOREIGN KEY (frecuencia_indicador_id) REFERENCES frecuencias_indicador(id),
    CONSTRAINT fk_ind_visualizacion
        FOREIGN KEY (tipo_visualizacion_kpi_id) REFERENCES tipos_visualizacion_kpi(id),
    CONSTRAINT fk_ind_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ind_modulo_activo
ON indicadores (modulo, activo);

-- ============================================================
-- 09. DIMENSIONES DE INDICADORES
-- ============================================================

CREATE TABLE dimensiones_indicador (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_dimension_indicador_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE indicador_dimensiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    indicador_id BIGINT UNSIGNED NOT NULL,
    dimension_indicador_id BIGINT UNSIGNED NOT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_indicador_dimension
        UNIQUE (indicador_id, dimension_indicador_id),

    CONSTRAINT fk_id_indicador
        FOREIGN KEY (indicador_id) REFERENCES indicadores(id),
    CONSTRAINT fk_id_dimension
        FOREIGN KEY (dimension_indicador_id) REFERENCES dimensiones_indicador(id)
) ENGINE=InnoDB;

-- ============================================================
-- 10. SNAPSHOTS HISTÓRICOS DE INDICADORES
-- ============================================================

CREATE TABLE indicador_snapshots (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    indicador_id BIGINT UNSIGNED NOT NULL,

    fecha_referencia DATE NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    sede_id BIGINT UNSIGNED NULL,
    carrera_id BIGINT UNSIGNED NULL,
    nivel_academico_id BIGINT UNSIGNED NULL,

    valor DECIMAL(18,4) NOT NULL,

    numerador DECIMAL(18,4) NULL,
    denominador DECIMAL(18,4) NULL,

    meta_objetivo_snapshot DECIMAL(18,4) NULL,

    dimensiones_json JSON NULL,

    calculado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_is_indicador
        FOREIGN KEY (indicador_id) REFERENCES indicadores(id),
    CONSTRAINT fk_is_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_is_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_is_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_is_nivel
        FOREIGN KEY (nivel_academico_id) REFERENCES niveles_academicos(id)
) ENGINE=InnoDB;

CREATE INDEX idx_is_indicador_fecha
ON indicador_snapshots (indicador_id, fecha_referencia);

CREATE INDEX idx_is_contexto
ON indicador_snapshots (periodo_academico_id, carrera_id, sede_id, fecha_referencia);

-- ============================================================
-- 11. DASHBOARDS
-- ============================================================

CREATE TABLE dashboards (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,

    perfil_id BIGINT UNSIGNED NULL,

    es_sistema BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_dashboard_codigo UNIQUE (codigo),

    CONSTRAINT fk_dashboard_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfiles(id),
    CONSTRAINT fk_dashboard_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE dashboard_widgets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    dashboard_id BIGINT UNSIGNED NOT NULL,

    indicador_id BIGINT UNSIGNED NULL,
    reporte_id BIGINT UNSIGNED NULL,

    titulo VARCHAR(180) NOT NULL,

    tipo_widget VARCHAR(50) NOT NULL,

    posicion_x SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    posicion_y SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    ancho SMALLINT UNSIGNED NOT NULL DEFAULT 4,
    alto SMALLINT UNSIGNED NOT NULL DEFAULT 3,

    configuracion_json JSON NULL,

    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_dw_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboards(id),
    CONSTRAINT fk_dw_indicador
        FOREIGN KEY (indicador_id) REFERENCES indicadores(id),
    CONSTRAINT fk_dw_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id)
) ENGINE=InnoDB;

CREATE INDEX idx_dw_dashboard_orden
ON dashboard_widgets (dashboard_id, orden_visual);

-- ============================================================
-- 12. DASHBOARDS PERSONALIZADOS DE USUARIO
-- ============================================================

CREATE TABLE usuario_dashboard_preferencias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,
    dashboard_id BIGINT UNSIGNED NOT NULL,

    configuracion_json JSON NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,

    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_udp_usuario_dashboard
        UNIQUE (usuario_id, dashboard_id),

    CONSTRAINT fk_udp_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_udp_dashboard
        FOREIGN KEY (dashboard_id) REFERENCES dashboards(id)
) ENGINE=InnoDB;

-- ============================================================
-- 13. PROGRAMACIÓN DE REPORTES
-- ============================================================

CREATE TABLE programaciones_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    formato_reporte_id BIGINT UNSIGNED NOT NULL,

    nombre VARCHAR(180) NOT NULL,

    expresion_cron VARCHAR(120) NOT NULL,
    timezone VARCHAR(80) NOT NULL DEFAULT 'America/Guayaquil',

    parametros_json JSON NULL,

    proxima_ejecucion_at DATETIME NULL,
    ultima_ejecucion_at DATETIME NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_pr_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id),
    CONSTRAINT fk_pr_formato
        FOREIGN KEY (formato_reporte_id) REFERENCES formatos_reporte(id),
    CONSTRAINT fk_pr_usuario
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_pr_proxima_ejecucion
ON programaciones_reporte (activa, proxima_ejecucion_at);

-- ============================================================
-- 14. SUSCRIPCIONES A REPORTES
-- ============================================================

CREATE TABLE suscripciones_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    programacion_reporte_id BIGINT UNSIGNED NOT NULL,
    estado_suscripcion_reporte_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    grupo_notificacion_id BIGINT UNSIGNED NULL,
    destinatario_externo VARCHAR(190) NULL,

    canal_notificacion_id BIGINT UNSIGNED NOT NULL,

    asunto_personalizado VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sr_programacion
        FOREIGN KEY (programacion_reporte_id) REFERENCES programaciones_reporte(id),
    CONSTRAINT fk_sr_estado
        FOREIGN KEY (estado_suscripcion_reporte_id) REFERENCES estados_suscripcion_reporte(id),
    CONSTRAINT fk_sr_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sr_grupo
        FOREIGN KEY (grupo_notificacion_id) REFERENCES grupos_notificacion(id),
    CONSTRAINT fk_sr_canal
        FOREIGN KEY (canal_notificacion_id) REFERENCES canales_notificacion(id)
) ENGINE=InnoDB;

-- ============================================================
-- 15. EJECUCIONES PROGRAMADAS
-- ============================================================

CREATE TABLE ejecuciones_programadas_reporte (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    programacion_reporte_id BIGINT UNSIGNED NOT NULL,
    ejecucion_reporte_id BIGINT UNSIGNED NULL,

    fecha_programada DATETIME NOT NULL,
    fecha_ejecucion DATETIME NULL,

    procesada BOOLEAN NOT NULL DEFAULT FALSE,

    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_epr_programacion
        FOREIGN KEY (programacion_reporte_id) REFERENCES programaciones_reporte(id),
    CONSTRAINT fk_epr_ejecucion
        FOREIGN KEY (ejecucion_reporte_id) REFERENCES ejecuciones_reporte(id)
) ENGINE=InnoDB;

CREATE INDEX idx_epr_pendientes
ON ejecuciones_programadas_reporte (procesada, fecha_programada);

-- ============================================================
-- 16. INDICADORES ACADÉMICOS ESPECIALIZADOS
-- Cache normalizada para consultas rápidas.
-- ============================================================

CREATE TABLE resumen_academico_periodo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,
    sede_id BIGINT UNSIGNED NULL,
    sede_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(sede_id, 0)) STORED,

    estudiantes_matriculados INT UNSIGNED NOT NULL DEFAULT 0,
    estudiantes_nuevos INT UNSIGNED NOT NULL DEFAULT 0,
    estudiantes_renovacion INT UNSIGNED NOT NULL DEFAULT 0,

    asignaturas_aprobadas INT UNSIGNED NOT NULL DEFAULT 0,
    asignaturas_reprobadas INT UNSIGNED NOT NULL DEFAULT 0,

    estudiantes_supletorio INT UNSIGNED NOT NULL DEFAULT 0,
    estudiantes_tercera_matricula INT UNSIGNED NOT NULL DEFAULT 0,

    promedio_general DECIMAL(6,3) NULL,

    tasa_aprobacion DECIMAL(6,2) NULL,
    tasa_reprobacion DECIMAL(6,2) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_rap_periodo_carrera_sede
        UNIQUE (periodo_academico_id, carrera_id, sede_key),

    CONSTRAINT fk_rap_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rap_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_rap_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),

    CONSTRAINT chk_rap_tasas CHECK (
        (tasa_aprobacion IS NULL OR (tasa_aprobacion >= 0 AND tasa_aprobacion <= 100))
        AND
        (tasa_reprobacion IS NULL OR (tasa_reprobacion >= 0 AND tasa_reprobacion <= 100))
    )
) ENGINE=InnoDB;

-- ============================================================
-- 17. RESUMEN FINANCIERO POR PERÍODO
-- ============================================================

CREATE TABLE resumen_financiero_periodo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NULL,
    carrera_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(carrera_id, 0)) STORED,
    sede_id BIGINT UNSIGNED NULL,
    sede_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(sede_id, 0)) STORED,

    total_facturado DECIMAL(16,2) NOT NULL DEFAULT 0.00,
    total_recaudado DECIMAL(16,2) NOT NULL DEFAULT 0.00,
    total_pendiente DECIMAL(16,2) NOT NULL DEFAULT 0.00,
    total_becas DECIMAL(16,2) NOT NULL DEFAULT 0.00,
    total_descuentos DECIMAL(16,2) NOT NULL DEFAULT 0.00,

    estudiantes_morosos INT UNSIGNED NOT NULL DEFAULT 0,
    estudiantes_al_dia INT UNSIGNED NOT NULL DEFAULT 0,

    tasa_recaudacion DECIMAL(6,2) NULL,
    tasa_morosidad DECIMAL(6,2) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_rfp_periodo_carrera_sede
        UNIQUE (periodo_academico_id, carrera_key, sede_key),

    CONSTRAINT fk_rfp_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rfp_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_rfp_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),

    CONSTRAINT chk_rfp_tasas CHECK (
        (tasa_recaudacion IS NULL OR (tasa_recaudacion >= 0 AND tasa_recaudacion <= 100))
        AND
        (tasa_morosidad IS NULL OR (tasa_morosidad >= 0 AND tasa_morosidad <= 100))
    )
) ENGINE=InnoDB;

-- ============================================================
-- 18. RESUMEN DE ASISTENCIA
-- ============================================================

CREATE TABLE resumen_asistencia_periodo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NULL,
    seccion_id BIGINT UNSIGNED NULL,

    total_sesiones INT UNSIGNED NOT NULL DEFAULT 0,
    total_registros INT UNSIGNED NOT NULL DEFAULT 0,
    total_presentes INT UNSIGNED NOT NULL DEFAULT 0,
    total_ausentes INT UNSIGNED NOT NULL DEFAULT 0,
    total_atrasos INT UNSIGNED NOT NULL DEFAULT 0,
    total_justificadas INT UNSIGNED NOT NULL DEFAULT 0,

    estudiantes_en_riesgo INT UNSIGNED NOT NULL DEFAULT 0,

    porcentaje_asistencia DECIMAL(6,2) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT fk_rasp_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rasp_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_rasp_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),

    CONSTRAINT chk_rasp_porcentaje CHECK (
        porcentaje_asistencia IS NULL OR
        (porcentaje_asistencia >= 0 AND porcentaje_asistencia <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 19. RESUMEN DE TITULACIÓN
-- ============================================================

CREATE TABLE resumen_titulacion_periodo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NULL,
    carrera_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(carrera_id, 0)) STORED,

    procesos_iniciados INT UNSIGNED NOT NULL DEFAULT 0,
    procesos_aprobados INT UNSIGNED NOT NULL DEFAULT 0,
    procesos_reprobados INT UNSIGNED NOT NULL DEFAULT 0,

    examenes_complexivos INT UNSIGNED NOT NULL DEFAULT 0,
    trabajos_titulacion INT UNSIGNED NOT NULL DEFAULT 0,

    graduados INT UNSIGNED NOT NULL DEFAULT 0,

    tasa_titulacion DECIMAL(6,2) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_rtp_periodo_carrera
        UNIQUE (periodo_academico_id, carrera_key),

    CONSTRAINT fk_rtp_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rtp_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),

    CONSTRAINT chk_rtp_tasa CHECK (
        tasa_titulacion IS NULL OR (tasa_titulacion >= 0 AND tasa_titulacion <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 20. RESUMEN DE BECAS
-- ============================================================

CREATE TABLE resumen_becas_periodo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NULL,
    carrera_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(carrera_id, 0)) STORED,

    estudiantes_becados INT UNSIGNED NOT NULL DEFAULT 0,
    becas_nuevas INT UNSIGNED NOT NULL DEFAULT 0,
    becas_renovadas INT UNSIGNED NOT NULL DEFAULT 0,
    becas_perdidas INT UNSIGNED NOT NULL DEFAULT 0,

    monto_total_otorgado DECIMAL(16,2) NOT NULL DEFAULT 0.00,
    porcentaje_promedio_beca DECIMAL(6,2) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_rbp_periodo_carrera
        UNIQUE (periodo_academico_id, carrera_key),

    CONSTRAINT fk_rbp_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_rbp_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),

    CONSTRAINT chk_rbp_porcentaje CHECK (
        porcentaje_promedio_beca IS NULL OR
        (porcentaje_promedio_beca >= 0 AND porcentaje_promedio_beca <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 21. MÉTRICAS DE REPORTERÍA
-- ============================================================

CREATE TABLE metricas_reportes_diarias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    reporte_id BIGINT UNSIGNED NOT NULL,
    fecha DATE NOT NULL,

    total_ejecuciones INT UNSIGNED NOT NULL DEFAULT 0,
    total_exitosas INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,
    total_exportaciones INT UNSIGNED NOT NULL DEFAULT 0,

    tiempo_promedio_ms BIGINT UNSIGNED NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_mrd_reporte_fecha
        UNIQUE (reporte_id, fecha),

    CONSTRAINT fk_mrd_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id)
) ENGINE=InnoDB;

-- ============================================================
-- 22. DATOS INICIALES - CATÁLOGOS
-- ============================================================

INSERT INTO tipos_reporte
(codigo, nombre, descripcion)
VALUES
('TABULAR', 'Reporte tabular', 'Listado detallado de registros'),
('RESUMEN', 'Reporte resumido', 'Resumen agregado'),
('ESTADISTICO', 'Reporte estadístico', 'Indicadores y estadísticas'),
('CERTIFICACION', 'Reporte certificable', 'Reporte susceptible de firma/certificación'),
('OPERATIVO', 'Reporte operativo', 'Reporte para gestión diaria');

INSERT INTO formatos_reporte
(codigo, nombre, extension, mime_type)
VALUES
('PANTALLA', 'Vista en pantalla', NULL, 'application/json'),
('PDF', 'PDF', 'pdf', 'application/pdf'),
('XLSX', 'Excel', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
('CSV', 'CSV', 'csv', 'text/csv');

INSERT INTO estados_reporte
(codigo, nombre, permite_ejecucion)
VALUES
('BORRADOR', 'Borrador', FALSE),
('ACTIVO', 'Activo', TRUE),
('PAUSADO', 'Pausado', FALSE),
('INACTIVO', 'Inactivo', FALSE),
('ARCHIVADO', 'Archivado', FALSE);

INSERT INTO estados_ejecucion_reporte
(codigo, nombre, es_final, exitoso)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('PROCESANDO', 'Procesando', FALSE, FALSE),
('EXITOSA', 'Exitosa', TRUE, TRUE),
('ERROR', 'Error', TRUE, FALSE),
('CANCELADA', 'Cancelada', TRUE, FALSE);

INSERT INTO tipos_parametro_reporte
(codigo, nombre)
VALUES
('TEXTO', 'Texto'),
('NUMERO', 'Número'),
('FECHA', 'Fecha'),
('RANGO_FECHAS', 'Rango de fechas'),
('SELECT', 'Selección única'),
('MULTISELECT', 'Selección múltiple'),
('BOOLEANO', 'Sí/No'),
('PERIODO', 'Período académico'),
('CARRERA', 'Carrera'),
('SEDE', 'Sede'),
('NIVEL', 'Nivel'),
('DOCENTE', 'Docente'),
('ESTUDIANTE', 'Estudiante');

INSERT INTO tipos_visualizacion_kpi
(codigo, nombre)
VALUES
('CARD', 'Tarjeta KPI'),
('LINEA', 'Gráfico de línea'),
('BARRA', 'Gráfico de barras'),
('DONUT', 'Gráfico donut'),
('TABLA', 'Tabla'),
('AREA', 'Gráfico de área'),
('GAUGE', 'Indicador tipo gauge');

INSERT INTO tipos_unidad_indicador
(codigo, nombre, simbolo)
VALUES
('NUMERO', 'Número', NULL),
('PORCENTAJE', 'Porcentaje', '%'),
('MONEDA', 'Moneda', '$'),
('PROMEDIO', 'Promedio', NULL),
('HORAS', 'Horas', 'h'),
('DIAS', 'Días', 'd');

INSERT INTO frecuencias_indicador
(codigo, nombre)
VALUES
('TIEMPO_REAL', 'Tiempo real'),
('DIARIA', 'Diaria'),
('SEMANAL', 'Semanal'),
('MENSUAL', 'Mensual'),
('PERIODO_ACADEMICO', 'Por período académico'),
('ANUAL', 'Anual');

INSERT INTO estados_suscripcion_reporte
(codigo, nombre)
VALUES
('ACTIVA', 'Activa'),
('PAUSADA', 'Pausada'),
('CANCELADA', 'Cancelada');

INSERT INTO dimensiones_indicador (codigo, nombre) VALUES
('PERIODO', 'Período académico'),
('CARRERA', 'Carrera'),
('SEDE', 'Sede'),
('NIVEL', 'Nivel'),
('MODALIDAD', 'Modalidad'),
('DOCENTE', 'Docente'),
('ASIGNATURA', 'Asignatura'),
('ESTADO_ESTUDIANTE', 'Estado del estudiante');

-- ============================================================
-- 23. KPIs INSTITUCIONALES BASE
-- ============================================================

-- Académicos
INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'ESTUDIANTES_MATRICULADOS',
    'Estudiantes matriculados',
    'Número de estudiantes con matrícula confirmada en el período',
    'ACADEMICO',
    u.id, f.id, v.id,
    'COUNT DISTINCT estudiantes con matrícula confirmada',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='PERIODO_ACADEMICO'
JOIN tipos_visualizacion_kpi v ON v.codigo='CARD'
WHERE u.codigo='NUMERO';

INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'TASA_APROBACION_ASIGNATURAS',
    'Tasa de aprobación de asignaturas',
    'Porcentaje de resultados finales aprobados',
    'ACADEMICO',
    u.id, f.id, v.id,
    '(Asignaturas aprobadas / asignaturas con resultado final) * 100',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='PERIODO_ACADEMICO'
JOIN tipos_visualizacion_kpi v ON v.codigo='LINEA'
WHERE u.codigo='PORCENTAJE';

INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'PROMEDIO_ACADEMICO_GENERAL',
    'Promedio académico general',
    'Promedio de notas finales definitivas',
    'ACADEMICO',
    u.id, f.id, v.id,
    'AVG(nota_final_definitiva)',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='PERIODO_ACADEMICO'
JOIN tipos_visualizacion_kpi v ON v.codigo='CARD'
WHERE u.codigo='PROMEDIO';

-- Financiero
INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'TASA_RECAUDACION',
    'Tasa de recaudación',
    'Porcentaje de valores recaudados respecto de lo facturado',
    'FINANCIERO',
    u.id, f.id, v.id,
    '(Total recaudado / total facturado) * 100',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='MENSUAL'
JOIN tipos_visualizacion_kpi v ON v.codigo='GAUGE'
WHERE u.codigo='PORCENTAJE';

INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'TASA_MOROSIDAD',
    'Tasa de morosidad',
    'Porcentaje de estudiantes con cuotas vencidas',
    'FINANCIERO',
    u.id, f.id, v.id,
    '(Estudiantes morosos / estudiantes con orden de pago) * 100',
    FALSE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='MENSUAL'
JOIN tipos_visualizacion_kpi v ON v.codigo='GAUGE'
WHERE u.codigo='PORCENTAJE';

-- Asistencia
INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'PORCENTAJE_ASISTENCIA',
    'Porcentaje de asistencia',
    'Porcentaje global de asistencias registradas como presentes',
    'ASISTENCIA',
    u.id, f.id, v.id,
    '(Presentes / registros válidos de asistencia) * 100',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='SEMANAL'
JOIN tipos_visualizacion_kpi v ON v.codigo='LINEA'
WHERE u.codigo='PORCENTAJE';

INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'ESTUDIANTES_RIESGO_ASISTENCIA',
    'Estudiantes en riesgo por asistencia',
    'Cantidad de estudiantes con rachas o alertas de inasistencia activas',
    'ASISTENCIA',
    u.id, f.id, v.id,
    'COUNT DISTINCT estudiantes con alerta activa de asistencia',
    FALSE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='DIARIA'
JOIN tipos_visualizacion_kpi v ON v.codigo='CARD'
WHERE u.codigo='NUMERO';

-- Becas
INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'ESTUDIANTES_BECADOS',
    'Estudiantes becados',
    'Número de estudiantes con beca activa',
    'BIENESTAR',
    u.id, f.id, v.id,
    'COUNT DISTINCT estudiantes con beca activa',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='PERIODO_ACADEMICO'
JOIN tipos_visualizacion_kpi v ON v.codigo='CARD'
WHERE u.codigo='NUMERO';

-- Titulación
INSERT INTO indicadores
(
    codigo, nombre, descripcion, modulo,
    tipo_unidad_indicador_id, frecuencia_indicador_id, tipo_visualizacion_kpi_id,
    formula_descripcion, mayor_es_mejor
)
SELECT
    'TASA_TITULACION',
    'Tasa de titulación',
    'Porcentaje de procesos de titulación aprobados',
    'TITULACION',
    u.id, f.id, v.id,
    '(Procesos aprobados / procesos finalizados) * 100',
    TRUE
FROM tipos_unidad_indicador u
JOIN frecuencias_indicador f ON f.codigo='PERIODO_ACADEMICO'
JOIN tipos_visualizacion_kpi v ON v.codigo='LINEA'
WHERE u.codigo='PORCENTAJE';

-- ============================================================
-- 24. REPORTES INSTITUCIONALES BASE
-- ============================================================

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_ESTUDIANTES_MATRICULADOS',
    'Estudiantes matriculados',
    'Listado de estudiantes matriculados por período, carrera, sede y nivel',
    tr.id,
    er.id,
    'ACADEMICO',
    FALSE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='TABULAR';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_RECORD_ACADEMICO',
    'Récord académico',
    'Histórico académico completo por estudiante/carrera',
    tr.id,
    er.id,
    'ACADEMICO',
    TRUE,
    FALSE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='CERTIFICACION';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_ASISTENCIA',
    'Reporte de asistencia',
    'Asistencia por período, carrera, sección, docente y estudiante',
    tr.id,
    er.id,
    'ASISTENCIA',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='TABULAR';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_CARTERA_FINANCIERA',
    'Cartera financiera',
    'Saldos, cuotas, morosidad y estado de pagos por estudiante',
    tr.id,
    er.id,
    'FINANCIERO',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='OPERATIVO';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_RECAUDACION',
    'Recaudación',
    'Ingresos aprobados por período, carrera y fecha',
    tr.id,
    er.id,
    'FINANCIERO',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='ESTADISTICO';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_BECAS',
    'Becas y ayudas económicas',
    'Becas otorgadas, renovadas, perdidas y montos aplicados',
    tr.id,
    er.id,
    'BIENESTAR',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='ESTADISTICO';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_TITULACION',
    'Procesos de titulación',
    'Estado de procesos, requisitos, modalidad, intentos y resultado',
    tr.id,
    er.id,
    'TITULACION',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='TABULAR';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_PRACTICAS_VINCULACION',
    'Prácticas y vinculación',
    'Horas cumplidas, pendientes y certificados por estudiante',
    tr.id,
    er.id,
    'PRACTICAS_VINCULACION',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='TABULAR';

INSERT INTO reportes
(codigo, nombre, descripcion, tipo_reporte_id, estado_reporte_id, modulo, requiere_background, cacheable)
SELECT
    'REP_ENCUESTAS',
    'Resultados de encuestas',
    'Resultados agregados y detalle permitido de encuestas institucionales',
    tr.id,
    er.id,
    'ENCUESTAS',
    TRUE,
    TRUE
FROM tipos_reporte tr
JOIN estados_reporte er ON er.codigo='ACTIVO'
WHERE tr.codigo='ESTADISTICO';

-- ============================================================
-- 25. FORMATOS BASE PARA REPORTES
-- ============================================================

INSERT INTO reporte_formatos (reporte_id, formato_reporte_id)
SELECT r.id, f.id
FROM reportes r
JOIN formatos_reporte f ON f.codigo IN ('PANTALLA','PDF','XLSX','CSV');

-- ============================================================
-- 26. DASHBOARDS BASE
-- ============================================================

INSERT INTO dashboards
(codigo, nombre, descripcion, es_sistema)
VALUES
('DASH_ADMIN_GENERAL', 'Dashboard General Administrativo', 'KPIs institucionales consolidados', TRUE),
('DASH_ACADEMICO', 'Dashboard Académico', 'Indicadores académicos y de matrícula', TRUE),
('DASH_FINANCIERO', 'Dashboard Financiero', 'Indicadores de recaudación y cartera', TRUE),
('DASH_DOCENTE', 'Dashboard Docente', 'Cursos, asistencia, evaluación y estudiantes', TRUE),
('DASH_ESTUDIANTE', 'Dashboard Estudiante', 'Estado académico, financiero y documental', TRUE),
('DASH_TITULACION', 'Dashboard Titulación', 'Seguimiento de procesos de titulación', TRUE),
('DASH_BIENESTAR', 'Dashboard Bienestar', 'Becas y acompañamiento', TRUE),
('DASH_TICS', 'Dashboard TICs', 'Integraciones, cuentas y automatizaciones', TRUE);

-- ============================================================
-- 27. REGLAS DE APLICACIÓN
-- ============================================================
--
-- REPORTES:
-- - Toda definición de reporte vive en reportes.
-- - La capa de aplicación valida permisos antes de ejecutar.
-- - Reportes grandes se envían a background.
--
-- SQL:
-- - consulta_sql puede existir para reportes controlados por TIC.
-- - Nunca permitir SQL arbitrario ingresado por usuarios finales.
-- - Parámetros siempre deben aplicarse mediante prepared statements.
--
-- CACHE:
-- - Reportes agregados pueden cachearse.
-- - Clave de cache:
--      SHA256(reporte + parámetros + permisos/contexto relevante)
--
-- EJECUCIÓN:
-- Usuario
--    ↓
-- Reporte
--    ↓
-- Parámetros
--    ↓
-- Permisos
--    ↓
-- Cache?
--   ├── Sí -> devolver
--   └── No -> ejecutar / background
--                  ↓
--               archivo
--                  ↓
--          auditoria_exportaciones
--
-- INDICADORES:
-- - Cada KPI tiene fórmula declarada.
-- - indicador_snapshots conserva histórico.
-- - Si la fórmula cambia, se recomienda crear nuevo indicador o
--   versionar la definición en una futura extensión.
--
-- DASHBOARDS:
-- - Los dashboards consumen indicadores y reportes.
-- - No duplican lógica de negocio.
-- - La UI puede personalizar layout por usuario.
--
-- ACADÉMICO:
-- KPIs recomendados:
--   estudiantes matriculados
--   estudiantes nuevos
--   renovaciones
--   tasa aprobación
--   tasa reprobación
--   promedio
--   supletorios
--   terceras matrículas
--   retención
--   abandono
--   egresados
--   graduados
--
-- FINANCIERO:
--   total facturado
--   recaudado
--   pendiente
--   morosidad
--   becas
--   descuentos
--   abonos
--   pagos rechazados
--
-- ASISTENCIA:
--   porcentaje de asistencia
--   estudiantes en riesgo
--   rachas de inasistencia
--
-- TITULACIÓN:
--   procesos iniciados
--   aprobados
--   pendientes de requisitos
--   complexivo
--   trabajo de titulación
--   graduados
--
-- BIENESTAR:
--   estudiantes becados
--   monto becas
--   renovaciones
--   pérdidas
--
-- TIC:
--   cuentas pendientes de aprovisionar
--   errores Microsoft
--   errores Moodle
--   workflows en dead letter
--   notificaciones fallidas
--
-- PROGRAMACIÓN:
-- - programaciones_reporte permite:
--      reporte diario de morosidad
--      resumen semanal académico
--      dashboard mensual directivo
--      reportes de cierre de PAO
--
-- DISTRIBUCIÓN:
-- - Se integra con 019_notificaciones_comunicaciones.sql.
-- - El worker genera el archivo y crea notificación con adjunto.
--
-- SEGURIDAD:
-- - Toda exportación masiva debe registrarse en
--   020_auditoria_seguridad.sql.
-- - Reportes financieros y personales deben restringirse por permisos.
--
-- ============================================================
-- FIN 021_reportes_indicadores.sql
-- ============================================================
