USE superarse_siga;

-- Orion v0.6.1 - Catálogos académicos base
-- Idempotente: puede ejecutarse nuevamente sin duplicar módulo/permisos.
INSERT INTO modulos (modulo_padre_id,codigo,nombre,descripcion,ruta_base,icono,orden_visual,activo)
SELECT NULL,'ACADEMICO','Académico','Estructura y catálogos académicos','/admin/academico','academic-cap',50,1
WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE codigo='ACADEMICO');

INSERT INTO permisos (modulo_id,codigo,nombre,descripcion,activo)
SELECT m.id,'academico.catalogos.ver','Ver catálogos académicos','Permite consultar sedes, carreras, mallas y modalidades',1 FROM modulos m
WHERE m.codigo='ACADEMICO' AND NOT EXISTS (SELECT 1 FROM permisos WHERE codigo='academico.catalogos.ver');

INSERT INTO permisos (modulo_id,codigo,nombre,descripcion,activo)
SELECT m.id,'academico.catalogos.gestionar','Gestionar catálogos académicos','Permite crear y editar sedes, carreras, mallas y modalidades',1 FROM modulos m
WHERE m.codigo='ACADEMICO' AND NOT EXISTS (SELECT 1 FROM permisos WHERE codigo='academico.catalogos.gestionar');
