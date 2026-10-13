-- Orion v0.10.1
-- Carga integral de aranceles institucionales publicados para PAO MAYO - OCTUBRE 2026.
-- Fuente: https://superarse.edu.ec/Aranceles
-- Fecha de los documentos: 2026-02-13.
-- Conserva los 13 tarifarios y 44 niveles publicados, incluso cuando Orion todavía
-- no posee una carrera/malla académica inequívoca para vincularlos.

START TRANSACTION;

CREATE TABLE IF NOT EXISTS tarifarios_publicados (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo_fuente VARCHAR(80) NOT NULL UNIQUE,
    nombre_programa VARCHAR(180) NOT NULL,
    periodo_nombre VARCHAR(120) NOT NULL,
    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NOT NULL,
    fecha_documento DATE NULL,
    fuente_url VARCHAR(500) NOT NULL,
    malla_codigo_sugerida VARCHAR(30) NULL,
    estado_vinculacion ENUM('VINCULADO','PENDIENTE') NOT NULL DEFAULT 'PENDIENTE',
    observacion VARCHAR(500) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tarifario_publicado_niveles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tarifario_publicado_id BIGINT UNSIGNED NOT NULL,
    numero_nivel SMALLINT UNSIGNED NOT NULL,
    creditos DECIMAL(8,2) NOT NULL,
    valor_credito DECIMAL(12,2) NOT NULL,
    valor_matricula DECIMAL(12,2) NOT NULL,
    valor_arancel DECIMAL(12,2) NOT NULL,
    total_nivel DECIMAL(12,2) NOT NULL,
    numero_cuotas SMALLINT UNSIGNED NOT NULL,
    monto_cuota DECIMAL(12,2) NOT NULL,
    es_ultimo_nivel BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_tpn (tarifario_publicado_id,numero_nivel),
    CONSTRAINT fk_tpn_tarifario FOREIGN KEY(tarifario_publicado_id) REFERENCES tarifarios_publicados(id)
) ENGINE=InnoDB;

-- El registro usado para pruebas ($26 + $128) no es una tarifa institucional real.
UPDATE tarifas_academicas t
JOIN carreras c ON c.id=t.carrera_id
JOIN mallas_curriculares m ON m.id=t.malla_id
JOIN niveles_academicos n ON n.id=t.nivel_academico_id
SET t.activo=0
WHERE c.nombre='ADMINISTRACIÓN' AND m.codigo='Q10-001' AND n.orden_nivel=1
  AND t.arancel_base=26.00 AND t.valor_matricula=128.00;

INSERT INTO tarifarios_publicados(codigo_fuente,nombre_programa,periodo_nombre,vigente_desde,vigente_hasta,fecha_documento,fuente_url,malla_codigo_sugerida,estado_vinculacion,observacion) VALUES
('ADM-2026-1','ADMINISTRACIÓN','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Administracion_2026.jpg','Q10-001','VINCULADO','Técnicatura Superior en Administración'),
('EB-2026-1','EDUCACIÓN BÁSICA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Educacion_basica_2026.jpg','Q10-003','VINCULADO',NULL),
('EBI-2026-1','EDUCACIÓN BILINGÜE','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Educacion_Bilingue_2026.jpg','Q10-006','VINCULADO',NULL),
('EV-2026-1','ENFERMERÍA VETERINARIA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Enfermeria_Veterinaria_2026.jpg','Q10-012','VINCULADO',NULL),
('IQ-2026-1','INSTRUMENTACIÓN QUIRÚRGICA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Instrumentacion_Quirurgica_2026.jpg',NULL,'PENDIENTE','Carrera/malla no identificada inequívocamente en el catálogo Q10 actual de Orion.'),
('MD-2026-1','MARKETING DIGITAL','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Marketing_digital_2026.jpg','Q10-023','VINCULADO',NULL),
('MIN-2026-1','MINERÍA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Mineria_2026.jpg','Q10-015','VINCULADO','Vinculado a malla rediseño importada desde Q10.'),
('PA-2026-1','PRODUCCIÓN ANIMAL','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Produccion_animal_2026.jpg','Q10-018','VINCULADO',NULL),
('SPRL-2026-1','SEGURIDAD Y PREVENCIÓN DE RIESGOS LABORALES','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Seguridad_prevencion_riesgos_2026.jpg','Q10-021','VINCULADO',NULL),
('TOP-2026-1','TOPOGRAFÍA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Arancel_Topografia_2026.jpg','Q10-026','VINCULADO','Vinculado a malla rediseño importada desde Q10.'),
('VIA-2026-1','VENTAS ESTRATÉGICAS CON INTELIGENCIA ARTIFICIAL','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Ventas_IA_2026.jpg',NULL,'PENDIENTE','Carrera/malla todavía no identificada en el catálogo Q10 actual de Orion.'),
('MDDM-2026-1','MARKETING DIGITAL Y DISEÑO MULTIMEDIA','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/MarketingD_Dise%C3%B1oM_2026.jpg',NULL,'PENDIENTE','Carrera existe en Orion, pero no hay malla Q10 inequívoca para vincular el tarifario.'),
('SHT-2026-1','SEGURIDAD E HIGIENE DEL TRABAJO','PAO MAYO - OCTUBRE 2026','2026-05-01','2026-10-31','2026-02-13','https://superarse.edu.ec/assets/docs/Servicios/aranceles/Higiene_trabajo_2026.jpg','Q10-019','VINCULADO','Vinculado a malla rediseño importada desde Q10.')
ON DUPLICATE KEY UPDATE nombre_programa=VALUES(nombre_programa),fuente_url=VALUES(fuente_url),malla_codigo_sugerida=VALUES(malla_codigo_sugerida),estado_vinculacion=VALUES(estado_vinculacion),observacion=VALUES(observacion);

-- helper: inserciones de niveles (44 registros)
INSERT INTO tarifario_publicado_niveles(tarifario_publicado_id,numero_nivel,creditos,valor_credito,valor_matricula,valor_arancel,total_nivel,numero_cuotas,monto_cuota,es_ultimo_nivel)
SELECT t.id,v.n,v.cr,v.vc,v.vm,v.va,v.total,v.cuotas,v.mc,v.ultimo FROM tarifarios_publicados t JOIN (
SELECT 'ADM-2026-1' c,1 n,15.00 cr,44.92 vc,76.36 vm,763.64 va,840.00 total,6 cuotas,140.00 mc,0 ultimo UNION ALL SELECT 'ADM-2026-1',2,19,53.59,101.82,1018.18,1120,8,140,1 UNION ALL
SELECT 'EB-2026-1',1,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'EB-2026-1',2,16,44.32,70.91,709.09,780,6,130,0 UNION ALL SELECT 'EB-2026-1',3,15,47.27,70.91,709.09,780,6,130,0 UNION ALL SELECT 'EB-2026-1',4,15,63.03,94.55,945.45,1040,8,130,1 UNION ALL
SELECT 'EBI-2026-1',1,17,44.92,76.36,763.64,840,6,140,0 UNION ALL SELECT 'EBI-2026-1',2,17,44.92,76.36,763.64,840,6,140,0 UNION ALL SELECT 'EBI-2026-1',3,21,36.36,76.36,763.63,840,6,140,0 UNION ALL SELECT 'EBI-2026-1',4,16,63.64,101.82,1018.18,1120,8,140,1 UNION ALL
SELECT 'EV-2026-1',1,15,69.09,103.64,1036.37,1140,6,190,0 UNION ALL SELECT 'EV-2026-1',2,15.25,78.69,120,1200,1320,6,220,0 UNION ALL SELECT 'EV-2026-1',3,19,71.77,136.36,1363.63,1500,6,250,0 UNION ALL SELECT 'EV-2026-1',4,14,135.07,189.09,1890.91,2080,8,260,1 UNION ALL
SELECT 'IQ-2026-1',1,16.67,68.71,114.55,1145.45,1260,6,210,0 UNION ALL SELECT 'IQ-2026-1',2,16.67,73.62,122.73,1227.27,1350,6,225,0 UNION ALL SELECT 'IQ-2026-1',3,19.67,62.39,122.73,1227.27,1350,6,225,0 UNION ALL SELECT 'IQ-2026-1',4,13.67,133.01,181.82,1818.18,2000,8,250,1 UNION ALL
SELECT 'MD-2026-1',1,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'MD-2026-1',2,15,63.03,94.55,945.45,1040,8,130,1 UNION ALL
SELECT 'MIN-2026-1',1,15,69.09,103.64,1036.37,1140,6,190,0 UNION ALL SELECT 'MIN-2026-1',2,15,80,120,1200,1320,6,220,0 UNION ALL SELECT 'MIN-2026-1',3,15,90.91,136.36,1363.64,1500,6,250,0 UNION ALL SELECT 'MIN-2026-1',4,15,126.06,189.09,1890.91,2080,8,260,1 UNION ALL
SELECT 'PA-2026-1',1,15,69.09,103.64,1036.37,1140,6,190,0 UNION ALL SELECT 'PA-2026-1',2,15.25,78.69,120,1200,1320,6,220,0 UNION ALL SELECT 'PA-2026-1',3,19,71.77,136.36,1363.63,1500,6,250,0 UNION ALL SELECT 'PA-2026-1',4,13,126.06,189.09,1890.91,2080,8,260,1 UNION ALL
SELECT 'SPRL-2026-1',1,15,50.91,76.36,763.64,840,6,140,0 UNION ALL SELECT 'SPRL-2026-1',2,19,53.59,101.82,1018.18,1120,8,140,1 UNION ALL
SELECT 'TOP-2026-1',1,15,69.09,103.64,1036.37,1140,6,190,0 UNION ALL SELECT 'TOP-2026-1',2,15,80,120,1200,1320,6,220,0 UNION ALL SELECT 'TOP-2026-1',3,15,90.91,136.36,1363.64,1500,6,250,0 UNION ALL SELECT 'TOP-2026-1',4,15,126.06,189.09,1890.91,2080,8,260,1 UNION ALL
SELECT 'VIA-2026-1',1,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'VIA-2026-1',2,15,63.03,94.55,945.45,1040,8,130,1 UNION ALL
SELECT 'MDDM-2026-1',1,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'MDDM-2026-1',2,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'MDDM-2026-1',3,15,47.27,70.91,709.10,780,6,130,0 UNION ALL SELECT 'MDDM-2026-1',4,15,63.03,94.55,945.45,1040,8,130,1 UNION ALL
SELECT 'SHT-2026-1',1,15,50.91,76.36,763.64,840,6,140,0 UNION ALL SELECT 'SHT-2026-1',2,15,50.91,76.36,763.64,840,6,140,0 UNION ALL SELECT 'SHT-2026-1',3,19,40.19,76.36,763.64,840,6,140,0 UNION ALL SELECT 'SHT-2026-1',4,13,78.32,101.82,1018.19,1120,8,140,1
) v ON v.c=t.codigo_fuente
ON DUPLICATE KEY UPDATE creditos=VALUES(creditos),valor_credito=VALUES(valor_credito),valor_matricula=VALUES(valor_matricula),valor_arancel=VALUES(valor_arancel),total_nivel=VALUES(total_nivel),numero_cuotas=VALUES(numero_cuotas),monto_cuota=VALUES(monto_cuota),es_ultimo_nivel=VALUES(es_ultimo_nivel);

-- Sincroniza a tarifas_academicas únicamente los tarifarios con malla Q10 explícita.
-- La política financiera vigente al 2026-05-01 se reutiliza como política operativa.
INSERT INTO tarifas_academicas(carrera_id,malla_id,nivel_academico_id,politica_financiera_version_id,creditos_totales_nivel,arancel_base,valor_matricula,numero_cuotas,vigente_desde,vigente_hasta,es_ultimo_nivel,aprobado_por_usuario_id,activo)
SELECT mc.carrera_id,mc.id,na.id,pfv.id,n.creditos,n.valor_arancel,n.valor_matricula,n.numero_cuotas,tp.vigente_desde,tp.vigente_hasta,n.es_ultimo_nivel,NULL,1
FROM tarifarios_publicados tp
JOIN tarifario_publicado_niveles n ON n.tarifario_publicado_id=tp.id
JOIN mallas_curriculares mc ON mc.codigo=tp.malla_codigo_sugerida AND mc.activo=1 AND mc.deleted_at IS NULL
JOIN niveles_academicos na ON na.orden_nivel=n.numero_nivel AND na.activo=1
JOIN politica_financiera_versiones pfv ON pfv.vigente_desde<=tp.vigente_desde AND (pfv.vigente_hasta IS NULL OR pfv.vigente_hasta>=tp.vigente_desde)
WHERE tp.estado_vinculacion='VINCULADO'
  AND NOT EXISTS(SELECT 1 FROM tarifas_academicas ta WHERE ta.carrera_id=mc.carrera_id AND ta.malla_id=mc.id AND ta.nivel_academico_id=na.id AND ta.vigente_desde=tp.vigente_desde);

COMMIT;

-- Validación esperada:
-- SELECT COUNT(*) FROM tarifarios_publicados;          -- 13
-- SELECT COUNT(*) FROM tarifario_publicado_niveles;   -- 44
-- SELECT codigo_fuente,nombre_programa,estado_vinculacion,malla_codigo_sugerida FROM tarifarios_publicados ORDER BY nombre_programa;
