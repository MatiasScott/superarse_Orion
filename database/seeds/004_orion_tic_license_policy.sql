USE superarse_siga;

-- Política institucional confirmada:
-- ESTUDIANTE -> A1_ESTUDIANTE
-- DOCENTE / ADMINISTRATIVO -> A1_PROFESOR
INSERT INTO licencia_microsoft_perfiles
(tipo_licencia_id, perfil_id, es_predeterminada, prioridad, activo)
SELECT l.id, p.id, TRUE, 10, TRUE
FROM tipos_licencia_institucional l
JOIN proveedores_identidad pi ON pi.id=l.proveedor_identidad_id
JOIN perfiles p ON p.codigo='ADMINISTRATIVO'
WHERE pi.codigo='MICROSOFT_ENTRA' AND l.codigo='A1_PROFESOR'
ON DUPLICATE KEY UPDATE es_predeterminada=TRUE, prioridad=10, activo=TRUE;

-- Reafirma las otras dos políticas de forma idempotente.
INSERT INTO licencia_microsoft_perfiles
(tipo_licencia_id, perfil_id, es_predeterminada, prioridad, activo)
SELECT l.id, p.id, TRUE, 10, TRUE
FROM tipos_licencia_institucional l
JOIN proveedores_identidad pi ON pi.id=l.proveedor_identidad_id
JOIN perfiles p ON p.codigo='DOCENTE'
WHERE pi.codigo='MICROSOFT_ENTRA' AND l.codigo='A1_PROFESOR'
ON DUPLICATE KEY UPDATE es_predeterminada=TRUE, prioridad=10, activo=TRUE;

INSERT INTO licencia_microsoft_perfiles
(tipo_licencia_id, perfil_id, es_predeterminada, prioridad, activo)
SELECT l.id, p.id, TRUE, 10, TRUE
FROM tipos_licencia_institucional l
JOIN proveedores_identidad pi ON pi.id=l.proveedor_identidad_id
JOIN perfiles p ON p.codigo='ESTUDIANTE'
WHERE pi.codigo='MICROSOFT_ENTRA' AND l.codigo='A1_ESTUDIANTE'
ON DUPLICATE KEY UPDATE es_predeterminada=TRUE, prioridad=10, activo=TRUE;
