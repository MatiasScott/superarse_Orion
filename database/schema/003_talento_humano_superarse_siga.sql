-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 003_talento_humano.sql
-- Requiere:
--   001_core_definitivo_superarse_siga.sql
--   002_identidad_microsoft_superarse_siga.sql
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Gestión de docentes, administrativos y personal institucional
--   - Relaciones laborales e histórico
--   - Cargos, unidades organizacionales, sedes y jornadas
--   - Clasificaciones de personal
--   - Desvinculaciones
--   - Integración referencial con solicitudes de cuentas a TIC
--
-- PRINCIPIOS:
--   - La información personal NO se duplica aquí; vive en personas.
--   - Un empleado puede tener más de una clasificación (ej. docente y administrativo).
--   - Una persona puede tener varias relaciones laborales históricas.
--   - No se eliminan físicamente relaciones laborales históricas.
--   - TTHH registra la información; TIC aprueba la creación de cuentas.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE TALENTO HUMANO
-- ============================================================

CREATE TABLE tipos_personal (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(255) NULL,
    genera_perfil_docente BOOLEAN NOT NULL DEFAULT FALSE,
    genera_perfil_administrativo BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_personal_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_contrato_laboral (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_contrato_laboral_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_jornada_laboral (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    horas_semanales DECIMAL(5,2) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipos_jornada_laboral_codigo UNIQUE (codigo),
    CONSTRAINT chk_jornada_horas CHECK (
        horas_semanales IS NULL OR (horas_semanales >= 0 AND horas_semanales <= 168)
    )
) ENGINE=InnoDB;

CREATE TABLE estados_relacion_laboral (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_acceso_institucional BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_relacion_laboral_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE motivos_desvinculacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_motivos_desvinculacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE cargos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,
    es_docente BOOLEAN NOT NULL DEFAULT FALSE,
    es_administrativo BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_cargos_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. EMPLEADOS
-- ============================================================

CREATE TABLE empleados (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    persona_id BIGINT UNSIGNED NOT NULL,
    codigo_empleado VARCHAR(40) NOT NULL,

    fecha_primer_ingreso DATE NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_empleados_persona UNIQUE (persona_id),
    CONSTRAINT uq_empleados_codigo UNIQUE (codigo_empleado),

    CONSTRAINT fk_empleados_persona
        FOREIGN KEY (persona_id) REFERENCES personas(id)
) ENGINE=InnoDB;

-- Una persona puede ser docente y administrativo al mismo tiempo.
CREATE TABLE empleado_tipos_personal (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    empleado_id BIGINT UNSIGNED NOT NULL,
    tipo_personal_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_empleado_tipo_periodo
        UNIQUE (empleado_id, tipo_personal_id, fecha_inicio),

    CONSTRAINT fk_empleado_tipo_empleado
        FOREIGN KEY (empleado_id) REFERENCES empleados(id),
    CONSTRAINT fk_empleado_tipo_tipo
        FOREIGN KEY (tipo_personal_id) REFERENCES tipos_personal(id),

    CONSTRAINT chk_empleado_tipo_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_empleado_tipos_activos
ON empleado_tipos_personal (empleado_id, activo);

-- ============================================================
-- 03. RELACIONES LABORALES
-- ============================================================

CREATE TABLE relaciones_laborales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    empleado_id BIGINT UNSIGNED NOT NULL,
    tipo_contrato_id BIGINT UNSIGNED NULL,
    tipo_jornada_id BIGINT UNSIGNED NULL,
    estado_relacion_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin_prevista DATE NULL,
    fecha_fin_real DATE NULL,

    numero_contrato VARCHAR(100) NULL,
    observacion TEXT NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_relaciones_empleado
        FOREIGN KEY (empleado_id) REFERENCES empleados(id),
    CONSTRAINT fk_relaciones_contrato
        FOREIGN KEY (tipo_contrato_id) REFERENCES tipos_contrato_laboral(id),
    CONSTRAINT fk_relaciones_jornada
        FOREIGN KEY (tipo_jornada_id) REFERENCES tipos_jornada_laboral(id),
    CONSTRAINT fk_relaciones_estado
        FOREIGN KEY (estado_relacion_id) REFERENCES estados_relacion_laboral(id),
    CONSTRAINT fk_relaciones_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_relacion_fechas CHECK (
        (fecha_fin_prevista IS NULL OR fecha_fin_prevista >= fecha_inicio)
        AND
        (fecha_fin_real IS NULL OR fecha_fin_real >= fecha_inicio)
    )
) ENGINE=InnoDB;

CREATE INDEX idx_relaciones_empleado_estado
ON relaciones_laborales (empleado_id, estado_relacion_id);

CREATE INDEX idx_relaciones_fechas
ON relaciones_laborales (fecha_inicio, fecha_fin_real);

-- ============================================================
-- 04. ASIGNACIONES DE CARGO / ÁREA / SEDE
-- ============================================================

CREATE TABLE asignaciones_laborales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    relacion_laboral_id BIGINT UNSIGNED NOT NULL,
    cargo_id BIGINT UNSIGNED NOT NULL,
    unidad_organizacional_id BIGINT UNSIGNED NULL,
    sede_id BIGINT UNSIGNED NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    es_principal BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_asignaciones_relacion
        FOREIGN KEY (relacion_laboral_id) REFERENCES relaciones_laborales(id),
    CONSTRAINT fk_asignaciones_cargo
        FOREIGN KEY (cargo_id) REFERENCES cargos(id),
    CONSTRAINT fk_asignaciones_unidad
        FOREIGN KEY (unidad_organizacional_id) REFERENCES unidades_organizacionales(id),
    CONSTRAINT fk_asignaciones_sede
        FOREIGN KEY (sede_id) REFERENCES sedes(id),
    CONSTRAINT fk_asignaciones_creado_por
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_asignacion_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_asignaciones_relacion_activas
ON asignaciones_laborales (relacion_laboral_id, activo);

CREATE INDEX idx_asignaciones_unidad_cargo
ON asignaciones_laborales (unidad_organizacional_id, cargo_id, activo);

-- ============================================================
-- 05. DOCENTES
-- ============================================================

CREATE TABLE estados_docente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estados_docente_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE docentes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    empleado_id BIGINT UNSIGNED NOT NULL,
    codigo_docente VARCHAR(40) NOT NULL,
    estado_docente_id BIGINT UNSIGNED NOT NULL,

    fecha_habilitacion DATE NULL,
    fecha_inhabilitacion DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,

    CONSTRAINT uq_docentes_empleado UNIQUE (empleado_id),
    CONSTRAINT uq_docentes_codigo UNIQUE (codigo_docente),

    CONSTRAINT fk_docentes_empleado
        FOREIGN KEY (empleado_id) REFERENCES empleados(id),
    CONSTRAINT fk_docentes_estado
        FOREIGN KEY (estado_docente_id) REFERENCES estados_docente(id),

    CONSTRAINT chk_docente_fechas CHECK (
        fecha_inhabilitacion IS NULL
        OR fecha_habilitacion IS NULL
        OR fecha_inhabilitacion >= fecha_habilitacion
    )
) ENGINE=InnoDB;

-- ============================================================
-- 06. DESVINCULACIONES
-- ============================================================

CREATE TABLE desvinculaciones_laborales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    relacion_laboral_id BIGINT UNSIGNED NOT NULL,
    motivo_desvinculacion_id BIGINT UNSIGNED NOT NULL,

    fecha_desvinculacion DATE NOT NULL,
    fecha_ultimo_dia_laboral DATE NULL,

    observacion TEXT NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NULL,
    confirmado_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_confirmacion DATETIME NULL,

    ejecutada BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_desvinculacion_relacion UNIQUE (relacion_laboral_id),

    CONSTRAINT fk_desvinculaciones_relacion
        FOREIGN KEY (relacion_laboral_id) REFERENCES relaciones_laborales(id),
    CONSTRAINT fk_desvinculaciones_motivo
        FOREIGN KEY (motivo_desvinculacion_id) REFERENCES motivos_desvinculacion(id),
    CONSTRAINT fk_desvinculaciones_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_desvinculaciones_confirmado_por
        FOREIGN KEY (confirmado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_desvinculacion_fechas CHECK (
        fecha_ultimo_dia_laboral IS NULL
        OR fecha_ultimo_dia_laboral <= fecha_desvinculacion
    )
) ENGINE=InnoDB;

CREATE INDEX idx_desvinculaciones_fecha
ON desvinculaciones_laborales (fecha_desvinculacion, ejecutada);

-- ============================================================
-- 07. HISTÓRICO DE ESTADOS LABORALES
-- ============================================================

CREATE TABLE historial_estado_relacion_laboral (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    relacion_laboral_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hist_relacion
        FOREIGN KEY (relacion_laboral_id) REFERENCES relaciones_laborales(id),
    CONSTRAINT fk_hist_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_relacion_laboral(id),
    CONSTRAINT fk_hist_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_relacion_laboral(id),
    CONSTRAINT fk_hist_cambiado_por
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_hist_relacion_fecha
ON historial_estado_relacion_laboral (relacion_laboral_id, changed_at);

-- ============================================================
-- 08. VÍNCULO TTHH <-> SOLICITUDES DE CUENTA TIC
--     Evita depender solo de origen_registro_id genérico.
-- ============================================================

CREATE TABLE relacion_laboral_solicitudes_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    relacion_laboral_id BIGINT UNSIGNED NOT NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NOT NULL,
    tipo_vinculo VARCHAR(50) NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_relacion_solicitud
        UNIQUE (relacion_laboral_id, solicitud_cuenta_id),

    CONSTRAINT fk_rlsc_relacion
        FOREIGN KEY (relacion_laboral_id) REFERENCES relaciones_laborales(id),
    CONSTRAINT fk_rlsc_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id)
) ENGINE=InnoDB;

CREATE INDEX idx_rlsc_solicitud
ON relacion_laboral_solicitudes_cuenta (solicitud_cuenta_id);

CREATE TABLE desvinculacion_solicitudes_cuenta (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    desvinculacion_id BIGINT UNSIGNED NOT NULL,
    solicitud_cuenta_id BIGINT UNSIGNED NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_desvinculacion_solicitud
        UNIQUE (desvinculacion_id, solicitud_cuenta_id),

    CONSTRAINT fk_dsc_desvinculacion
        FOREIGN KEY (desvinculacion_id) REFERENCES desvinculaciones_laborales(id),
    CONSTRAINT fk_dsc_solicitud
        FOREIGN KEY (solicitud_cuenta_id) REFERENCES solicitudes_cuentas(id)
) ENGINE=InnoDB;

-- ============================================================
-- 09. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_personal
(codigo, nombre, descripcion, genera_perfil_docente, genera_perfil_administrativo)
VALUES
('DOCENTE', 'Docente', 'Personal docente institucional', TRUE, FALSE),
('ADMINISTRATIVO', 'Administrativo', 'Personal administrativo institucional', FALSE, TRUE),
('DOCENTE_ADMINISTRATIVO', 'Docente-Administrativo', 'Personal con funciones docentes y administrativas', TRUE, TRUE),
('OTRO', 'Otro', 'Otro tipo de personal', FALSE, FALSE);

INSERT INTO tipos_contrato_laboral (codigo, nombre) VALUES
('INDEFINIDO', 'Contrato indefinido'),
('PLAZO_FIJO', 'Contrato a plazo fijo'),
('SERVICIOS_PROFESIONALES', 'Servicios profesionales'),
('OCASIONAL', 'Ocasional'),
('PASANTIA', 'Pasantía'),
('OTRO', 'Otro');

INSERT INTO tipos_jornada_laboral
(codigo, nombre, horas_semanales)
VALUES
('TIEMPO_COMPLETO', 'Tiempo completo', 40.00),
('MEDIO_TIEMPO', 'Medio tiempo', 20.00),
('PARCIAL', 'Tiempo parcial', NULL),
('POR_HORAS', 'Por horas', NULL),
('OTRA', 'Otra', NULL);

INSERT INTO estados_relacion_laboral
(codigo, nombre, permite_acceso_institucional, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE, FALSE),
('ACTIVA', 'Activa', TRUE, FALSE),
('SUSPENDIDA', 'Suspendida', FALSE, FALSE),
('FINALIZADA', 'Finalizada', FALSE, TRUE),
('ANULADA', 'Anulada', FALSE, TRUE);

INSERT INTO motivos_desvinculacion (codigo, nombre) VALUES
('RENUNCIA', 'Renuncia'),
('FIN_CONTRATO', 'Fin de contrato'),
('DESPIDO', 'Terminación laboral'),
('JUBILACION', 'Jubilación'),
('FALLECIMIENTO', 'Fallecimiento'),
('CAMBIO_VINCULO', 'Cambio de vínculo laboral'),
('OTRO', 'Otro');

INSERT INTO estados_docente (codigo, nombre) VALUES
('HABILITADO', 'Habilitado'),
('SUSPENDIDO', 'Suspendido'),
('INHABILITADO', 'Inhabilitado');

-- ============================================================
-- 10. REGLAS DE APLICACIÓN (NO TRIGGERS)
-- ============================================================
--
-- ALTA DE PERSONAL:
-- 1. TTHH crea/actualiza personas.
-- 2. Crea empleados.
-- 3. Registra empleado_tipos_personal.
-- 4. Registra relacion_laboral y asignacion_laboral.
-- 5. El backend crea solicitudes_cuentas con origen TTHH.
-- 6. Se vincula mediante relacion_laboral_solicitudes_cuenta.
-- 7. TIC revisa y aprueba.
-- 8. El bloque 002 provisiona Microsoft 365, licencia, usuario SIGA y perfil.
--
-- PERFIL:
-- DOCENTE -> perfil DOCENTE
-- ADMINISTRATIVO -> perfil ADMINISTRATIVO
-- DOCENTE_ADMINISTRATIVO -> ambos perfiles
--
-- DESVINCULACIÓN:
-- 1. TTHH registra desvinculaciones_laborales.
-- 2. Se actualiza relacion_laboral a FINALIZADA.
-- 3. Se conserva historial.
-- 4. Backend crea solicitud de DESACTIVACION / acción de ciclo.
-- 5. Se vincula con desvinculacion_solicitudes_cuenta.
-- 6. Microsoft: desactivar cuenta + retirar licencia según política.
-- 7. SIGA: usuario inactivo si no mantiene otro vínculo/perfil activo.
--
-- IMPORTANTE:
-- Si la persona todavía mantiene otra relación activa (ej. docente y estudiante),
-- NO se debe desactivar toda su identidad automáticamente. El motor debe revisar
-- perfiles/vínculos vigentes antes de retirar acceso global.
--
-- ============================================================
-- FIN 003_talento_humano.sql
-- ============================================================
