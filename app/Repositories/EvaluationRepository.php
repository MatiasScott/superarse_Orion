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

    /** Crea un borrador independiente copiando parciales y parámetros. */
    public function cloneDraft(int $sourceId, string $name, string $start): int
    {
        if ($sourceId <= 0 || trim($name) === '' || strlen($name) > 180
            || !preg_match('/^\d{4}-\d{2}-\d{2}$/D', $start)
            || !checkdate((int)substr($start, 5, 2), (int)substr($start, 8, 2), (int)substr($start, 0, 4))) {
            throw new \InvalidArgumentException('Versión, nombre o fecha de vigencia inválidos.');
        }
        $this->db->beginTransaction();
        try {
            $q = $this->db->prepare('SELECT * FROM esquema_evaluacion_versiones WHERE id=? FOR UPDATE');
            $q->execute([$sourceId]);
            $source = $q->fetch(PDO::FETCH_ASSOC);
            if (!$source) throw new \RuntimeException('No existe la versión de origen.');
            $q = $this->db->query("SELECT id FROM estados_esquema_evaluacion WHERE codigo='BORRADOR' AND permite_edicion=1 AND activo=1 LIMIT 1");
            $draftState = (int)$q->fetchColumn();
            if (!$draftState) throw new \RuntimeException('El catálogo BORRADOR no está configurado.');
            // Serializar versiones de un mismo esquema para evitar números repetidos.
            $q = $this->db->prepare('SELECT id FROM esquemas_evaluacion WHERE id=? AND deleted_at IS NULL FOR UPDATE');
            $q->execute([(int)$source['esquema_evaluacion_id']]);
            if (!$q->fetchColumn()) throw new \RuntimeException('El esquema ya no está disponible.');
            $q = $this->db->prepare('SELECT COALESCE(MAX(numero_version),0)+1 FROM esquema_evaluacion_versiones WHERE esquema_evaluacion_id=?');
            $q->execute([(int)$source['esquema_evaluacion_id']]);
            $number = (int)$q->fetchColumn();
            $q = $this->db->prepare('INSERT INTO esquema_evaluacion_versiones (esquema_evaluacion_id,estado_esquema_id,numero_version,nombre_version,descripcion_cambio,vigente_desde) VALUES (?,?,?,?,?,?)');
            $q->execute([(int)$source['esquema_evaluacion_id'],$draftState,$number,trim($name),'Borrador derivado de versión #'.$sourceId,$start]);
            $newId = (int)$this->db->lastInsertId();
            $q = $this->db->prepare('SELECT * FROM parciales_evaluacion WHERE esquema_version_id=? ORDER BY orden_visual,id');
            $q->execute([$sourceId]);
            $partials = $q->fetchAll(PDO::FETCH_ASSOC);
            $insertPartial = $this->db->prepare('INSERT INTO parciales_evaluacion (esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual,activo) VALUES (?,?,?,?,?,?)');
            $getParams = $this->db->prepare('SELECT * FROM parametros_evaluacion WHERE parcial_id=? ORDER BY orden_visual,id');
            $insertParam = $this->db->prepare('INSERT INTO parametros_evaluacion (parcial_id,codigo,nombre,ponderacion_parcial,orden_visual,modificable_al_evaluar,activo) VALUES (?,?,?,?,?,?,?)');
            foreach ($partials as $partial) {
                $insertPartial->execute([$newId,$partial['codigo'],$partial['nombre'],$partial['ponderacion_nota_final'],$partial['orden_visual'],$partial['activo']]);
                $newPartialId = (int)$this->db->lastInsertId();
                $getParams->execute([(int)$partial['id']]);
                foreach ($getParams->fetchAll(PDO::FETCH_ASSOC) as $param) {
                    $insertParam->execute([$newPartialId,$param['codigo'],$param['nombre'],$param['ponderacion_parcial'],$param['orden_visual'],$param['modificable_al_evaluar'],$param['activo']]);
                }
            }
            $this->db->commit();
            return $newId;
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $e;
        }
    }

    /** Modifica exclusivamente las ponderaciones de un borrador editable. */
    public function updateDraftWeights(int $versionId, array $partialWeights, array $parameterWeights): void
    {
        if ($versionId <= 0) throw new \InvalidArgumentException('Versión inválida.');
        $this->db->beginTransaction();
        try {
            $q = $this->db->prepare('SELECT st.permite_edicion, st.es_publicado FROM esquema_evaluacion_versiones v JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id WHERE v.id=? FOR UPDATE');
            $q->execute([$versionId]);
            $state = $q->fetch(PDO::FETCH_ASSOC);
            if (!$state || (int)$state['permite_edicion'] !== 1 || (int)$state['es_publicado'] === 1) {
                throw new \RuntimeException('Solo se pueden editar borradores no publicados.');
            }
            $q = $this->db->prepare('SELECT id FROM parciales_evaluacion WHERE esquema_version_id=? FOR UPDATE');
            $q->execute([$versionId]);
            $partialIds = array_map('intval', $q->fetchAll(PDO::FETCH_COLUMN));
            $q = $this->db->prepare('SELECT pa.id FROM parametros_evaluacion pa JOIN parciales_evaluacion p ON p.id=pa.parcial_id WHERE p.esquema_version_id=? FOR UPDATE');
            $q->execute([$versionId]);
            $paramIds = array_map('intval', $q->fetchAll(PDO::FETCH_COLUMN));
            $normalize = static function (array $values, array $ids): array {
                $out=[];
                foreach ($values as $key=>$value) {
                    if (!ctype_digit((string)$key) || !in_array((int)$key,$ids,true)
                        || !is_scalar($value) || !preg_match('/^\d{1,3}(?:\.\d{1,2})?$/D', (string)$value)
                        || (float)$value<=0 || (float)$value>100) {
                        throw new \InvalidArgumentException('Ponderación inválida o ajena a la versión.');
                    }
                    $out[(int)$key]=number_format((float)$value,2,'.','');
                }
                if (count($out)!==count($ids)) throw new \InvalidArgumentException('Se deben enviar todas las ponderaciones de la versión.');
                return $out;
            };
            $pw=$normalize($partialWeights,$partialIds);
            $aw=$normalize($parameterWeights,$paramIds);
            $u=$this->db->prepare('UPDATE parciales_evaluacion SET ponderacion_nota_final=? WHERE id=?');
            foreach($pw as $id=>$weight) $u->execute([$weight,$id]);
            $u=$this->db->prepare('UPDATE parametros_evaluacion SET ponderacion_parcial=? WHERE id=?');
            foreach($aw as $id=>$weight) $u->execute([$weight,$id]);
            $this->db->commit();
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $e;
        }
    }

}
