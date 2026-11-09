<?php
declare(strict_types=1);

namespace App\Repositories;

use PDO;

/** Consultas de diagnóstico de evaluación. Sin escrituras. */
final class EvaluationRepository
{
    public function __construct(private PDO $db) {}

    /** Secciones y asignación histórica de su esquema. */
    public function sectionAssignments(): array
    {
        return $this->db->query(
            "SELECT s.id, s.codigo, s.nombre, s.fecha_apertura, s.activo,
                    p.nombre AS periodo, a.nombre AS asignatura,
                    es.nombre AS estado_seccion, see.id AS asignacion_id,
                    see.esquema_version_id, see.bloqueado, see.fecha_asignacion,
                    ev.numero_version, ee.nombre AS esquema_nombre
             FROM secciones s
             JOIN ofertas_academicas o ON o.id=s.oferta_academica_id
             JOIN periodos_academicos p ON p.id=o.periodo_academico_id
             JOIN malla_asignaturas ma ON ma.id=s.malla_asignatura_id
             JOIN asignaturas a ON a.id=ma.asignatura_id
             JOIN estados_seccion es ON es.id=s.estado_seccion_id
             LEFT JOIN seccion_esquema_evaluacion see ON see.seccion_id=s.id
             LEFT JOIN esquema_evaluacion_versiones ev ON ev.id=see.esquema_version_id
             LEFT JOIN esquemas_evaluacion ee ON ee.id=ev.esquema_evaluacion_id
             WHERE s.deleted_at IS NULL
             ORDER BY p.fecha_inicio DESC, a.nombre, s.codigo, s.id
             LIMIT 300"
        )->fetchAll(PDO::FETCH_ASSOC);
    }

    /** Únicamente versiones publicadas vigentes hoy, sin alterar las históricas. */
    public function assignableVersions(): array
    {
        return $this->db->query(
            "SELECT v.id, v.numero_version, e.nombre AS esquema_nombre, v.vigente_desde
             FROM esquema_evaluacion_versiones v
             JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
             JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id
             WHERE st.codigo='PUBLICADO' AND st.activo=1
               AND e.deleted_at IS NULL AND e.activo=1
               AND v.vigente_desde<=CURDATE()
               AND (v.vigente_hasta IS NULL OR v.vigente_hasta>=CURDATE())
             ORDER BY e.nombre,v.numero_version DESC"
        )->fetchAll(PDO::FETCH_ASSOC);
    }

    /** Asignación inicial única, atómica e inmutable. No sincroniza Moodle. */
    public function assignVersionToSection(int $sectionId, int $versionId, int $actor): void
    {
        if ($sectionId<=0 || $versionId<=0 || $actor<=0) {
            throw new \InvalidArgumentException('Sección, versión o usuario inválido.');
        }
        $this->db->beginTransaction();
        try {
            $q=$this->db->prepare(
                'SELECT s.id,s.activo,s.deleted_at,s.fecha_apertura,o.activo AS oferta_activa '
                .'FROM secciones s JOIN ofertas_academicas o ON o.id=s.oferta_academica_id '
                .'WHERE s.id=? FOR UPDATE'
            );
            $q->execute([$sectionId]);
            $section=$q->fetch(PDO::FETCH_ASSOC);
            if (!$section || (int)$section['activo']!==1 || $section['deleted_at']!==null
                || (int)$section['oferta_activa']!==1) {
                throw new \RuntimeException('La sección no está activa o disponible.');
            }
            if ($section['fecha_apertura']!==null && strtotime((string)$section['fecha_apertura'])<=time()) {
                throw new \RuntimeException('La sección ya inició; su esquema debe revisarse antes de asignar.');
            }
            $q=$this->db->prepare('SELECT id FROM seccion_esquema_evaluacion WHERE seccion_id=? FOR UPDATE');
            $q->execute([$sectionId]);
            if ($q->fetchColumn()) throw new \RuntimeException('Esta sección ya tiene un esquema asignado.');
            $q=$this->db->prepare(
                "SELECT v.id FROM esquema_evaluacion_versiones v
                 JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id
                 JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id
                 WHERE v.id=? AND st.codigo='PUBLICADO' AND st.activo=1
                   AND e.activo=1 AND e.deleted_at IS NULL
                   AND v.vigente_desde<=CURDATE()
                   AND (v.vigente_hasta IS NULL OR v.vigente_hasta>=CURDATE()) FOR UPDATE"
            );
            $q->execute([$versionId]);
            if (!$q->fetchColumn()) throw new \RuntimeException('Selecciona una versión publicada y vigente.');
            $q=$this->db->prepare(
                'INSERT INTO seccion_esquema_evaluacion '
                .'(seccion_id,esquema_version_id,asignado_por_usuario_id,bloqueado,fecha_bloqueo,observacion) '
                .'VALUES (?,?,?,1,NOW(),?)'
            );
            $q->execute([$sectionId,$versionId,$actor,'Asignación inicial bloqueada para preservar el historial académico']);
            $this->db->commit();
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $e;
        }
    }

    /** Reasignación excepcional TICs: denegar ante cualquier evidencia académica o vinculación. */
    public function reassignVersionToSection(int $sectionId,int $versionId,int $actor,string $reason): void
    {
        if ($sectionId<=0 || $versionId<=0 || $actor<=0 || mb_strlen($reason)<15 || mb_strlen($reason)>1000) {
            throw new \InvalidArgumentException('Sección, versión o usuario inválido; el motivo debe tener entre 15 y 1000 caracteres.');
        }
        $this->db->beginTransaction();
        try {
            $q=$this->db->prepare('SELECT s.id,s.activo,s.deleted_at,o.activo AS oferta_activa FROM secciones s JOIN ofertas_academicas o ON o.id=s.oferta_academica_id WHERE s.id=? FOR UPDATE');
            $q->execute([$sectionId]); $section=$q->fetch(PDO::FETCH_ASSOC);
            if (!$section || (int)$section['activo']!==1 || $section['deleted_at']!==null || (int)$section['oferta_activa']!==1) throw new \RuntimeException('La sección u oferta no está activa.');
            $q=$this->db->prepare('SELECT id,esquema_version_id FROM seccion_esquema_evaluacion WHERE seccion_id=? FOR UPDATE');
            $q->execute([$sectionId]); $old=$q->fetch(PDO::FETCH_ASSOC);
            if (!$old) throw new \RuntimeException('La sección no tiene una asignación previa.');
            if ((int)$old['esquema_version_id']===$versionId) throw new \RuntimeException('La versión seleccionada ya está asignada.');
            $q=$this->db->prepare("SELECT v.id FROM esquema_evaluacion_versiones v JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE v.id=? AND st.codigo='PUBLICADO' AND st.activo=1 AND e.activo=1 AND e.deleted_at IS NULL AND v.vigente_desde<=CURDATE() AND (v.vigente_hasta IS NULL OR v.vigente_hasta>=CURDATE()) FOR UPDATE");
            $q->execute([$versionId]); if (!$q->fetchColumn()) throw new \RuntimeException('La nueva versión debe estar publicada y vigente hoy.');
            // Política conservadora: bloquear incluso ante recursos creados, vínculos, notas o cierres.
            $checks=[
                'SELECT 1 FROM recursos_evaluables WHERE seccion_id=? LIMIT 1',
                'SELECT 1 FROM recurso_parametro_evaluacion WHERE seccion_id=? LIMIT 1',
                'SELECT 1 FROM calificaciones_recursos cr JOIN recursos_evaluables r ON r.id=cr.recurso_id WHERE r.seccion_id=? LIMIT 1',
                'SELECT 1 FROM resultados_parciales_estudiante rp JOIN matricula_asignaturas ma ON ma.id=rp.matricula_asignatura_id WHERE ma.seccion_id=? LIMIT 1',
                'SELECT 1 FROM resultados_finales_asignatura rf JOIN matricula_asignaturas ma ON ma.id=rf.matricula_asignatura_id WHERE ma.seccion_id=? LIMIT 1',
                'SELECT 1 FROM cierre_parcial_seccion WHERE seccion_id=? LIMIT 1',
            ];
            foreach($checks as $sql){$q=$this->db->prepare($sql);$q->execute([$sectionId]);if($q->fetchColumn())throw new \RuntimeException('Reasignación bloqueada: existen recursos, vinculaciones, calificaciones, resultados o cierres académicos.');}
            $q=$this->db->prepare('INSERT INTO historial_reasignacion_esquema_tics (seccion_id,asignacion_id,version_anterior_id,version_nueva_id,usuario_tics_id,motivo) VALUES (?,?,?,?,?,?)');
            $q->execute([$sectionId,(int)$old['id'],(int)$old['esquema_version_id'],$versionId,$actor,$reason]);
            $q=$this->db->prepare('UPDATE seccion_esquema_evaluacion SET esquema_version_id=?,asignado_por_usuario_id=?,fecha_asignacion=NOW(),bloqueado=1,fecha_bloqueo=NOW(),observacion=? WHERE id=?');
            $q->execute([$versionId,$actor,'Reasignación excepcional TICs. Consultar historial de auditoría.',(int)$old['id']]);
            $this->db->commit();
        }catch(\Throwable $e){if($this->db->inTransaction())$this->db->rollBack();throw $e;}
    }

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

    public function publicationMinimum(int $schemaId,int $excludeId): ?string
    {
        $q=$this->db->prepare("SELECT MAX(v.vigente_desde) FROM esquema_evaluacion_versiones v JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id WHERE v.esquema_evaluacion_id=? AND v.id<>? AND st.codigo='PUBLICADO'");
        $q->execute([$schemaId,$excludeId]);$date=$q->fetchColumn();
        return $date ? (new \DateTimeImmutable((string)$date))->modify('+1 day')->format('Y-m-d') : null;
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


    /** Configura parámetros exclusivamente en una versión BORRADOR; no modifica notas. */
    public function configureDraft(int $versionId, string $operation, array $data): void
    {
        if ($versionId <= 0) throw new \InvalidArgumentException('Versión inválida.');
        $this->db->beginTransaction();
        try {
            $q=$this->db->prepare("SELECT v.id FROM esquema_evaluacion_versiones v JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id WHERE v.id=? AND st.codigo='BORRADOR' AND st.permite_edicion=1 AND st.es_publicado=0 FOR UPDATE");
            $q->execute([$versionId]);
            if (!$q->fetchColumn()) throw new \RuntimeException('Solo se pueden configurar versiones en borrador.');
            $partialId=(int)($data['parcial_id']??0);
            if ($operation==='plantilla') {
                $type=(string)($data['tipo']??'');
                $templates=[
                    'PRACTICAS'=>[['NOTA_TUTOR_EMPRESARIAL','NOTA TUTOR EMPRESARIAL',50],['NOTA_TUTOR_ACADEMICO','NOTA TUTOR ACADÉMICO',50]],
                    'VINCULACION'=>[['NOTA_APROBATORIA','Nota Aprobatoria',100]],
                ];
                if (!isset($templates[$type])) throw new \InvalidArgumentException('Plantilla no válida.');
                $q=$this->db->prepare('SELECT COUNT(*) FROM seccion_esquema_evaluacion WHERE esquema_version_id=?');$q->execute([$versionId]);
                if ((int)$q->fetchColumn()>0) throw new \RuntimeException('No se puede sustituir una versión asignada a secciones.');
                // Borrador aislado: crear el nuevo parcial antes de eliminar los anteriores.
                $q=$this->db->prepare('SELECT id FROM parciales_evaluacion WHERE esquema_version_id=? FOR UPDATE');$q->execute([$versionId]);$oldIds=array_map('intval',$q->fetchAll(PDO::FETCH_COLUMN));
                $q=$this->db->prepare('DELETE FROM parametros_evaluacion WHERE parcial_id=?');
                foreach($oldIds as $id)$q->execute([$id]);
                $q=$this->db->prepare('DELETE FROM parciales_evaluacion WHERE id=?');foreach($oldIds as $id)$q->execute([$id]);
                $q=$this->db->prepare('INSERT INTO parciales_evaluacion (esquema_version_id,codigo,nombre,ponderacion_nota_final,orden_visual,activo) VALUES (?,?,?,?,?,1)');
                $q->execute([$versionId,'UNICO','EVALUACIÓN ÚNICA',100,1]);$partialId=(int)$this->db->lastInsertId();
                $q=$this->db->prepare('INSERT INTO parametros_evaluacion (parcial_id,codigo,nombre,ponderacion_parcial,orden_visual,modificable_al_evaluar,activo) VALUES (?,?,?,?,?,0,1)');
                foreach($templates[$type] as $i=>$row)$q->execute([$partialId,$row[0],$row[1],$row[2],$i+1]);
            } else {
                $q=$this->db->prepare('SELECT id FROM parciales_evaluacion WHERE id=? AND esquema_version_id=? FOR UPDATE');$q->execute([$partialId,$versionId]);
                if (!$q->fetchColumn()) throw new \InvalidArgumentException('Parcial ajeno a la versión.');
                $id=(int)($data['parametro_id']??0);
                if ($operation==='guardar') {
                    $name=trim((string)($data['nombre']??''));
                    $code=strtoupper(trim((string)($data['codigo']??'')));
                    $weight=(string)($data['ponderacion']??'');
                    if ($name==='' || mb_strlen($name)>220 || !preg_match('/^[A-Z0-9_]{2,100}$/D',$code) || !preg_match('/^\d{1,3}(?:\.\d{1,2})?$/D',$weight) || (float)$weight<=0 || (float)$weight>100) throw new \InvalidArgumentException('Nombre, código o ponderación inválidos.');
                    if ($id>0) {
                        $q=$this->db->prepare('UPDATE parametros_evaluacion SET nombre=?,codigo=?,ponderacion_parcial=? WHERE id=? AND parcial_id=?');
                        $q->execute([$name,$code,$weight,$id,$partialId]);
                        if (!$q->rowCount()) { $q=$this->db->prepare('SELECT id FROM parametros_evaluacion WHERE id=? AND parcial_id=?');$q->execute([$id,$partialId]);if (!$q->fetchColumn())throw new \RuntimeException('Parámetro inexistente.'); }
                    } else {
                        $q=$this->db->prepare('SELECT COALESCE(MAX(orden_visual),0)+1 FROM parametros_evaluacion WHERE parcial_id=?');$q->execute([$partialId]);$order=(int)$q->fetchColumn();
                        $q=$this->db->prepare('INSERT INTO parametros_evaluacion (parcial_id,codigo,nombre,ponderacion_parcial,orden_visual,modificable_al_evaluar,activo) VALUES (?,?,?,?,?,0,1)');$q->execute([$partialId,$code,$name,$weight,$order]);
                    }
                } elseif ($operation==='estado') {
                    $q=$this->db->prepare('UPDATE parametros_evaluacion SET activo=IF(activo=1,0,1) WHERE id=? AND parcial_id=?');$q->execute([$id,$partialId]);
                    if (!$q->rowCount())throw new \RuntimeException('Parámetro inexistente.');
                } else throw new \InvalidArgumentException('Operación desconocida.');
            }
            $this->db->commit();
        } catch (\Throwable $e) {if($this->db->inTransaction())$this->db->rollBack();throw $e;}
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

    /** Publicación atómica: valida P1/P2, archiva la versión anterior y registra auditoría. */
    public function publishDraft(int $versionId, int $actor): void
    {
        if ($versionId <= 0 || $actor <= 0) {
            throw new \InvalidArgumentException('Versión o usuario inválido.');
        }
        $this->db->beginTransaction();
        try {
            $q = $this->db->prepare(
                'SELECT v.*, st.codigo AS estado_codigo FROM esquema_evaluacion_versiones v '
                . 'JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id '
                . 'WHERE v.id=? FOR UPDATE'
            );
            $q->execute([$versionId]);
            $version = $q->fetch(PDO::FETCH_ASSOC);
            if (!$version || $version['estado_codigo'] !== 'BORRADOR') {
                throw new \RuntimeException('Solo se pueden publicar versiones en BORRADOR.');
            }
            // Bloquear el esquema padre para serializar publicaciones concurrentes.
            $q = $this->db->prepare('SELECT id FROM esquemas_evaluacion WHERE id=? AND deleted_at IS NULL FOR UPDATE');
            $q->execute([(int)$version['esquema_evaluacion_id']]);
            if (!$q->fetchColumn()) throw new \RuntimeException('El esquema no está disponible.');

            $q = $this->db->prepare('SELECT id,codigo,activo,ponderacion_nota_final FROM parciales_evaluacion WHERE esquema_version_id=? FOR UPDATE');
            $q->execute([$versionId]);
            $partials = $q->fetchAll(PDO::FETCH_ASSOC);
            $active = array_values(array_filter($partials, static fn($p) => (int)$p['activo'] === 1));
            $single=count($active)===1 && strtoupper(trim((string)$active[0]['codigo']))==='UNICO' && abs((float)$active[0]['ponderacion_nota_final']-100)<0.001;
            if (!$single && count($active)!==2) throw new \RuntimeException('Se requiere P1/P2 al 50 % o evaluación única al 100 %.');
            $codes = [];
            foreach ($active as $partial) {
                $code = strtoupper(trim((string)$partial['codigo']));
                if (!$single && (!in_array($code, ['P1','P2'], true) || isset($codes[$code]) || abs((float)$partial['ponderacion_nota_final'] - 50.0) > 0.001)) {
                    throw new \RuntimeException('P1 y P2 deben tener una ponderación de 50 % cada uno.');
                }
                $codes[$code] = true;
                $q = $this->db->prepare('SELECT activo,ponderacion_parcial FROM parametros_evaluacion WHERE parcial_id=? FOR UPDATE');
                $q->execute([(int)$partial['id']]);
                $params = array_values(array_filter($q->fetchAll(PDO::FETCH_ASSOC), static fn($p) => (int)$p['activo'] === 1));
                $sum = array_sum(array_map(static fn($p) => (float)$p['ponderacion_parcial'], $params));
                if (!$params || abs($sum - 100.0) > 0.001) {
                    throw new \RuntimeException('Los parámetros activos de cada parcial deben sumar exactamente 100 %.');
                }
            }
            $q = $this->db->query("SELECT id,codigo FROM estados_esquema_evaluacion WHERE codigo IN ('PUBLICADO','HISTORICO') AND activo=1 FOR UPDATE");
            $states = [];
            foreach ($q->fetchAll(PDO::FETCH_ASSOC) as $state) $states[$state['codigo']] = (int)$state['id'];
            if (empty($states['PUBLICADO']) || empty($states['HISTORICO'])) throw new \RuntimeException('Faltan estados PUBLICADO o HISTORICO.');

            // No se permite retroceder la vigencia respecto de una versión ya publicada.
            $q = $this->db->prepare('SELECT v.id,v.vigente_desde FROM esquema_evaluacion_versiones v '
                . 'JOIN estados_esquema_evaluacion st ON st.id=v.estado_esquema_id '
                . "WHERE v.esquema_evaluacion_id=? AND st.codigo='PUBLICADO' AND v.id<>? FOR UPDATE");
            $q->execute([(int)$version['esquema_evaluacion_id'], $versionId]);
            $previous = $q->fetchAll(PDO::FETCH_ASSOC);
            if (count($previous) > 1) throw new \RuntimeException('Existen varias versiones publicadas; revisar antes de continuar.');
            $start = (string)$version['vigente_desde'];
            if ($previous) {
                if ($start <= (string)$previous[0]['vigente_desde']) {
                    throw new \RuntimeException('La nueva vigencia debe ser posterior al inicio de la versión publicada.');
                }
                $end = (new \DateTimeImmutable($start))->modify('-1 day')->format('Y-m-d');
                $q = $this->db->prepare('UPDATE esquema_evaluacion_versiones SET estado_esquema_id=?, vigente_hasta=? WHERE id=?');
                $q->execute([$states['HISTORICO'], $end, (int)$previous[0]['id']]);
            }
            $q = $this->db->prepare('UPDATE esquema_evaluacion_versiones SET estado_esquema_id=?, publicado_por_usuario_id=?, fecha_publicacion=NOW(), vigente_hasta=NULL WHERE id=?');
            $q->execute([$states['PUBLICADO'], $actor, $versionId]);
            $this->db->commit();
        } catch (\Throwable $e) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $e;
        }
    }

}
