-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 009_asistencia.sql
-- Requiere bloques 001-008
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Asistencia tomada por el DOCENTE
--   - Sesiones reales de clase por sección
--   - Presente / Ausente / Atraso / Justificada
--   - Apertura, cierre y bloqueo de sesiones
--   - Justificaciones con evidencia y aprobación
--   - Histórico auditable de modificaciones
--   - Control de inasistencias consecutivas
--   - Alertas y acciones por 7+ inasistencias continuas
--   - Integración futura con Microsoft 365 y Moodle
--   - Validación de habilitación académica/financiera
--
-- PRINCIPIOS:
--   1. El profesor registra la asistencia de sus secciones.
--   2. Una sesión cerrada no se modifica directamente.
--   3. Toda corrección posterior queda auditada.
--   4. Las ausencias justificadas no rompen el histórico, pero su efecto
--      en el contador se define mediante política versionada.
--   5. El umbral institucional actual es 7 inasistencias continuas.
--   6. No se elimina histórico de asistencia.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS
-- ============================================================

CREATE TABLE estados_sesion_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    permite_registro BOOLEAN NOT NULL DEFAULT FALSE,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_sesion_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    cuenta_como_inasistencia BOOLEAN NOT NULL DEFAULT FALSE,
    rompe_racha_inasistencia BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_justificacion_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_justificacion_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_alerta_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_alerta_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_alerta_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_estado_alerta_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_accion_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tipo_accion_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. POLÍTICAS VERSIONADAS DE ASISTENCIA
-- ============================================================

CREATE TABLE politicas_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_politica_asistencia_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE politica_asistencia_versiones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    politica_asistencia_id BIGINT UNSIGNED NOT NULL,
    numero_version INT UNSIGNED NOT NULL,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    max_inasistencias_continuas SMALLINT UNSIGNED NOT NULL DEFAULT 7,
    justificada_cuenta_para_racha BOOLEAN NOT NULL DEFAULT FALSE,
    atraso_cuenta_como_inasistencia BOOLEAN NOT NULL DEFAULT FALSE,

    genera_alerta BOOLEAN NOT NULL DEFAULT TRUE,
    solicita_baja_cuenta_institucional BOOLEAN NOT NULL DEFAULT TRUE,

    creado_por_usuario_id BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_pav_version
        UNIQUE (politica_asistencia_id, numero_version),

    CONSTRAINT fk_pav_politica
        FOREIGN KEY (politica_asistencia_id) REFERENCES politicas_asistencia(id),
    CONSTRAINT fk_pav_usuario
        FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_pav_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    ),
    CONSTRAINT chk_pav_umbral CHECK (
        max_inasistencias_continuas > 0
    )
) ENGINE=InnoDB;

-- ============================================================
-- 03. POLÍTICA APLICADA A SECCIÓN
-- ============================================================

CREATE TABLE seccion_politica_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seccion_id BIGINT UNSIGNED NOT NULL,
    politica_version_id BIGINT UNSIGNED NOT NULL,

    asignado_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_bloqueo DATETIME NULL,

    CONSTRAINT uq_seccion_politica_asistencia UNIQUE (seccion_id),

    CONSTRAINT fk_spa_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_spa_politica_version
        FOREIGN KEY (politica_version_id) REFERENCES politica_asistencia_versiones(id),
    CONSTRAINT fk_spa_usuario
        FOREIGN KEY (asignado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 04. SESIONES DE CLASE
-- ============================================================

CREATE TABLE sesiones_clase (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    seccion_id BIGINT UNSIGNED NOT NULL,
    horario_id BIGINT UNSIGNED NULL,
    estado_sesion_asistencia_id BIGINT UNSIGNED NOT NULL,

    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,

    tema_clase VARCHAR(500) NULL,
    observacion TEXT NULL,

    creada_automaticamente BOOLEAN NOT NULL DEFAULT FALSE,

    creada_por_usuario_id BIGINT UNSIGNED NULL,
    abierta_por_usuario_id BIGINT UNSIGNED NULL,
    cerrada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_apertura DATETIME NULL,
    fecha_cierre DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_sesion_seccion_fecha_hora
        UNIQUE (seccion_id, fecha, hora_inicio),

    CONSTRAINT fk_sesion_seccion
        FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    CONSTRAINT fk_sesion_horario
        FOREIGN KEY (horario_id) REFERENCES seccion_horarios(id),
    CONSTRAINT fk_sesion_estado
        FOREIGN KEY (estado_sesion_asistencia_id) REFERENCES estados_sesion_asistencia(id),
    CONSTRAINT fk_sesion_creada_por
        FOREIGN KEY (creada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sesion_abierta_por
        FOREIGN KEY (abierta_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_sesion_cerrada_por
        FOREIGN KEY (cerrada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_sesion_horas CHECK (hora_fin > hora_inicio)
) ENGINE=InnoDB;

CREATE INDEX idx_sesiones_seccion_fecha
ON sesiones_clase (seccion_id, fecha);

-- ============================================================
-- 05. ESTUDIANTES ESPERADOS EN LA SESIÓN
-- Snapshot para preservar quién debía asistir ese día.
-- ============================================================

CREATE TABLE sesion_estudiantes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sesion_clase_id BIGINT UNSIGNED NOT NULL,
    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,

    habilitado_asistencia BOOLEAN NOT NULL DEFAULT TRUE,
    motivo_no_habilitado VARCHAR(255) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_sesion_estudiante
        UNIQUE (sesion_clase_id, matricula_asignatura_id),

    CONSTRAINT fk_se_sesion
        FOREIGN KEY (sesion_clase_id) REFERENCES sesiones_clase(id),
    CONSTRAINT fk_se_matricula_asignatura
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id)
) ENGINE=InnoDB;

-- Al abrir la sesión, el servicio copia las matrículas activas de la sección.
-- Si un estudiante no está habilitado por reglas académicas/financieras,
-- queda en el snapshot pero habilitado_asistencia=FALSE.

-- ============================================================
-- 06. REGISTRO DE ASISTENCIA
-- ============================================================

CREATE TABLE asistencias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sesion_estudiante_id BIGINT UNSIGNED NOT NULL,
    estado_asistencia_id BIGINT UNSIGNED NOT NULL,

    minutos_atraso SMALLINT UNSIGNED NULL,

    observacion VARCHAR(500) NULL,

    registrado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ultima_modificacion_por_usuario_id BIGINT UNSIGNED NULL,
    fecha_ultima_modificacion DATETIME NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_asistencia_sesion_estudiante
        UNIQUE (sesion_estudiante_id),

    CONSTRAINT fk_asistencia_sesion_estudiante
        FOREIGN KEY (sesion_estudiante_id) REFERENCES sesion_estudiantes(id),
    CONSTRAINT fk_asistencia_estado
        FOREIGN KEY (estado_asistencia_id) REFERENCES estados_asistencia(id),
    CONSTRAINT fk_asistencia_registrado_por
        FOREIGN KEY (registrado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_asistencia_modificado_por
        FOREIGN KEY (ultima_modificacion_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_asistencia_atraso CHECK (
        minutos_atraso IS NULL OR minutos_atraso >= 0
    )
) ENGINE=InnoDB;

CREATE INDEX idx_asistencia_estado
ON asistencias (estado_asistencia_id);

-- ============================================================
-- 07. HISTÓRICO DE CAMBIOS DE ASISTENCIA
-- ============================================================

CREATE TABLE historial_asistencias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    asistencia_id BIGINT UNSIGNED NOT NULL,

    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    minutos_atraso_anterior SMALLINT UNSIGNED NULL,
    minutos_atraso_nuevo SMALLINT UNSIGNED NULL,

    motivo TEXT NULL,

    cambiado_por_usuario_id BIGINT UNSIGNED NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ha_asistencia
        FOREIGN KEY (asistencia_id) REFERENCES asistencias(id),
    CONSTRAINT fk_ha_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_asistencia(id),
    CONSTRAINT fk_ha_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_asistencia(id),
    CONSTRAINT fk_ha_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ha_asistencia_fecha
ON historial_asistencias (asistencia_id, changed_at);

-- ============================================================
-- 08. JUSTIFICACIONES
-- ============================================================

CREATE TABLE justificaciones_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_solicitud VARCHAR(50) NOT NULL,

    asistencia_id BIGINT UNSIGNED NOT NULL,
    estado_justificacion_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NOT NULL,
    evidencia_archivo_id BIGINT UNSIGNED NULL,

    solicitada_por_usuario_id BIGINT UNSIGNED NOT NULL,
    revisada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,

    observacion_revision TEXT NULL,
    motivo_rechazo TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_justificacion_numero UNIQUE (numero_solicitud),

    CONSTRAINT fk_ja_asistencia
        FOREIGN KEY (asistencia_id) REFERENCES asistencias(id),
    CONSTRAINT fk_ja_estado
        FOREIGN KEY (estado_justificacion_id) REFERENCES estados_justificacion_asistencia(id),
    CONSTRAINT fk_ja_archivo
        FOREIGN KEY (evidencia_archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_ja_solicitada_por
        FOREIGN KEY (solicitada_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ja_revisada_por
        FOREIGN KEY (revisada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ja_estado_fecha
ON justificaciones_asistencia (estado_justificacion_id, fecha_solicitud);

-- ============================================================
-- 09. RESUMEN / CONTADOR DE ASISTENCIA POR ASIGNATURA
-- Cache recalculable. El histórico real sigue en asistencias.
-- ============================================================

CREATE TABLE resumen_asistencia_asignatura (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,

    total_sesiones INT UNSIGNED NOT NULL DEFAULT 0,
    total_presentes INT UNSIGNED NOT NULL DEFAULT 0,
    total_ausentes INT UNSIGNED NOT NULL DEFAULT 0,
    total_atrasos INT UNSIGNED NOT NULL DEFAULT 0,
    total_justificadas INT UNSIGNED NOT NULL DEFAULT 0,

    inasistencias_continuas_actuales INT UNSIGNED NOT NULL DEFAULT 0,
    max_inasistencias_continuas INT UNSIGNED NOT NULL DEFAULT 0,

    porcentaje_asistencia DECIMAL(5,2) NULL,

    ultima_asistencia_fecha DATE NULL,
    recalculado_at DATETIME NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_resumen_asistencia_ma UNIQUE (matricula_asignatura_id),

    CONSTRAINT fk_raa_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),

    CONSTRAINT chk_raa_porcentaje CHECK (
        porcentaje_asistencia IS NULL
        OR (porcentaje_asistencia >= 0 AND porcentaje_asistencia <= 100)
    )
) ENGINE=InnoDB;

-- ============================================================
-- 10. RACHAS DE INASISTENCIAS
-- Guarda evidencia exacta del evento que disparó la regla.
-- ============================================================

CREATE TABLE rachas_inasistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    politica_version_id BIGINT UNSIGNED NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    cantidad_inasistencias INT UNSIGNED NOT NULL DEFAULT 1,

    umbral_alcanzado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_umbral DATETIME NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_ri_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_ri_politica
        FOREIGN KEY (politica_version_id) REFERENCES politica_asistencia_versiones(id),

    CONSTRAINT chk_ri_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_ri_ma_activa
ON rachas_inasistencia (matricula_asignatura_id, activa);

-- ============================================================
-- 11. ALERTAS POR ASISTENCIA
-- ============================================================

CREATE TABLE alertas_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    racha_inasistencia_id BIGINT UNSIGNED NULL,

    tipo_alerta_id BIGINT UNSIGNED NOT NULL,
    estado_alerta_id BIGINT UNSIGNED NOT NULL,

    titulo VARCHAR(200) NOT NULL,
    mensaje TEXT NOT NULL,

    cantidad_inasistencias INT UNSIGNED NULL,

    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_atencion DATETIME NULL,

    atendida_por_usuario_id BIGINT UNSIGNED NULL,
    observacion_atencion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_aa_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_aa_racha
        FOREIGN KEY (racha_inasistencia_id) REFERENCES rachas_inasistencia(id),
    CONSTRAINT fk_aa_tipo
        FOREIGN KEY (tipo_alerta_id) REFERENCES tipos_alerta_asistencia(id),
    CONSTRAINT fk_aa_estado
        FOREIGN KEY (estado_alerta_id) REFERENCES estados_alerta_asistencia(id),
    CONSTRAINT fk_aa_atendida_por
        FOREIGN KEY (atendida_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_alertas_asistencia_estado
ON alertas_asistencia (estado_alerta_id, fecha_generacion);

-- ============================================================
-- 12. ACCIONES DERIVADAS DE ASISTENCIA
-- No desactiva directamente Microsoft. Genera una acción auditable.
-- ============================================================

CREATE TABLE acciones_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    matricula_asignatura_id BIGINT UNSIGNED NOT NULL,
    alerta_asistencia_id BIGINT UNSIGNED NULL,
    tipo_accion_id BIGINT UNSIGNED NOT NULL,

    ejecutada BOOLEAN NOT NULL DEFAULT FALSE,

    referencia_externa VARCHAR(150) NULL,

    fecha_programada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ejecucion DATETIME NULL,

    ejecutada_por_usuario_id BIGINT UNSIGNED NULL,

    resultado TEXT NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_accion_asistencia_ma
        FOREIGN KEY (matricula_asignatura_id) REFERENCES matricula_asignaturas(id),
    CONSTRAINT fk_accion_asistencia_alerta
        FOREIGN KEY (alerta_asistencia_id) REFERENCES alertas_asistencia(id),
    CONSTRAINT fk_accion_asistencia_tipo
        FOREIGN KEY (tipo_accion_id) REFERENCES tipos_accion_asistencia(id),
    CONSTRAINT fk_accion_asistencia_usuario
        FOREIGN KEY (ejecutada_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_acciones_asistencia_pendientes
ON acciones_asistencia (ejecutada, fecha_programada);

-- ============================================================
-- 13. HISTÓRICO DE SESIONES
-- ============================================================

CREATE TABLE historial_sesion_asistencia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sesion_clase_id BIGINT UNSIGNED NOT NULL,
    estado_anterior_id BIGINT UNSIGNED NULL,
    estado_nuevo_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(500) NULL,
    cambiado_por_usuario_id BIGINT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hsa_sesion
        FOREIGN KEY (sesion_clase_id) REFERENCES sesiones_clase(id),
    CONSTRAINT fk_hsa_estado_anterior
        FOREIGN KEY (estado_anterior_id) REFERENCES estados_sesion_asistencia(id),
    CONSTRAINT fk_hsa_estado_nuevo
        FOREIGN KEY (estado_nuevo_id) REFERENCES estados_sesion_asistencia(id),
    CONSTRAINT fk_hsa_usuario
        FOREIGN KEY (cambiado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 14. DATOS INICIALES
-- ============================================================

INSERT INTO estados_sesion_asistencia
(codigo, nombre, permite_registro, es_final)
VALUES
('PROGRAMADA', 'Programada', FALSE, FALSE),
('ABIERTA', 'Abierta', TRUE, FALSE),
('CERRADA', 'Cerrada', FALSE, TRUE),
('REABIERTA', 'Reabierta excepcionalmente', TRUE, FALSE),
('CANCELADA', 'Cancelada', FALSE, TRUE);

INSERT INTO estados_asistencia
(codigo, nombre, cuenta_como_inasistencia, rompe_racha_inasistencia)
VALUES
('PRESENTE', 'Presente', FALSE, TRUE),
('AUSENTE', 'Ausente', TRUE, FALSE),
('ATRASO', 'Atraso', FALSE, TRUE),
('JUSTIFICADA', 'Ausencia justificada', FALSE, TRUE),
('NO_HABILITADO', 'No habilitado para asistencia', FALSE, TRUE);

INSERT INTO estados_justificacion_asistencia
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_REVISION', 'En revisión', FALSE),
('APROBADA', 'Aprobada', TRUE),
('RECHAZADA', 'Rechazada', TRUE),
('ANULADA', 'Anulada', TRUE);

INSERT INTO tipos_alerta_asistencia
(codigo, nombre, descripcion)
VALUES
('UMBRAL_INASISTENCIAS', 'Umbral de inasistencias continuas', 'Alcanzó el máximo institucional de inasistencias continuas'),
('RIESGO_ASISTENCIA', 'Riesgo por asistencia', 'Estudiante con riesgo académico por inasistencia'),
('OTRA', 'Otra alerta', 'Otra alerta relacionada con asistencia');

INSERT INTO estados_alerta_asistencia
(codigo, nombre, es_final)
VALUES
('PENDIENTE', 'Pendiente', FALSE),
('EN_GESTION', 'En gestión', FALSE),
('ATENDIDA', 'Atendida', TRUE),
('DESCARTADA', 'Descartada', TRUE);

INSERT INTO tipos_accion_asistencia
(codigo, nombre)
VALUES
('NOTIFICAR_ESTUDIANTE', 'Notificar al estudiante'),
('NOTIFICAR_DOCENTE', 'Notificar al docente'),
('NOTIFICAR_COORDINACION', 'Notificar a coordinación académica'),
('NOTIFICAR_TICS', 'Notificar a TICs'),
('SOLICITAR_DESACTIVACION_MICROSOFT', 'Solicitar desactivación de cuenta Microsoft y retiro de licencia'),
('BLOQUEAR_ACCESO_ACADEMICO', 'Solicitar bloqueo de acceso académico'),
('OTRA', 'Otra acción');

-- ============================================================
-- 15. POLÍTICA INSTITUCIONAL ACTUAL
-- ============================================================

INSERT INTO politicas_asistencia
(codigo, nombre, descripcion)
VALUES
(
    'ASISTENCIA_GENERAL',
    'Política General de Asistencia',
    'Política institucional versionada para control de asistencia e inasistencias continuas'
);

INSERT INTO politica_asistencia_versiones
(
    politica_asistencia_id,
    numero_version,
    vigente_desde,
    max_inasistencias_continuas,
    justificada_cuenta_para_racha,
    atraso_cuenta_como_inasistencia,
    genera_alerta,
    solicita_baja_cuenta_institucional
)
SELECT
    id,
    1,
    '2026-01-01',
    7,
    FALSE,
    FALSE,
    TRUE,
    TRUE
FROM politicas_asistencia
WHERE codigo = 'ASISTENCIA_GENERAL';

-- ============================================================
-- 16. REGLAS DE NEGOCIO
-- ============================================================
--
-- FLUJO DEL DOCENTE:
--
-- Docente
--   -> Mis cursos
--      -> Selecciona curso/sección
--         -> Asistencia
--            -> Selecciona/abre sesión
--               -> Lista de estudiantes
--                  -> Presente / Ausente / Atraso
--               -> Guardar
--               -> Cerrar sesión
--
-- SESIONES:
-- - Pueden generarse automáticamente desde horarios.
-- - Al abrir una sesión se genera sesion_estudiantes como snapshot.
-- - Solo docentes asignados a la sección y roles autorizados pueden registrar.
--
-- HABILITACIÓN:
-- - Antes de generar el snapshot se valida matrícula activa.
-- - También se consulta habilitaciones_matricula del bloque 007.
-- - Si Financiero bloquea al estudiante, no se elimina de la lista histórica:
--      habilitado_asistencia = FALSE
--      estado sugerido = NO_HABILITADO
-- - Esto cumple la regla: no tomar asistencia académica a quien no esté
--   habilitado para cursar.
--
-- CIERRE:
-- - Una sesión CERRADA no admite edición ordinaria.
-- - Una reapertura requiere permiso y motivo.
-- - Toda modificación genera historial_asistencias.
--
-- JUSTIFICACIÓN:
-- - La ausencia original permanece en histórico.
-- - Al aprobar justificación, el estado vigente puede pasar a JUSTIFICADA.
-- - Se recalcula la racha según la política aplicada.
--
-- 7 INASISTENCIAS CONTINUAS:
-- - El contador se calcula cronológicamente por estudiante/asignatura.
-- - Al alcanzar el umbral configurado:
--      1. marcar racha_inasistencia.umbral_alcanzado
--      2. generar alerta
--      3. notificar coordinación
--      4. generar acción de control
--      5. cuando corresponda, solicitar a integración Microsoft
--         desactivar cuenta y retirar licencia.
--
-- IMPORTANTE:
-- - Este bloque NO llama directamente a Microsoft Graph.
-- - La ejecución real se realizará en el bloque de integración Microsoft.
-- - Esto evita que un error de asistencia desactive una cuenta sin trazabilidad.
--
-- HISTÓRICO:
-- - Si la política cambia de 7 a otro valor, se crea una nueva versión.
-- - Las secciones antiguas mantienen la versión aplicada.
--
-- MOODLE:
-- - Moodle podrá recibir restricciones de acceso desde SIGA en el bloque
--   de integración, pero la asistencia oficial se mantiene en SIGA.
--
-- ============================================================
-- FIN 009_asistencia.sql
-- ============================================================
