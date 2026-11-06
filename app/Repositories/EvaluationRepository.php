<?php
declare(strict_types=1);

namespace App\Repositories;

use PDO;

/** Consultas de diagnóstico de evaluación. Sin escrituras. */
final class EvaluationRepository
{
    public function __construct(private PDO $db) {}

    public function versions(): array
    {
        return $this->db->query(
            "SELECT v.id, v.numero_version, v.nombre_version, v.vigente_desde, v.vigente_hasta,
                    e.codigo AS esquema_codigo, e.nombre AS esquema_nombre,
                    st.codigo AS estado_codigo, st.nombre AS estado_nombre, st.es_publicado,
                    COUNT(DISTINCT CASE WHEN p.activo=1 THEN p.id END) AS parciales,
                    COALESCE(SUM(CASE WHEN p.activo=1 THEN p.ponderacion_nota_final ELSE 0 END),0) AS total_ponderacion
             FROM esquema_evaluacion_versiones v
             JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id AND e.deleted_at IS NULL
             JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id
             LEFT JOIN parciales_evaluacion p ON p.esquema_version_id=v.id
             GROUP BY v.id, v.numero_version, v.nombre_version, v.vigente_desde, v.vigente_hasta,
                      e.codigo, e.nombre, st.codigo, st.nombre, st.es_publicado
             ORDER BY e.nombre, v.numero_version DESC"
        )->fetchAll(PDO::FETCH_ASSOC);
    }

    public function version(int $id): ?array
    {
        $s=$this->db->prepare(
            "SELECT v.*, e.codigo AS esquema_codigo, e.nombre AS esquema_nombre,
                    st.codigo AS estado_codigo, st.nombre AS estado_nombre, st.es_publicado
             FROM esquema_evaluacion_versiones v
             JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id AND e.deleted_at IS NULL
             JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id
             WHERE v.id=:id"
        );
        $s->execute(['id'=>$id]);
        return $s->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    public function partials(int $versionId): array
    {
        $s=$this->db->prepare(
            "SELECT p.id,p.codigo,p.nombre,p.orden_visual,p.activo,p.ponderacion_nota_final,
                    COUNT(CASE WHEN pa.activo=1 THEN pa.id END) AS parametros,
                    COALESCE(SUM(CASE WHEN pa.activo=1 THEN pa.ponderacion_parcial ELSE 0 END),0) AS total_parametros
             FROM parciales_evaluacion p
             LEFT JOIN parametros_evaluacion pa ON pa.parcial_id=p.id
             WHERE p.esquema_version_id=:id
             GROUP BY p.id,p.codigo,p.nombre,p.orden_visual,p.activo,p.ponderacion_nota_final
             ORDER BY p.orden_visual,p.id"
        );
        $s->execute(['id'=>$versionId]);
        return $s->fetchAll(PDO::FETCH_ASSOC);
    }

    public function parameters(int $versionId): array
    {
        $s=$this->db->prepare(
            "SELECT pa.id,pa.parcial_id,pa.codigo,pa.nombre,pa.ponderacion_parcial,pa.activo
             FROM parametros_evaluacion pa
             JOIN parciales_evaluacion p ON p.id=pa.parcial_id
             WHERE p.esquema_version_id=:id
             ORDER BY p.orden_visual,pa.orden_visual,pa.id"
        );
        $s->execute(['id'=>$versionId]);
        return $s->fetchAll(PDO::FETCH_ASSOC);
    }
}
