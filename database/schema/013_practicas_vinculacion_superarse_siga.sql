-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 013_practicas_vinculacion.sql
-- Requiere bloques 001-012
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión de prácticas preprofesionales
--   - Gestión de vinculación con la sociedad
--   - Instituciones receptoras y convenios
--   - Proyectos / programas
--   - Asignación de estudiantes y responsables
--   - Planificación, seguimiento y evidencias
--   - Registro de horas
--   - Evaluaciones y cumplimiento
--   - Certificados
--   - Integración con expediente documental
--
-- PRINCIPIOS:
--   - Prácticas y vinculación comparten infraestructura de seguimiento,
--     pero mantienen tipos/procesos diferenciados.
--   - Las horas requeridas deben ser configurables y versionadas.
--   - No se elimina histórico de actividades ni certificados.
--   - Los certificados oficiales se vinculan al expediente documental.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS GENERALES
-- ============================================================

CREATE TABLE tipos_experiencia_formativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_experiencia_formativa_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_experiencia_formativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_registro_horas BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_experiencia_formativa_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_asignacion_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_registro BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_asignacion_experiencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_institucion_receptora (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_institucion_receptora_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE sectores_economicos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_sector_economico_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_convenio (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_asignaciones BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_convenio_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_convenio (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_convenio_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_proyecto_vinculacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    permite_participacion BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_proyecto_vinculacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_registro_horas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    es_aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_registro_horas_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_evidencia_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_evidencia_experiencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_evaluacion_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_evaluacion_experiencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. POLÍTICAS HISTÓRICAS DE HORAS
-- ============================================================

CREATE TABLE politicas_experiencia_formativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,

    horas_requeridas DECIMAL(8,2) NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_politica_experiencia_codigo UNIQUE (codigo),

    CONSTRAINT fk_pef_tipo
        FOREIGN KEY (tipo_experiencia_formativa_id) REFERENCES tipos_experiencia_formativa(id),
    CONSTRAINT fk_pef_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pef_horas CHECK (horas_requeridas >= 0),
    CONSTRAINT chk_pef_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 03. INSTITUCIONES RECEPTORAS
-- ============================================================

CREATE TABLE instituciones_receptoras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_institucion_receptora_id BIGINT UNSIGNED NOT NULL,
    sector_economico_id BIGINT UNSIGNED NULL,

    ruc VARCHAR(20) NULL,
    razon_social VARCHAR(220) NOT NULL,
    nombre_comercial VARCHAR(220) NULL,

    pais_id BIGINT UNSIGNED NULL,
    provincia_id BIGINT UNSIGNED NULL,
    canton_id BIGINT UNSIGNED NULL,

    direccion VARCHAR(255) NULL,
    telefono VARCHAR(30) NULL,
    correo VARCHAR(190) NULL,
    sitio_web VARCHAR(190) NULL,

    representante_legal VARCHAR(220) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_institucion_receptora_ruc UNIQUE (ruc),

    CONSTRAINT fk_ir_tipo
        FOREIGN KEY (tipo_institucion_receptora_id) REFERENCES tipos_institucion_receptora(id),
    CONSTRAINT fk_ir_sector
        FOREIGN KEY (sector_economico_id) REFERENCES sectores_economicos(id),
    CONSTRAINT fk_ir_pais
        FOREIGN KEY (pais_id) REFERENCES paises(id),
    CONSTRAINT fk_ir_provincia
        FOREIGN KEY (provincia_id) REFERENCES provincias(id),
    CONSTRAINT fk_ir_canton
        FOREIGN KEY (canton_id) REFERENCES cantones(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ir_nombre
ON instituciones_receptoras (razon_social);

-- ============================================================
-- 04. CONTACTOS DE INSTITUCIONES RECEPTORAS
-- ============================================================

CREATE TABLE institucion_receptora_contactos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    institucion_receptora_id BIGINT UNSIGNED NOT NULL,

    nombres VARCHAR(160) NOT NULL,
    apellidos VARCHAR(160) NULL,
    cargo VARCHAR(160) NULL,

    telefono VARCHAR(30) NULL,
    correo VARCHAR(190) NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_irc_institucion
        FOREIGN KEY (institucion_receptora_id) REFERENCES instituciones_receptoras(id)
) ENGINE=InnoDB;

-- ============================================================
-- 05. CONVENIOS
-- ============================================================

CREATE TABLE convenios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_convenio VARCHAR(80) NOT NULL,

    institucion_receptora_id BIGINT UNSIGNED NOT NULL,
    tipo_convenio_id BIGINT UNSIGNED NOT NULL,
    estado_convenio_id BIGINT UNSIGNED NOT NULL,

    nombre VARCHAR(220) NOT NULL,
    objeto TEXT NULL,

    fecha_firma DATE NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    renovacion_automatica BOOLEAN NOT NULL DEFAULT FALSE,

    documento_convenio_archivo_id BIGINT UNSIGNED NULL,

    responsable_interno_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_convenio_numero UNIQUE (numero_convenio),

    CONSTRAINT fk_convenio_institucion
        FOREIGN KEY (institucion_receptora_id) REFERENCES instituciones_receptoras(id),
    CONSTRAINT fk_convenio_tipo
        FOREIGN KEY (tipo_convenio_id) REFERENCES tipos_convenio(id),
    CONSTRAINT fk_convenio_estado
        FOREIGN KEY (estado_convenio_id) REFERENCES estados_convenio(id),
    CONSTRAINT fk_convenio_archivo
        FOREIGN KEY (documento_convenio_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_convenio_responsable
        FOREIGN KEY (responsable_interno_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_convenio_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_convenio_vigencia
ON convenios (estado_convenio_id, fecha_inicio, fecha_fin);

-- ============================================================
-- 06. CARRERAS HABILITADAS POR CONVENIO
-- ============================================================

CREATE TABLE convenio_carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    convenio_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_convenio_carrera
        UNIQUE (convenio_id, carrera_id),

    CONSTRAINT fk_cc_convenio
        FOREIGN KEY (convenio_id) REFERENCES convenios(id),
    CONSTRAINT fk_cc_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id)
) ENGINE=InnoDB;

-- ============================================================
-- 07. PROYECTOS / PROGRAMAS DE VINCULACIÓN
-- ============================================================

CREATE TABLE proyectos_vinculacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,

    estado_proyecto_vinculacion_id BIGINT UNSIGNED NOT NULL,

    institucion_receptora_id BIGINT UNSIGNED NULL,
    convenio_id BIGINT UNSIGNED NULL,

    descripcion TEXT NULL,
    objetivo_general TEXT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    alcance VARCHAR(500) NULL,

    responsable_usuario_id BIGINT UNSIGNED NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_proyecto_vinculacion_codigo UNIQUE (codigo),

    CONSTRAINT fk_pv_estado
        FOREIGN KEY (estado_proyecto_vinculacion_id) REFERENCES estados_proyecto_vinculacion(id),
    CONSTRAINT fk_pv_institucion
        FOREIGN KEY (institucion_receptora_id) REFERENCES instituciones_receptoras(id),
    CONSTRAINT fk_pv_convenio
        FOREIGN KEY (convenio_id) REFERENCES convenios(id),
    CONSTRAINT fk_pv_responsable
        FOREIGN KEY (responsable_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pv_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE TABLE proyecto_vinculacion_carreras (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    proyecto_vinculacion_id BIGINT UNSIGNED NOT NULL,
    carrera_id BIGINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_pvc_proyecto_carrera
        UNIQUE (proyecto_vinculacion_id, carrera_id),

    CONSTRAINT fk_pvc_proyecto
        FOREIGN KEY (proyecto_vinculacion_id) REFERENCES proyectos_vinculacion(id),
    CONSTRAINT fk_pvc_carrera
        FOREIGN KEY (carrera_id) REFERENCES carreras(id)
) ENGINE=InnoDB;

-- ============================================================
-- 08. EXPERIENCIAS FORMATIVAS / PROCESOS DEL ESTUDIANTE
-- ============================================================

CREATE TABLE experiencias_formativas_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_experiencia VARCHAR(60) NOT NULL,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    tipo_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,
    politica_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,
    estado_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,

    convenio_id BIGINT UNSIGNED NULL,
    institucion_receptora_id BIGINT UNSIGNED NULL,
    proyecto_vinculacion_id BIGINT UNSIGNED NULL,

    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,

    horas_requeridas_snapshot DECIMAL(8,2) NOT NULL,
    horas_aprobadas DECIMAL(8,2) NOT NULL DEFAULT 0.00,

    tutor_interno_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_experiencia_numero UNIQUE (numero_experiencia),

    CONSTRAINT fk_efe_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_efe_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_efe_tipo
        FOREIGN KEY (tipo_experiencia_formativa_id) REFERENCES tipos_experiencia_formativa(id),
    CONSTRAINT fk_efe_politica
        FOREIGN KEY (politica_experiencia_formativa_id) REFERENCES politicas_experiencia_formativa(id),
    CONSTRAINT fk_efe_estado
        FOREIGN KEY (estado_experiencia_formativa_id) REFERENCES estados_experiencia_formativa(id),
    CONSTRAINT fk_efe_convenio
        FOREIGN KEY (convenio_id) REFERENCES convenios(id),
    CONSTRAINT fk_efe_institucion
        FOREIGN KEY (institucion_receptora_id) REFERENCES instituciones_receptoras(id),
    CONSTRAINT fk_efe_proyecto
        FOREIGN KEY (proyecto_vinculacion_id) REFERENCES proyectos_vinculacion(id),
    CONSTRAINT fk_efe_tutor_interno
        FOREIGN KEY (tutor_interno_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_efe_horas CHECK (
        horas_requeridas_snapshot >= 0
        AND horas_aprobadas >= 0
    ),
    CONSTRAINT chk_efe_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_efe_estudiante_tipo
ON experiencias_formativas_estudiante (estudiante_carrera_id, tipo_experiencia_formativa_id);

-- ============================================================
-- 09. ASIGNACIÓN / PLAZA CONCRETA
-- ============================================================

CREATE TABLE asignaciones_experiencia_formativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    experiencia_formativa_estudiante_id BIGINT UNSIGNED NOT NULL,
    estado_asignacion_experiencia_id BIGINT UNSIGNED NOT NULL,

    institucion_receptora_id BIGINT UNSIGNED NULL,
    convenio_id BIGINT UNSIGNED NULL,

    area_departamento VARCHAR(180) NULL,
    cargo_funcion VARCHAR(180) NULL,

    tutor_externo_nombre VARCHAR(220) NULL,
    tutor_externo_cargo VARCHAR(180) NULL,
    tutor_externo_correo VARCHAR(190) NULL,
    tutor_externo_telefono VARCHAR(30) NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    horario_descripcion VARCHAR(255) NULL,

    creada_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_aef_experiencia
        FOREIGN KEY (experiencia_formativa_estudiante_id) REFERENCES experiencias_formativas_estudiante(id),
    CONSTRAINT fk_aef_estado
        FOREIGN KEY (estado_asignacion_experiencia_id) REFERENCES estados_asignacion_experiencia(id),
    CONSTRAINT fk_aef_institucion
        FOREIGN KEY (institucion_receptora_id) REFERENCES instituciones_receptoras(id),
    CONSTRAINT fk_aef_convenio
        FOREIGN KEY (convenio_id) REFERENCES convenios(id),
    CONSTRAINT fk_aef_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_aef_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_aef_experiencia_estado
ON asignaciones_experiencia_formativa (experiencia_formativa_estudiante_id, estado_asignacion_experiencia_id);

-- ============================================================
-- 10. PLAN DE ACTIVIDADES
-- ============================================================

CREATE TABLE planes_actividad_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    asignacion_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,

    titulo VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,

    horas_planificadas DECIMAL(8,2) NULL,

    aprobado BOOLEAN NOT NULL DEFAULT FALSE,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_aprobacion DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pae_asignacion
        FOREIGN KEY (asignacion_experiencia_formativa_id) REFERENCES asignaciones_experiencia_formativa(id),
    CONSTRAINT fk_pae_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pae_horas CHECK (
        horas_planificadas IS NULL OR horas_planificadas >= 0
    ),
    CONSTRAINT chk_pae_fechas CHECK (
        fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

-- ============================================================
-- 11. REGISTRO DE HORAS / BITÁCORA
-- ============================================================

CREATE TABLE registros_horas_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    asignacion_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,
    estado_registro_horas_id BIGINT UNSIGNED NOT NULL,

    fecha DATE NOT NULL,
    hora_inicio TIME NULL,
    hora_fin TIME NULL,

    horas_reportadas DECIMAL(6,2) NOT NULL,

    actividad TEXT NOT NULL,

    registrada_por_usuario_id BIGINT UNSIGNED NULL,
    revisada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,

    observacion_revision TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_rhe_asignacion
        FOREIGN KEY (asignacion_experiencia_formativa_id) REFERENCES asignaciones_experiencia_formativa(id),
    CONSTRAINT fk_rhe_estado
        FOREIGN KEY (estado_registro_horas_id) REFERENCES estados_registro_horas(id),
    CONSTRAINT fk_rhe_registrada_por
        FOREIGN KEY (registrada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_rhe_revisada_por
        FOREIGN KEY (revisada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_rhe_horas CHECK (
        horas_reportadas > 0
    ),
    CONSTRAINT chk_rhe_horario CHECK (
        hora_fin IS NULL OR hora_inicio IS NULL OR hora_fin > hora_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_rhe_asignacion_fecha
ON registros_horas_experiencia (asignacion_experiencia_formativa_id, fecha);

-- ============================================================
-- 12. EVIDENCIAS
-- ============================================================

CREATE TABLE evidencias_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    experiencia_formativa_estudiante_id BIGINT UNSIGNED NOT NULL,
    registro_horas_experiencia_id BIGINT UNSIGNED NULL,
    tipo_evidencia_experiencia_id BIGINT UNSIGNED NOT NULL,

    archivo_id BIGINT UNSIGNED NOT NULL,

    descripcion VARCHAR(255) NULL,

    cargada_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    vigente BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_ee_experiencia
        FOREIGN KEY (experiencia_formativa_estudiante_id) REFERENCES experiencias_formativas_estudiante(id),
    CONSTRAINT fk_ee_registro_horas
        FOREIGN KEY (registro_horas_experiencia_id) REFERENCES registros_horas_experiencia(id),
    CONSTRAINT fk_ee_tipo
        FOREIGN KEY (tipo_evidencia_experiencia_id) REFERENCES tipos_evidencia_experiencia(id),
    CONSTRAINT fk_ee_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_ee_usuario
        FOREIGN KEY (cargada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 13. EVALUACIONES
-- ============================================================

CREATE TABLE evaluaciones_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    experiencia_formativa_estudiante_id BIGINT UNSIGNED NOT NULL,
    tipo_evaluacion_experiencia_id BIGINT UNSIGNED NOT NULL,

    evaluador_usuario_id BIGINT UNSIGNED NULL,
    evaluador_externo_nombre VARCHAR(220) NULL,

    nota DECIMAL(5,2) NULL,
    aprobado BOOLEAN NULL,

    observacion TEXT NULL,

    fecha_evaluacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_eval_exp_experiencia
        FOREIGN KEY (experiencia_formativa_estudiante_id) REFERENCES experiencias_formativas_estudiante(id),
    CONSTRAINT fk_eval_exp_tipo
        FOREIGN KEY (tipo_evaluacion_experiencia_id) REFERENCES tipos_evaluacion_experiencia(id),
    CONSTRAINT fk_eval_exp_usuario
        FOREIGN KEY (evaluador_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_eval_exp_nota CHECK (
        nota IS NULL OR (nota >= 0 AND nota <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. CERTIFICADOS DE CUMPLIMIENTO
-- ============================================================

CREATE TABLE certificados_experiencia_formativa (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    experiencia_formativa_estudiante_id BIGINT UNSIGNED NOT NULL,

    numero_certificado VARCHAR(80) NOT NULL,

    archivo_id BIGINT UNSIGNED NOT NULL,
    documento_expediente_id BIGINT UNSIGNED NULL,

    horas_certificadas DECIMAL(8,2) NOT NULL,

    fecha_emision DATE NOT NULL,

    emitido_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_certificado_experiencia_numero UNIQUE (numero_certificado),
    CONSTRAINT uq_certificado_experiencia UNIQUE (experiencia_formativa_estudiante_id),

    CONSTRAINT fk_cef_experiencia
        FOREIGN KEY (experiencia_formativa_estudiante_id) REFERENCES experiencias_formativas_estudiante(id),
    CONSTRAINT fk_cef_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_cef_documento_expediente
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_cef_emitido_por
        FOREIGN KEY (emitido_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_cef_horas CHECK (
        horas_certificadas >= 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 15. RESUMEN DE CUMPLIMIENTO
-- ============================================================

CREATE TABLE resumen_experiencia_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,
    tipo_experiencia_formativa_id BIGINT UNSIGNED NOT NULL,

    horas_requeridas DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    horas_aprobadas DECIMAL(8,2) NOT NULL DEFAULT 0.00,

    cumplido BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_cumplimiento DATE NULL,

    ultima_experiencia_id BIGINT UNSIGNED NULL,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_resumen_exp_estudiante
        UNIQUE (estudiante_carrera_id, tipo_experiencia_formativa_id),

    CONSTRAINT fk_ree_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),
    CONSTRAINT fk_ree_tipo
        FOREIGN KEY (tipo_experiencia_formativa_id) REFERENCES tipos_experiencia_formativa(id),
    CONSTRAINT fk_ree_ultima_experiencia
        FOREIGN KEY (ultima_experiencia_id) REFERENCES experiencias_formativas_estudiante(id),

    CONSTRAINT chk_ree_horas CHECK (
        horas_requeridas >= 0 AND horas_aprobadas >= 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 16. HISTÓRICO DE ESTADOS
-- ============================================================

CREATE TABLE historial_estado_experiencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    experiencia_formativa_estudiante_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hee_experiencia
        FOREIGN KEY (experiencia_formativa_estudiante_id) REFERENCES experiencias_formativas_estudiante(id),
    CONSTRAINT fk_hee_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_experiencia_formativa(id),
    CONSTRAINT fk_hee_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_experiencia_formativa(id),
    CONSTRAINT fk_hee_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hee_experiencia_fecha
ON historial_estado_experiencia (experiencia_formativa_estudiante_id, changed_at);

-- ============================================================
-- 17. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_experiencia_formativa
(codigo, nombre, descripcion)
VALUES
('PRACTICAS_PREPROFESIONALES', 'Prácticas preprofesionales', 'Proceso institucional de prácticas preprofesionales'),
('VINCULACION_SOCIEDAD', 'Vinculación con la sociedad', 'Proceso de vinculación con la sociedad');

INSERT INTO estados_experiencia_formativa
(codigo, nombre, permite_registro_horas, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('ASIGNADA', 'Asignada', TRUE, FALSE),
('EN_PROCESO', 'En proceso', TRUE, FALSE),
('EN_REVISION', 'En revisión', FALSE, FALSE),
('CUMPLIDA', 'Cumplida', FALSE, TRUE),
('REPROBADA', 'Reprobada', FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO estados_asignacion_experiencia
(codigo, nombre, permite_registro, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('ACTIVA', 'Activa', TRUE, FALSE),
('FINALIZADA', 'Finalizada', FALSE, TRUE),
('CANCELADA', 'Cancelada', FALSE, TRUE);

INSERT INTO tipos_institucion_receptora (codigo, nombre) VALUES
('PUBLICA', 'Institución pública'),
('PRIVADA', 'Institución privada'),
('ONG', 'Organización no gubernamental'),
('COMUNITARIA', 'Organización comunitaria'),
('INSTITUCION_EDUCATIVA', 'Institución educativa'),
('OTRA', 'Otra');

INSERT INTO sectores_economicos (codigo, nombre) VALUES
('AGRICULTURA', 'Agricultura'),
('COMERCIO', 'Comercio'),
('EDUCACION', 'Educación'),
('SALUD', 'Salud'),
('TECNOLOGIA', 'Tecnología'),
('SERVICIOS', 'Servicios'),
('INDUSTRIA', 'Industria'),
('FINANCIERO', 'Financiero'),
('PUBLICO', 'Sector público'),
('OTRO', 'Otro');

INSERT INTO estados_convenio
(codigo, nombre, permite_asignaciones, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('VIGENTE', 'Vigente', TRUE, FALSE),
('VENCIDO', 'Vencido', FALSE, TRUE),
('SUSPENDIDO', 'Suspendido', FALSE, FALSE),
('FINALIZADO', 'Finalizado', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE);

INSERT INTO tipos_convenio (codigo, nombre) VALUES
('PRACTICAS', 'Convenio de prácticas preprofesionales'),
('VINCULACION', 'Convenio de vinculación con la sociedad'),
('MARCO', 'Convenio marco'),
('ESPECIFICO', 'Convenio específico'),
('MIXTO', 'Convenio mixto'),
('OTRO', 'Otro');

INSERT INTO estados_proyecto_vinculacion
(codigo, nombre, permite_participacion, es_final)
VALUES
('BORRADOR', 'Borrador', FALSE, FALSE),
('PLANIFICADO', 'Planificado', FALSE, FALSE),
('ACTIVO', 'Activo', TRUE, FALSE),
('CERRADO', 'Cerrado', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE);

INSERT INTO estados_registro_horas
(codigo, nombre, es_aprobado, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('EN_REVISION', 'En revisión', FALSE, FALSE),
('APROBADO', 'Aprobado', TRUE, TRUE),
('RECHAZADO', 'Rechazado', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE);

INSERT INTO tipos_evidencia_experiencia (codigo, nombre) VALUES
('BITACORA', 'Bitácora'),
('INFORME', 'Informe'),
('FOTO', 'Fotografía'),
('CERTIFICADO', 'Certificado'),
('ACTA', 'Acta'),
('EVALUACION', 'Evaluación'),
('OTRO', 'Otro');

INSERT INTO tipos_evaluacion_experiencia (codigo, nombre) VALUES
('TUTOR_INTERNO', 'Evaluación del tutor interno'),
('TUTOR_EXTERNO', 'Evaluación del tutor externo'),
('AUTOEVALUACION', 'Autoevaluación del estudiante'),
('FINAL', 'Evaluación final'),
('OTRA', 'Otra');

-- Políticas actuales según requerimientos institucionales.
INSERT INTO politicas_experiencia_formativa
(tipo_experiencia_formativa_id, codigo, nombre, horas_requeridas, vigente_desde)
SELECT id, 'PRACTICAS_240H_2026', 'Prácticas preprofesionales - 240 horas', 240.00, '2026-01-01'
FROM tipos_experiencia_formativa
WHERE codigo='PRACTICAS_PREPROFESIONALES';

INSERT INTO politicas_experiencia_formativa
(tipo_experiencia_formativa_id, codigo, nombre, horas_requeridas, vigente_desde)
SELECT id, 'VINCULACION_96H_2026', 'Vinculación con la sociedad - 96 horas', 96.00, '2026-01-01'
FROM tipos_experiencia_formativa
WHERE codigo='VINCULACION_SOCIEDAD';

-- ============================================================
-- 18. REGLAS DE APLICACIÓN
-- ============================================================
--
-- PRÁCTICAS:
-- 1. Se crea experiencia_formativa_estudiante.
-- 2. Se asigna institución receptora / convenio.
-- 3. Se registra asignación concreta.
-- 4. Estudiante/tutor registra horas y actividades.
-- 5. Responsable revisa y aprueba horas.
-- 6. Al alcanzar horas requeridas y cumplir evaluaciones:
--      estado -> CUMPLIDA
--      generar certificado.
--
-- VINCULACIÓN:
-- 1. Puede vincularse a proyecto_vinculacion.
-- 2. Se registran horas, actividades y evidencias.
-- 3. Al completar requisitos se genera certificado.
--
-- POLÍTICAS:
-- - Horas requeridas son históricas.
-- - Actualmente:
--      Prácticas = 240h
--      Vinculación = 96h
-- - Si cambian, se crea nueva política.
--
-- EXPEDIENTE:
-- - Certificado oficial se guarda como archivo.
-- - Se crea/vincula documentos_expediente:
--      CERT_PRACTICAS_240H
--      CERT_VINCULACION_96H
--   del bloque 012.
--
-- CARRERA:
-- - La experiencia pertenece a estudiante_carrera.
-- - Si inicia otra carrera, se crea nueva experiencia según corresponda.
--
-- REPORTES:
-- - Horas cumplidas por estudiante/carrera
-- - Estudiantes pendientes
-- - Convenios vigentes
-- - Instituciones receptoras
-- - Proyectos activos
-- - Cumplimiento por carrera/período
--
-- ============================================================
-- FIN 013_practicas_vinculacion.sql
-- ============================================================
