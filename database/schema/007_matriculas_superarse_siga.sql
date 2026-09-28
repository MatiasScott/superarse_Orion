-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 007_matriculas.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
--   003_talento_humano_superarse_siga.sql
--   004_admisiones_estudiantes_superarse_siga.sql
--   005_estructura_academica_superarse_siga.sql
--   006_periodos_oferta_academica_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Matrícula general por período
--   - Matrícula por sección/asignatura
--   - Renovaciones
--   - Intentos de matrícula (máximo 3 por asignatura)
--   - Prerrequisitos AND
--   - Materias pendientes
--   - Bloqueos académicos
--   - Reconocimientos/homologaciones aplicados a matrícula
--   - Preparación para matrícula automática posterior a aprobación financiera
--
-- PRINCIPIOS:
--   - La matrícula oficial vive en SIGA.
--   - Moodle será consecuencia de la matrícula, no la fuente maestra.
--   - Un estudiante puede avanzar de período aun con materias pendientes.
--   - Solo puede matricular asignaturas cuyos prerrequisitos estén aprobados/reconocidos.
--   - Máximo 3 intentos por asignatura.
--   - Si reprueba el tercer intento, se bloquea la trayectoria/carrera.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE MATRÍCULA
-- ============================================================

CREATE TABLE tipos_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_matricula_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    permite_cursar BOOLEAN NOT NULL DEFAULT FALSE,
    permite_modificacion BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_matricula_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_matricula_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    consume_intento BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_matricula_asignatura_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_bloqueo_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,
    bloquea_matricula_carrera BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_bloqueo_academico_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_bloqueo_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_bloqueo_academico_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_resultado_validacion_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    bloqueante BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_resultado_validacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_renovacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_renovacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. MATRÍCULA GENERAL POR PERÍODO
-- ============================================================

CREATE TABLE matriculas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_matricula VARCHAR(50) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    oferta_academica_id BIGINT UNSIGNED NOT NULL,

    tipo_matricula_id BIGINT UNSIGNED NOT NULL,
    estado_matricula_id BIGINT UNSIGNED NOT NULL,

    fecha_solicitud DATETIME NULL,
    fecha_matricula DATETIME NULL,
    fecha_confirmacion DATETIME NULL,
    fecha_anulacion DATETIME NULL,

    generada_automaticamente BOOLEAN NOT NULL DEFAULT FALSE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,
    confirmada_por_usuario_id BIGINT UNSIGNED NULL,
    anulada_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,
    motivo_anulacion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_matriculas_numero UNIQUE (numero_matricula),
    CONSTRAINT uq_matricula_trayectoria_periodo
        UNIQUE (estudiante_carrera_id, periodo_academico_id),

    CONSTRAINT fk_matriculas_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_matriculas_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_matriculas_oferta
        FOREIGN KEY (oferta_academica_id) REFERENCES ofertas_academicas(id),
    CONSTRAINT fk_matriculas_tipo
        FOREIGN KEY (tipo_matricula_id) REFERENCES tipos_matricula(id),
    CONSTRAINT fk_matriculas_estado
        FOREIGN KEY (estado_matricula_id) REFERENCES estados_matricula(id),
    CONSTRAINT fk_matriculas_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_matriculas_confirmada_por
        FOREIGN KEY (confirmada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_matriculas_anulada_por
        FOREIGN KEY (anulada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_matriculas_periodo_estado
ON matriculas (periodo_academico_id, estado_matricula_id);

CREATE INDEX idx_matriculas_estudiante
ON matriculas (estudiante_carrera_id, periodo_academico_id);

-- ============================================================
-- 03. MATRÍCULA POR ASIGNATURA / SECCIÓN
-- ============================================================

CREATE TABLE matricula_asignaturas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_id BIGINT UNSIGNED NOT NULL,
    seccion_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,

    estado_matricula_asignatura_id BIGINT UNSIGNED NOT NULL,

    numero_intento SMALLINT UNSIGNED NOT NULL,

    fecha_matricula DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_retiro DATETIME NULL,

    materia_pendiente BOOLEAN NOT NULL DEFAULT FALSE,
    reconocimiento_aplicado BOOLEAN NOT NULL DEFAULT FALSE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_matricula_seccion
        UNIQUE (matricula_id, seccion_id),

    CONSTRAINT fk_ma_matricula
        FOREIGN KEY (matricula_id) REFERENCES matriculas(id),
    CONSTRAINT fk_ma_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_ma_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_ma_estado
        FOREIGN KEY (estado_matricula_asignatura_id) REFERENCES estados_matricula_asignatura(id),
    CONSTRAINT fk_ma_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ma_numero_intento CHECK (
        numero_intento BETWEEN 1 AND 3
    )
) ENGINE=InnoDB;

CREATE INDEX idx_ma_matricula_estado
ON matricula_asignaturas (matricula_id, estado_matricula_asignatura_id);

CREATE INDEX idx_ma_malla_asignatura
ON matricula_asignaturas (malla_asignatura_id, numero_intento);

-- ============================================================
-- 04. HISTÓRICO DE INTENTOS POR ASIGNATURA
--     Fuente oficial para saber cuántas veces ha cursado una materia.
-- ============================================================

CREATE TABLE historial_intentos_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,
    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,

    numero_intento SMALLINT UNSIGNED NOT NULL,

    resultado VARCHAR(40) NULL,
    nota_final DECIMAL(4,2) NULL,

    fecha_resultado DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_hist_intento
        UNIQUE (estudiante_carrera_id, malla_asignatura_id, numero_intento),

    CONSTRAINT fk_hia_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_hia_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_hia_matricula_asignatura
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),

    CONSTRAINT chk_hia_intento CHECK (
        numero_intento BETWEEN 1 AND 3
    ),
    CONSTRAINT chk_hia_nota CHECK (
        nota_final IS NULL OR (nota_final >= 0 AND nota_final <= 10)
    )
) ENGINE=InnoDB;

CREATE INDEX idx_hia_estudiante_asignatura
ON historial_intentos_asignatura (estudiante_carrera_id, malla_asignatura_id);

-- ============================================================
-- 05. BLOQUEOS ACADÉMICOS
-- ============================================================

CREATE TABLE bloqueos_academicos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    tipo_bloqueo_id BIGINT UNSIGNED NOT NULL,
    estado_bloqueo_id BIGINT UNSIGNED NOT NULL,

    matricula_asignatura_id BIGINT UNSIGNED NULL,
    malla_asignatura_id BIGINT UNSIGNED NULL,

    motivo TEXT NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    cerrado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_bloqueos_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_bloqueos_tipo
        FOREIGN KEY (tipo_bloqueo_id) REFERENCES tipos_bloqueo_academico(id),
    CONSTRAINT fk_bloqueos_estado
        FOREIGN KEY (estado_bloqueo_id) REFERENCES estados_bloqueo_academico(id),
    CONSTRAINT fk_bloqueos_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_bloqueos_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_bloqueos_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_bloqueos_cerrado_por
        FOREIGN KEY (cerrado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_bloqueo_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_bloqueos_estudiante_activo
ON bloqueos_academicos (estudiante_carrera_id, activo);

-- ============================================================
-- 06. VALIDACIONES DE MATRÍCULA
--     Guarda el resultado del motor antes de confirmar matrícula.
-- ============================================================

CREATE TABLE validaciones_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_id BIGINT UNSIGNED NOT NULL,
    tipo_resultado_id BIGINT UNSIGNED NOT NULL,

    malla_asignatura_id BIGINT UNSIGNED NULL,
    seccion_id BIGINT UNSIGNED NULL,

    mensaje VARCHAR(500) NOT NULL,

    bloqueante BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_vm_matricula
        FOREIGN KEY (matricula_id) REFERENCES matriculas(id),
    CONSTRAINT fk_vm_tipo
        FOREIGN KEY (tipo_resultado_id) REFERENCES tipos_resultado_validacion_matricula(id),
    CONSTRAINT fk_vm_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_vm_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

CREATE INDEX idx_vm_matricula_bloqueante
ON validaciones_matricula (matricula_id, bloqueante);

-- ============================================================
-- 07. PRERREQUISITOS CUMPLIDOS / NO CUMPLIDOS
--     Evidencia del cálculo en el momento de matrícula.
-- ============================================================

CREATE TABLE validacion_prerrequisitos_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,
    prerrequisito_malla_asignatura_id BIGINT UNSIGNED NOT NULL,

    cumplido BOOLEAN NOT NULL,
    fuente_cumplimiento VARCHAR(60) NULL,
    referencia_id BIGINT UNSIGNED NULL,

    detalle VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_vpm
        UNIQUE (matricula_id, malla_asignatura_id, prerrequisito_malla_asignatura_id),

    CONSTRAINT fk_vpm_matricula
        FOREIGN KEY (matricula_id) REFERENCES matriculas(id),
    CONSTRAINT fk_vpm_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_vpm_prerrequisito
        FOREIGN KEY (prerrequisito_malla_asignatura_id) REFERENCES malla_asignaturas(id)
) ENGINE=InnoDB;

-- ============================================================
-- 08. RECONOCIMIENTOS APLICADOS A MATRÍCULA
-- ============================================================

CREATE TABLE matricula_reconocimientos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,

    tipo_equivalencia_id BIGINT UNSIGNED NOT NULL,

    origen_malla_asignatura_id BIGINT UNSIGNED NULL,
    solicitud_cambio_malla_id BIGINT UNSIGNED NULL,

    aprobado BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_aplicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    aplicado_por_usuario_id BIGINT UNSIGNED NULL,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_matricula_reconocimiento
        UNIQUE (matricula_id, malla_asignatura_id),

    CONSTRAINT fk_mr_matricula
        FOREIGN KEY (matricula_id) REFERENCES matriculas(id),
    CONSTRAINT fk_mr_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_mr_tipo_equivalencia
        FOREIGN KEY (tipo_equivalencia_id) REFERENCES tipos_equivalencia_asignatura(id),
    CONSTRAINT fk_mr_origen
        FOREIGN KEY (origen_malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_mr_cambio_malla
        FOREIGN KEY (solicitud_cambio_malla_id) REFERENCES solicitudes_cambio_malla(id),
    CONSTRAINT fk_mr_usuario
        FOREIGN KEY (aplicado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 09. RENOVACIONES
-- ============================================================

CREATE TABLE renovaciones_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_renovacion VARCHAR(40) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_origen_id BIGINT UNSIGNED NOT NULL,
    periodo_destino_id BIGINT UNSIGNED NOT NULL,
    estado_renovacion_id BIGINT UNSIGNED NOT NULL,

    matricula_origen_id BIGINT UNSIGNED NULL,
    matricula_destino_id BIGINT UNSIGNED NULL,

    calculada_automaticamente BOOLEAN NOT NULL DEFAULT TRUE,
    confirmada_manualmente BOOLEAN NOT NULL DEFAULT FALSE,

    fecha_calculo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_confirmacion DATETIME NULL,

    confirmado_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_renovaciones_numero UNIQUE (numero_renovacion),
    CONSTRAINT uq_renovacion_trayectoria_destino
        UNIQUE (estudiante_carrera_id, periodo_destino_id),

    CONSTRAINT fk_renovacion_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_renovacion_periodo_origen
        FOREIGN KEY (periodo_origen_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_renovacion_periodo_destino
        FOREIGN KEY (periodo_destino_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_renovacion_estado
        FOREIGN KEY (estado_renovacion_id) REFERENCES estados_renovacion(id),
    CONSTRAINT fk_renovacion_matricula_origen
        FOREIGN KEY (matricula_origen_id) REFERENCES matriculas(id),
    CONSTRAINT fk_renovacion_matricula_destino
        FOREIGN KEY (matricula_destino_id) REFERENCES matriculas(id),
    CONSTRAINT fk_renovacion_confirmado_por
        FOREIGN KEY (confirmado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_renovacion_periodos_distintos CHECK (
        periodo_origen_id <> periodo_destino_id
    )
) ENGINE=InnoDB;

CREATE INDEX idx_renovaciones_estado
ON renovaciones_matricula (estado_renovacion_id, periodo_destino_id);

-- ============================================================
-- 10. PROPUESTA DE MATERIAS PARA RENOVACIÓN
-- ============================================================

CREATE TABLE renovacion_asignaturas_propuestas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    renovacion_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,

    seccion_propuesta_id BIGINT UNSIGNED NULL,

    es_pendiente BOOLEAN NOT NULL DEFAULT FALSE,
    prerrequisitos_cumplidos BOOLEAN NOT NULL DEFAULT TRUE,
    bloqueada BOOLEAN NOT NULL DEFAULT FALSE,

    motivo_bloqueo VARCHAR(255) NULL,

    incluir_en_matricula BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_renovacion_asignatura
        UNIQUE (renovacion_id, malla_asignatura_id),

    CONSTRAINT fk_rap_renovacion
        FOREIGN KEY (renovacion_id) REFERENCES renovaciones_matricula(id),
    CONSTRAINT fk_rap_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_rap_seccion
        FOREIGN KEY (seccion_propuesta_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. HISTÓRICO DE ESTADOS DE MATRÍCULA
-- ============================================================

CREATE TABLE historial_estado_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hem_matricula
        FOREIGN KEY (matricula_id) REFERENCES matriculas(id),
    CONSTRAINT fk_hem_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_matricula(id),
    CONSTRAINT fk_hem_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_matricula(id),
    CONSTRAINT fk_hem_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hem_matricula_fecha
ON historial_estado_matricula (matricula_id, changed_at);

-- ============================================================
-- 12. PREPARACIÓN PARA MATRÍCULA AUTOMÁTICA POR PAGO
-- ============================================================

CREATE TABLE estados_habilitacion_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    habilita BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_habilitacion_matricula_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE habilitaciones_matricula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    estado_habilitacion_id BIGINT UNSIGNED NOT NULL,

    origen VARCHAR(60) NOT NULL,
    referencia_id BIGINT UNSIGNED NULL,

    fecha_habilitacion DATETIME NULL,
    fecha_deshabilitacion DATETIME NULL,

    observacion VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_habilitacion_trayectoria_periodo
        UNIQUE (estudiante_carrera_id, periodo_academico_id),

    CONSTRAINT fk_hm_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_hm_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_hm_estado
        FOREIGN KEY (estado_habilitacion_id) REFERENCES estados_habilitacion_matricula(id),

    CONSTRAINT chk_hm_fechas CHECK (
        fecha_deshabilitacion IS NULL
        OR fecha_habilitacion IS NULL
        OR fecha_deshabilitacion >= fecha_habilitacion
    )
) ENGINE=InnoDB;

-- El bloque financiero actualizará esta tabla mediante servicio de dominio:
--   PAGO_APROBADO / ABONO_>=80 / BLOQUEO_FINANCIERO / etc.

-- ============================================================
-- 13. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_matricula (codigo, nombre, descripcion) VALUES
('INICIAL', 'Matrícula inicial', 'Primera matrícula de la trayectoria'),
('RENOVACION', 'Renovación', 'Matrícula de continuación de estudios'),
('REINGRESO', 'Reingreso', 'Matrícula por reingreso'),
('HOMOLOGACION', 'Homologación', 'Matrícula vinculada a homologación'),
('CAMBIO_CARRERA', 'Cambio de carrera', 'Matrícula por nueva carrera'),
('OTRA', 'Otra', 'Otro tipo de matrícula');

INSERT INTO estados_matricula
(codigo, nombre, permite_cursar, permite_modificacion, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, TRUE, FALSE),
('PENDIENTE_VALIDACION', 'Pendiente de validación', FALSE, TRUE, FALSE),
('PENDIENTE_FINANCIERO', 'Pendiente financiero', FALSE, TRUE, FALSE),
('CONFIRMADA', 'Confirmada', TRUE, FALSE, FALSE),
('EN_CURSO', 'En curso', TRUE, FALSE, FALSE),
('FINALIZADA', 'Finalizada', FALSE, FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, FALSE, TRUE);

INSERT INTO estados_matricula_asignatura
(codigo, nombre, consume_intento)
VALUES
('MATRICULADA', 'Matriculada', TRUE),
('EN_CURSO', 'En curso', TRUE),
('APROBADA', 'Aprobada', TRUE),
('REPROBADA', 'Reprobada', TRUE),
('RETIRADA', 'Retirada', TRUE),
('RECONOCIDA', 'Reconocida / homologada', FALSE),
('ANULADA', 'Anulada', FALSE);

INSERT INTO tipos_bloqueo_academico
(codigo, nombre, descripcion, bloquea_matricula_carrera)
VALUES
('TERCERA_MATRICULA_REPROBADA', 'Tercera matrícula reprobada', 'Bloquea continuidad en la carrera actual', TRUE),
('PRERREQUISITO', 'Prerrequisito incumplido', 'Bloqueo de asignatura por prerrequisito', FALSE),
('DISCIPLINARIO', 'Bloqueo disciplinario', 'Bloqueo académico por disposición institucional', TRUE),
('ADMINISTRATIVO', 'Bloqueo administrativo', 'Bloqueo administrativo temporal', TRUE),
('OTRO', 'Otro', 'Otro tipo de bloqueo', TRUE);

INSERT INTO estados_bloqueo_academico (codigo, nombre) VALUES
('ACTIVO', 'Activo'),
('LEVANTADO', 'Levantado'),
('ANULADO', 'Anulado');

INSERT INTO tipos_resultado_validacion_matricula
(codigo, nombre, bloqueante)
VALUES
('OK', 'Validación correcta', FALSE),
('PRERREQUISITO_NO_CUMPLIDO', 'Prerrequisito no cumplido', TRUE),
('TERCERA_MATRICULA_BLOQUEADA', 'Carrera bloqueada por tercera matrícula', TRUE),
('SECCION_NO_DISPONIBLE', 'Sección no disponible', TRUE),
('CUPO_AGOTADO', 'Cupo agotado', TRUE),
('MALLA_INCOMPATIBLE', 'Malla incompatible', TRUE),
('FUERA_DE_OFERTA', 'Asignatura fuera de oferta', TRUE),
('PAGO_NO_HABILITA', 'Estado financiero no habilita matrícula', TRUE),
('ADVERTENCIA_MATERIA_PENDIENTE', 'Materia pendiente', FALSE),
('OTRO', 'Otro', FALSE);

INSERT INTO estados_renovacion
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('CALCULADA', 'Calculada', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('CONFIRMADA', 'Confirmada', TRUE),
('RECHAZADA', 'Rechazada', TRUE),
('ANULADA', 'Anulada', TRUE);

INSERT INTO estados_habilitacion_matricula
(codigo, nombre, habilita)
VALUES
('NO_HABILITADA', 'No habilitada', FALSE),
('HABILITADA', 'Habilitada', TRUE),
('BLOQUEADA_FINANCIERO', 'Bloqueada por financiero', FALSE),
('BLOQUEADA_ACADEMICO', 'Bloqueada por académico', FALSE),
('PENDIENTE', 'Pendiente', FALSE);

-- ============================================================
-- 14. REGLAS DE APLICACIÓN
-- ============================================================
--
-- MATRÍCULA:
-- 1. Debe existir estudiante_carreras activo y compatible con oferta.
-- 2. La oferta debe corresponder a la misma carrera/malla/sede/modalidad.
-- 3. Cada sección debe pertenecer a la oferta.
-- 4. El estudiante debe estar habilitado por financiero cuando aplique.
--
-- PRERREQUISITOS:
-- Para una materia X, se consultan TODAS las filas activas en
-- malla_asignatura_prerrequisitos.
-- Todas deben tener evidencia de cumplimiento:
--   - aprobada previamente
--   - reconocida
--   - homologada
-- No existe lógica OR.
--
-- MATERIAS PENDIENTES:
-- El estudiante puede renovar al siguiente período con materias pendientes.
-- Debe repetir las pendientes y solo matricular materias nuevas cuyos
-- prerrequisitos estén aprobados.
--
-- INTENTOS:
-- numero_intento = 1,2,3
-- Nunca > 3.
-- Si intento 3 queda REPROBADA:
--   - crear bloqueos_academicos tipo TERCERA_MATRICULA_REPROBADA
--   - actualizar estudiante_carreras a BLOQUEADA_TERCERA_MATRICULA
--   - impedir nuevas matrículas en esa trayectoria.
--
-- RENOVACIÓN:
-- El motor puede calcularla automáticamente, pero Académico puede confirmar
-- individual o masivamente.
--
-- FINANCIERO:
-- 010_financiero.sql controlará pagos y actualizará habilitaciones_matricula.
-- Para primer pago >= 80% (según política vigente) podrá habilitar matrícula.
--
-- MOODLE:
-- 017_moodle.sql sincronizará SOLO matrículas confirmadas.
-- Si Moodle falla, la matrícula SIGA permanece válida y queda pendiente de sync.
--
-- ============================================================
-- FIN 007_matriculas.sql
-- ============================================================
