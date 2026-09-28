-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 005_estructura_academica.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
--   003_talento_humano_superarse_siga.sql
--   004_admisiones_estudiantes_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Carreras, modalidades y niveles
--   - Mallas curriculares versionadas y estados
--   - Asignaturas reutilizables entre mallas
--   - Créditos e intensidad horaria
--   - Prerrequisitos AND
--   - Equivalencias / reconocimientos entre asignaturas
--   - Cohortes
--   - Trayectorias estudiante-carrera-malla
--   - Preferencia de carrera en admisión
--
-- PRINCIPIOS:
--   - Una carrera puede tener varias mallas.
--   - Solo las mallas vigentes se asignan a nuevos estudiantes.
--   - Las mallas no vigentes permanecen para estudiantes antiguos.
--   - Una asignatura existe una sola vez en el catálogo maestro.
--   - Su ubicación/nivel/créditos pertenecen a la relación malla-asignatura.
--   - Todos los prerrequisitos son obligatorios (AND).
--   - Créditos con 2 decimales.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS ACADÉMICOS
-- ============================================================

CREATE TABLE tipos_carrera (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_carrera_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_carrera (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_nuevos_ingresos BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_carrera_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE modalidades_academicas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_modalidades_academicas_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_malla (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_nuevos_estudiantes BOOLEAN NOT NULL DEFAULT FALSE,
    es_historica BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_malla_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_asignatura_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_trayectoria_academica (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_trayectoria_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_cambio_malla (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_cambio_malla_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_equivalencia_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_equivalencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. CARRERAS
-- ============================================================

CREATE TABLE carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    institucion_id BIGINT UNSIGNED NOT NULL,
    tipo_carrera_id BIGINT UNSIGNED NULL,
    estado_carrera_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    titulo_otorgado VARCHAR(220) NULL,
    abreviatura VARCHAR(50) NULL,

    numero_niveles SMALLINT UNSIGNED NULL,

    fecha_inicio_vigencia DATE NULL,
    fecha_fin_vigencia DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_carreras_codigo UNIQUE (institucion_id, codigo),

    CONSTRAINT fk_carreras_institucion
        FOREIGN KEY (institucion_id) REFERENCES instituciones(id),
    CONSTRAINT fk_carreras_tipo
        FOREIGN KEY (tipo_carrera_id) REFERENCES tipos_carrera(id),
    CONSTRAINT fk_carreras_estado
        FOREIGN KEY (estado_carrera_id) REFERENCES estados_carrera(id),

    CONSTRAINT chk_carrera_vigencia CHECK (
        fecha_fin_vigencia IS NULL
        OR fecha_inicio_vigencia IS NULL
        OR fecha_fin_vigencia >= fecha_inicio_vigencia
    )
) ENGINE=InnoDB;

CREATE INDEX idx_carreras_estado
ON carreras (estado_carrera_id, activo);

CREATE TABLE carrera_sedes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    carrera_id BIGINT UNSIGNED NOT NULL,
    sede_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_carrera_sede UNIQUE (carrera_id, sede_id),

    CONSTRAINT fk_carrera_sedes_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_carrera_sedes_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),

    CONSTRAINT chk_carrera_sede_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE TABLE carrera_modalidades (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    carrera_id BIGINT UNSIGNED NOT NULL,
    modalidad_academica_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_carrera_modalidad UNIQUE (carrera_id, modalidad_academica_id),

    CONSTRAINT fk_carrera_modalidad_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_carrera_modalidad_modalidad
        FOREIGN KEY (modalidad_academica_id) REFERENCES modalidades_academicas(id),

    CONSTRAINT chk_carrera_modalidad_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

-- ============================================================
-- 03. NIVELES ACADÉMICOS
-- ============================================================

CREATE TABLE niveles_academicos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    orden_nivel SMALLINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_niveles_academicos_codigo UNIQUE (codigo),
    CONSTRAINT uq_niveles_academicos_orden UNIQUE (orden_nivel)
) ENGINE=InnoDB;

-- ============================================================
-- 04. MALLAS CURRICULARES
-- ============================================================

CREATE TABLE mallas_curriculares (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    carrera_id BIGINT UNSIGNED NOT NULL,
    estado_malla_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    version VARCHAR(60) NULL,
    descripcion TEXT NULL,

    fecha_inicio_vigencia DATE NOT NULL,
    fecha_fin_vigencia DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_mallas_carrera_codigo UNIQUE (carrera_id, codigo),

    CONSTRAINT fk_mallas_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_mallas_estado
        FOREIGN KEY (estado_malla_id) REFERENCES estados_malla(id),

    CONSTRAINT chk_malla_vigencia CHECK (
        fecha_fin_vigencia IS NULL OR fecha_fin_vigencia >= fecha_inicio_vigencia
    )
) ENGINE=InnoDB;

CREATE INDEX idx_mallas_carrera_estado
ON mallas_curriculares (carrera_id, estado_malla_id, activo);

-- ============================================================
-- 05. ASIGNATURAS MAESTRAS
-- ============================================================

CREATE TABLE asignaturas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_asignatura_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_asignaturas_codigo UNIQUE (codigo),

    CONSTRAINT fk_asignaturas_tipo
        FOREIGN KEY (tipo_asignatura_id) REFERENCES tipos_asignatura(id)
) ENGINE=InnoDB;

CREATE INDEX idx_asignaturas_nombre
ON asignaturas (nombre);

-- ============================================================
-- 06. ASIGNATURAS DENTRO DE UNA MALLA
-- ============================================================

CREATE TABLE malla_asignaturas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    malla_id BIGINT UNSIGNED NOT NULL,
    asignatura_id BIGINT UNSIGNED NOT NULL,
    nivel_academico_id BIGINT UNSIGNED NOT NULL,

    creditos DECIMAL(6,2) NOT NULL,
    ih_semanal DECIMAL(6,2) NULL,
    ih_total DECIMAL(8,2) NULL,

    orden_en_nivel SMALLINT UNSIGNED NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
    evaluable BOOLEAN NOT NULL DEFAULT TRUE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_malla_asignatura UNIQUE (malla_id, asignatura_id),

    CONSTRAINT fk_malla_asignaturas_malla
        FOREIGN KEY (malla_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_malla_asignaturas_asignatura
        FOREIGN KEY (asignatura_id) REFERENCES asignaturas(id),
    CONSTRAINT fk_malla_asignaturas_nivel
        FOREIGN KEY (nivel_academico_id) REFERENCES niveles_academicos(id),

    CONSTRAINT chk_malla_asig_creditos CHECK (creditos >= 0),
    CONSTRAINT chk_malla_asig_ih_semanal CHECK (ih_semanal IS NULL OR ih_semanal >= 0),
    CONSTRAINT chk_malla_asig_ih_total CHECK (ih_total IS NULL OR ih_total >= 0)
) ENGINE=InnoDB;

CREATE INDEX idx_malla_asignaturas_nivel
ON malla_asignaturas (malla_id, nivel_academico_id, orden_en_nivel);

-- ============================================================
-- 07. PRERREQUISITOS
--     Regla institucional: AND únicamente.
-- ============================================================

CREATE TABLE malla_asignatura_prerrequisitos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    malla_asignatura_id BIGINT UNSIGNED NOT NULL,
    prerrequisito_malla_asignatura_id BIGINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_prerrequisito
        UNIQUE (malla_asignatura_id, prerrequisito_malla_asignatura_id),

    CONSTRAINT fk_prerreq_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_prerreq_requisito
        FOREIGN KEY (prerrequisito_malla_asignatura_id) REFERENCES malla_asignaturas(id),

    CONSTRAINT chk_prerreq_no_autoreferencia CHECK (
        malla_asignatura_id <> prerrequisito_malla_asignatura_id
    )
) ENGINE=InnoDB;

-- La aplicación debe validar además que ambos registros pertenezcan
-- a la misma malla curricular.

-- ============================================================
-- 08. EQUIVALENCIAS / RECONOCIMIENTOS
-- ============================================================

CREATE TABLE equivalencias_asignaturas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_equivalencia_id BIGINT UNSIGNED NOT NULL,

    malla_asignatura_origen_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_destino_id BIGINT UNSIGNED NOT NULL,

    porcentaje_reconocimiento DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    observacion TEXT NULL,

    fecha_inicio_vigencia DATE NOT NULL,
    fecha_fin_vigencia DATE NULL,

    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_equivalencia_asignaturas
        UNIQUE (malla_asignatura_origen_id, malla_asignatura_destino_id, fecha_inicio_vigencia),

    CONSTRAINT fk_equivalencias_tipo
        FOREIGN KEY (tipo_equivalencia_id) REFERENCES tipos_equivalencia_asignatura(id),
    CONSTRAINT fk_equivalencias_origen
        FOREIGN KEY (malla_asignatura_origen_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_equivalencias_destino
        FOREIGN KEY (malla_asignatura_destino_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_equivalencias_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_equivalencia_porcentaje CHECK (
        porcentaje_reconocimiento >= 0 AND porcentaje_reconocimiento <= 100
    ),
    CONSTRAINT chk_equivalencia_fechas CHECK (
        fecha_fin_vigencia IS NULL OR fecha_fin_vigencia >= fecha_inicio_vigencia
    ),
    CONSTRAINT chk_equivalencia_no_autoreferencia CHECK (
        malla_asignatura_origen_id <> malla_asignatura_destino_id
    )
) ENGINE=InnoDB;

-- Para asignaturas con el mismo código/identidad maestra entre mallas,
-- el sistema puede reconocerlas automáticamente sin crear equivalencia manual.

-- ============================================================
-- 09. COHORTES
-- ============================================================

CREATE TABLE cohortes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,

    fecha_inicio DATE NULL,
    fecha_fin_estimada DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_cohortes_codigo UNIQUE (codigo),

    CONSTRAINT chk_cohorte_fechas CHECK (
        fecha_fin_estimada IS NULL
        OR fecha_inicio IS NULL
        OR fecha_fin_estimada >= fecha_inicio
    )
) ENGINE=InnoDB;

-- ============================================================
-- 10. TRAYECTORIAS ACADÉMICAS
--     Una persona puede tener varias carreras a lo largo del tiempo.
-- ============================================================

CREATE TABLE estudiante_carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,
    malla_id BIGINT UNSIGNED NOT NULL,
    cohorte_id BIGINT UNSIGNED NULL,

    estado_trayectoria_id BIGINT UNSIGNED NOT NULL,
    tipo_ingreso_id BIGINT UNSIGNED NULL,

    sede_id BIGINT UNSIGNED NULL,
    modalidad_academica_id BIGINT UNSIGNED NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    nivel_referencial_id BIGINT UNSIGNED NULL,

    motivo_finalizacion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_estudiante_carrera_inicio
        UNIQUE (estudiante_id, carrera_id, fecha_inicio),

    CONSTRAINT fk_estudiante_carreras_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    CONSTRAINT fk_estudiante_carreras_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_estudiante_carreras_malla
        FOREIGN KEY (malla_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_estudiante_carreras_cohorte
        FOREIGN KEY (cohorte_id) REFERENCES cohortes(id),
    CONSTRAINT fk_estudiante_carreras_estado
        FOREIGN KEY (estado_trayectoria_id) REFERENCES estados_trayectoria_academica(id),
    CONSTRAINT fk_estudiante_carreras_tipo_ingreso
        FOREIGN KEY (tipo_ingreso_id) REFERENCES tipos_ingreso_estudiante(id),
    CONSTRAINT fk_estudiante_carreras_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_estudiante_carreras_modalidad
        FOREIGN KEY (modalidad_academica_id) REFERENCES modalidades_academicas(id),
    CONSTRAINT fk_estudiante_carreras_nivel
        FOREIGN KEY (nivel_referencial_id) REFERENCES niveles_academicos(id),

    CONSTRAINT chk_estudiante_carrera_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_estudiante_carreras_estado
ON estudiante_carreras (estudiante_id, estado_trayectoria_id, activo);

CREATE INDEX idx_estudiante_carreras_carrera_malla
ON estudiante_carreras (carrera_id, malla_id, activo);

-- ============================================================
-- 11. HISTÓRICO DE TRAYECTORIA
-- ============================================================

CREATE TABLE historial_estado_trayectoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_trayectoria
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_hist_trayectoria_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_trayectoria_academica(id),
    CONSTRAINT fk_hist_trayectoria_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_trayectoria_academica(id),
    CONSTRAINT fk_hist_trayectoria_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_trayectoria_fecha
ON historial_estado_trayectoria (estudiante_carrera_id, changed_at);

-- ============================================================
-- 12. SOLICITUD DE CAMBIO DE MALLA
-- ============================================================

CREATE TABLE estados_solicitud_cambio_malla (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_cambio_malla_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE solicitudes_cambio_malla (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(40) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    malla_origen_id BIGINT UNSIGNED NOT NULL,
    malla_destino_id BIGINT UNSIGNED NOT NULL,

    tipo_cambio_malla_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_id BIGINT UNSIGNED NOT NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    fecha_resolucion DATETIME NULL,

    solicitado_por_usuario_id BIGINT UNSIGNED NULL,
    revisado_por_usuario_id BIGINT UNSIGNED NULL,
    resuelto_por_usuario_id BIGINT UNSIGNED NULL,

    motivo TEXT NULL,
    observacion_resolucion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitud_cambio_malla_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_scm_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_scm_malla_origen
        FOREIGN KEY (malla_origen_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_scm_malla_destino
        FOREIGN KEY (malla_destino_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_scm_tipo
        FOREIGN KEY (tipo_cambio_malla_id) REFERENCES tipos_cambio_malla(id),
    CONSTRAINT fk_scm_estado
        FOREIGN KEY (estado_solicitud_id) REFERENCES estados_solicitud_cambio_malla(id),
    CONSTRAINT fk_scm_solicitado_por
        FOREIGN KEY (solicitado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scm_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_scm_resuelto_por
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_scm_mallas_distintas CHECK (
        malla_origen_id <> malla_destino_id
    )
) ENGINE=InnoDB;

-- ============================================================
-- 13. DETALLE DE RECONOCIMIENTO EN CAMBIO DE MALLA
-- ============================================================

CREATE TABLE cambio_malla_reconocimientos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_cambio_malla_id BIGINT UNSIGNED NOT NULL,

    malla_asignatura_origen_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_destino_id BIGINT UNSIGNED NOT NULL,

    tipo_equivalencia_id BIGINT UNSIGNED NOT NULL,

    reconocimiento_automatico BOOLEAN NOT NULL DEFAULT FALSE,
    porcentaje_reconocimiento DECIMAL(5,2) NOT NULL DEFAULT 100.00,

    observacion VARCHAR(255) NULL,

    aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_aprobacion DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_cambio_malla_reconocimiento
        UNIQUE (solicitud_cambio_malla_id, malla_asignatura_origen_id, malla_asignatura_destino_id),

    CONSTRAINT fk_cmr_solicitud
        FOREIGN KEY (solicitud_cambio_malla_id) REFERENCES solicitudes_cambio_malla(id),
    CONSTRAINT fk_cmr_origen
        FOREIGN KEY (malla_asignatura_origen_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_cmr_destino
        FOREIGN KEY (malla_asignatura_destino_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_cmr_tipo
        FOREIGN KEY (tipo_equivalencia_id) REFERENCES tipos_equivalencia_asignatura(id),
    CONSTRAINT fk_cmr_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_cmr_porcentaje CHECK (
        porcentaje_reconocimiento >= 0 AND porcentaje_reconocimiento <= 100
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. PREFERENCIA / SELECCIÓN DE CARRERA EN ADMISIÓN
-- ============================================================

CREATE TABLE solicitud_admision_carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_admision_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,
    sede_id BIGINT UNSIGNED NULL,
    modalidad_academica_id BIGINT UNSIGNED NULL,

    prioridad SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    seleccionada BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_admision_carrera_prioridad
        UNIQUE (solicitud_admision_id, prioridad),

    CONSTRAINT fk_sac_solicitud
        FOREIGN KEY (solicitud_admision_id) REFERENCES solicitudes_admision(id),
    CONSTRAINT fk_sac_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_sac_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_sac_modalidad
        FOREIGN KEY (modalidad_academica_id) REFERENCES modalidades_academicas(id)
) ENGINE=InnoDB;

CREATE INDEX idx_sac_solicitud_seleccionada
ON solicitud_admision_carreras (solicitud_admision_id, seleccionada);

-- ============================================================
-- 15. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_carrera (codigo, nombre) VALUES
('TECNICO_SUPERIOR', 'Técnico Superior'),
('TECNOLOGIA_SUPERIOR', 'Tecnología Superior'),
('OTRA', 'Otra');

INSERT INTO estados_carrera
(codigo, nombre, permite_nuevos_ingresos)
VALUES
('ACTIVA', 'Activa', TRUE),
('INACTIVA', 'Inactiva', FALSE),
('CERRADA', 'Cerrada', FALSE),
('EN_TRANSICION', 'En transición', FALSE);

INSERT INTO modalidades_academicas (codigo, nombre) VALUES
('PRESENCIAL', 'Presencial'),
('SEMIPRESENCIAL', 'Semipresencial'),
('EN_LINEA', 'En línea'),
('HIBRIDA', 'Híbrida'),
('OTRA', 'Otra');

INSERT INTO estados_malla
(codigo, nombre, permite_nuevos_estudiantes, es_historica)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('VIGENTE', 'Vigente', TRUE, FALSE),
('NO_VIGENTE', 'No vigente', FALSE, TRUE),
('ARCHIVADA', 'Archivada', FALSE, TRUE);

INSERT INTO tipos_asignatura (codigo, nombre) VALUES
('ACADEMICA', 'Asignatura académica'),
('PRACTICAS', 'Prácticas preprofesionales'),
('VINCULACION', 'Vinculación con la sociedad'),
('TITULACION', 'Trabajo / componente de titulación'),
('IDIOMA', 'Idioma extranjero'),
('OTRA', 'Otra');

INSERT INTO estados_trayectoria_academica
(codigo, nombre, descripcion, permite_matricula, es_final)
VALUES
('PREMATRICULA', 'Prematrícula', 'Trayectoria en prematrícula', TRUE, FALSE),
('ACTIVA', 'Activa', 'Trayectoria activa', TRUE, FALSE),
('RENOVACION', 'Renovación', 'Trayectoria en renovación', TRUE, FALSE),
('SUSPENDIDA', 'Suspendida', 'Trayectoria suspendida', FALSE, FALSE),
('BLOQUEADA_TERCERA_MATRICULA', 'Bloqueada por tercera matrícula', 'No puede continuar en la carrera', FALSE, TRUE),
('RETIRADA', 'Retirada', 'Trayectoria retirada', FALSE, TRUE),
('EGRESADA', 'Egresada', 'Malla culminada / condición de egreso según proceso', FALSE, FALSE),
('GRADUADA', 'Graduada', 'Trayectoria graduada', FALSE, TRUE),
('ANULADA', 'Anulada', 'Trayectoria anulada', FALSE, TRUE);

INSERT INTO tipos_cambio_malla (codigo, nombre) VALUES
('SOLICITUD_ESTUDIANTE', 'Solicitud del estudiante'),
('ACTUALIZACION_INSTITUCIONAL', 'Actualización institucional'),
('HOMOLOGACION', 'Cambio por homologación'),
('OTRO', 'Otro');

INSERT INTO tipos_equivalencia_asignatura (codigo, nombre, descripcion) VALUES
('MISMA_ASIGNATURA', 'Misma asignatura', 'Misma asignatura maestra usada en ambas mallas'),
('EQUIVALENCIA', 'Equivalencia', 'Asignaturas diferentes reconocidas como equivalentes'),
('HOMOLOGACION', 'Homologación', 'Reconocimiento académico por proceso de homologación'),
('PARCIAL', 'Reconocimiento parcial', 'Reconocimiento parcial sujeto a revisión');

INSERT INTO niveles_academicos (codigo, nombre, orden_nivel) VALUES
('N1', 'Nivel 1', 1),
('N2', 'Nivel 2', 2),
('N3', 'Nivel 3', 3),
('N4', 'Nivel 4', 4),
('N5', 'Nivel 5', 5),
('N6', 'Nivel 6', 6),
('N7', 'Nivel 7', 7),
('N8', 'Nivel 8', 8);

INSERT INTO estados_solicitud_cambio_malla
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('APROBADA', 'Aprobada', TRUE),
('RECHAZADA', 'Rechazada', TRUE),
('ANULADA', 'Anulada', TRUE);

-- ============================================================
-- 16. REGLAS DE APLICACIÓN
-- ============================================================
--
-- NUEVOS ESTUDIANTES:
-- 1. Admisiones selecciona carrera/sede/modalidad.
-- 2. Al aprobarse la admisión se crea estudiante.
-- 3. Al crear estudiante_carreras:
--      - usar únicamente una malla con estado VIGENTE
--      - la malla debe pertenecer a la carrera seleccionada
--
-- MALLAS ANTIGUAS:
-- Los estudiantes ya asignados a mallas NO_VIGENTES pueden continuar.
-- NO se deben reasignar automáticamente a la malla vigente.
--
-- ASIGNATURAS REPETIDAS ENTRE MALLAS:
-- Si ambas mallas usan la misma asignatura maestra (asignatura_id),
-- el historial académico puede reconocerse automáticamente.
--
-- CAMBIO DE MALLA:
-- 1. Crear solicitudes_cambio_malla.
-- 2. Comparar asignaturas origen/destino.
-- 3. Misma asignatura maestra -> reconocimiento automático.
-- 4. Código/asignatura diferente -> usar equivalencias/homologación.
-- 5. Conservar SIEMPRE la trayectoria y malla anterior en histórico.
--
-- PRERREQUISITOS:
-- Todos son AND.
-- Para cursar una materia, TODAS las filas activas de
-- malla_asignatura_prerrequisitos deben estar aprobadas/reconocidas.
--
-- TERCERA MATRÍCULA:
-- La regla de máximo 3 intentos se implementará en 007_matriculas.sql.
-- Si reprueba el tercer intento, estudiante_carreras pasa a
-- BLOQUEADA_TERCERA_MATRICULA.
--
-- ============================================================
-- FIN 005_estructura_academica.sql
-- ============================================================
