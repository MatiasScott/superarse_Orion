-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 004_admisiones_estudiantes.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
--   003_talento_humano_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión de aspirantes y solicitudes de admisión
--   - Conversión de aspirante/admitido a estudiante
--   - Estados e histórico de admisión
--   - Información socioeconómica general del estudiante
--   - Contactos de emergencia / representantes
--   - Vinculación con solicitud automática de cuenta institucional a TIC
--
-- IMPORTANTE:
--   - La carrera/malla/cohorte NO se duplica aquí.
--   - La selección de carrera se conectará en 005_estructura_academica.sql
--     mediante tablas puente con FK reales a carreras/mallas.
--   - Becas se gestionarán en el bloque 011_becas_bienestar.sql.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE ADMISIÓN
-- ============================================================

CREATE TABLE estados_aspirante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(255) NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_aspirante_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_solicitud_admision (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(255) NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_solicitud_admision_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE canales_admision (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_canales_admision_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_ingreso_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_ingreso_estudiante_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    permite_matricula BOOLEAN NOT NULL DEFAULT FALSE,
    permite_acceso_academico BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_estudiante_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE ocupaciones_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_ocupaciones_estudiante_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE niveles_formacion_familiar (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    orden_nivel SMALLINT UNSIGNED NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_niveles_formacion_familiar_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_financiamiento_estudios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_financiamiento_estudios_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_colegio (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_colegio_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. ASPIRANTES
-- ============================================================

CREATE TABLE aspirantes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    persona_id BIGINT UNSIGNED NOT NULL,
    estado_aspirante_id BIGINT UNSIGNED NOT NULL,

    codigo_aspirante VARCHAR(40) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_interaccion DATETIME NULL,

    canal_admision_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_aspirantes_persona UNIQUE (persona_id),
    CONSTRAINT uq_aspirantes_codigo UNIQUE (codigo_aspirante),

    CONSTRAINT fk_aspirantes_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_aspirantes_estado
        FOREIGN KEY (estado_aspirante_id) REFERENCES estados_aspirante(id),
    CONSTRAINT fk_aspirantes_canal
        FOREIGN KEY (canal_admision_id) REFERENCES canales_admision(id)
) ENGINE=InnoDB;

CREATE INDEX idx_aspirantes_estado_fecha
ON aspirantes (estado_aspirante_id, fecha_registro);

-- ============================================================
-- 03. SOLICITUDES DE ADMISIÓN
-- ============================================================

CREATE TABLE solicitudes_admision (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(40) NOT NULL,
    aspirante_id BIGINT UNSIGNED NOT NULL,
    estado_solicitud_id BIGINT UNSIGNED NOT NULL,
    tipo_ingreso_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    fecha_resolucion DATETIME NULL,

    revisado_por_usuario_id BIGINT UNSIGNED NULL,
    resuelto_por_usuario_id BIGINT UNSIGNED NULL,

    observacion TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_solicitudes_admision_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_solicitudes_admision_aspirante
        FOREIGN KEY (aspirante_id) REFERENCES aspirantes(id),
    CONSTRAINT fk_solicitudes_admision_estado
        FOREIGN KEY (estado_solicitud_id) REFERENCES estados_solicitud_admision(id),
    CONSTRAINT fk_solicitudes_admision_tipo_ingreso
        FOREIGN KEY (tipo_ingreso_id) REFERENCES tipos_ingreso_estudiante(id),
    CONSTRAINT fk_solicitudes_admision_revisado_por
        FOREIGN KEY (revisado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_solicitudes_admision_resuelto_por
        FOREIGN KEY (resuelto_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_solicitudes_admision_estado_fecha
ON solicitudes_admision (estado_solicitud_id, fecha_solicitud);

-- ============================================================
-- 04. HISTÓRICO DE ESTADOS DE ADMISIÓN
-- ============================================================

CREATE TABLE historial_estado_aspirante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    aspirante_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_aspirante
        FOREIGN KEY (aspirante_id) REFERENCES aspirantes(id),
    CONSTRAINT fk_hist_aspirante_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_aspirante(id),
    CONSTRAINT fk_hist_aspirante_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_aspirante(id),
    CONSTRAINT fk_hist_aspirante_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_aspirante_fecha
ON historial_estado_aspirante (aspirante_id, changed_at);

CREATE TABLE historial_estado_solicitud_admision (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_admision_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_solicitud_admision
        FOREIGN KEY (solicitud_admision_id) REFERENCES solicitudes_admision(id),
    CONSTRAINT fk_hist_solicitud_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_solicitud_admision(id),
    CONSTRAINT fk_hist_solicitud_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_solicitud_admision(id),
    CONSTRAINT fk_hist_solicitud_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_solicitud_admision_fecha
ON historial_estado_solicitud_admision (solicitud_admision_id, changed_at);

-- ============================================================
-- 05. ESTUDIANTES
-- ============================================================

CREATE TABLE estudiantes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    persona_id BIGINT UNSIGNED NOT NULL,
    estado_estudiante_id BIGINT UNSIGNED NOT NULL,

    codigo_estudiante VARCHAR(40) NOT NULL,
    fecha_ingreso DATE NULL,
    fecha_egreso DATE NULL,
    fecha_graduacion DATE NULL,
    fecha_baja DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_estudiantes_persona UNIQUE (persona_id),
    CONSTRAINT uq_estudiantes_codigo UNIQUE (codigo_estudiante),

    CONSTRAINT fk_estudiantes_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_estudiantes_estado
        FOREIGN KEY (estado_estudiante_id) REFERENCES estados_estudiante(id),

    CONSTRAINT chk_estudiante_fechas CHECK (
        (fecha_egreso IS NULL OR fecha_ingreso IS NULL OR fecha_egreso >= fecha_ingreso)
        AND
        (fecha_graduacion IS NULL OR fecha_ingreso IS NULL OR fecha_graduacion >= fecha_ingreso)
        AND
        (fecha_baja IS NULL OR fecha_ingreso IS NULL OR fecha_baja >= fecha_ingreso)
    )
) ENGINE=InnoDB;

CREATE INDEX idx_estudiantes_estado
ON estudiantes (estado_estudiante_id, activo);

-- ============================================================
-- 06. CONVERSIÓN ADMISIÓN -> ESTUDIANTE
-- ============================================================

CREATE TABLE conversiones_admision_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_admision_id BIGINT UNSIGNED NOT NULL,
    estudiante_id BIGINT UNSIGNED NOT NULL,

    convertido_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_conversion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observacion VARCHAR(255) NULL,

    CONSTRAINT uq_conversion_solicitud UNIQUE (solicitud_admision_id),
    CONSTRAINT uq_conversion_estudiante UNIQUE (estudiante_id),

    CONSTRAINT fk_conversion_solicitud
        FOREIGN KEY (solicitud_admision_id) REFERENCES solicitudes_admision(id),
    CONSTRAINT fk_conversion_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    CONSTRAINT fk_conversion_usuario
        FOREIGN KEY (convertido_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 07. HISTÓRICO DE ESTADOS DEL ESTUDIANTE
-- ============================================================

CREATE TABLE historial_estado_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    CONSTRAINT fk_hist_estudiante_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_estudiante(id),
    CONSTRAINT fk_hist_estudiante_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_estudiante(id),
    CONSTRAINT fk_hist_estudiante_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_estudiante_fecha
ON historial_estado_estudiante (estudiante_id, changed_at);

-- ============================================================
-- 08. INFORMACIÓN SOCIOECONÓMICA GENERAL
--     Se versiona por vigencia para mantener histórico.
-- ============================================================

CREATE TABLE estudiante_datos_socioeconomicos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_id BIGINT UNSIGNED NOT NULL,

    ocupacion_id BIGINT UNSIGNED NULL,
    financiamiento_estudios_id BIGINT UNSIGNED NULL,

    recibe_bono_desarrollo_humano BOOLEAN NULL,

    nivel_formacion_padre_id BIGINT UNSIGNED NULL,
    nivel_formacion_madre_id BIGINT UNSIGNED NULL,

    ingresos_hogar DECIMAL(12,2) NULL,
    numero_miembros_hogar SMALLINT UNSIGNED NULL,

    tipo_colegio_id BIGINT UNSIGNED NULL,

    tiene_ayuda_economica BOOLEAN NULL,
    valor_ayuda_economica DECIMAL(12,2) NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_socio_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    CONSTRAINT fk_socio_ocupacion
        FOREIGN KEY (ocupacion_id) REFERENCES ocupaciones_estudiante(id),
    CONSTRAINT fk_socio_financiamiento
        FOREIGN KEY (financiamiento_estudios_id) REFERENCES tipos_financiamiento_estudios(id),
    CONSTRAINT fk_socio_formacion_padre
        FOREIGN KEY (nivel_formacion_padre_id) REFERENCES niveles_formacion_familiar(id),
    CONSTRAINT fk_socio_formacion_madre
        FOREIGN KEY (nivel_formacion_madre_id) REFERENCES niveles_formacion_familiar(id),
    CONSTRAINT fk_socio_tipo_colegio
        FOREIGN KEY (tipo_colegio_id) REFERENCES tipos_colegio(id),
    CONSTRAINT fk_socio_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_socio_ingresos CHECK (
        ingresos_hogar IS NULL OR ingresos_hogar >= 0
    ),
    CONSTRAINT chk_socio_miembros CHECK (
        numero_miembros_hogar IS NULL OR numero_miembros_hogar >= 1
    ),
    CONSTRAINT chk_socio_ayuda CHECK (
        valor_ayuda_economica IS NULL OR valor_ayuda_economica >= 0
    ),
    CONSTRAINT chk_socio_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

CREATE INDEX idx_socio_estudiante_vigencia
ON estudiante_datos_socioeconomicos (estudiante_id, vigente_desde, vigente_hasta);

-- ============================================================
-- 09. CONTACTOS DE EMERGENCIA / REPRESENTANTES
-- ============================================================

CREATE TABLE tipos_contacto_estudiante (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_contacto_estudiante_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estudiante_contactos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    estudiante_id BIGINT UNSIGNED NOT NULL,
    tipo_contacto_id BIGINT UNSIGNED NOT NULL,

    nombres VARCHAR(160) NOT NULL,
    apellidos VARCHAR(160) NULL,
    parentesco VARCHAR(100) NULL,

    telefono VARCHAR(30) NULL,
    correo VARCHAR(190) NULL,
    direccion VARCHAR(255) NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT fk_estudiante_contactos_estudiante
        FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
    CONSTRAINT fk_estudiante_contactos_tipo
        FOREIGN KEY (tipo_contacto_id) REFERENCES tipos_contacto_estudiante(id)
) ENGINE=InnoDB;

CREATE INDEX idx_estudiante_contactos_activos
ON estudiante_contactos (estudiante_id, activo);

-- ============================================================
-- 10. VÍNCULO ADMISIÓN -> SOLICITUD DE CUENTA TIC
-- ============================================================

CREATE TABLE admision_solicitudes_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    solicitud_admision_id BIGINT UNSIGNED NOT NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_admision_solicitud_cuenta
        UNIQUE (solicitud_admision_id, solicitud_cuenta_id),

    CONSTRAINT fk_admision_sc_admision
        FOREIGN KEY (solicitud_admision_id) REFERENCES solicitudes_admision(id),
    CONSTRAINT fk_admision_sc_cuenta
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id)
) ENGINE=InnoDB;

CREATE INDEX idx_admision_sc_cuenta
ON admision_solicitudes_cuenta (solicitud_cuenta_id);

-- ============================================================
-- 11. DATOS INICIALES
-- ============================================================

INSERT INTO estados_aspirante
(codigo, nombre, descripcion, es_final)
VALUES
('REGISTRADO', 'Registrado', 'Aspirante registrado', FALSE),
('EN_PROCESO', 'En proceso', 'Aspirante con proceso de admisión activo', FALSE),
('ADMITIDO', 'Admitido', 'Aspirante admitido', TRUE),
('NO_ADMITIDO', 'No admitido', 'Aspirante no admitido', TRUE),
('DESISTIDO', 'Desistido', 'Aspirante que desistió del proceso', TRUE),
('INACTIVO', 'Inactivo', 'Aspirante inactivo', TRUE);

INSERT INTO estados_solicitud_admision
(codigo, nombre, descripcion, es_final)
VALUES
('BORRADOR', 'Borrador', 'Solicitud aún no enviada', FALSE),
('ENVIADA', 'Enviada', 'Solicitud enviada', FALSE),
('EN_REVISION', 'En revisión', 'Solicitud en revisión', FALSE),
('OBSERVADA', 'Observada', 'Solicitud requiere correcciones', FALSE),
('APROBADA', 'Aprobada', 'Solicitud aprobada', TRUE),
('RECHAZADA', 'Rechazada', 'Solicitud rechazada', TRUE),
('ANULADA', 'Anulada', 'Solicitud anulada', TRUE);

INSERT INTO canales_admision (codigo, nombre) VALUES
('WEB', 'Portal web'),
('PRESENCIAL', 'Presencial'),
('TELEFONO', 'Teléfono'),
('WHATSAPP', 'WhatsApp'),
('CORREO', 'Correo electrónico'),
('REFERIDO', 'Referido'),
('OTRO', 'Otro');

INSERT INTO tipos_ingreso_estudiante (codigo, nombre) VALUES
('NUEVO', 'Nuevo ingreso'),
('REINGRESO', 'Reingreso'),
('HOMOLOGACION', 'Ingreso por homologación'),
('CAMBIO_CARRERA', 'Cambio de carrera'),
('OTRO', 'Otro');

INSERT INTO estados_estudiante
(codigo, nombre, descripcion, permite_matricula, permite_acceso_academico, es_final)
VALUES
('PREMATRICULADO', 'Prematriculado', 'Estudiante en proceso previo a matrícula', TRUE, FALSE, FALSE),
('ACTIVO', 'Activo', 'Estudiante activo', TRUE, TRUE, FALSE),
('RENOVACION', 'Renovación', 'Estudiante en proceso de renovación', TRUE, TRUE, FALSE),
('SUSPENDIDO', 'Suspendido', 'Estudiante suspendido temporalmente', FALSE, FALSE, FALSE),
('BLOQUEADO_ACADEMICO', 'Bloqueado académicamente', 'Bloqueo académico por regla institucional', FALSE, FALSE, FALSE),
('RETIRADO', 'Retirado', 'Estudiante retirado', FALSE, FALSE, TRUE),
('BAJA', 'Baja', 'Estudiante dado de baja', FALSE, FALSE, TRUE),
('EGRESADO', 'Egresado', 'Estudiante egresado', FALSE, TRUE, FALSE),
('GRADUADO', 'Graduado', 'Estudiante graduado', FALSE, TRUE, TRUE);

INSERT INTO ocupaciones_estudiante (codigo, nombre) VALUES
('SOLO_ESTUDIA', 'Solo estudia'),
('ESTUDIA_TRABAJA', 'Estudia y trabaja'),
('TRABAJA', 'Trabaja'),
('OTRO', 'Otro');

INSERT INTO niveles_formacion_familiar
(codigo, nombre, orden_nivel)
VALUES
('SIN_INSTRUCCION', 'Sin instrucción formal', 1),
('ALFABETIZACION', 'Centro de alfabetización', 2),
('PRIMARIA', 'Primaria', 3),
('SECUNDARIA', 'Secundaria / Bachillerato', 4),
('TECNICO_TECNOLOGICO', 'Técnico / Tecnológico', 5),
('TERCER_NIVEL', 'Tercer nivel', 6),
('CUARTO_NIVEL', 'Cuarto nivel', 7),
('NO_ESPECIFICA', 'No especifica', 99);

INSERT INTO tipos_financiamiento_estudios (codigo, nombre) VALUES
('INGRESOS_PROPIOS', 'Ingresos propios'),
('APOYO_FAMILIAR', 'Apoyo familiar'),
('BECA', 'Beca'),
('CREDITO', 'Crédito'),
('OTRO', 'Otro');

INSERT INTO tipos_colegio (codigo, nombre) VALUES
('PUBLICO', 'Público'),
('PRIVADO', 'Privado'),
('FISCOMISIONAL', 'Fiscomisional'),
('MUNICIPAL', 'Municipal'),
('OTRO', 'Otro');

INSERT INTO tipos_contacto_estudiante (codigo, nombre) VALUES
('EMERGENCIA', 'Contacto de emergencia'),
('REPRESENTANTE', 'Representante'),
('PADRE', 'Padre'),
('MADRE', 'Madre'),
('TUTOR', 'Tutor'),
('OTRO', 'Otro');

-- ============================================================
-- 12. REGLAS DE APLICACIÓN
-- ============================================================
--
-- ADMISIÓN:
-- 1. Registrar persona (si no existe).
-- 2. Crear aspirante.
-- 3. Crear solicitud de admisión.
-- 4. Registrar histórico de estados.
-- 5. Cuando la solicitud queda APROBADA:
--      - aspirante -> ADMITIDO
--      - crear estudiante si no existe
--      - registrar conversiones_admision_estudiante
--      - generar solicitud de cuenta institucional con origen ADMISIONES
--      - vincular mediante admision_solicitudes_cuenta
--      - TIC aprueba y bloque 002 provisiona Microsoft + SIGA + perfil ESTUDIANTE
--
-- CARRERA / MALLA:
-- Se añadirá en 005_estructura_academica.sql mediante relaciones con:
--   - solicitud_admision
--   - estudiante
-- sin duplicar nombres o códigos de carrera en este bloque.
--
-- ESTADO EGRESADO / GRADUADO:
-- El bloque 002 ya contiene políticas de ciclo de vida:
--   EGRESADO -> 180 días
--   GRADUADO -> 90 días
-- para desactivar cuenta/licencia según reglas vigentes.
--
-- DATOS SOCIOECONÓMICOS:
-- Se versionan por vigencia. No se sobrescribe la ficha histórica.
--
-- BECAS:
-- No se almacenan aquí. Se crearán en 011_becas_bienestar.sql
-- y referenciarán estudiantes / periodos / carreras.
--
-- ============================================================
-- FIN 004_admisiones_estudiantes.sql
-- ============================================================
