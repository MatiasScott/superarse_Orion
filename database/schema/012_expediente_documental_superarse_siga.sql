-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 012_expediente_documental.sql
-- Requiere bloques 001-011
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Repositorio documental institucional del estudiante
--   - Expediente por persona y por trayectoria/carrera
--   - Categorías y tipos documentales configurables
--   - Responsables múltiples de carga por tipo documental
--   - Versionado de documentos
--   - Documento aprobado/vigente
--   - Nomenclatura institucional de archivos
--   - Histórico de quién subió, reemplazó, aprobó o modificó
--   - Documentación reutilizable entre carreras cuando corresponda
--   - Documentación específica por nueva trayectoria/carrera
--   - Integración con Secretaría, Titulación, Financiero,
--     Coordinaciones, Bienestar y Estudiante
--
-- PRINCIPIOS:
--   - No se duplican archivos físicos innecesariamente.
--   - El mismo archivo puede relacionarse con distintos requerimientos
--     si institucionalmente es válido/reutilizable.
--   - Al iniciar una nueva carrera, se crea un nuevo expediente académico
--     de trayectoria, preservando el expediente histórico anterior.
--   - Una versión aprobada es la vigente; versiones anteriores se conservan.
--   - Los archivos se guardan en tabla archivos (001), no como BLOB.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DEL REPOSITORIO
-- ============================================================

CREATE TABLE categorias_documentales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT NULL,
    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_categoria_documental_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_documento_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    categoria_documental_id BIGINT UNSIGNED NOT NULL,

    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(220) NOT NULL,
    descripcion TEXT NULL,

    -- Define si el documento pertenece a la persona en general
    -- o a una trayectoria/carrera concreta.
    ambito VARCHAR(30) NOT NULL, -- PERSONA / TRAYECTORIA / PERIODO

    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,
    permite_multiples BOOLEAN NOT NULL DEFAULT FALSE,
    requiere_aprobacion BOOLEAN NOT NULL DEFAULT TRUE,
    reutilizable_entre_carreras BOOLEAN NOT NULL DEFAULT FALSE,

    solo_pdf BOOLEAN NOT NULL DEFAULT FALSE,

    orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_tipo_documento_expediente_codigo UNIQUE (codigo),

    CONSTRAINT fk_tde_categoria
        FOREIGN KEY (categoria_documental_id) REFERENCES categorias_documentales(id),

    CONSTRAINT chk_tde_ambito CHECK (
        ambito IN ('PERSONA', 'TRAYECTORIA', 'PERIODO')
    )
) ENGINE=InnoDB;

CREATE TABLE estados_documento_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    es_vigente BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_documento_expediente_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_responsable_documento (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_responsable_documento_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE acciones_documento_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_accion_documento_expediente_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. EXPEDIENTE MAESTRO DE PERSONA
-- ============================================================

CREATE TABLE expedientes_persona (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    persona_id BIGINT UNSIGNED NOT NULL,

    codigo_expediente VARCHAR(60) NOT NULL,

    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_expediente_persona UNIQUE (persona_id),
    CONSTRAINT uq_expediente_persona_codigo UNIQUE (codigo_expediente),

    CONSTRAINT fk_expediente_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),

    CONSTRAINT chk_expediente_persona_fechas CHECK (
        fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura
    )
) ENGINE=InnoDB;

-- ============================================================
-- 03. EXPEDIENTE POR TRAYECTORIA / CARRERA
-- ============================================================

CREATE TABLE expedientes_trayectoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    expediente_persona_id BIGINT UNSIGNED NOT NULL,
    estudiante_carrera_id BIGINT UNSIGNED NOT NULL,

    codigo_expediente VARCHAR(80) NOT NULL,

    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_expediente_trayectoria UNIQUE (estudiante_carrera_id),
    CONSTRAINT uq_expediente_trayectoria_codigo UNIQUE (codigo_expediente),

    CONSTRAINT fk_et_expediente_persona
        FOREIGN KEY (expediente_persona_id) REFERENCES expedientes_persona(id),
    CONSTRAINT fk_et_estudiante_carrera
        FOREIGN KEY (estudiante_carrera_id) REFERENCES estudiante_carreras(id),

    CONSTRAINT chk_et_fechas CHECK (
        fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura
    )
) ENGINE=InnoDB;

-- ============================================================
-- 04. REQUERIMIENTOS DOCUMENTALES
-- Cada expediente puede instanciar los tipos requeridos.
-- ============================================================

CREATE TABLE requisitos_documentales_persona (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    expediente_persona_id BIGINT UNSIGNED NOT NULL,
    tipo_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    obligatorio BOOLEAN NOT NULL,
    fecha_limite DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_req_doc_persona
        UNIQUE (expediente_persona_id, tipo_documento_expediente_id),

    CONSTRAINT fk_rdp_expediente_persona
        FOREIGN KEY (expediente_persona_id) REFERENCES expedientes_persona(id),
    CONSTRAINT fk_rdp_tipo_documento
        FOREIGN KEY (tipo_documento_expediente_id) REFERENCES tipos_documento_expediente(id)
) ENGINE=InnoDB;

CREATE TABLE requisitos_documentales_trayectoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    expediente_trayectoria_id BIGINT UNSIGNED NOT NULL,
    tipo_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    periodo_academico_id BIGINT UNSIGNED NULL,
    periodo_academico_key BIGINT UNSIGNED
        GENERATED ALWAYS AS (IFNULL(periodo_academico_id, 0)) STORED,

    obligatorio BOOLEAN NOT NULL,
    fecha_limite DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_req_doc_trayectoria
        UNIQUE (expediente_trayectoria_id, tipo_documento_expediente_id, periodo_academico_key),

    CONSTRAINT fk_rdt_expediente_trayectoria
        FOREIGN KEY (expediente_trayectoria_id) REFERENCES expedientes_trayectoria(id),
    CONSTRAINT fk_rdt_tipo_documento
        FOREIGN KEY (tipo_documento_expediente_id) REFERENCES tipos_documento_expediente(id),
    CONSTRAINT fk_rdt_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id)
) ENGINE=InnoDB;

-- ============================================================
-- 05. RESPONSABLES DE CARGA POR TIPO DOCUMENTAL
-- Múltiples responsables permitidos.
-- ============================================================

CREATE TABLE tipo_documento_responsables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_documento_expediente_id BIGINT UNSIGNED NOT NULL,
    tipo_responsable_documento_id BIGINT UNSIGNED NOT NULL,

    rol_id BIGINT UNSIGNED NULL,
    perfil_id BIGINT UNSIGNED NULL,
    unidad_organizacional_id BIGINT UNSIGNED NULL,

    puede_subir BOOLEAN NOT NULL DEFAULT TRUE,
    puede_reemplazar BOOLEAN NOT NULL DEFAULT FALSE,
    puede_aprobar BOOLEAN NOT NULL DEFAULT FALSE,
    puede_rechazar BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tdr_tipo_documento
        FOREIGN KEY (tipo_documento_expediente_id) REFERENCES tipos_documento_expediente(id),
    CONSTRAINT fk_tdr_tipo_responsable
        FOREIGN KEY (tipo_responsable_documento_id) REFERENCES tipos_responsable_documento(id),
    CONSTRAINT fk_tdr_rol
        FOREIGN KEY (rol_id) REFERENCES roles(id),
    CONSTRAINT fk_tdr_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfiles(id),
    CONSTRAINT fk_tdr_unidad
        FOREIGN KEY (unidad_organizacional_id) REFERENCES unidades_organizacionales(id)
) ENGINE=InnoDB;

CREATE INDEX idx_tdr_documento_activo
ON tipo_documento_responsables (tipo_documento_expediente_id, activo);

-- ============================================================
-- 06. DOCUMENTOS MAESTROS
-- Un documento lógico puede tener varias versiones.
-- ============================================================

CREATE TABLE documentos_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    expediente_persona_id BIGINT UNSIGNED NULL,
    expediente_trayectoria_id BIGINT UNSIGNED NULL,
    periodo_academico_id BIGINT UNSIGNED NULL,

    codigo_documento VARCHAR(80) NOT NULL,

    titulo VARCHAR(255) NOT NULL,

    estado_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    version_vigente_id BIGINT UNSIGNED NULL,

    fecha_emision DATE NULL,
    fecha_vencimiento DATE NULL,

    observacion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_documento_codigo UNIQUE (codigo_documento),

    CONSTRAINT fk_de_tipo_documento
        FOREIGN KEY (tipo_documento_expediente_id) REFERENCES tipos_documento_expediente(id),
    CONSTRAINT fk_de_expediente_persona
        FOREIGN KEY (expediente_persona_id) REFERENCES expedientes_persona(id),
    CONSTRAINT fk_de_expediente_trayectoria
        FOREIGN KEY (expediente_trayectoria_id) REFERENCES expedientes_trayectoria(id),
    CONSTRAINT fk_de_periodo
        FOREIGN KEY (periodo_academico_id) REFERENCES periodos_academicos(id),
    CONSTRAINT fk_de_estado
        FOREIGN KEY (estado_documento_expediente_id) REFERENCES estados_documento_expediente(id),

    CONSTRAINT chk_de_ambito CHECK (
        expediente_persona_id IS NOT NULL
        OR expediente_trayectoria_id IS NOT NULL
    ),
    CONSTRAINT chk_de_fechas CHECK (
        fecha_vencimiento IS NULL OR fecha_emision IS NULL OR fecha_vencimiento >= fecha_emision
    )
) ENGINE=InnoDB;

-- ============================================================
-- 07. VERSIONES DE DOCUMENTO
-- ============================================================

CREATE TABLE documento_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    documento_expediente_id BIGINT UNSIGNED NOT NULL,
    archivo_id BIGINT UNSIGNED NOT NULL,

    numero_version INT UNSIGNED NOT NULL,

    nombre_archivo_institucional VARCHAR(255) NOT NULL,
    nombre_archivo_original VARCHAR(255) NULL,

    estado_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    cargado_por_usuario_id BIGINT UNSIGNED NULL,
    aprobado_por_usuario_id BIGINT UNSIGNED NULL,
    rechazado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion DATETIME NULL,
    fecha_rechazo DATETIME NULL,

    motivo_rechazo TEXT NULL,
    observacion TEXT NULL,

    es_vigente BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_documento_version
        UNIQUE (documento_expediente_id, numero_version),

    CONSTRAINT fk_dv_documento
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_dv_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_dv_estado
        FOREIGN KEY (estado_documento_expediente_id) REFERENCES estados_documento_expediente(id),
    CONSTRAINT fk_dv_cargado_por
        FOREIGN KEY (cargado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_dv_aprobado_por
        FOREIGN KEY (aprobado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_dv_rechazado_por
        FOREIGN KEY (rechazado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_dv_documento_vigente
ON documento_versiones (documento_expediente_id, es_vigente);

ALTER TABLE documentos_expediente
ADD CONSTRAINT fk_de_version_vigente
FOREIGN KEY (version_vigente_id) REFERENCES documento_versiones(id);

-- ============================================================
-- 08. HISTÓRICO / BITÁCORA DEL DOCUMENTO
-- ============================================================

CREATE TABLE historial_documentos_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    documento_expediente_id BIGINT UNSIGNED NOT NULL,
    documento_version_id BIGINT UNSIGNED NULL,
    accion_documento_expediente_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,

    detalle TEXT NULL,
    datos_json JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hde_documento
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_hde_version
        FOREIGN KEY (documento_version_id) REFERENCES documento_versiones(id),
    CONSTRAINT fk_hde_accion
        FOREIGN KEY (accion_documento_expediente_id) REFERENCES acciones_documento_expediente(id),
    CONSTRAINT fk_hde_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hde_documento_fecha
ON historial_documentos_expediente (documento_expediente_id, created_at);

-- ============================================================
-- 09. REUTILIZACIÓN DE DOCUMENTOS ENTRE TRAYECTORIAS
-- ============================================================

CREATE TABLE documento_reutilizaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    documento_expediente_id BIGINT UNSIGNED NOT NULL,
    expediente_trayectoria_destino_id BIGINT UNSIGNED NOT NULL,

    autorizado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_reutilizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_documento_reutilizacion
        UNIQUE (documento_expediente_id, expediente_trayectoria_destino_id),

    CONSTRAINT fk_dr_documento
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id),
    CONSTRAINT fk_dr_trayectoria_destino
        FOREIGN KEY (expediente_trayectoria_destino_id) REFERENCES expedientes_trayectoria(id),
    CONSTRAINT fk_dr_usuario
        FOREIGN KEY (autorizado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- Solo procede si tipos_documento_expediente.reutilizable_entre_carreras = TRUE.

-- ============================================================
-- 10. PLANTILLAS DE NOMENCLATURA
-- ============================================================

CREATE TABLE plantillas_nomenclatura_documento (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    patron VARCHAR(255) NOT NULL,

    descripcion VARCHAR(255) NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_pnd_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipo_documento_nomenclatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_documento_expediente_id BIGINT UNSIGNED NOT NULL,
    plantilla_nomenclatura_documento_id BIGINT UNSIGNED NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tdn_documento
        UNIQUE (tipo_documento_expediente_id),

    CONSTRAINT fk_tdn_tipo_documento
        FOREIGN KEY (tipo_documento_expediente_id) REFERENCES tipos_documento_expediente(id),
    CONSTRAINT fk_tdn_plantilla
        FOREIGN KEY (plantilla_nomenclatura_documento_id) REFERENCES plantillas_nomenclatura_documento(id)
) ENGINE=InnoDB;

-- Ejemplo de patrón:
-- {APELLIDOS}_{NOMBRES}_{TIPO}.pdf
-- Resultado:
-- ARIAS_MINA_LESLY_MAILEN_CEDULA.pdf

-- ============================================================
-- 11. VALIDACIONES / CONTROL DE COMPLETITUD
-- ============================================================

CREATE TABLE estados_completitud_expediente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    expediente_trayectoria_id BIGINT UNSIGNED NOT NULL,

    total_requeridos INT UNSIGNED NOT NULL DEFAULT 0,
    total_cargados INT UNSIGNED NOT NULL DEFAULT 0,
    total_aprobados INT UNSIGNED NOT NULL DEFAULT 0,
    total_pendientes INT UNSIGNED NOT NULL DEFAULT 0,
    total_rechazados INT UNSIGNED NOT NULL DEFAULT 0,

    porcentaje_completitud DECIMAL(5,2) NOT NULL DEFAULT 0.00,

    completo BOOLEAN NOT NULL DEFAULT FALSE,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_ece_trayectoria UNIQUE (expediente_trayectoria_id),

    CONSTRAINT fk_ece_trayectoria
        FOREIGN KEY (expediente_trayectoria_id) REFERENCES expedientes_trayectoria(id),

    CONSTRAINT chk_ece_porcentaje CHECK (
        porcentaje_completitud >= 0 AND porcentaje_completitud <= 100
    )
) ENGINE=InnoDB;

-- ============================================================
-- 12. VÍNCULOS CON OTROS MÓDULOS
-- ============================================================

CREATE TABLE documento_vinculos_modulo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    documento_expediente_id BIGINT UNSIGNED NOT NULL,

    modulo_codigo VARCHAR(80) NOT NULL,
    referencia_id BIGINT UNSIGNED NOT NULL,

    descripcion VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_dvm_documento
        FOREIGN KEY (documento_expediente_id) REFERENCES documentos_expediente(id)
) ENGINE=InnoDB;

CREATE INDEX idx_dvm_modulo_referencia
ON documento_vinculos_modulo (modulo_codigo, referencia_id);

-- Permitirá enlazar documentos con:
-- TITULACION, FINANCIERO, BECAS, PRACTICAS, VINCULACION, etc.
-- sin duplicar el archivo.

-- ============================================================
-- 13. DATOS INICIALES
-- ============================================================

INSERT INTO categorias_documentales
(codigo, nombre, descripcion, orden_visual)
VALUES
('PERSONAL_ACADEMICA', 'Información personal y académica básica', 'Documentos generales del expediente', 1),
('HOMOLOGACION', 'Homologación', 'Documentos aplicables a procesos de homologación', 2),
('BECA', 'Beca', 'Documentación asociada a becas', 3),
('PLAN_ESTUDIOS', 'Cumplimiento del plan de estudios', 'Documentos de cumplimiento académico', 4),
('TITULACION', 'Titulación', 'Documentos del proceso de titulación', 5),
('VINCULACION_PRACTICAS', 'Vinculación y prácticas preprofesionales', 'Documentos de vinculación y prácticas', 6),
('IDIOMA', 'Idioma extranjero', 'Certificados de suficiencia de idioma', 7),
('NO_ADEUDAR', 'No mantener deudas con el instituto', 'Certificados de no adeudar valores', 8),
('OTROS', 'Otros', 'Otros documentos institucionales', 99);

INSERT INTO estados_documento_expediente
(codigo, nombre, es_vigente, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('CARGADO', 'Cargado', FALSE, FALSE),
('EN_REVISION', 'En revisión', FALSE, FALSE),
('APROBADO', 'Aprobado', TRUE, TRUE),
('RECHAZADO', 'Rechazado', FALSE, TRUE),
('VENCIDO', 'Vencido', FALSE, TRUE),
('ANULADO', 'Anulado', FALSE, TRUE);

INSERT INTO tipos_responsable_documento
(codigo, nombre)
VALUES
('ESTUDIANTE', 'Estudiante'),
('ADMINISTRATIVO', 'Administrativo'),
('SECRETARIA', 'Secretaría General'),
('FINANCIERO', 'Financiero'),
('TITULACION', 'Titulación'),
('COORDINACION', 'Coordinación de carrera'),
('BIENESTAR', 'Bienestar'),
('TIC', 'TIC'),
('OTRO', 'Otro');

INSERT INTO acciones_documento_expediente
(codigo, nombre)
VALUES
('CREAR', 'Crear documento'),
('CARGAR_VERSION', 'Cargar versión'),
('REEMPLAZAR', 'Reemplazar versión'),
('APROBAR', 'Aprobar documento'),
('RECHAZAR', 'Rechazar documento'),
('MARCAR_VIGENTE', 'Marcar versión vigente'),
('REUTILIZAR', 'Reutilizar documento'),
('VINCULAR_MODULO', 'Vincular a módulo'),
('DESCARGAR', 'Descargar documento'),
('ANULAR', 'Anular documento');

INSERT INTO plantillas_nomenclatura_documento
(codigo, nombre, patron, descripcion)
VALUES
(
    'APELLIDOS_NOMBRES_TIPO',
    'Apellidos_Nombres_Tipo',
    '{APELLIDOS}_{NOMBRES}_{TIPO}.{EXT}',
    'Ejemplo: ARIAS_MINA_LESLY_MAILEN_CEDULA.pdf'
);

-- ============================================================
-- 14. TIPOS DOCUMENTALES DEL EXPEDIENTE
-- ============================================================

-- I. Información personal y académica básica
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CONTRATO_INSCRIPCION_MATRICULA', 'Contrato de inscripción y matrícula', 'TRAYECTORIA', TRUE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERTIFICADO_TITULO_BACHILLER', 'Certificado de registro de título de bachiller', 'PERSONA', TRUE, FALSE, TRUE, TRUE, TRUE, 2
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CEDULA', 'Copia de cédula o pasaporte', 'PERSONA', TRUE, FALSE, TRUE, TRUE, TRUE, 3
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'PAPELETA_VOTACION', 'Papeleta de votación', 'PERSONA', FALSE, TRUE, TRUE, TRUE, TRUE, 4
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'SERVICIO_BASICO', 'Servicio básico de domicilio', 'PERSONA', FALSE, TRUE, TRUE, TRUE, TRUE, 5
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'FOTOGRAFIAS_CARNET', 'Fotografías tamaño carné', 'PERSONA', FALSE, TRUE, TRUE, TRUE, FALSE, 6
FROM categorias_documentales WHERE codigo='PERSONAL_ACADEMICA';

-- II. Homologación
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_NO_TERCERA_MATRICULA', 'Certificado de no tener tercera matrícula', 'TRAYECTORIA', FALSE, FALSE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='HOMOLOGACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'MALLA_SILABOS_CERTIFICADOS', 'Malla curricular y sílabos certificados', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 2
FROM categorias_documentales WHERE codigo='HOMOLOGACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'RECORD_ACADEMICO_HOMOLOGACION', 'Récord académico certificado', 'TRAYECTORIA', FALSE, FALSE, TRUE, FALSE, TRUE, 3
FROM categorias_documentales WHERE codigo='HOMOLOGACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_NO_IMPEDIMENTO', 'Certificado de no tener impedimento legal ni disciplinario', 'TRAYECTORIA', FALSE, FALSE, TRUE, FALSE, TRUE, 4
FROM categorias_documentales WHERE codigo='HOMOLOGACION';

-- III. Beca
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'FICHA_SOLICITUD_BECA', 'Ficha solicitud de beca', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='BECA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'FICHA_SOCIOECONOMICA_BECA', 'Ficha socioeconómica', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 2
FROM categorias_documentales WHERE codigo='BECA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CONTRATO_BECA', 'Contrato de beca', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 3
FROM categorias_documentales WHERE codigo='BECA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERTIFICADO_PERDIDA_BECA', 'Certificado de pérdida de beca', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 4
FROM categorias_documentales WHERE codigo='BECA';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'ACOMPANAMIENTO_PSICOPEDAGOGICO', 'Acompañamiento psicopedagógico', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 5
FROM categorias_documentales WHERE codigo='BECA';

-- IV. Cumplimiento del plan de estudios
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CAPA', 'Certificado de Aprobación del Periodo Académico (CAPA)', 'PERIODO', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='PLAN_ESTUDIOS';

-- V. Titulación
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'TIT_EXAMEN_COMPLEXIVO_ANEXO_A', 'Examen complexivo - Anexo A', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='TITULACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'TIT_TRABAJO_ANEXO_A_B', 'Trabajo de titulación - Anexo A y Anexo B', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 2
FROM categorias_documentales WHERE codigo='TITULACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'ACTA_DEFENSA_TITULACION', 'Acta de defensa del trabajo de titulación', 'TRAYECTORIA', FALSE, FALSE, TRUE, FALSE, TRUE, 3
FROM categorias_documentales WHERE codigo='TITULACION';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'ACTA_GRADO', 'Acta de grado', 'TRAYECTORIA', FALSE, FALSE, TRUE, FALSE, TRUE, 4
FROM categorias_documentales WHERE codigo='TITULACION';

-- VI. Vinculación y prácticas
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_VINCULACION_96H', 'Certificado de aprobación de vinculación con la sociedad', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='VINCULACION_PRACTICAS';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_PRACTICAS_240H', 'Certificado de aprobación de prácticas preprofesionales', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 2
FROM categorias_documentales WHERE codigo='VINCULACION_PRACTICAS';

-- VII. Idioma
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_SUFFICIENCIA_IDIOMA', 'Certificado de suficiencia de segundo idioma', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='IDIOMA';

-- VIII. No adeudar
INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CERT_NO_ADEUDAR_BIBLIOTECA', 'Certificado de no adeudar valores de biblioteca', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 1
FROM categorias_documentales WHERE codigo='NO_ADEUDAR';

INSERT INTO tipos_documento_expediente
(categoria_documental_id, codigo, nombre, ambito, obligatorio, permite_multiples, requiere_aprobacion, reutilizable_entre_carreras, solo_pdf, orden_visual)
SELECT id, 'CCF', 'Certificado de cumplimiento financiero', 'TRAYECTORIA', FALSE, TRUE, TRUE, FALSE, TRUE, 2
FROM categorias_documentales WHERE codigo='NO_ADEUDAR';

-- ============================================================
-- 15. ASIGNAR NOMENCLATURA BASE A TIPOS
-- ============================================================

INSERT INTO tipo_documento_nomenclatura
(tipo_documento_expediente_id, plantilla_nomenclatura_documento_id)
SELECT t.id, p.id
FROM tipos_documento_expediente t
JOIN plantillas_nomenclatura_documento p
  ON p.codigo='APELLIDOS_NOMBRES_TIPO';

-- ============================================================
-- 16. REGLAS DE APLICACIÓN
-- ============================================================
--
-- EXPEDIENTE:
-- 1. Cada persona tiene un expediente_persona.
-- 2. Cada estudiante_carrera tiene su expediente_trayectoria.
-- 3. Si se gradúa de una carrera y luego inicia otra:
--      - NO se borra ni reutiliza ciegamente el expediente anterior.
--      - se crea nuevo expediente_trayectoria.
--      - documentos PERSONA reutilizables pueden enlazarse.
--      - documentos TRAYECTORIA/PERIODO se gestionan de nuevo.
--
-- RESPONSABLES:
-- - Se pueden configurar múltiples responsables por tipo documental.
-- - Ej.: Secretaría, Financiero, Titulación, Coordinación, Estudiante.
-- - Por ahora la configuración queda abierta y administrable.
--
-- VERSIONES:
-- - Cada nueva carga = nueva documento_versiones.
-- - Si una nueva versión es aprobada:
--      versión anterior -> es_vigente=FALSE
--      nueva versión -> es_vigente=TRUE
--      documentos_expediente.version_vigente_id = nueva versión.
-- - Nunca se elimina el histórico.
--
-- NOMBRE DE ARCHIVO:
-- - El backend genera:
--      APELLIDOS_NOMBRES_TIPO.ext
-- - Ejemplo:
--      ARIAS_MINA_LESLY_MAILEN_CEDULA.pdf
-- - Si permite múltiples:
--      puede añadirse sufijo controlado:
--      ARIAS_MINA_LESLY_MAILEN_SERVICIO_BASICO_2026_01.pdf
--
-- DERE-12 / DERE-02:
-- - No se crea DERE-02.
-- - Si existe nomenclatura/catálogo legado, se migrará solo a DERE-12.
--
-- TRAZABILIDAD:
-- - Quién subió: documento_versiones.cargado_por_usuario_id
-- - Quién aprobó/rechazó: campos específicos
-- - Qué pasó: historial_documentos_expediente
--
-- INTEGRACIÓN:
-- - Becas, Titulación, Financiero, Prácticas, Vinculación, etc.
--   pueden vincular un documento existente con documento_vinculos_modulo.
--
-- ============================================================
-- FIN 012_expediente_documental.sql
-- ============================================================
