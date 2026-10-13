-- SOLO LECTURA. Ejecutar después del importador v0.8.0.
SELECT 'PERIODOS_CON_ORDEN' indicador, COUNT(*) total FROM periodos_academicos WHERE ordenamiento IS NOT NULL
UNION ALL SELECT 'CURSOS_Q10_IMPORTADOS',COUNT(*) FROM migracion_q10_historico_cursos WHERE estado='IMPORTADO'
UNION ALL SELECT 'NOTAS_Q10_IMPORTADAS',COUNT(*) FROM migracion_q10_historico_notas WHERE estado='IMPORTADO'
UNION ALL SELECT 'NOTAS_SIN_MATRICULA_ASIGNATURA',COUNT(*) FROM migracion_q10_historico_notas WHERE estado='IMPORTADO' AND matricula_asignatura_id IS NULL
UNION ALL SELECT 'INCIDENTES_ERROR_PENDIENTES',COUNT(*) FROM migracion_q10_historico_incidentes WHERE severidad='ERROR' AND resuelto=0
UNION ALL SELECT 'INCIDENTES_ADVERTENCIA_PENDIENTES',COUNT(*) FROM migracion_q10_historico_incidentes WHERE severidad='ADVERTENCIA' AND resuelto=0;

SELECT e.codigo esquema, COUNT(DISTINCT pa.id) parciales, COUNT(pe.id) parametros
FROM esquemas_evaluacion e
JOIN esquema_evaluacion_versiones v ON v.esquema_evaluacion_id=e.id
JOIN parciales_evaluacion pa ON pa.esquema_version_id=v.id
JOIN parametros_evaluacion pe ON pe.parcial_id=pa.id
WHERE e.codigo LIKE 'Q10_HIST_%'
GROUP BY e.codigo ORDER BY e.codigo;

SELECT match_status,COUNT(*) total FROM migracion_q10_historico_notas GROUP BY match_status ORDER BY total DESC;
SELECT tipo,severidad,COUNT(*) total FROM migracion_q10_historico_incidentes WHERE resuelto=0 GROUP BY tipo,severidad ORDER BY severidad,tipo;
