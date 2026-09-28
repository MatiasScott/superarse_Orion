-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 015_encuestas.sql
-- Requiere bloques 001-014
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión de encuestas institucionales
--   - Encuestas a estudiantes, docentes y administrativos
--   - Evaluación docente por estudiantes
--   - Evaluación por pares docentes
--   - Autoevaluación docente
--   - Encuestas generales de una sola aplicación o por asignatura
--   - Preguntas de texto, respuesta única, múltiple y escala
--   - Copia de preguntas desde encuestas anteriores
--   - Publicar / despublicar / archivar
--   - Máximo 10 preguntas por página
--   - Resultados, indicadores y exportación
--   - Encuestas obligatorias que pueden bloquear otras acciones
--
-- PRINCIPIOS:
--   - Una encuesta publicada no debe permitir cambios estructurales arbitrarios.
--   - Preguntas y opciones se versionan por encuesta.
--   - Las respuestas no se eliminan físicamente.
--   - La obligatoriedad se controla por asignación y vigencia.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS
-- ============================================================

CREATE TABLE tipos_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    permite_edicion_estructura BOOLEAN NOT NULL DEFAULT FALSE,
    visible_usuarios BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE audiencias_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_audiencia_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE modos_aplicacion_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_modo_aplicacion_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_pregunta_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_opciones BOOLEAN NOT NULL DEFAULT FALSE,
    permite_multiples BOOLEAN NOT NULL DEFAULT FALSE,
    permite_escala BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_pregunta_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_asignacion_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    pendiente BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_asignacion_encuesta_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_relacion_evaluacion_docente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(170) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_rel_eval_docente_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. ENCUESTAS
-- ============================================================

CREATE TABLE encuestas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    tipo_encuesta_id BIGINT UNSIGNED NOT NULL,
    estado_encuesta_id BIGINT UNSIGNED NOT NULL,
    audiencia_encuesta_id BIGINT UNSIGNED NOT NULL,
    modo_aplicacion_encuesta_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT FALSE,
    bloquea_otras_acciones BOOLEAN NOT NULL DEFAULT FALSE,

    preguntas_por_pagina SMALLINT UNSIGNED NOT NULL DEFAULT 10,

    permite_anonimato BOOLEAN NOT NULL DEFAULT FALSE,
    es_anonima BOOLEAN NOT NULL DEFAULT FALSE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,
    publicada_por_usuario_id BIGINT UNSIGNED NULL,
    archivada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_publicacion DATETIME NULL,
    fecha_archivo DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_encuesta_codigo UNIQUE (codigo),

    CONSTRAINT fk_encuesta_tipo
        FOREIGN KEY (tipo_encuesta_id) REFERENCES tipos_encuesta(id),
    CONSTRAINT fk_encuesta_estado
        FOREIGN KEY (estado_encuesta_id) REFERENCES estados_encuesta(id),
    CONSTRAINT fk_encuesta_audiencia
        FOREIGN KEY (audiencia_encuesta_id) REFERENCES audiencias_encuesta(id),
    CONSTRAINT fk_encuesta_modo
        FOREIGN KEY (modo_aplicacion_encuesta_id) REFERENCES modos_aplicacion_encuesta(id),
    CONSTRAINT fk_encuesta_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_encuesta_publicada_por
        FOREIGN KEY (publicada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_encuesta_archivada_por
        FOREIGN KEY (archivada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_encuesta_fechas CHECK (
        fecha_fin >= fecha_inicio
    ),
    CONSTRAINT chk_encuesta_preguntas_pagina CHECK (
        preguntas_por_pagina BETWEEN 1 AND 10
    )
) ENGINE=InnoDB;

CREATE INDEX idx_encuestas_estado_fechas
ON encuestas (estado_encuesta_id, fecha_inicio, fecha_fin);

-- ============================================================
-- 03. ALCANCE DE ENCUESTA
-- ============================================================

CREATE TABLE encuesta_sedes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    sede_id BIGINT UNSIGNED NOT NULL,

    CONSTRAINT uq_encuesta_sede UNIQUE (encuesta_id, sede_id),

    CONSTRAINT fk_es_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_es_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id)
) ENGINE=InnoDB;

CREATE TABLE encuesta_carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,

    CONSTRAINT uq_encuesta_carrera UNIQUE (encuesta_id, carrera_id),

    CONSTRAINT fk_ec_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_ec_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id)
) ENGINE=InnoDB;

CREATE TABLE encuesta_secciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    seccion_id BIGINT UNSIGNED NOT NULL,

    CONSTRAINT uq_encuesta_seccion UNIQUE (encuesta_id, seccion_id),

    CONSTRAINT fk_ese_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_ese_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. PREGUNTAS
-- ============================================================

CREATE TABLE preguntas_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    tipo_pregunta_id BIGINT UNSIGNED NOT NULL,

    texto_pregunta TEXT NOT NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,

    orden_pregunta SMALLINT UNSIGNED NOT NULL,
    numero_pagina SMALLINT UNSIGNED NOT NULL,

    escala_minima DECIMAL(6,2) NULL,
    escala_maxima DECIMAL(6,2) NULL,
    etiqueta_minima VARCHAR(120) NULL,
    etiqueta_maxima VARCHAR(120) NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    copiada_de_pregunta_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_pregunta_orden
        UNIQUE (encuesta_id, orden_pregunta),

    CONSTRAINT fk_pe_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_pe_tipo
        FOREIGN KEY (tipo_pregunta_id) REFERENCES tipos_pregunta_encuesta(id),
    CONSTRAINT fk_pe_copiada_de
        FOREIGN KEY (copiada_de_pregunta_id) REFERENCES preguntas_encuesta(id),

    CONSTRAINT chk_pe_pagina CHECK (
        numero_pagina >= 1
    ),
    CONSTRAINT chk_pe_escala CHECK (
        escala_minima IS NULL
        OR escala_maxima IS NULL
        OR escala_maxima > escala_minima
    )
) ENGINE=InnoDB;

CREATE INDEX idx_pe_encuesta_pagina
ON preguntas_encuesta (encuesta_id, numero_pagina, orden_pregunta);

-- ============================================================
-- 05. OPCIONES DE RESPUESTA
-- ============================================================

CREATE TABLE opciones_pregunta_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    valor VARCHAR(100) NOT NULL,
    etiqueta VARCHAR(220) NOT NULL,

    orden SMALLINT UNSIGNED NOT NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_opcion_pregunta_orden
        UNIQUE (pregunta_encuesta_id, orden),

    CONSTRAINT fk_ope_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id)
) ENGINE=InnoDB;

-- ============================================================
-- 06. RELACIONES DE EVALUACIÓN DOCENTE
-- ============================================================

CREATE TABLE relaciones_evaluacion_docente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    tipo_relacion_evaluacion_docente_id BIGINT UNSIGNED NOT NULL,

    evaluador_usuario_id BIGINT UNSIGNED NOT NULL,
    evaluado_usuario_id BIGINT UNSIGNED NOT NULL,

    seccion_id BIGINT UNSIGNED NULL,
    seccion_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(seccion_id, 0)) STORED,
    carrera_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_rel_eval_docente
        UNIQUE (encuesta_id, evaluador_usuario_id, evaluado_usuario_id, seccion_key),

    CONSTRAINT fk_red_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_red_tipo
        FOREIGN KEY (tipo_relacion_evaluacion_docente_id) REFERENCES tipos_relacion_evaluacion_docente(id),
    CONSTRAINT fk_red_evaluador
        FOREIGN KEY (evaluador_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_red_evaluado
        FOREIGN KEY (evaluado_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_red_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_red_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id)
) ENGINE=InnoDB;

-- La app valida:
-- PARES -> evaluador != evaluado
-- AUTOEVALUACION -> evaluador = evaluado
-- ESTUDIANTE_DOCENTE -> estudiante evalúa docente asignado

-- ============================================================
-- 07. ASIGNACIONES DE ENCUESTA
-- ============================================================

CREATE TABLE asignaciones_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,
    estado_asignacion_encuesta_id BIGINT UNSIGNED NOT NULL,

    relacion_evaluacion_docente_id BIGINT UNSIGNED NULL,
    relacion_evaluacion_docente_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(relacion_evaluacion_docente_id, 0)) STORED,
    seccion_id BIGINT UNSIGNED NULL,
    seccion_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(seccion_id, 0)) STORED,

    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite DATETIME NULL,
    fecha_inicio_respuesta DATETIME NULL,
    fecha_completado DATETIME NULL,

    obligatoria BOOLEAN NOT NULL DEFAULT FALSE,
    bloquea_otras_acciones BOOLEAN NOT NULL DEFAULT FALSE,

    token_anonimo_hash CHAR(64) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_asignacion_encuesta_usuario_contexto
        UNIQUE (
            encuesta_id,
            usuario_id,
            seccion_key,
            relacion_evaluacion_docente_key
        ),

    CONSTRAINT fk_ae_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_ae_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ae_estado
        FOREIGN KEY (estado_asignacion_encuesta_id) REFERENCES estados_asignacion_encuesta(id),
    CONSTRAINT fk_ae_relacion_docente
        FOREIGN KEY (relacion_evaluacion_docente_id) REFERENCES relaciones_evaluacion_docente(id),
    CONSTRAINT fk_ae_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ae_usuario_pendiente
ON asignaciones_encuesta (usuario_id, estado_asignacion_encuesta_id, obligatoria);

-- ============================================================
-- 08. RESPUESTAS / INTENTOS
-- ============================================================

CREATE TABLE respuestas_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    asignacion_encuesta_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_envio DATETIME NULL,

    completada BOOLEAN NOT NULL DEFAULT FALSE,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_respuesta_asignacion UNIQUE (asignacion_encuesta_id),

    CONSTRAINT fk_re_asignacion
        FOREIGN KEY (asignacion_encuesta_id) REFERENCES asignaciones_encuesta(id)
) ENGINE=InnoDB;

-- ============================================================
-- 09. RESPUESTAS POR PREGUNTA
-- ============================================================

CREATE TABLE respuesta_pregunta_texto (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    respuesta_encuesta_id BIGINT UNSIGNED NOT NULL,
    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    respuesta_texto TEXT NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_rpt_respuesta_pregunta
        UNIQUE (respuesta_encuesta_id, pregunta_encuesta_id),

    CONSTRAINT fk_rpt_respuesta
        FOREIGN KEY (respuesta_encuesta_id) REFERENCES respuestas_encuesta(id),
    CONSTRAINT fk_rpt_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id)
) ENGINE=InnoDB;

CREATE TABLE respuesta_pregunta_opcion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    respuesta_encuesta_id BIGINT UNSIGNED NOT NULL,
    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,
    opcion_pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_rpo_respuesta_pregunta_opcion
        UNIQUE (respuesta_encuesta_id, pregunta_encuesta_id, opcion_pregunta_encuesta_id),

    CONSTRAINT fk_rpo_respuesta
        FOREIGN KEY (respuesta_encuesta_id) REFERENCES respuestas_encuesta(id),
    CONSTRAINT fk_rpo_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id),
    CONSTRAINT fk_rpo_opcion
        FOREIGN KEY (opcion_pregunta_encuesta_id) REFERENCES opciones_pregunta_encuesta(id)
) ENGINE=InnoDB;

CREATE TABLE respuesta_pregunta_escala (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    respuesta_encuesta_id BIGINT UNSIGNED NOT NULL,
    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    valor DECIMAL(6,2) NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_rpe_respuesta_pregunta
        UNIQUE (respuesta_encuesta_id, pregunta_encuesta_id),

    CONSTRAINT fk_rpe_respuesta
        FOREIGN KEY (respuesta_encuesta_id) REFERENCES respuestas_encuesta(id),
    CONSTRAINT fk_rpe_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id)
) ENGINE=InnoDB;

-- ============================================================
-- 10. COPIA DE PREGUNTAS ENTRE ENCUESTAS
-- ============================================================

CREATE TABLE copias_preguntas_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_destino_id BIGINT UNSIGNED NOT NULL,
    encuesta_origen_id BIGINT UNSIGNED NOT NULL,

    copiada_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_copia DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cpe_destino
        FOREIGN KEY (encuesta_destino_id) REFERENCES encuestas(id),
    CONSTRAINT fk_cpe_origen
        FOREIGN KEY (encuesta_origen_id) REFERENCES encuestas(id),
    CONSTRAINT fk_cpe_usuario
        FOREIGN KEY (copiada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. RESULTADOS AGREGADOS
-- ============================================================

CREATE TABLE resultados_pregunta_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    total_respuestas INT UNSIGNED NOT NULL DEFAULT 0,
    promedio_escala DECIMAL(10,4) NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_resultado_pregunta UNIQUE (pregunta_encuesta_id),

    CONSTRAINT fk_rpe2_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id)
) ENGINE=InnoDB;

CREATE TABLE resultados_opcion_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,
    opcion_pregunta_encuesta_id BIGINT UNSIGNED NOT NULL,

    cantidad INT UNSIGNED NOT NULL DEFAULT 0,
    porcentaje DECIMAL(6,2) NOT NULL DEFAULT 0.00,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_resultado_opcion
        UNIQUE (pregunta_encuesta_id, opcion_pregunta_encuesta_id),

    CONSTRAINT fk_roe_pregunta
        FOREIGN KEY (pregunta_encuesta_id) REFERENCES preguntas_encuesta(id),
    CONSTRAINT fk_roe_opcion
        FOREIGN KEY (opcion_pregunta_encuesta_id) REFERENCES opciones_pregunta_encuesta(id),

    CONSTRAINT chk_roe_porcentaje CHECK (
        porcentaje >= 0 AND porcentaje <= 100
    )
) ENGINE=InnoDB;

-- ============================================================
-- 12. BLOQUEOS POR ENCUESTAS OBLIGATORIAS
-- ============================================================

CREATE TABLE bloqueos_encuesta_usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,
    asignacion_encuesta_id BIGINT UNSIGNED NOT NULL,

    bloqueado BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    motivo VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_bloqueo_encuesta_asignacion
        UNIQUE (asignacion_encuesta_id),

    CONSTRAINT fk_beu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_beu_asignacion
        FOREIGN KEY (asignacion_encuesta_id) REFERENCES asignaciones_encuesta(id)
) ENGINE=InnoDB;

CREATE INDEX idx_beu_usuario_bloqueado
ON bloqueos_encuesta_usuario (usuario_id, bloqueado);

-- ============================================================
-- 13. HISTÓRICO DE ESTADOS DE ENCUESTA
-- ============================================================

CREATE TABLE historial_estado_encuesta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    encuesta_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,

    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hee_encuesta
        FOREIGN KEY (encuesta_id) REFERENCES encuestas(id),
    CONSTRAINT fk_hist_enc_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_encuesta(id),
    CONSTRAINT fk_hist_enc_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_encuesta(id),
    CONSTRAINT fk_hist_enc_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 14. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_encuesta (codigo, nombre, descripcion) VALUES
('GENERAL', 'Encuesta general', 'Encuesta institucional general'),
('EVALUACION_DOCENTE_ESTUDIANTE', 'Evaluación docente por estudiantes', 'Estudiantes evalúan docentes'),
('EVALUACION_PARES', 'Evaluación por pares', 'Docentes evalúan a otros docentes'),
('AUTOEVALUACION_DOCENTE', 'Autoevaluación docente', 'Docente se evalúa a sí mismo');

INSERT INTO estados_encuesta
(codigo, nombre, permite_edicion_estructura, visible_usuarios, es_final)
VALUES
('BORRADOR', 'Borrador', TRUE, FALSE, FALSE),
('PUBLICADA', 'Publicada', FALSE, TRUE, FALSE),
('DESPUBLICADA', 'Despublicada', FALSE, FALSE, FALSE),
('FINALIZADA', 'Finalizada', FALSE, FALSE, TRUE),
('ARCHIVADA', 'Archivada', FALSE, FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, FALSE, TRUE);

INSERT INTO audiencias_encuesta (codigo, nombre) VALUES
('ESTUDIANTES', 'Estudiantes'),
('DOCENTES', 'Docentes'),
('ADMINISTRATIVOS', 'Administrativos');

INSERT INTO modos_aplicacion_encuesta (codigo, nombre) VALUES
('UNA_VEZ', 'Una sola vez'),
('POR_ASIGNATURA', 'Por asignatura'),
('POR_DOCENTE', 'Por docente'),
('POR_RELACION', 'Por relación de evaluación');

INSERT INTO tipos_pregunta_encuesta
(codigo, nombre, permite_opciones, permite_multiples, permite_escala)
VALUES
('TEXTO', 'Respuesta abierta', FALSE, FALSE, FALSE),
('UNICA', 'Respuesta única', TRUE, FALSE, FALSE),
('MULTIPLE', 'Respuesta múltiple', TRUE, TRUE, FALSE),
('ESCALA', 'Escala valorativa', FALSE, FALSE, TRUE);

INSERT INTO estados_asignacion_encuesta
(codigo, nombre, pendiente, es_final)
VALUES
('PENDIENTE', 'Pendiente', TRUE, FALSE),
('EN_PROGRESO', 'En progreso', TRUE, FALSE),
('COMPLETADA', 'Completada', FALSE, TRUE),
('VENCIDA', 'Vencida', TRUE, TRUE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO tipos_relacion_evaluacion_docente
(codigo, nombre)
VALUES
('ESTUDIANTE_DOCENTE', 'Estudiante evalúa docente'),
('PAR_DOCENTE', 'Docente evalúa a otro docente'),
('AUTOEVALUACION', 'Docente se autoevalúa');

-- ============================================================
-- 15. REGLAS DE APLICACIÓN
-- ============================================================
--
-- CREACIÓN:
-- - Nombre obligatorio.
-- - Audiencia: estudiantes, docentes o administrativos.
-- - Fecha inicio/fin.
-- - Puede copiar preguntas desde una encuesta anterior.
--
-- ALCANCE ESTUDIANTES:
-- - Puede aplicar a:
--      todas las sedes
--      sedes seleccionadas
--      todas las carreras
--      carreras seleccionadas
-- - Si modo POR_ASIGNATURA:
--      se generan asignaciones por sección/matrícula.
--
-- EVALUACIÓN DOCENTE POR ESTUDIANTES:
-- - Puede ser por carrera o asignatura.
-- - Se vincula al docente/sección correspondiente.
--
-- PARES:
-- - Se crean relaciones A -> B y B -> A.
-- - La aplicación valida evaluador != evaluado.
--
-- AUTOEVALUACIÓN:
-- - evaluador = evaluado.
--
-- PREGUNTAS:
-- - TEXTO
-- - UNICA
-- - MULTIPLE
-- - ESCALA
-- - Máximo 10 preguntas por página.
-- - Puede haber más de 10 preguntas totales, distribuidas por páginas.
--
-- PUBLICAR:
-- - Al publicar, la estructura queda bloqueada.
-- - Solo nombre y fechas pueden editarse mediante flujo controlado si se permite.
--
-- ELIMINAR:
-- - Si no tiene respuestas -> se puede anular/eliminar lógicamente.
-- - Si tiene respuestas -> no borrar físicamente.
--   La UI puede pedir escribir "ELIMINAR" y luego marcar ANULADA/ARCHIVADA.
--
-- OBLIGATORIEDAD:
-- - asignaciones_encuesta.obligatoria = TRUE
-- - bloquea_otras_acciones = TRUE
-- - mientras esté pendiente, bloqueos_encuesta_usuario mantiene restricción.
-- - Al completar, se levanta el bloqueo.
--
-- RESULTADOS:
-- - preguntas de opciones -> conteos/porcentajes
-- - escalas -> promedio
-- - texto -> listado exportable
-- - exportación PDF/XLSX se implementará en capa de aplicación/reportes.
--
-- ARCHIVAR:
-- - Encuesta finalizada puede pasar a ARCHIVADA sin perder resultados.
--
-- ============================================================
-- FIN 015_encuestas.sql
-- ============================================================
