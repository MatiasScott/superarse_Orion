-- ============================================================
-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 020_auditoria_seguridad.sql
-- Requiere bloques 001-019
-- Motor: MySQL 8.x / InnoDB / utf8mb4
--
-- Objetivo:
--   - Auditoría global del ERP académico
--   - Registro de accesos, sesiones y eventos de seguridad
--   - Trazabilidad de operaciones sensibles
--   - Histórico de cambios de datos
--   - Intentos fallidos y bloqueos
--   - Auditoría de permisos y suplantación controlada
--   - Registro de integraciones y acciones administrativas
--   - Evidencia para investigación, cumplimiento y soporte
--
-- PRINCIPIOS:
--   - La auditoría debe ser append-only desde la aplicación.
--   - No registrar contraseñas, tokens, secretos ni datos sensibles completos.
--   - Las operaciones críticas requieren actor, fecha, IP y contexto.
--   - El histórico de negocio específico sigue en cada módulo;
--     este bloque centraliza seguridad y trazabilidad transversal.
--   - Toda suplantación debe ser explícita, autorizada y auditable.
-- ============================================================

USE superarse_siga;

-- ============================================================
-- 01. CATÁLOGOS DE AUDITORÍA Y SEGURIDAD
-- ============================================================

CREATE TABLE tipos_evento_auditoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    categoria VARCHAR(80) NOT NULL,
    criticidad SMALLINT UNSIGNED NOT NULL DEFAULT 50,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_evento_auditoria_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE resultados_evento_seguridad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_resultado_evento_seguridad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_autenticacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_autenticacion_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_riesgo_seguridad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    nivel SMALLINT UNSIGNED NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_riesgo_seguridad_codigo UNIQUE (codigo),
    CONSTRAINT uq_tipo_riesgo_seguridad_nivel UNIQUE (nivel)
) ENGINE=InnoDB;

CREATE TABLE estados_incidente_seguridad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_estado_incidente_seguridad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE tipos_accion_seguridad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(70) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_tipo_accion_seguridad_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

-- ============================================================
-- 02. SESIONES DE USUARIO
-- ============================================================

-- ============================================================
-- 02. EXTENSIÓN DE SESIONES DE USUARIO
-- La tabla sesiones_usuario nace en el bloque 001.
-- Aquí se agregan únicamente atributos de seguridad.
-- ============================================================

ALTER TABLE sesiones_usuario
    ADD COLUMN tipo_autenticacion_id BIGINT UNSIGNED NULL AFTER session_uuid,
    ADD COLUMN proveedor_identidad_id BIGINT UNSIGNED NULL AFTER tipo_autenticacion_id,
    ADD COLUMN dispositivo_hash CHAR(64) NULL AFTER user_agent,
    ADD COLUMN cierre_forzado BOOLEAN NOT NULL DEFAULT FALSE AFTER activa,
    ADD COLUMN motivo_cierre VARCHAR(255) NULL AFTER cierre_forzado,
    ADD CONSTRAINT fk_su_tipo_auth
        FOREIGN KEY (tipo_autenticacion_id) REFERENCES tipos_autenticacion(id),
    ADD CONSTRAINT fk_su_proveedor_identidad
        FOREIGN KEY (proveedor_identidad_id) REFERENCES proveedores_identidad(id);

-- El índice idx_sesiones_usuario_activa ya existe desde 001.

-- ============================================================
-- 03. INTENTOS DE AUTENTICACIÓN
-- ============================================================

CREATE TABLE intentos_autenticacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NULL,

    identificador_ingresado VARCHAR(190) NULL,

    tipo_autenticacion_id BIGINT UNSIGNED NOT NULL,
    resultado_evento_seguridad_id BIGINT UNSIGNED NOT NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    proveedor_identidad_codigo VARCHAR(80) NULL,

    error_codigo VARCHAR(100) NULL,
    error_mensaje VARCHAR(500) NULL,

    ocurrido_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ia_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ia_tipo_auth
        FOREIGN KEY (tipo_autenticacion_id) REFERENCES tipos_autenticacion(id),
    CONSTRAINT fk_ia_resultado
        FOREIGN KEY (resultado_evento_seguridad_id) REFERENCES resultados_evento_seguridad(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ia_identificador_fecha
ON intentos_autenticacion (identificador_ingresado, ocurrido_at);

CREATE INDEX idx_ia_ip_fecha
ON intentos_autenticacion (ip, ocurrido_at);

-- ============================================================
-- 04. EVENTOS DE AUDITORÍA GLOBAL
-- ============================================================

CREATE TABLE eventos_auditoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo_evento_auditoria_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,
    sesion_usuario_id BIGINT UNSIGNED NULL,

    modulo VARCHAR(80) NULL,
    entidad VARCHAR(100) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    accion VARCHAR(100) NOT NULL,

    descripcion TEXT NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    request_uuid CHAR(36) NULL,
    correlation_id VARCHAR(190) NULL,

    antes_json JSON NULL,
    despues_json JSON NULL,
    contexto_json JSON NULL,

    exitoso BOOLEAN NOT NULL DEFAULT TRUE,

    error_codigo VARCHAR(100) NULL,
    error_mensaje TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ea_tipo
        FOREIGN KEY (tipo_evento_auditoria_id) REFERENCES tipos_evento_auditoria(id),
    CONSTRAINT fk_ea_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ea_sesion
        FOREIGN KEY (sesion_usuario_id) REFERENCES sesiones_usuario(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ea_usuario_fecha
ON eventos_auditoria (usuario_id, created_at);

CREATE INDEX idx_ea_entidad
ON eventos_auditoria (entidad, entidad_id, created_at);

CREATE INDEX idx_ea_modulo_fecha
ON eventos_auditoria (modulo, created_at);

CREATE INDEX idx_ea_correlation
ON eventos_auditoria (correlation_id);

-- ============================================================
-- 05. ACCIONES SENSIBLES
-- ============================================================

CREATE TABLE acciones_sensibles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT NULL,

    requiere_motivo BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_confirmacion BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_doble_aprobacion BOOLEAN NOT NULL DEFAULT FALSE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_accion_sensible_codigo UNIQUE (codigo)
) ENGINE=InnoDB;

CREATE TABLE ejecuciones_accion_sensible (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    accion_sensible_id BIGINT UNSIGNED NOT NULL,

    usuario_solicitante_id BIGINT UNSIGNED NOT NULL,
    usuario_aprobador_id BIGINT UNSIGNED NULL,

    entidad VARCHAR(100) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    motivo TEXT NULL,

    confirmada BOOLEAN NOT NULL DEFAULT FALSE,
    aprobada BOOLEAN NULL,
    ejecutada BOOLEAN NOT NULL DEFAULT FALSE,

    fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion DATETIME NULL,
    fecha_ejecucion DATETIME NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    resultado_json JSON NULL,
    error_mensaje TEXT NULL,

    CONSTRAINT fk_eas_accion
        FOREIGN KEY (accion_sensible_id) REFERENCES acciones_sensibles(id),
    CONSTRAINT fk_eas_solicitante
        FOREIGN KEY (usuario_solicitante_id) REFERENCES usuarios(id),
    CONSTRAINT fk_eas_aprobador
        FOREIGN KEY (usuario_aprobador_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX idx_eas_pendientes
ON ejecuciones_accion_sensible (ejecutada, fecha_solicitud);

-- ============================================================
-- 06. SUPLANTACIÓN / "VER COMO"
-- ============================================================

CREATE TABLE sesiones_suplantacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_actor_id BIGINT UNSIGNED NOT NULL,
    usuario_objetivo_id BIGINT UNSIGNED NOT NULL,

    rol_objetivo_id BIGINT UNSIGNED NULL,

    motivo TEXT NOT NULL,

    aprobada_por_usuario_id BIGINT UNSIGNED NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    activa BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_ss_actor
        FOREIGN KEY (usuario_actor_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ss_objetivo
        FOREIGN KEY (usuario_objetivo_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ss_rol
        FOREIGN KEY (rol_objetivo_id) REFERENCES roles(id),
    CONSTRAINT fk_ss_aprobada_por
        FOREIGN KEY (aprobada_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ss_distintos CHECK (
        usuario_actor_id <> usuario_objetivo_id
    ),
    CONSTRAINT chk_ss_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_ss_actor_activa
ON sesiones_suplantacion (usuario_actor_id, activa);

-- ============================================================
-- 07. AUDITORÍA DE PERMISOS / ROLES
-- ============================================================

CREATE TABLE auditoria_permisos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_afectado_id BIGINT UNSIGNED NOT NULL,

    rol_id BIGINT UNSIGNED NULL,
    permiso_id BIGINT UNSIGNED NULL,

    accion VARCHAR(40) NOT NULL, -- ASIGNAR / REVOCAR / MODIFICAR

    realizado_por_usuario_id BIGINT UNSIGNED NOT NULL,

    motivo TEXT NULL,

    datos_antes_json JSON NULL,
    datos_despues_json JSON NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ap_usuario_afectado
        FOREIGN KEY (usuario_afectado_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ap_rol
        FOREIGN KEY (rol_id) REFERENCES roles(id),
    CONSTRAINT fk_ap_permiso
        FOREIGN KEY (permiso_id) REFERENCES permisos(id),
    CONSTRAINT fk_ap_realizado_por
        FOREIGN KEY (realizado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_ap_accion CHECK (
        accion IN ('ASIGNAR','REVOCAR','MODIFICAR')
    )
) ENGINE=InnoDB;

CREATE INDEX idx_ap_usuario_fecha
ON auditoria_permisos (usuario_afectado_id, created_at);

-- ============================================================
-- 08. BLOQUEOS DE SEGURIDAD
-- ============================================================

CREATE TABLE bloqueos_seguridad_usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,

    motivo VARCHAR(255) NOT NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    bloqueado_por_usuario_id BIGINT UNSIGNED NULL,
    desbloqueado_por_usuario_id BIGINT UNSIGNED NULL,

    automatico BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bsu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_bsu_bloqueado_por
        FOREIGN KEY (bloqueado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_bsu_desbloqueado_por
        FOREIGN KEY (desbloqueado_por_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_bsu_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    )
) ENGINE=InnoDB;

CREATE INDEX idx_bsu_usuario_activo
ON bloqueos_seguridad_usuario (usuario_id, activo);

-- ============================================================
-- 09. INCIDENTES DE SEGURIDAD
-- ============================================================

CREATE TABLE incidentes_seguridad (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_incidente VARCHAR(60) NOT NULL,

    tipo_riesgo_seguridad_id BIGINT UNSIGNED NOT NULL,
    estado_incidente_seguridad_id BIGINT UNSIGNED NOT NULL,

    titulo VARCHAR(220) NOT NULL,
    descripcion TEXT NOT NULL,

    usuario_afectado_id BIGINT UNSIGNED NULL,

    detectado_por_usuario_id BIGINT UNSIGNED NULL,
    asignado_a_usuario_id BIGINT UNSIGNED NULL,

    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre DATETIME NULL,

    impacto VARCHAR(500) NULL,
    causa_raiz TEXT NULL,
    resolucion TEXT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_incidente_seguridad_numero UNIQUE (numero_incidente),

    CONSTRAINT fk_is_riesgo
        FOREIGN KEY (tipo_riesgo_seguridad_id) REFERENCES tipos_riesgo_seguridad(id),
    CONSTRAINT fk_is_estado
        FOREIGN KEY (estado_incidente_seguridad_id) REFERENCES estados_incidente_seguridad(id),
    CONSTRAINT fk_is_usuario_afectado
        FOREIGN KEY (usuario_afectado_id) REFERENCES usuarios(id),
    CONSTRAINT fk_is_detectado_por
        FOREIGN KEY (detectado_por_usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_is_asignado_a
        FOREIGN KEY (asignado_a_usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_is_fechas CHECK (
        fecha_cierre IS NULL OR fecha_cierre >= fecha_deteccion
    )
) ENGINE=InnoDB;

CREATE INDEX idx_is_estado_riesgo
ON incidentes_seguridad (estado_incidente_seguridad_id, tipo_riesgo_seguridad_id);

-- ============================================================
-- 10. ACCIONES DE INCIDENTE
-- ============================================================

CREATE TABLE incidente_acciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    incidente_seguridad_id BIGINT UNSIGNED NOT NULL,
    tipo_accion_seguridad_id BIGINT UNSIGNED NOT NULL,

    usuario_id BIGINT UNSIGNED NULL,

    detalle TEXT NOT NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ias_incidente
        FOREIGN KEY (incidente_seguridad_id) REFERENCES incidentes_seguridad(id),
    CONSTRAINT fk_ias_tipo_accion
        FOREIGN KEY (tipo_accion_seguridad_id) REFERENCES tipos_accion_seguridad(id),
    CONSTRAINT fk_ias_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 11. AUDITORÍA DE EXPORTACIONES / DESCARGAS
-- ============================================================

CREATE TABLE auditoria_exportaciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,

    modulo VARCHAR(80) NOT NULL,
    tipo_exportacion VARCHAR(50) NOT NULL,

    descripcion VARCHAR(255) NULL,

    filtros_json JSON NULL,

    archivo_id BIGINT UNSIGNED NULL,

    cantidad_registros INT UNSIGNED NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audexp_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ae_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

CREATE INDEX idx_ae_usuario_fecha
ON auditoria_exportaciones (usuario_id, created_at);

-- ============================================================
-- 12. AUDITORÍA DE ARCHIVOS / DOCUMENTOS
-- ============================================================

CREATE TABLE auditoria_archivos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    archivo_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NULL,

    accion VARCHAR(50) NOT NULL, -- SUBIR / DESCARGAR / PREVISUALIZAR / REEMPLAZAR / ELIMINAR_LOGICO

    modulo VARCHAR(80) NULL,
    entidad VARCHAR(100) NULL,
    entidad_id BIGINT UNSIGNED NULL,

    ip VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    detalle VARCHAR(500) NULL,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_aa_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos(id),
    CONSTRAINT fk_aa_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),

    CONSTRAINT chk_aa_accion CHECK (
        accion IN ('SUBIR','DESCARGAR','PREVISUALIZAR','REEMPLAZAR','ELIMINAR_LOGICO')
    )
) ENGINE=InnoDB;

CREATE INDEX idx_aa_archivo_fecha
ON auditoria_archivos (archivo_id, created_at);

-- ============================================================
-- 13. RETENCIÓN DE AUDITORÍA
-- ============================================================

CREATE TABLE politicas_retencion_auditoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo VARCHAR(60) NOT NULL,
    nombre VARCHAR(160) NOT NULL,

    categoria VARCHAR(80) NOT NULL,

    dias_retencion INT UNSIGNED NULL,
    conservar_indefinidamente BOOLEAN NOT NULL DEFAULT FALSE,

    anonimizar_al_vencer BOOLEAN NOT NULL DEFAULT FALSE,

    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_pra_codigo UNIQUE (codigo),

    CONSTRAINT chk_pra_vigencia CHECK (
        vigente_hasta IS NULL OR vigente_hasta >= vigente_desde
    )
) ENGINE=InnoDB;

-- ============================================================
-- 14. RESUMEN DE SEGURIDAD POR USUARIO
-- ============================================================

CREATE TABLE resumen_seguridad_usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario_id BIGINT UNSIGNED NOT NULL,

    ultimo_login_exitoso_at DATETIME NULL,
    ultimo_login_fallido_at DATETIME NULL,

    intentos_fallidos_24h INT UNSIGNED NOT NULL DEFAULT 0,

    sesiones_activas INT UNSIGNED NOT NULL DEFAULT 0,

    bloqueado_seguridad BOOLEAN NOT NULL DEFAULT FALSE,

    nivel_riesgo SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    recalculado_at DATETIME NULL,

    CONSTRAINT uq_rsu_usuario UNIQUE (usuario_id),

    CONSTRAINT fk_rsu_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 15. CAMBIOS MASIVOS
-- ============================================================

CREATE TABLE auditoria_operaciones_masivas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    operacion_uuid CHAR(36) NOT NULL,

    usuario_id BIGINT UNSIGNED NOT NULL,

    modulo VARCHAR(80) NOT NULL,
    accion VARCHAR(100) NOT NULL,

    total_objetivos INT UNSIGNED NOT NULL DEFAULT 0,
    total_exitosos INT UNSIGNED NOT NULL DEFAULT 0,
    total_error INT UNSIGNED NOT NULL DEFAULT 0,

    filtros_json JSON NULL,
    resultado_json JSON NULL,

    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL,

    ip VARCHAR(45) NULL,

    CONSTRAINT uq_aom_uuid UNIQUE (operacion_uuid),

    CONSTRAINT fk_aom_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

-- ============================================================
-- 16. DATOS INICIALES
-- ============================================================

INSERT INTO tipos_autenticacion (codigo, nombre) VALUES
('MICROSOFT_SSO', 'Microsoft SSO / Entra ID'),
('LOCAL_EMERGENCIA', 'Autenticación local de emergencia'),
('API', 'Autenticación de API'),
('SERVICIO', 'Cuenta de servicio');

INSERT INTO resultados_evento_seguridad (codigo, nombre, exitoso) VALUES
('EXITOSO', 'Exitoso', TRUE),
('FALLIDO', 'Fallido', FALSE),
('BLOQUEADO', 'Bloqueado', FALSE),
('EXPIRADO', 'Expirado', FALSE),
('DENEGADO', 'Denegado', FALSE);

INSERT INTO tipos_riesgo_seguridad (codigo, nombre, nivel) VALUES
('BAJO', 'Bajo', 10),
('MEDIO', 'Medio', 30),
('ALTO', 'Alto', 60),
('CRITICO', 'Crítico', 100);

INSERT INTO estados_incidente_seguridad
(codigo, nombre, es_final)
VALUES
('ABIERTO', 'Abierto', FALSE),
('EN_ANALISIS', 'En análisis', FALSE),
('CONTENIDO', 'Contenido', FALSE),
('RESUELTO', 'Resuelto', TRUE),
('FALSO_POSITIVO', 'Falso positivo', TRUE),
('CERRADO', 'Cerrado', TRUE);

INSERT INTO tipos_accion_seguridad (codigo, nombre) VALUES
('BLOQUEAR_USUARIO', 'Bloquear usuario'),
('CERRAR_SESIONES', 'Cerrar sesiones activas'),
('RETIRAR_PERMISO', 'Retirar permiso'),
('RESTAURAR_PERMISO', 'Restaurar permiso'),
('NOTIFICAR_TICS', 'Notificar a TIC'),
('ROTAR_CREDENCIAL', 'Rotar credencial'),
('REVISAR_AUDITORIA', 'Revisar auditoría'),
('OTRA', 'Otra');

INSERT INTO tipos_evento_auditoria
(codigo, nombre, categoria, criticidad)
VALUES
('LOGIN_EXITOSO', 'Inicio de sesión exitoso', 'AUTENTICACION', 30),
('LOGIN_FALLIDO', 'Inicio de sesión fallido', 'AUTENTICACION', 50),
('LOGOUT', 'Cierre de sesión', 'AUTENTICACION', 20),
('SESION_CERRADA_FORZADA', 'Sesión cerrada de forma forzada', 'SEGURIDAD', 60),
('ACCESO_DENEGADO', 'Acceso denegado', 'AUTORIZACION', 60),

('CREAR_REGISTRO', 'Crear registro', 'DATOS', 20),
('MODIFICAR_REGISTRO', 'Modificar registro', 'DATOS', 30),
('ELIMINAR_LOGICO', 'Eliminación lógica', 'DATOS', 50),

('ASIGNAR_ROL', 'Asignar rol', 'PERMISOS', 70),
('REVOCAR_ROL', 'Revocar rol', 'PERMISOS', 70),
('ASIGNAR_PERMISO', 'Asignar permiso', 'PERMISOS', 70),
('REVOCAR_PERMISO', 'Revocar permiso', 'PERMISOS', 70),

('VER_COMO_USUARIO', 'Suplantación controlada / ver como', 'SEGURIDAD', 90),

('CAMBIO_NOTA', 'Cambio de nota', 'ACADEMICO', 100),
('APROBAR_PAGO', 'Aprobar pago', 'FINANCIERO', 80),
('RECHAZAR_PAGO', 'Rechazar pago', 'FINANCIERO', 70),
('AJUSTE_FINANCIERO', 'Ajuste financiero', 'FINANCIERO', 100),

('MATRICULA_CONFIRMADA', 'Matrícula confirmada', 'ACADEMICO', 60),
('MATRICULA_ANULADA', 'Matrícula anulada', 'ACADEMICO', 80),

('CUENTA_MICROSOFT_CREADA', 'Cuenta Microsoft creada', 'INTEGRACION', 60),
('LICENCIA_MICROSOFT_ASIGNADA', 'Licencia Microsoft asignada', 'INTEGRACION', 60),
('LICENCIA_MICROSOFT_RETIRADA', 'Licencia Microsoft retirada', 'INTEGRACION', 80),

('EXPORTACION_DATOS', 'Exportación de datos', 'DATOS', 70),
('DESCARGA_DOCUMENTO', 'Descarga de documento', 'DOCUMENTOS', 50),
('CAMBIO_CONFIGURACION', 'Cambio de configuración', 'SISTEMA', 80);

INSERT INTO acciones_sensibles
(codigo, nombre, descripcion, requiere_motivo, requiere_confirmacion, requiere_doble_aprobacion)
VALUES
('CAMBIAR_NOTA_CERRADA', 'Cambiar nota con parcial cerrado', 'Corrección excepcional de nota oficial', TRUE, TRUE, TRUE),
('AJUSTE_FINANCIERO_MANUAL', 'Ajuste financiero manual', 'Modificación manual de saldo/kardex', TRUE, TRUE, TRUE),
('ANULAR_MATRICULA', 'Anular matrícula', 'Anulación académica de matrícula confirmada', TRUE, TRUE, TRUE),
('REVOCAR_CERTIFICADO', 'Revocar certificado', 'Revocación de certificado emitido', TRUE, TRUE, FALSE),
('DESACTIVAR_CUENTA_MICROSOFT', 'Desactivar cuenta Microsoft', 'Desactivar cuenta institucional', TRUE, TRUE, FALSE),
('RETIRAR_LICENCIA_MICROSOFT', 'Retirar licencia Microsoft', 'Retirar licencia institucional', TRUE, TRUE, FALSE),
('SUPLANTAR_USUARIO', 'Ver como otro usuario', 'Suplantación controlada para soporte/administración', TRUE, TRUE, FALSE),
('EXPORTAR_DATOS_MASIVOS', 'Exportar datos masivos', 'Exportación amplia de datos institucionales', TRUE, TRUE, FALSE);

-- Política base de retención.
INSERT INTO politicas_retencion_auditoria
(codigo, nombre, categoria, dias_retencion, conservar_indefinidamente, anonimizar_al_vencer, vigente_desde)
VALUES
('AUDITORIA_CRITICA', 'Auditoría crítica', 'CRITICA', NULL, TRUE, FALSE, '2026-01-01'),
('AUTENTICACION', 'Eventos de autenticación', 'AUTENTICACION', 1825, FALSE, TRUE, '2026-01-01'),
('AUDITORIA_OPERATIVA', 'Auditoría operativa general', 'OPERATIVA', 3650, FALSE, TRUE, '2026-01-01');

-- ============================================================
-- 17. REGLAS DE APLICACIÓN
-- ============================================================
--
-- AUTENTICACIÓN:
-- - El acceso normal será Microsoft SSO.
-- - LOCAL_EMERGENCIA solo para cuentas especialmente autorizadas.
-- - No guardar token de acceso, refresh token, contraseña ni secreto.
--
-- EVENTOS:
-- - Toda operación crítica genera eventos_auditoria.
-- - antes_json / despues_json deben contener solo campos relevantes.
-- - Nunca incluir:
--      password
--      access_token
--      refresh_token
--      client_secret
--      api_key
--      números completos sensibles no necesarios.
--
-- SUPLANTACIÓN:
-- - Función "Ver como" debe crear sesiones_suplantacion.
-- - La UI debe mostrar claramente que se está actuando como otro usuario.
-- - Toda acción realizada en esa sesión debe conservar:
--      usuario_actor
--      usuario_objetivo
--      motivo
-- - Nunca ocultar quién fue el actor real.
--
-- ACCIONES SENSIBLES:
-- Ejemplo cambio de nota:
--
-- Docente solicita
--      ↓
-- Académico aprueba
--      ↓
-- ejecuciones_accion_sensible
--      ↓
-- evento de auditoría
--      ↓
-- cambio oficial
--
-- AJUSTES FINANCIEROS:
-- - Recomendado doble control.
--
-- EXPORTACIONES:
-- - Registrar filtros y cantidad de filas exportadas.
-- - No almacenar el contenido completo exportado dentro de auditoría.
--
-- ARCHIVOS:
-- - Registrar descarga/visualización de documentos sensibles.
--
-- INTENTOS FALLIDOS:
-- - worker de seguridad puede detectar:
--      múltiples fallos en 15 minutos
--      IPs inusuales
--      sesiones simultáneas anómalas
-- - La respuesta puede ser alerta o bloqueo temporal.
--
-- MICROSOFT:
-- - Si Entra ID provee Conditional Access/MFA, se recomienda mantener
--   esas políticas en Microsoft y reflejar solo resultado relevante en SIGA.
--
-- RETENCIÓN:
-- - Las políticas definitivas deben alinearse con normativa institucional.
-- - Los registros críticos de notas, pagos, matrículas y permisos se
--   recomienda conservar indefinidamente.
--
-- BACKEND:
-- - Crear AuditService central.
-- - Ningún controlador debería insertar eventos directamente sin pasar
--   por el servicio de auditoría.
--
-- Ejemplo:
--
-- AuditService::log(
--     tipo: 'APROBAR_PAGO',
--     usuario: current_user,
--     modulo: 'FINANCIERO',
--     entidad: 'pagos',
--     entidad_id: 123,
--     before: {...},
--     after: {...},
--     request_uuid: ...
-- );
--
-- ============================================================
-- FIN 020_auditoria_seguridad.sql
-- ============================================================
