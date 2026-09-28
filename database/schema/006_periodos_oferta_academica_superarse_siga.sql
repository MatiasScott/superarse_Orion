-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 006_periodos_oferta_academica.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
--   003_talento_humano_superarse_siga.sql
--   004_admisiones_estudiantes_superarse_siga.sql
--   005_estructura_academica_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Períodos académicos
--   - Ofertas académicas por carrera/malla/sede/modalidad
--   - Cursos/secciones/paralelos
--   - Docentes asignados
--   - Horarios y aulas
--   - Relación con asignaturas de malla
--   - Preparación para integración Moodle
--
-- PRINCIPIOS:
--   - La oferta se crea por período académico.
--   - Un curso/sección representa una asignatura ofertada en un período.
--   - La asignatura base proviene de malla_asignaturas.
--   - Los docentes pueden tener múltiples asignaciones históricas.
--   - Los horarios son entidades separadas y normalizadas.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE PERIODOS Y OFERTA
-- ============================================================

CREATE TABLE estados_periodo_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    permite_calificacion BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_periodo_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_periodo_academico (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_periodo_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_oferta_academica (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_oferta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_seccion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    permite_calificacion BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estados_seccion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_aula (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_aula_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_horario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipos_horario_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE dias_semana (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(30) NOT NULL,
    orden SMALLINT UNSIGNED NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_dias_semana_codigo UNIQUE (codigo),
    CONSTRAINT uq_dias_semana_orden UNIQUE (orden)
) ENGINE=InnoDB;

CREATE TABLE roles_docente_seccion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_roles_docente_seccion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. PERIODOS ACADÉMICOS
-- ============================================================

CREATE TABLE periodos_academicos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    institucion_id BIGINT UNSIGNED NOT NULL,
    tipo_periodo_id BIGINT UNSIGNED NULL,
    estado_periodo_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,

    fecha_inicio_matricula DATE NULL,
    fecha_fin_matricula DATE NULL,

    fecha_inicio_calificaciones DATE NULL,
    fecha_fin_calificaciones DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_periodos_codigo UNIQUE (institucion_id, codigo),

    CONSTRAINT fk_periodos_institucion
        FOREIGN KEY (institucion_id) REFERENCES instituciones(id),
    CONSTRAINT fk_periodos_tipo
        FOREIGN KEY (tipo_periodo_id) REFERENCES tipos_periodo_academico(id),
    CONSTRAINT fk_periodos_estado
        FOREIGN KEY (estado_periodo_id) REFERENCES estados_periodo_academico(id),

    CONSTRAINT chk_periodo_fechas CHECK (
        fecha_fin >= fecha_inicio
        AND (fecha_inicio_matricula IS NULL OR fecha_fin_matricula IS NULL OR fecha_fin_matricula >= fecha_inicio_matricula)
        AND (fecha_inicio_calificaciones IS NULL OR fecha_fin_calificaciones IS NULL OR fecha_fin_calificaciones >= fecha_inicio_calificaciones)
    )
) ENGINE=InnoDB;

CREATE INDEX idx_periodos_estado_fechas
ON periodos_academicos (estado_periodo_id, fecha_inicio, fecha_fin);

-- ============================================================
-- 03. AULAS / ESPACIOS
-- ============================================================

CREATE TABLE aulas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sede_id BIGINT UNSIGNED NOT NULL,
    tipo_aula_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    capacidad SMALLINT UNSIGNED NULL,

    ubicacion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_aulas_sede_codigo UNIQUE (sede_id, codigo),

    CONSTRAINT fk_aulas_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_aulas_tipo
        FOREIGN KEY (tipo_aula_id) REFERENCES tipos_aula(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. OFERTA ACADÉMICA
-- ============================================================

CREATE TABLE ofertas_academicas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo_academico_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,
    malla_id BIGINT UNSIGNED NOT NULL,
    sede_id BIGINT UNSIGNED NULL,
    modalidad_academica_id BIGINT UNSIGNED NULL,
    estado_oferta_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    fecha_publicacion DATETIME NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_oferta_codigo UNIQUE (periodo_academico_id, codigo),

    CONSTRAINT fk_oferta_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_oferta_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id),
    CONSTRAINT fk_oferta_malla
        FOREIGN KEY (malla_id) REFERENCES mallas_curriculares(id),
    CONSTRAINT fk_oferta_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_oferta_modalidad
        FOREIGN KEY (modalidad_academica_id) REFERENCES modalidades_academicas(id),
    CONSTRAINT fk_oferta_estado
        FOREIGN KEY (estado_oferta_id) REFERENCES estados_oferta_academica(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ofertas_periodo_carrera
ON ofertas_academicas (periodo_academico_id, carrera_id, estado_oferta_id);

-- ============================================================
-- 05. PARALELOS
-- ============================================================

CREATE TABLE paralelos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_paralelos_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 06. CURSOS / SECCIONES
-- ============================================================

CREATE TABLE secciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    oferta_academica_id BIGINT UNSIGNED NOT NULL,
    malla_asignatura_id BIGINT UNSIGNED NOT NULL,
    paralelo_id BIGINT UNSIGNED NULL,
    estado_seccion_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(220) NOT NULL,

    cupo_maximo SMALLINT UNSIGNED NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_apertura DATETIME NULL,
    fecha_cierre DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_secciones_codigo UNIQUE (oferta_academica_id, codigo),

    CONSTRAINT fk_secciones_oferta
        FOREIGN KEY (oferta_academica_id) REFERENCES ofertas_academicas(id),
    CONSTRAINT fk_secciones_malla_asignatura
        FOREIGN KEY (malla_asignatura_id) REFERENCES malla_asignaturas(id),
    CONSTRAINT fk_secciones_paralelo
        FOREIGN KEY (paralelo_id) REFERENCES paralelos(id),
    CONSTRAINT fk_secciones_estado
        FOREIGN KEY (estado_seccion_id) REFERENCES estados_seccion(id),

    CONSTRAINT chk_seccion_fechas CHECK (
        fecha_cierre IS NULL OR fecha_apertura IS NULL OR fecha_cierre >= fecha_apertura
    )
) ENGINE=InnoDB;

CREATE INDEX idx_secciones_oferta_asignatura
ON secciones (oferta_academica_id, malla_asignatura_id, estado_seccion_id);

CREATE INDEX idx_secciones_activa
ON secciones (estado_seccion_id, activo);

-- ============================================================
-- 07. ASIGNACIÓN DE DOCENTES A SECCIÓN
-- ============================================================

CREATE TABLE seccion_docentes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    docente_id BIGINT UNSIGNED NOT NULL,
    rol_docente_seccion_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    asignado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_seccion_docente_periodo
        UNIQUE (seccion_id, docente_id, rol_docente_seccion_id, fecha_inicio),

    CONSTRAINT fk_seccion_docentes_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_seccion_docentes_docente
        FOREIGN KEY (docente_id) REFERENCES docentes(id),
    CONSTRAINT fk_seccion_docentes_rol
        FOREIGN KEY (rol_docente_seccion_id) REFERENCES roles_docente_seccion(id),
    CONSTRAINT fk_seccion_docentes_asignado_por
        FOREIGN KEY (asignado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_seccion_docente_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_seccion_docentes_activos
ON seccion_docentes (seccion_id, activo);

CREATE INDEX idx_docente_secciones_activas
ON seccion_docentes (docente_id, activo);

-- ============================================================
-- 08. HORARIOS
-- ============================================================

CREATE TABLE seccion_horarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    tipo_horario_id BIGINT UNSIGNED NOT NULL,
    dia_semana_id BIGINT UNSIGNED NOT NULL,
    aula_id BIGINT UNSIGNED NULL,

    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,

    fecha_desde DATE NULL,
    fecha_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_seccion_horarios_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_seccion_horarios_tipo
        FOREIGN KEY (tipo_horario_id) REFERENCES tipos_horario(id),
    CONSTRAINT fk_seccion_horarios_dia
        FOREIGN KEY (dia_semana_id) REFERENCES dias_semana(id),
    CONSTRAINT fk_seccion_horarios_aula
        FOREIGN KEY (aula_id) REFERENCES aulas(id),

    CONSTRAINT chk_seccion_horario_horas CHECK (
        hora_fin > hora_inicio
    ),
    CONSTRAINT chk_seccion_horario_fechas CHECK (
        fecha_hasta IS NULL OR fecha_desde IS NULL OR fecha_hasta >= fecha_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_seccion_horarios_seccion
ON seccion_horarios (seccion_id, dia_semana_id, activo);

CREATE INDEX idx_seccion_horarios_aula
ON seccion_horarios (aula_id, dia_semana_id, hora_inicio, hora_fin);

-- ============================================================
-- 09. BLOQUES / COMPONENTES DE HORARIO OPCIONALES
-- ============================================================

CREATE TABLE bloques_horarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    orden SMALLINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_bloques_horarios_codigo UNIQUE (codigo),
    CONSTRAINT uq_bloques_horarios_orden UNIQUE (orden),
    CONSTRAINT chk_bloque_horario CHECK (hora_fin > hora_inicio)
) ENGINE=InnoDB;

CREATE TABLE seccion_bloques_horario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    dia_semana_id BIGINT UNSIGNED NOT NULL,
    bloque_horario_id BIGINT UNSIGNED NOT NULL,
    aula_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_seccion_bloque
        UNIQUE (seccion_id, dia_semana_id, bloque_horario_id),

    CONSTRAINT fk_sbh_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_sbh_dia
        FOREIGN KEY (dia_semana_id) REFERENCES dias_semana(id),
    CONSTRAINT fk_sbh_bloque
        FOREIGN KEY (bloque_horario_id) REFERENCES bloques_horarios(id),
    CONSTRAINT fk_sbh_aula
        FOREIGN KEY (aula_id) REFERENCES aulas(id)
) ENGINE=InnoDB;

-- Se puede usar seccion_horarios directamente o bloques_horarios si la
-- institución desea manejar franjas normalizadas.

-- ============================================================
-- 10. HISTÓRICO DE ESTADOS DE SECCIÓN
-- ============================================================

CREATE TABLE historial_estado_seccion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_hist_seccion_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_seccion(id),
    CONSTRAINT fk_hist_seccion_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_seccion(id),
    CONSTRAINT fk_hist_seccion_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_seccion_fecha
ON historial_estado_seccion (seccion_id, changed_at);

-- ============================================================
-- 11. PREPARACIÓN PARA MOODLE
--     No se crean aún tablas de mapping externas definitivas.
--     Solo campos estables del SIGA; el mapping real se hará en 017_moodle.sql.
-- ============================================================

CREATE TABLE seccion_integracion_estado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,

    preparada_para_moodle BOOLEAN NOT NULL DEFAULT FALSE,
    publicada_en_moodle BOOLEAN NOT NULL DEFAULT FALSE,

    ultima_preparacion_at DATETIME NULL,
    observacion VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_seccion_integracion_estado UNIQUE (seccion_id),

    CONSTRAINT fk_sie_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

-- ============================================================
-- 12. DATOS INICIALES
-- ============================================================

INSERT INTO estados_periodo_academico
(codigo, nombre, permite_matricula, permite_calificacion, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE, FALSE),
('PLANIFICACION', 'Planificación', FALSE, FALSE, FALSE),
('MATRICULA', 'Matrícula', TRUE, FALSE, FALSE),
('EN_CURSO', 'En curso', FALSE, TRUE, FALSE),
('CIERRE', 'Cierre académico', FALSE, FALSE, FALSE),
('CERRADO', 'Cerrado', FALSE, FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, FALSE, TRUE);

INSERT INTO tipos_periodo_academico (codigo, nombre) VALUES
('ORDINARIO', 'Ordinario'),
('EXTRAORDINARIO', 'Extraordinario'),
('ESPECIAL', 'Especial'),
('OTRO', 'Otro');

INSERT INTO estados_oferta_academica
(codigo, nombre, permite_matricula)
VALUES
('BORRADOR', 'Borrador', FALSE),
('PUBLICADA', 'Publicada', TRUE),
('CERRADA', 'Cerrada', FALSE),
('ANULADA', 'Anulada', FALSE);

INSERT INTO estados_seccion
(codigo, nombre, permite_matricula, permite_calificacion)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('ABIERTA', 'Abierta', TRUE, FALSE),
('EN_CURSO', 'En curso', FALSE, TRUE),
('CERRADA', 'Cerrada', FALSE, FALSE),
('ANULADA', 'Anulada', FALSE, FALSE);

INSERT INTO tipos_aula (codigo, nombre) VALUES
('FISICA', 'Aula física'),
('LABORATORIO', 'Laboratorio'),
('VIRTUAL', 'Aula virtual'),
('OTRA', 'Otra');

INSERT INTO tipos_horario (codigo, nombre) VALUES
('CLASE', 'Clase'),
('PRACTICA', 'Práctica'),
('TUTORIA', 'Tutoría'),
('EXAMEN', 'Examen'),
('OTRO', 'Otro');

INSERT INTO dias_semana (codigo, nombre, orden) VALUES
('LUNES', 'Lunes', 1),
('MARTES', 'Martes', 2),
('MIERCOLES', 'Miércoles', 3),
('JUEVES', 'Jueves', 4),
('VIERNES', 'Viernes', 5),
('SABADO', 'Sábado', 6),
('DOMINGO', 'Domingo', 7);

INSERT INTO roles_docente_seccion (codigo, nombre) VALUES
('PRINCIPAL', 'Docente principal'),
('APOYO', 'Docente de apoyo'),
('TUTOR', 'Tutor'),
('OTRO', 'Otro');

INSERT INTO paralelos (codigo, nombre) VALUES
('A', 'Paralelo A'),
('B', 'Paralelo B'),
('C', 'Paralelo C'),
('D', 'Paralelo D'),
('UNICO', 'Paralelo único');

-- ============================================================
-- 13. REGLAS DE APLICACIÓN
-- ============================================================
--
-- PERÍODO ACADÉMICO:
-- El período define ventanas de matrícula y calificación.
--
-- OFERTA:
-- Cada oferta debe corresponder a una carrera + malla + período.
-- La aplicación debe validar que la malla pertenezca a la carrera.
--
-- SECCIÓN:
-- Cada sección debe apuntar a una malla_asignatura de la misma malla
-- definida en la oferta académica.
--
-- DOCENTE:
-- Solo docentes habilitados deberían poder asignarse a una sección.
--
-- HORARIOS:
-- La aplicación debe validar choques de aula y docente.
-- La base deja índices para detectar colisiones, pero la regla se resuelve
-- en el servicio académico antes de guardar.
--
-- MOODLE:
-- El mapping real SIGA <-> Moodle se crea en 017_moodle.sql.
-- Aquí solo preparamos la sección para futura publicación/sincronización.
--
-- MATRÍCULA:
-- El bloque 007_matriculas.sql referenciará secciones reales, no solo
-- asignaturas abstractas. Así cada estudiante queda matriculado en una
-- oferta concreta del período.
--
-- ============================================================
-- FIN 006_periodos_oferta_academica.sql
-- ============================================================
