-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 008_evaluacion_calificaciones.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
--   003_talento_humano_superarse_siga.sql
--   004_admisiones_estudiantes_superarse_siga.sql
--   005_estructura_academica_superarse_siga.sql
--   006_periodos_oferta_academica_superarse_siga.sql
--   007_matriculas_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Esquemas globales de evaluación versionados e históricos
--   - Parciales y parámetros de evaluación
--   - Asignación de una versión de evaluación a cada sección
--   - Recursos evaluables sincronizados desde Moodle
--   - Un recurso -> un parámetro
--   - Un parámetro solo puede utilizarse una vez por sección
--   - Calificaciones operativas provenientes de Moodle
--   - Consolidación oficial por parcial y nota final en SIGA
--   - Cierre de parciales
--   - Solicitudes excepcionales de cambio de nota en SIGA
--   - Aprobación, auditoría, histórico y sincronización hacia Moodle
--   - Protección contra sobrescritura de correcciones oficiales
--   - Reglas históricas de aprobación y supletorios
--
-- PRINCIPIOS:
--   - Moodle = operación diaria de actividades y calificación normal.
--   - SIGA = fuente oficial de consolidación e histórico académico.
--   - Una versión PUBLICADA no se modifica; se crea una nueva versión.
--   - Después del cierre de un parcial, una nota NO se edita directamente.
--   - Toda corrección posterior al cierre requiere solicitud y aprobación.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE EVALUACIÓN
-- ============================================================

CREATE TABLE estados_esquema_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_edicion BOOLEAN NOT NULL DEFAULT FALSE,
    es_publicado BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_esquema_eval_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_recurso_evaluable (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    evaluable BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_recurso_evaluable_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE origenes_recurso_evaluable (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_origenes_recurso_evaluable_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_recurso_evaluable (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_recurso_evaluable_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_cierre_parcial (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_cambios_ordinarios BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_cierre_parcial_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_calificacion_recurso (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_oficial BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_calificacion_recurso_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE origenes_calificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_origenes_calificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_solicitud_cambio_nota (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    permite_ejecucion BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_solicitud_cambio_nota_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_sincronizacion_calificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_sync_calificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE direcciones_sincronizacion_calificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_direcciones_sync_calificacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE resultados_academicos_catalogo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    habilita_supletorio BOOLEAN NOT NULL DEFAULT FALSE,
    bloquea_supletorio BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_resultados_academicos_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_supletorio (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_supletorio_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. ESQUEMAS GLOBALES DE EVALUACIÓN
-- ============================================================

CREATE TABLE esquemas_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_esquemas_evaluacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE esquema_evaluacion_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    esquema_evaluacion_id BIGINT UNSIGNED NOT NULL,
    estado_esquema_id BIGINT UNSIGNED NOT NULL,

    numero_version INT UNSIGNED NOT NULL,

    nombre_version VARCHAR(180) NULL,
    descripcion_cambio TEXT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    publicado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_publicacion DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_esquema_version
        UNIQUE (esquema_evaluacion_id, numero_version),

    CONSTRAINT fk_eev_esquema
        FOREIGN KEY (esquema_evaluacion_id) REFERENCES esquemas_evaluacion(id),
    CONSTRAINT fk_eev_estado
        FOREIGN KEY (estado_esquema_id) REFERENCES estados_esquema_evaluacion(id),
    CONSTRAINT fk_eev_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_eev_publicado_por
        FOREIGN KEY (publicado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_eev_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_eev_esquema_vigencia
ON esquema_evaluacion_versiones (esquema_evaluacion_id, vigente_desde, vigente_hasta);

-- ============================================================
-- 03. PARCIALES
-- ============================================================

CREATE TABLE parciales_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    esquema_version_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    ponderacion_nota_final DECIMAL(5,2) NOT NULL,

    orden_visual SMALLINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_parcial_version_codigo
        UNIQUE (esquema_version_id, codigo),

    CONSTRAINT uq_parcial_version_orden
        UNIQUE (esquema_version_id, orden_visual),

    CONSTRAINT fk_parciales_version
        FOREIGN KEY (esquema_version_id) REFERENCES esquema_evaluacion_versiones(id),

    CONSTRAINT chk_parcial_ponderacion CHECK (
        ponderacion_nota_final > 0 AND ponderacion_nota_final <= 100
    )
) ENGINE=InnoDB;

-- La suma de ponderacion_nota_final de todos los parciales activos
-- de una versión debe ser exactamente 100%. Se valida en servicio antes
-- de publicar la versión.

-- ============================================================
-- 04. PARÁMETROS DE EVALUACIÓN
-- ============================================================

CREATE TABLE parametros_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    parcial_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,

    ponderacion_parcial DECIMAL(5,2) NOT NULL,

    orden_visual SMALLINT UNSIGNED NOT NULL,

    modificable_al_evaluar BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_parametro_parcial_codigo
        UNIQUE (parcial_id, codigo),

    CONSTRAINT uq_parametro_parcial_orden
        UNIQUE (parcial_id, orden_visual),

    CONSTRAINT fk_parametros_parcial
        FOREIGN KEY (parcial_id) REFERENCES parciales_evaluacion(id),

    CONSTRAINT chk_parametro_ponderacion CHECK (
        ponderacion_parcial > 0 AND ponderacion_parcial <= 100
    )
) ENGINE=InnoDB;

-- La suma de ponderacion_parcial de todos los parámetros activos
-- de cada parcial debe ser exactamente 100%.

-- ============================================================
-- 05. ASIGNACIÓN DE ESQUEMA A SECCIÓN
--     Una sección queda ligada históricamente a una versión concreta.
-- ============================================================

CREATE TABLE seccion_esquema_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    esquema_version_id BIGINT UNSIGNED NOT NULL,

    asignado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_bloqueo DATETIME NULL,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_seccion_esquema
        UNIQUE (seccion_id),

    CONSTRAINT fk_see_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_see_version
        FOREIGN KEY (esquema_version_id) REFERENCES esquema_evaluacion_versiones(id),
    CONSTRAINT fk_see_asignado_por
        FOREIGN KEY (asignado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- Cuando inicia la sección, bloqueado=TRUE y la versión no debe cambiar.

-- ============================================================
-- 06. RECURSOS EVALUABLES
--     Se sincronizan desde Moodle, pero aún sin acoplar la BD de Moodle.
-- ============================================================

CREATE TABLE recursos_evaluables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    tipo_recurso_id BIGINT UNSIGNED NOT NULL,
    origen_recurso_id BIGINT UNSIGNED NOT NULL,
    estado_recurso_id BIGINT UNSIGNED NOT NULL,

    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT NULL,

    calificacion_maxima DECIMAL(8,2) NULL,

    -- Referencias externas temporales.
    -- El mapping formal se extenderá en 017_moodle.sql.
    external_course_id VARCHAR(100) NULL,
    external_resource_id VARCHAR(100) NULL,

    visible BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    ultima_sincronizacion_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT fk_recursos_eval_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_recursos_eval_tipo
        FOREIGN KEY (tipo_recurso_id) REFERENCES tipos_recurso_evaluable(id),
    CONSTRAINT fk_recursos_eval_origen
        FOREIGN KEY (origen_recurso_id) REFERENCES origenes_recurso_evaluable(id),
    CONSTRAINT fk_recursos_eval_estado
        FOREIGN KEY (estado_recurso_id) REFERENCES estados_recurso_evaluable(id),

    CONSTRAINT chk_recurso_calificacion_maxima CHECK (
        calificacion_maxima IS NULL OR calificacion_maxima > 0
    )
) ENGINE=InnoDB;

CREATE UNIQUE INDEX uq_recurso_externo
ON recursos_evaluables (seccion_id, external_resource_id);

CREATE INDEX idx_recursos_eval_seccion
ON recursos_evaluables (seccion_id, activo);

-- ============================================================
-- 07. VINCULACIÓN RECURSO -> PARÁMETRO
-- ============================================================

CREATE TABLE recurso_parametro_evaluacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    recurso_id BIGINT UNSIGNED NOT NULL,
    parametro_evaluacion_id BIGINT UNSIGNED NOT NULL,

    vinculado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_vinculacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_recurso_un_parametro
        UNIQUE (recurso_id),

    CONSTRAINT uq_parametro_unico_por_seccion
        UNIQUE (seccion_id, parametro_evaluacion_id),

    CONSTRAINT fk_rpe_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_rpe_recurso
        FOREIGN KEY (recurso_id) REFERENCES recursos_evaluables(id),
    CONSTRAINT fk_rpe_parametro
        FOREIGN KEY (parametro_evaluacion_id) REFERENCES parametros_evaluacion(id),
    CONSTRAINT fk_rpe_usuario
        FOREIGN KEY (vinculado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- Reglas:
-- 1. El recurso debe pertenecer a la misma sección.
-- 2. El parámetro debe pertenecer al esquema asignado a la sección.
-- 3. Si un parámetro ya está usado, NO debe aparecer en la lista disponible.
-- 4. Si un recurso ya tiene calificaciones, no debe reasignarse sin autorización.

-- ============================================================
-- 08. CIERRES DE PARCIALES POR SECCIÓN
-- ============================================================

CREATE TABLE cierres_parciales_seccion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    parcial_id BIGINT UNSIGNED NOT NULL,
    estado_cierre_id BIGINT UNSIGNED NOT NULL,

    fecha_apertura DATETIME NULL,
    fecha_cierre DATETIME NULL,

    cerrado_por_usuario_id BIGINT UNSIGNED NULL,
    reabierto_por_usuario_id BIGINT UNSIGNED NULL,

    observacion VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_cierre_parcial_seccion
        UNIQUE (seccion_id, parcial_id),

    CONSTRAINT fk_cps_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_cps_parcial
        FOREIGN KEY (parcial_id) REFERENCES parciales_evaluacion(id),
    CONSTRAINT fk_cps_estado
        FOREIGN KEY (estado_cierre_id) REFERENCES estados_cierre_parcial(id),
    CONSTRAINT fk_cps_cerrado_por
        FOREIGN KEY (cerrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_cps_reabierto_por
        FOREIGN KEY (reabierto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE historial_cierre_parcial (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    cierre_parcial_seccion_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hcp_cierre
        FOREIGN KEY (cierre_parcial_seccion_id) REFERENCES cierres_parciales_seccion(id),
    CONSTRAINT fk_hcp_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_cierre_parcial(id),
    CONSTRAINT fk_hcp_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_cierre_parcial(id),
    CONSTRAINT fk_hcp_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 09. CALIFICACIONES DE RECURSOS
--     Valor actual operativo/oficial por estudiante-recurso.
-- ============================================================

CREATE TABLE calificaciones_recursos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    recurso_id BIGINT UNSIGNED NOT NULL,
    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,

    estado_calificacion_id BIGINT UNSIGNED NOT NULL,
    origen_calificacion_id BIGINT UNSIGNED NOT NULL,

    nota_obtenida DECIMAL(8,4) NULL,
    nota_maxima DECIMAL(8,4) NOT NULL,

    fecha_calificacion DATETIME NULL,
    calificado_por_usuario_id BIGINT UNSIGNED NULL,

    protegida_correccion_oficial BOOLEAN NOT NULL DEFAULT FALSE,
    solicitud_cambio_nota_id_ref BIGINT UNSIGNED NULL,

    ultima_sincronizacion_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_calificacion_recurso_estudiante
        UNIQUE (recurso_id, matricula_asignatura_id),

    CONSTRAINT fk_cr_recurso
        FOREIGN KEY (recurso_id) REFERENCES recursos_evaluables(id),
    CONSTRAINT fk_cr_matricula_asignatura
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_cr_estado
        FOREIGN KEY (estado_calificacion_id) REFERENCES estados_calificacion_recurso(id),
    CONSTRAINT fk_cr_origen
        FOREIGN KEY (origen_calificacion_id) REFERENCES origenes_calificacion(id),
    CONSTRAINT fk_cr_calificado_por
        FOREIGN KEY (calificado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_cr_notas CHECK (
        nota_maxima > 0
        AND (nota_obtenida IS NULL OR (nota_obtenida >= 0 AND nota_obtenida <= nota_maxima))
    )
) ENGINE=InnoDB;

CREATE INDEX idx_cr_matricula_asignatura
ON calificaciones_recursos (matricula_asignatura_id);

-- ============================================================
-- 10. HISTÓRICO DE CALIFICACIONES
--     Append-only desde la aplicación.
-- ============================================================

CREATE TABLE historial_calificaciones_recursos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    calificacion_recurso_id BIGINT UNSIGNED NOT NULL,

    version_numero INT UNSIGNED NOT NULL,

    nota_anterior DECIMAL(8,4) NULL,
    nota_nueva DECIMAL(8,4) NULL,
    nota_maxima DECIMAL(8,4) NOT NULL,

    origen_calificacion_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(500) NULL,
    solicitud_cambio_nota_id_ref BIGINT UNSIGNED NULL,

    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_hist_calificacion_version
        UNIQUE (calificacion_recurso_id, version_numero),

    CONSTRAINT fk_hcr_calificacion
        FOREIGN KEY (calificacion_recurso_id) REFERENCES calificaciones_recursos(id),
    CONSTRAINT fk_hcr_origen
        FOREIGN KEY (origen_calificacion_id) REFERENCES origenes_calificacion(id),
    CONSTRAINT fk_hcr_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_hcr_notas CHECK (
        nota_maxima > 0
        AND (nota_anterior IS NULL OR (nota_anterior >= 0 AND nota_anterior <= nota_maxima))
        AND (nota_nueva IS NULL OR (nota_nueva >= 0 AND nota_nueva <= nota_maxima))
    )
) ENGINE=InnoDB;

-- ============================================================
-- 11. RESULTADOS CONSOLIDADOS POR PARCIAL
-- ============================================================

CREATE TABLE resultados_parciales_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    parcial_id BIGINT UNSIGNED NOT NULL,

    nota_parcial DECIMAL(4,2) NULL,
    aporte_nota_final DECIMAL(5,4) NULL,

    completo BOOLEAN NOT NULL DEFAULT FALSE,
    oficial BOOLEAN NOT NULL DEFAULT FALSE,

    calculado_at DATETIME NULL,
    oficializado_at DATETIME NULL,

    oficializado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_resultado_parcial_estudiante
        UNIQUE (matricula_asignatura_id, parcial_id),

    CONSTRAINT fk_rpe_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_rpe_parcial
        FOREIGN KEY (parcial_id) REFERENCES parciales_evaluacion(id),
    CONSTRAINT fk_rpe_oficializado_por
        FOREIGN KEY (oficializado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_resultado_parcial_nota CHECK (
        nota_parcial IS NULL OR (nota_parcial >= 0 AND nota_parcial <= 10)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 12. POLÍTICAS HISTÓRICAS DE RESULTADO ACADÉMICO
-- ============================================================

CREATE TABLE politicas_resultado_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_politicas_resultado_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE politica_resultado_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    politica_resultado_id BIGINT UNSIGNED NOT NULL,
    numero_version INT UNSIGNED NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_politica_resultado_version
        UNIQUE (politica_resultado_id, numero_version),

    CONSTRAINT fk_prv_politica
        FOREIGN KEY (politica_resultado_id) REFERENCES politicas_resultado_academico(id),
    CONSTRAINT fk_prv_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_prv_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE TABLE reglas_resultado_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    politica_version_id BIGINT UNSIGNED NOT NULL,
    resultado_academico_id BIGINT UNSIGNED NOT NULL,

    nota_minima DECIMAL(4,2) NOT NULL,
    nota_maxima DECIMAL(4,2) NOT NULL,

    orden_evaluacion SMALLINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_regla_resultado_orden
        UNIQUE (politica_version_id, orden_evaluacion),

    CONSTRAINT fk_rra_version
        FOREIGN KEY (politica_version_id) REFERENCES politica_resultado_versiones(id),
    CONSTRAINT fk_rra_resultado
        FOREIGN KEY (resultado_academico_id) REFERENCES resultados_academicos_catalogo(id),

    CONSTRAINT chk_rra_rango CHECK (
        nota_minima >= 0
        AND nota_maxima <= 10
        AND nota_maxima >= nota_minima
    )
) ENGINE=InnoDB;

-- ============================================================
-- 13. RESULTADO FINAL DE ASIGNATURA
-- ============================================================

CREATE TABLE resultados_finales_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    politica_version_id BIGINT UNSIGNED NOT NULL,
    resultado_academico_id BIGINT UNSIGNED NULL,

    nota_final_ordinaria DECIMAL(4,2) NULL,
    nota_supletorio DECIMAL(4,2) NULL,
    nota_final_definitiva DECIMAL(4,2) NULL,

    oficial BOOLEAN NOT NULL DEFAULT FALSE,

    calculado_at DATETIME NULL,
    oficializado_at DATETIME NULL,
    oficializado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_resultado_final_ma
        UNIQUE (matricula_asignatura_id),

    CONSTRAINT fk_rfa_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_rfa_politica
        FOREIGN KEY (politica_version_id) REFERENCES politica_resultado_versiones(id),
    CONSTRAINT fk_rfa_resultado
        FOREIGN KEY (resultado_academico_id) REFERENCES resultados_academicos_catalogo(id),
    CONSTRAINT fk_rfa_oficializado_por
        FOREIGN KEY (oficializado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_rfa_notas CHECK (
        (nota_final_ordinaria IS NULL OR (nota_final_ordinaria >= 0 AND nota_final_ordinaria <= 10))
        AND
        (nota_supletorio IS NULL OR (nota_supletorio >= 0 AND nota_supletorio <= 10))
        AND
        (nota_final_definitiva IS NULL OR (nota_final_definitiva >= 0 AND nota_final_definitiva <= 10))
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. SUPLETORIOS
-- ============================================================

CREATE TABLE supletorios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    estado_supletorio_id BIGINT UNSIGNED NOT NULL,

    nota_habilitante DECIMAL(4,2) NOT NULL,
    nota_supletorio DECIMAL(4,2) NULL,

    fecha_programada DATETIME NULL,
    fecha_rendida DATETIME NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_supletorio_ma UNIQUE (matricula_asignatura_id),

    CONSTRAINT fk_supletorios_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_supletorios_estado
        FOREIGN KEY (estado_supletorio_id) REFERENCES estados_supletorio(id),
    CONSTRAINT fk_supletorios_usuario
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_supletorio_notas CHECK (
        nota_habilitante >= 0 AND nota_habilitante <= 10
        AND (nota_supletorio IS NULL OR (nota_supletorio >= 0 AND nota_supletorio <= 10))
    )
) ENGINE=InnoDB;

-- ============================================================
-- 15. SOLICITUDES EXCEPCIONALES DE CAMBIO DE NOTA
-- ============================================================

CREATE TABLE solicitudes_cambio_nota (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(50) NOT NULL,

    calificacion_recurso_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_id BIGINT UNSIGNED NOT NULL,

    nota_anterior DECIMAL(8,4) NOT NULL,
    nota_solicitada DECIMAL(8,4) NOT NULL,
    nota_maxima DECIMAL(8,4) NOT NULL,

    motivo TEXT NOT NULL,
    evidencia_archivo_id BIGINT UNSIGNED NULL,

    solicitado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    revisado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    rechazado_por_usuario_id BIGINT UNSIGNED NULL,
    ejecutado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    fecha_aprobacion DATETIME NULL,
    fecha_rechazo DATETIME NULL,
    fecha_ejecucion DATETIME NULL,

    observacion_revision TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitud_cambio_nota_numero
        UNIQUE (numero_solicitud),

    CONSTRAINT fk_scn_calificacion
        FOREIGN KEY (calificacion_recurso_id) REFERENCES calificaciones_recursos(id),
    CONSTRAINT fk_scn_estado
        FOREIGN KEY (estado_solicitud_id) REFERENCES estados_solicitud_cambio_nota(id),
    CONSTRAINT fk_scn_evidencia
        FOREIGN KEY (evidencia_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_scn_solicitado_por
        FOREIGN KEY (solicitado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scn_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scn_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scn_rechazado_por
        FOREIGN KEY (rechazado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scn_ejecutado_por
        FOREIGN KEY (ejecutado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_scn_notas CHECK (
        nota_maxima > 0
        AND nota_anterior >= 0 AND nota_anterior <= nota_maxima
        AND nota_solicitada >= 0 AND nota_solicitada <= nota_maxima
        AND nota_solicitada <> nota_anterior
    )
) ENGINE=InnoDB;

CREATE INDEX idx_scn_estado_fecha
ON solicitudes_cambio_nota (estado_solicitud_id, fecha_solicitud);

-- Una calificación puede tener varias solicitudes históricas,
-- pero la aplicación solo permitirá una solicitud no final simultánea.

-- ============================================================
-- 16. SINCRONIZACIÓN DE CALIFICACIONES
--     Normal: Moodle -> SIGA
--     Corrección oficial: SIGA -> Moodle
-- ============================================================

CREATE TABLE sincronizaciones_calificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    calificacion_recurso_id BIGINT UNSIGNED NOT NULL,
    solicitud_cambio_nota_id BIGINT UNSIGNED NULL,

    direccion_sincronizacion_id BIGINT UNSIGNED NOT NULL,
    estado_sincronizacion_id BIGINT UNSIGNED NOT NULL,

    operacion VARCHAR(80) NOT NULL,

    intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    max_intentos SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    proximo_reintento_at DATETIME NULL,

    request_uuid CHAR(36) NULL,

    valor_enviado DECIMAL(8,4) NULL,
    valor_recibido DECIMAL(8,4) NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sc_calificacion
        FOREIGN KEY (calificacion_recurso_id) REFERENCES calificaciones_recursos(id),
    CONSTRAINT fk_sc_solicitud
        FOREIGN KEY (solicitud_cambio_nota_id) REFERENCES solicitudes_cambio_nota(id),
    CONSTRAINT fk_sc_direccion
        FOREIGN KEY (direccion_sincronizacion_id) REFERENCES direcciones_sincronizacion_calificacion(id),
    CONSTRAINT fk_sc_estado
        FOREIGN KEY (estado_sincronizacion_id) REFERENCES estados_sincronizacion_calificacion(id)
) ENGINE=InnoDB;

CREATE INDEX idx_sc_cola
ON sincronizaciones_calificacion (estado_sincronizacion_id, fecha_programada, proximo_reintento_at);

-- ============================================================
-- 17. CONFLICTOS DE SINCRONIZACIÓN
-- ============================================================

CREATE TABLE conflictos_calificacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    calificacion_recurso_id BIGINT UNSIGNED NOT NULL,

    valor_oficial_siga DECIMAL(8,4) NOT NULL,
    valor_recibido_externo DECIMAL(8,4) NOT NULL,

    motivo VARCHAR(255) NOT NULL,

    resuelto BOOLEAN NOT NULL DEFAULT FALSE,
    resuelto_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_resolucion DATETIME NULL,
    observacion_resolucion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_conflicto_calificacion
        FOREIGN KEY (calificacion_recurso_id) REFERENCES calificaciones_recursos(id),
    CONSTRAINT fk_conflicto_resuelto_por
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_conflictos_pendientes
ON conflictos_calificacion (resuelto, created_at);

-- Si protegida_correccion_oficial=TRUE y Moodle devuelve otro valor,
-- SIGA NO sobrescribe la nota oficial. Crea conflicto_calificacion.

-- ============================================================
-- 18. DATOS INICIALES
-- ============================================================

INSERT INTO estados_esquema_evaluacion
(codigo, nombre, permite_edicion, es_publicado, es_final)
VALUES
('BORRADOR', 'Borrador', TRUE, FALSE, FALSE),
('PUBLICADO', 'Publicado', FALSE, TRUE, FALSE),
('HISTORICO', 'Histórico', FALSE, TRUE, TRUE),
('ANULADO', 'Anulado', FALSE, FALSE, TRUE);

INSERT INTO tipos_recurso_evaluable (codigo, nombre, evaluable) VALUES
('TAREA', 'Tarea / Deber', TRUE),
('CUESTIONARIO', 'Cuestionario', TRUE),
('FORO', 'Foro evaluado', TRUE),
('PROYECTO', 'Proyecto', TRUE),
('EXAMEN', 'Examen', TRUE),
('TALLER', 'Taller', TRUE),
('OTRO_EVALUABLE', 'Otro recurso evaluable', TRUE),
('NO_EVALUABLE', 'Recurso no evaluable', FALSE);

INSERT INTO origenes_recurso_evaluable (codigo, nombre) VALUES
('MOODLE', 'Moodle'),
('SIGA', 'SIGA'),
('IMPORTACION', 'Importación'),
('OTRO', 'Otro');

INSERT INTO estados_recurso_evaluable (codigo, nombre) VALUES
('ACTIVO', 'Activo'),
('OCULTO', 'Oculto'),
('ELIMINADO_ORIGEN', 'Eliminado en sistema de origen'),
('ANULADO', 'Anulado');

INSERT INTO estados_cierre_parcial
(codigo, nombre, permite_cambios_ordinarios)
VALUES
('ABIERTO', 'Abierto', TRUE),
('CERRADO', 'Cerrado', FALSE),
('REABIERTO', 'Reabierto excepcionalmente', TRUE);

INSERT INTO estados_calificacion_recurso
(codigo, nombre, es_oficial)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('SINCRONIZADA', 'Sincronizada', FALSE),
('OFICIAL', 'Oficial', TRUE),
('CORREGIDA_OFICIAL', 'Corregida oficialmente', TRUE),
('ANULADA', 'Anulada', FALSE);

INSERT INTO origenes_calificacion (codigo, nombre) VALUES
('MOODLE', 'Moodle'),
('CORRECCION_SIGA', 'Corrección autorizada desde SIGA'),
('IMPORTACION', 'Importación'),
('MIGRACION', 'Migración histórica'),
('OTRO', 'Otro');

INSERT INTO estados_solicitud_cambio_nota
(codigo, nombre, es_final, permite_ejecucion)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('EN_REVISION', 'En revisión', FALSE, FALSE),
('APROBADA', 'Aprobada', FALSE, TRUE),
('RECHAZADA', 'Rechazada', TRUE, FALSE),
('EJECUTANDO', 'Ejecutando', FALSE, FALSE),
('EJECUTADA', 'Ejecutada', TRUE, FALSE),
('ERROR_SINCRONIZACION', 'Error de sincronización', FALSE, FALSE),
('ANULADA', 'Anulada', TRUE, FALSE);

INSERT INTO estados_sincronizacion_calificacion
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('PROCESANDO', 'Procesando', FALSE),
('EXITOSA', 'Exitosa', TRUE),
('ERROR', 'Error', FALSE),
('REINTENTO', 'Reintento', FALSE),
('CONFLICTO', 'Conflicto', FALSE),
('CANCELADA', 'Cancelada', TRUE);

INSERT INTO direcciones_sincronizacion_calificacion (codigo, nombre) VALUES
('MOODLE_A_SIGA', 'Moodle -> SIGA'),
('SIGA_A_MOODLE', 'SIGA -> Moodle');

INSERT INTO resultados_academicos_catalogo
(codigo, nombre, aprobado, habilita_supletorio, bloquea_supletorio)
VALUES
('REPROBADO_SIN_SUPLETORIO', 'Reprobado sin derecho a supletorio', FALSE, FALSE, TRUE),
('HABILITADO_SUPLETORIO', 'Habilitado para supletorio', FALSE, TRUE, FALSE),
('APROBADO', 'Aprobado', TRUE, FALSE, FALSE),
('REPROBADO_SUPLETORIO', 'Reprobado después de supletorio', FALSE, FALSE, TRUE);

INSERT INTO estados_supletorio
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('PROGRAMADO', 'Programado', FALSE),
('RENDIDO', 'Rendido', FALSE),
('APROBADO', 'Aprobado', TRUE),
('REPROBADO', 'Reprobado', TRUE),
('NO_APLICA', 'No aplica', TRUE),
('ANULADO', 'Anulado', TRUE);

-- ============================================================
-- 19. ESQUEMA GLOBAL ACTUAL 2026
-- ============================================================

INSERT INTO esquemas_evaluacion
(codigo, nombre, descripcion)
VALUES
('EVAL_GENERAL', 'Esquema General de Evaluación', 'Esquema institucional global reutilizable por carreras y secciones');

INSERT INTO esquema_evaluacion_versiones
(esquema_evaluacion_id, estado_esquema_id, numero_version, nombre_version,
 vigente_desde, fecha_publicacion)
SELECT
    e.id,
    s.id,
    1,
    'Versión 1 - 2026',
    '2026-01-01',
    CURRENT_TIMESTAMP
FROM esquemas_evaluacion e
JOIN estados_esquema_evaluacion s ON s.codigo = 'PUBLICADO'
WHERE e.codigo = 'EVAL_GENERAL';

INSERT INTO parciales_evaluacion
(esquema_version_id, codigo, nombre, ponderacion_nota_final, orden_visual)
SELECT v.id, 'P1', 'PARCIAL 1', 50.00, 1
FROM esquema_evaluacion_versiones v
JOIN esquemas_evaluacion e ON e.id = v.esquema_evaluacion_id
WHERE e.codigo = 'EVAL_GENERAL' AND v.numero_version = 1;

INSERT INTO parciales_evaluacion
(esquema_version_id, codigo, nombre, ponderacion_nota_final, orden_visual)
SELECT v.id, 'P2', 'PARCIAL 2', 50.00, 2
FROM esquema_evaluacion_versiones v
JOIN esquemas_evaluacion e ON e.id = v.esquema_evaluacion_id
WHERE e.codigo = 'EVAL_GENERAL' AND v.numero_version = 1;

-- PARCIAL 1
INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U1_AUTONOMA_1', 'U1 Actividad Autónoma 1', 10.00, 1, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id = p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id = v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U1_PRACTICO_1_1', 'U1 Práctico Experimental 1.1', 8.75, 2, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U1_PRACTICO_EF_1_2', 'U1 Práctico Experimental EF 1.2', 8.75, 3, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U2_AUTONOMA_2', 'U2 Actividad Autónoma 2', 10.00, 4, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U2_PRACTICO_2_1', 'U2 Práctico Experimental 2.1', 8.75, 5, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_U2_PRACTICO_EF_2_2', 'U2 Práctico Experimental EF 2.2', 8.75, 6, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_CONTACTO_DOCENTE', 'P1 Contacto con el Docente', 10.00, 7, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_FINAL_TEORICO_1_1', 'P1 Evaluación Final Teórico 1.1', 17.50, 8, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P1_FINAL_PRACTICO_1_2', 'P1 Evaluación Final Práctico 1.2', 17.50, 9, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P1';

-- PARCIAL 2
INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U3_AUTONOMA_1', 'U3 Actividad Autónoma 1', 10.00, 1, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U3_PRACTICO_1_1', 'U3 Práctico Experimental 1.1', 8.75, 2, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U3_PRACTICO_EF_1_2', 'U3 Práctico Experimental EF 1.2', 8.75, 3, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U4_AUTONOMA_2', 'U4 Actividad Autónoma 2', 10.00, 4, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U4_PRACTICO_2_1', 'U4 Práctico Experimental 2.1', 8.75, 5, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_U4_PRACTICO_EF_2_2', 'U4 Práctico Experimental EF 2.2', 8.75, 6, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_CONTACTO_DOCENTE', 'P2 Contacto con el Docente', 10.00, 7, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_FINAL_TEORICO_1_1', 'P2 Evaluación Final Teórico 1.1', 17.50, 8, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

INSERT INTO parametros_evaluacion
(parcial_id, codigo, nombre, ponderacion_parcial, orden_visual, modificable_al_evaluar)
SELECT p.id, 'P2_FINAL_PRACTICO_1_2', 'P2 Evaluación Final Práctico 1.2', 17.50, 9, FALSE
FROM parciales_evaluacion p
JOIN esquema_evaluacion_versiones v ON v.id=p.esquema_version_id
JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
WHERE e.codigo='EVAL_GENERAL' AND v.numero_version=1 AND p.codigo='P2';

-- ============================================================
-- 20. POLÍTICA ACTUAL DE APROBACIÓN / SUPLETORIO
-- ============================================================

INSERT INTO politicas_resultado_academico
(codigo, nombre, descripcion)
VALUES
('POLITICA_GENERAL_NOTAS', 'Política General de Calificaciones', 'Reglas históricas de aprobación y supletorio en escala 0-10');

INSERT INTO politica_resultado_versiones
(politica_resultado_id, numero_version, vigente_desde)
SELECT id, 1, '2026-01-01'
FROM politicas_resultado_academico
WHERE codigo = 'POLITICA_GENERAL_NOTAS';

-- 0.00 - 4.99 -> no supletorio
INSERT INTO reglas_resultado_academico
(politica_version_id, resultado_academico_id, nota_minima, nota_maxima, orden_evaluacion)
SELECT pv.id, r.id, 0.00, 4.99, 1
FROM politica_resultado_versiones pv
JOIN politicas_resultado_academico p ON p.id = pv.politica_resultado_id
JOIN resultados_academicos_catalogo r ON r.codigo = 'REPROBADO_SIN_SUPLETORIO'
WHERE p.codigo='POLITICA_GENERAL_NOTAS' AND pv.numero_version=1;

-- 5.00 - 6.99 -> supletorio
INSERT INTO reglas_resultado_academico
(politica_version_id, resultado_academico_id, nota_minima, nota_maxima, orden_evaluacion)
SELECT pv.id, r.id, 5.00, 6.99, 2
FROM politica_resultado_versiones pv
JOIN politicas_resultado_academico p ON p.id = pv.politica_resultado_id
JOIN resultados_academicos_catalogo r ON r.codigo = 'HABILITADO_SUPLETORIO'
WHERE p.codigo='POLITICA_GENERAL_NOTAS' AND pv.numero_version=1;

-- 7.00 - 10.00 -> aprobado
INSERT INTO reglas_resultado_academico
(politica_version_id, resultado_academico_id, nota_minima, nota_maxima, orden_evaluacion)
SELECT pv.id, r.id, 7.00, 10.00, 3
FROM politica_resultado_versiones pv
JOIN politicas_resultado_academico p ON p.id = pv.politica_resultado_id
JOIN resultados_academicos_catalogo r ON r.codigo = 'APROBADO'
WHERE p.codigo='POLITICA_GENERAL_NOTAS' AND pv.numero_version=1;

-- ============================================================
-- 21. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ESQUEMAS:
-- - Se configuran globalmente.
-- - Una versión PUBLICADA es inmutable.
-- - Para cambiar nombres/porcentajes se crea nueva versión.
-- - La suma de parciales debe ser 100%.
-- - La suma de parámetros de cada parcial debe ser 100%.
--
-- SECCIÓN:
-- - Al abrir un curso se asigna una versión de esquema.
-- - Una vez iniciado, se bloquea y nunca cambia retroactivamente.
--
-- RECURSOS:
-- - Moodle crea tareas/cuestionarios/etc.
-- - SIGA sincroniza recursos.
-- - Docente entra:
--      Docente -> Mis cursos -> Curso -> Evaluación
-- - Selecciona un recurso y luego un parámetro disponible.
-- - Un recurso = un parámetro.
-- - Un parámetro solo puede usarse una vez en esa sección.
--
-- CALIFICACIÓN NORMAL:
-- - Mientras el parcial está ABIERTO:
--      Moodle -> SIGA
-- - Docente califica normalmente en Moodle.
-- - SIGA consolida parciales y nota final.
--
-- CIERRE:
-- - Cuando Académico cierra el parcial:
--      no se permiten cambios ordinarios.
-- - Si se requiere corrección:
--      se crea solicitudes_cambio_nota.
--
-- CAMBIO EXCEPCIONAL:
-- 1. Docente solicita.
-- 2. Guarda nota_anterior, nota_solicitada, motivo, evidencia.
-- 3. Académico revisa.
-- 4. RECHAZADA -> no cambia nota.
-- 5. APROBADA -> servicio ejecuta:
--      - guardar historial
--      - modificar calificaciones_recursos
--      - marcar CORREGIDA_OFICIAL
--      - protegida_correccion_oficial = TRUE
--      - recalcular parcial
--      - recalcular nota final
--      - crear sync SIGA_A_MOODLE
-- 6. Si Moodle falla -> reintento.
-- 7. Si Moodle luego intenta enviar un valor distinto:
--      NO sobrescribir;
--      crear conflictos_calificacion.
--
-- SUPLETORIO:
-- Política actual:
--   0.00 - 4.99 = reprobado sin supletorio
--   5.00 - 6.99 = habilitado para supletorio
--   7.00 - 10.00 = aprobado
-- Las reglas son históricas y versionadas.
--
-- INTENTOS:
-- Al oficializar resultado REPROBADO, 007_matriculas.sql actualizará
-- historial_intentos_asignatura.
-- Si es tercer intento reprobado -> bloqueo de carrera.
--
-- ============================================================
-- FIN 008_evaluacion_calificaciones.sql
-- ============================================================
