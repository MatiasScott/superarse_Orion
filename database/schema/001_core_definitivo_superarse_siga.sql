-- SIGA / ERP Académico - Instituto Superior Tecnológico Superarse
-- 001_core_definitivo_superarse_siga.sql
-- MySQL 8.x | InnoDB | utf8mb4 | 1FN/2FN/3FN

SET NAMES utf8mb4;
SET time_zone = '-05:00';

CREATE DATABASE IF NOT EXISTS superarse_siga
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE superarse_siga;

CREATE TABLE instituciones (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(200) NOT NULL,
 razon_social VARCHAR(200) NULL,
 ruc VARCHAR(20) NULL UNIQUE,
 dominio_principal VARCHAR(150) NULL,
 sitio_web VARCHAR(190) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE sedes (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 institucion_id BIGINT UNSIGNED NOT NULL,
 codigo VARCHAR(30) NOT NULL,
 nombre VARCHAR(150) NOT NULL,
 descripcion VARCHAR(255) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_sedes_codigo (institucion_id,codigo),
 CONSTRAINT fk_sedes_institucion FOREIGN KEY (institucion_id) REFERENCES instituciones(id)
) ENGINE=InnoDB;

CREATE TABLE unidades_organizacionales (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 institucion_id BIGINT UNSIGNED NOT NULL,
 unidad_padre_id BIGINT UNSIGNED NULL,
 codigo VARCHAR(40) NOT NULL,
 nombre VARCHAR(150) NOT NULL,
 descripcion VARCHAR(255) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_unidades_codigo (institucion_id,codigo),
 CONSTRAINT fk_unidades_institucion FOREIGN KEY (institucion_id) REFERENCES instituciones(id),
 CONSTRAINT fk_unidades_padre FOREIGN KEY (unidad_padre_id) REFERENCES unidades_organizacionales(id)
) ENGINE=InnoDB;

CREATE TABLE paises (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo_iso2 CHAR(2) NOT NULL UNIQUE,
 codigo_iso3 CHAR(3) NULL UNIQUE,
 nombre VARCHAR(120) NOT NULL,
 gentilicio VARCHAR(120) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE provincias (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 pais_id BIGINT UNSIGNED NOT NULL,
 codigo VARCHAR(20) NULL,
 nombre VARCHAR(120) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE KEY uq_provincias_pais_codigo (pais_id,codigo),
 CONSTRAINT fk_provincias_pais FOREIGN KEY (pais_id) REFERENCES paises(id)
) ENGINE=InnoDB;

CREATE TABLE cantones (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 provincia_id BIGINT UNSIGNED NOT NULL,
 codigo VARCHAR(20) NULL,
 nombre VARCHAR(120) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE KEY uq_cantones_provincia_codigo (provincia_id,codigo),
 CONSTRAINT fk_cantones_provincia FOREIGN KEY (provincia_id) REFERENCES provincias(id)
) ENGINE=InnoDB;

CREATE TABLE parroquias (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 canton_id BIGINT UNSIGNED NOT NULL,
 codigo VARCHAR(20) NULL,
 nombre VARCHAR(120) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE KEY uq_parroquias_canton_codigo (canton_id,codigo),
 CONSTRAINT fk_parroquias_canton FOREIGN KEY (canton_id) REFERENCES cantones(id)
) ENGINE=InnoDB;

CREATE TABLE tipos_identificacion (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 longitud_min SMALLINT UNSIGNED NULL,
 longitud_max SMALLINT UNSIGNED NULL,
 usa_validacion_especial BOOLEAN NOT NULL DEFAULT FALSE,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE sexos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE estados_civiles (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE tipos_sangre (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(10) NOT NULL UNIQUE,
 nombre VARCHAR(30) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE etnias (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(120) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE tipos_discapacidad (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(120) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE tipos_telefono (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(80) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE tipos_correo (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(80) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE tipos_direccion (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(30) NOT NULL UNIQUE,
 nombre VARCHAR(80) NOT NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE personas (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tipo_identificacion_id BIGINT UNSIGNED NOT NULL,
 numero_identificacion VARCHAR(30) NOT NULL,
 primer_nombre VARCHAR(80) NOT NULL,
 segundo_nombre VARCHAR(80) NULL,
 primer_apellido VARCHAR(80) NOT NULL,
 segundo_apellido VARCHAR(80) NULL,
 fecha_nacimiento DATE NULL,
 pais_nacimiento_id BIGINT UNSIGNED NULL,
 provincia_nacimiento_id BIGINT UNSIGNED NULL,
 canton_nacimiento_id BIGINT UNSIGNED NULL,
 sexo_id BIGINT UNSIGNED NULL,
 estado_civil_id BIGINT UNSIGNED NULL,
 tipo_sangre_id BIGINT UNSIGNED NULL,
 etnia_id BIGINT UNSIGNED NULL,
 pueblo_nacionalidad VARCHAR(150) NULL,
 nacionalidad_pais_id BIGINT UNSIGNED NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_personas_identificacion (tipo_identificacion_id,numero_identificacion),
 KEY idx_personas_nombres (primer_apellido,segundo_apellido,primer_nombre,segundo_nombre),
 CONSTRAINT fk_personas_tipo_identificacion FOREIGN KEY (tipo_identificacion_id) REFERENCES tipos_identificacion(id),
 CONSTRAINT fk_personas_pais_nacimiento FOREIGN KEY (pais_nacimiento_id) REFERENCES paises(id),
 CONSTRAINT fk_personas_provincia_nacimiento FOREIGN KEY (provincia_nacimiento_id) REFERENCES provincias(id),
 CONSTRAINT fk_personas_canton_nacimiento FOREIGN KEY (canton_nacimiento_id) REFERENCES cantones(id),
 CONSTRAINT fk_personas_sexo FOREIGN KEY (sexo_id) REFERENCES sexos(id),
 CONSTRAINT fk_personas_estado_civil FOREIGN KEY (estado_civil_id) REFERENCES estados_civiles(id),
 CONSTRAINT fk_personas_tipo_sangre FOREIGN KEY (tipo_sangre_id) REFERENCES tipos_sangre(id),
 CONSTRAINT fk_personas_etnia FOREIGN KEY (etnia_id) REFERENCES etnias(id),
 CONSTRAINT fk_personas_nacionalidad_pais FOREIGN KEY (nacionalidad_pais_id) REFERENCES paises(id)
) ENGINE=InnoDB;

CREATE TABLE persona_discapacidades (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 tipo_discapacidad_id BIGINT UNSIGNED NOT NULL,
 porcentaje DECIMAL(5,2) NULL,
 consta_en_documento BOOLEAN NOT NULL DEFAULT FALSE,
 fecha_desde DATE NULL,
 fecha_hasta DATE NULL,
 observacion VARCHAR(255) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 CONSTRAINT fk_persona_discapacidades_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_discapacidades_tipo FOREIGN KEY (tipo_discapacidad_id) REFERENCES tipos_discapacidad(id),
 CONSTRAINT chk_discapacidad_porcentaje CHECK (porcentaje IS NULL OR (porcentaje >= 0 AND porcentaje <= 100))
) ENGINE=InnoDB;

CREATE TABLE persona_telefonos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 tipo_telefono_id BIGINT UNSIGNED NOT NULL,
 numero VARCHAR(30) NOT NULL,
 es_principal BOOLEAN NOT NULL DEFAULT FALSE,
 verificado BOOLEAN NOT NULL DEFAULT FALSE,
 fecha_verificacion DATETIME NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_persona_telefonos (persona_id,numero),
 KEY idx_persona_telefonos_numero (numero),
 CONSTRAINT fk_persona_telefonos_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_telefonos_tipo FOREIGN KEY (tipo_telefono_id) REFERENCES tipos_telefono(id)
) ENGINE=InnoDB;

CREATE TABLE persona_correos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 tipo_correo_id BIGINT UNSIGNED NOT NULL,
 correo VARCHAR(190) NOT NULL,
 es_principal BOOLEAN NOT NULL DEFAULT FALSE,
 verificado BOOLEAN NOT NULL DEFAULT FALSE,
 fecha_verificacion DATETIME NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 UNIQUE KEY uq_persona_correos (persona_id,correo),
 KEY idx_persona_correos_correo (correo),
 CONSTRAINT fk_persona_correos_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_correos_tipo FOREIGN KEY (tipo_correo_id) REFERENCES tipos_correo(id)
) ENGINE=InnoDB;

CREATE TABLE persona_direcciones (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 tipo_direccion_id BIGINT UNSIGNED NOT NULL,
 pais_id BIGINT UNSIGNED NULL,
 provincia_id BIGINT UNSIGNED NULL,
 canton_id BIGINT UNSIGNED NULL,
 parroquia_id BIGINT UNSIGNED NULL,
 barrio VARCHAR(150) NULL,
 direccion_linea1 VARCHAR(255) NULL,
 direccion_linea2 VARCHAR(255) NULL,
 referencia VARCHAR(255) NULL,
 codigo_postal VARCHAR(20) NULL,
 es_principal BOOLEAN NOT NULL DEFAULT FALSE,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 CONSTRAINT fk_persona_direcciones_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_direcciones_tipo FOREIGN KEY (tipo_direccion_id) REFERENCES tipos_direccion(id),
 CONSTRAINT fk_persona_direcciones_pais FOREIGN KEY (pais_id) REFERENCES paises(id),
 CONSTRAINT fk_persona_direcciones_provincia FOREIGN KEY (provincia_id) REFERENCES provincias(id),
 CONSTRAINT fk_persona_direcciones_canton FOREIGN KEY (canton_id) REFERENCES cantones(id),
 CONSTRAINT fk_persona_direcciones_parroquia FOREIGN KEY (parroquia_id) REFERENCES parroquias(id)
) ENGINE=InnoDB;

CREATE TABLE archivos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 uuid CHAR(36) NOT NULL UNIQUE,
 nombre_original VARCHAR(255) NOT NULL,
 nombre_interno VARCHAR(255) NOT NULL UNIQUE,
 ruta_relativa VARCHAR(500) NOT NULL,
 extension VARCHAR(20) NULL,
 mime_type VARCHAR(120) NULL,
 tamano_bytes BIGINT UNSIGNED NULL,
 hash_sha256 CHAR(64) NULL,
 almacenamiento_codigo VARCHAR(50) NOT NULL DEFAULT 'PRINCIPAL',
 creado_por_usuario_id BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE persona_fotografias (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 archivo_id BIGINT UNSIGNED NOT NULL,
 es_actual BOOLEAN NOT NULL DEFAULT TRUE,
 fecha_desde DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 fecha_hasta DATETIME NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_persona_foto_archivo (persona_id,archivo_id),
 CONSTRAINT fk_persona_fotografias_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_fotografias_archivo FOREIGN KEY (archivo_id) REFERENCES archivos(id)
) ENGINE=InnoDB;

CREATE TABLE estados_usuario (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(40) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 descripcion VARCHAR(255) NULL,
 permite_acceso BOOLEAN NOT NULL DEFAULT FALSE,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE usuarios (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL UNIQUE,
 estado_usuario_id BIGINT UNSIGNED NOT NULL,
 requiere_actualizacion_datos BOOLEAN NOT NULL DEFAULT FALSE,
 ultimo_acceso_at DATETIME NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 CONSTRAINT fk_usuarios_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_usuarios_estado FOREIGN KEY (estado_usuario_id) REFERENCES estados_usuario(id)
) ENGINE=InnoDB;

ALTER TABLE archivos ADD CONSTRAINT fk_archivos_creado_por_usuario
FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios(id);

CREATE TABLE perfiles (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(40) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 descripcion VARCHAR(255) NULL,
 ruta_inicio VARCHAR(190) NOT NULL,
 orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE usuario_perfiles (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 usuario_id BIGINT UNSIGNED NOT NULL,
 perfil_id BIGINT UNSIGNED NOT NULL,
 fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 fecha_fin DATETIME NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 asignado_por_usuario_id BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY uq_usuario_perfiles (usuario_id,perfil_id),
 CONSTRAINT fk_usuario_perfiles_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
 CONSTRAINT fk_usuario_perfiles_perfil FOREIGN KEY (perfil_id) REFERENCES perfiles(id),
 CONSTRAINT fk_usuario_perfiles_asignado_por FOREIGN KEY (asignado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE modulos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 modulo_padre_id BIGINT UNSIGNED NULL,
 codigo VARCHAR(80) NOT NULL UNIQUE,
 nombre VARCHAR(120) NOT NULL,
 descripcion VARCHAR(255) NULL,
 ruta_base VARCHAR(190) NULL,
 icono VARCHAR(80) NULL,
 orden_visual SMALLINT UNSIGNED NOT NULL DEFAULT 1,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT fk_modulos_padre FOREIGN KEY (modulo_padre_id) REFERENCES modulos(id)
) ENGINE=InnoDB;

CREATE TABLE roles (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 perfil_id BIGINT UNSIGNED NULL,
 codigo VARCHAR(60) NOT NULL UNIQUE,
 nombre VARCHAR(120) NOT NULL,
 descripcion VARCHAR(255) NULL,
 es_sistema BOOLEAN NOT NULL DEFAULT FALSE,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 deleted_at DATETIME NULL,
 CONSTRAINT fk_roles_perfil FOREIGN KEY (perfil_id) REFERENCES perfiles(id)
) ENGINE=InnoDB;

CREATE TABLE permisos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 modulo_id BIGINT UNSIGNED NOT NULL,
 codigo VARCHAR(120) NOT NULL UNIQUE,
 nombre VARCHAR(150) NOT NULL,
 descripcion VARCHAR(255) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT fk_permisos_modulo FOREIGN KEY (modulo_id) REFERENCES modulos(id)
) ENGINE=InnoDB;

CREATE TABLE rol_permisos (
 rol_id BIGINT UNSIGNED NOT NULL,
 permiso_id BIGINT UNSIGNED NOT NULL,
 permitido BOOLEAN NOT NULL DEFAULT TRUE,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (rol_id,permiso_id),
 CONSTRAINT fk_rol_permisos_rol FOREIGN KEY (rol_id) REFERENCES roles(id),
 CONSTRAINT fk_rol_permisos_permiso FOREIGN KEY (permiso_id) REFERENCES permisos(id)
) ENGINE=InnoDB;

CREATE TABLE usuario_roles (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 usuario_id BIGINT UNSIGNED NOT NULL,
 rol_id BIGINT UNSIGNED NOT NULL,
 fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 fecha_fin DATETIME NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE,
 asignado_por_usuario_id BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY uq_usuario_roles (usuario_id,rol_id),
 CONSTRAINT fk_usuario_roles_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
 CONSTRAINT fk_usuario_roles_rol FOREIGN KEY (rol_id) REFERENCES roles(id),
 CONSTRAINT fk_usuario_roles_asignado_por FOREIGN KEY (asignado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE tipos_actualizacion_datos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(60) NOT NULL UNIQUE,
 nombre VARCHAR(150) NOT NULL,
 descripcion VARCHAR(255) NULL,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE estados_actualizacion_datos (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 codigo VARCHAR(40) NOT NULL UNIQUE,
 nombre VARCHAR(100) NOT NULL,
 es_final BOOLEAN NOT NULL DEFAULT FALSE,
 activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE persona_actualizaciones (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 persona_id BIGINT UNSIGNED NOT NULL,
 tipo_actualizacion_id BIGINT UNSIGNED NOT NULL,
 estado_actualizacion_id BIGINT UNSIGNED NOT NULL,
 solicitado_por_usuario_id BIGINT UNSIGNED NULL,
 fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 fecha_limite DATETIME NULL,
 fecha_completado DATETIME NULL,
 obligatoria BOOLEAN NOT NULL DEFAULT TRUE,
 bloquear_acceso BOOLEAN NOT NULL DEFAULT FALSE,
 observacion TEXT NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 KEY idx_persona_actualizaciones_pendientes (persona_id,estado_actualizacion_id,obligatoria),
 CONSTRAINT fk_persona_actualizaciones_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
 CONSTRAINT fk_persona_actualizaciones_tipo FOREIGN KEY (tipo_actualizacion_id) REFERENCES tipos_actualizacion_datos(id),
 CONSTRAINT fk_persona_actualizaciones_estado FOREIGN KEY (estado_actualizacion_id) REFERENCES estados_actualizacion_datos(id),
 CONSTRAINT fk_persona_actualizaciones_solicitado_por FOREIGN KEY (solicitado_por_usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE sesiones_usuario (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 usuario_id BIGINT UNSIGNED NOT NULL,
 perfil_actual_id BIGINT UNSIGNED NULL,
 session_uuid CHAR(36) NOT NULL UNIQUE,
 ip VARCHAR(45) NULL,
 user_agent VARCHAR(500) NULL,
 inicio_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 ultimo_movimiento_at DATETIME NULL,
 cierre_at DATETIME NULL,
 activa BOOLEAN NOT NULL DEFAULT TRUE,
 KEY idx_sesiones_usuario_activa (usuario_id,activa),
 CONSTRAINT fk_sesiones_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
 CONSTRAINT fk_sesiones_perfil_actual FOREIGN KEY (perfil_actual_id) REFERENCES perfiles(id)
) ENGINE=InnoDB;

CREATE TABLE historial_cambio_perfil (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 sesion_id BIGINT UNSIGNED NOT NULL,
 perfil_origen_id BIGINT UNSIGNED NULL,
 perfil_destino_id BIGINT UNSIGNED NOT NULL,
 changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT fk_historial_cambio_perfil_sesion FOREIGN KEY (sesion_id) REFERENCES sesiones_usuario(id),
 CONSTRAINT fk_historial_cambio_perfil_origen FOREIGN KEY (perfil_origen_id) REFERENCES perfiles(id),
 CONSTRAINT fk_historial_cambio_perfil_destino FOREIGN KEY (perfil_destino_id) REFERENCES perfiles(id)
) ENGINE=InnoDB;

-- ============================================================
-- CONFIGURACIÓN GENERAL
-- ============================================================
-- El modelo avanzado de parámetros del sistema se crea en:
-- 023_configuracion_sistema_parametros_superarse_siga.sql
-- Se evita mantener aquí un modelo simplificado duplicado.
-- ============================================================

-- ============================================================
-- AUDITORÍA Y SEGURIDAD
-- ============================================================
-- El modelo transversal y definitivo de auditoría se crea en:
-- 020_auditoria_seguridad_superarse_siga.sql
-- Se evita mantener aquí un segundo origen de verdad.
-- ============================================================

INSERT INTO instituciones (codigo,nombre,dominio_principal)
VALUES ('SUPERARSE','Instituto Superior Tecnológico Superarse','superarse.edu.ec');

INSERT INTO paises (codigo_iso2,codigo_iso3,nombre,gentilicio)
VALUES ('EC','ECU','Ecuador','Ecuatoriana/o');

INSERT INTO tipos_identificacion (codigo,nombre,longitud_min,longitud_max,usa_validacion_especial) VALUES
('CEDULA','Cédula',10,10,TRUE),('PASAPORTE','Pasaporte',NULL,NULL,FALSE),('OTRO','Otro',NULL,NULL,FALSE);

INSERT INTO sexos (codigo,nombre) VALUES
('MASCULINO','Masculino'),('FEMENINO','Femenino'),('OTRO','Otro'),('NO_ESPECIFICA','No especifica');

INSERT INTO estados_civiles (codigo,nombre) VALUES
('SOLTERO','Soltero/a'),('CASADO','Casado/a'),('DIVORCIADO','Divorciado/a'),('VIUDO','Viudo/a'),('UNION_HECHO','Unión de hecho'),('NO_ESPECIFICA','No especifica');

INSERT INTO tipos_sangre (codigo,nombre) VALUES
('A+','A+'),('A-','A-'),('B+','B+'),('B-','B-'),('AB+','AB+'),('AB-','AB-'),('O+','O+'),('O-','O-');

INSERT INTO etnias (codigo,nombre) VALUES
('INDIGENA','Indígena'),('AFROECUATORIANO','Afroecuatoriano/a'),('MONTUBIO','Montubio/a'),('MESTIZO','Mestizo/a'),('BLANCO','Blanco/a'),('OTRO','Otro');

INSERT INTO tipos_discapacidad (codigo,nombre) VALUES
('FISICA','Física'),('INTELECTUAL','Intelectual'),('AUDITIVA','Auditiva'),('VISUAL','Visual'),('PSICOSOCIAL','Psicosocial'),('LENGUAJE','Lenguaje'),('MULTIPLE','Múltiple'),('OTRA','Otra');

INSERT INTO tipos_telefono (codigo,nombre) VALUES
('MOVIL','Móvil'),('DOMICILIO','Domicilio'),('TRABAJO','Trabajo'),('OTRO','Otro');

INSERT INTO tipos_correo (codigo,nombre) VALUES
('PERSONAL','Personal'),('INSTITUCIONAL','Institucional'),('OTRO','Otro');

INSERT INTO tipos_direccion (codigo,nombre) VALUES
('DOMICILIO','Domicilio'),('TRABAJO','Trabajo'),('OTRO','Otro');

INSERT INTO estados_usuario (codigo,nombre,descripcion,permite_acceso) VALUES
('PENDIENTE','Pendiente','Usuario pendiente de habilitación',FALSE),
('ACTIVO','Activo','Usuario habilitado para ingresar al SIGA',TRUE),
('SUSPENDIDO','Suspendido','Acceso suspendido temporalmente',FALSE),
('INACTIVO','Inactivo','Usuario inactivo',FALSE),
('BLOQUEADO','Bloqueado','Usuario bloqueado',FALSE);

INSERT INTO perfiles (codigo,nombre,descripcion,ruta_inicio,orden_visual) VALUES
('ADMINISTRATIVO','Administrador','Perfil administrativo institucional','/admin/dashboard',1),
('DOCENTE','Docente','Perfil para personal docente','/docente/dashboard',2),
('ESTUDIANTE','Estudiante','Perfil para estudiantes','/estudiante/dashboard',3);

INSERT INTO tipos_actualizacion_datos (codigo,nombre,descripcion) VALUES
('GENERAL','Actualización general','Confirmación o actualización general de información'),
('CONTACTO','Actualización de contacto','Actualización de teléfono y correo personal'),
('DIRECCION','Actualización de dirección','Actualización de residencia/dirección'),
('FOTOGRAFIA','Actualización de fotografía','Carga o actualización de fotografía'),
('SOCIOECONOMICA','Actualización socioeconómica','Actualización de datos socioeconómicos');

INSERT INTO estados_actualizacion_datos (codigo,nombre,es_final) VALUES
('PENDIENTE','Pendiente',FALSE),('EN_PROCESO','En proceso',FALSE),('COMPLETADA','Completada',TRUE),('VENCIDA','Vencida',FALSE),('ANULADA','Anulada',TRUE);


-- FIN 001_core_definitivo_superarse_siga.sql
