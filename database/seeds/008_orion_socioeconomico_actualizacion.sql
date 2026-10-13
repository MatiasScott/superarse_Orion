USE superarse_siga;

-- Orion v0.6.3
-- Política configurable: renovación completa de Ficha Situacional cada 6 meses.
SET @ORION_OLD_SQL_SAFE_UPDATES = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
INSERT INTO parametros_sistema
(categoria_configuracion_sistema_id,tipo_parametro_sistema_id,alcance_parametro_sistema_id,codigo,nombre,descripcion,modulo,valor_defecto_texto,obligatorio,editable_desde_ui,activo)
SELECT c.id,t.id,a.id,
       'SOCIOECONOMICO_ACTUALIZACION_MESES',
       'Meses para actualización de Ficha Situacional',
       'Número de meses desde el registro de la Ficha Situacional vigente para solicitar al estudiante una actualización completa.',
       'ADMISIONES','6',TRUE,TRUE,TRUE
FROM categorias_configuracion_sistema c
JOIN tipos_parametro_sistema t ON t.codigo='INTEGER'
JOIN alcances_parametro_sistema a ON a.codigo='GLOBAL'
WHERE c.codigo='GENERAL'
  AND NOT EXISTS (SELECT 1 FROM parametros_sistema p WHERE p.codigo='SOCIOECONOMICO_ACTUALIZACION_MESES');

-- Normaliza datos creados antes de v0.6.3: conserva como vigente únicamente
-- el registro abierto más reciente de cada estudiante, sin borrar historial.
UPDATE estudiante_datos_socioeconomicos s
JOIN (
    SELECT estudiante_id, MAX(id) AS conservar_id
    FROM estudiante_datos_socioeconomicos
    WHERE vigente_hasta IS NULL
    GROUP BY estudiante_id
    HAVING COUNT(*) > 1
) d ON d.estudiante_id=s.estudiante_id
SET s.vigente_hasta=GREATEST(s.vigente_desde,CURDATE())
WHERE s.vigente_hasta IS NULL
  AND s.id<>d.conservar_id;

SET SQL_SAFE_UPDATES = @ORION_OLD_SQL_SAFE_UPDATES;
