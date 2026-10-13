<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use RuntimeException;
use Throwable;

final class AcademicEnrollmentRepository
{
    public function __construct(private PDO $db) {}
    public function searchStudents(string $q): array
    {
        $q = trim($q);

        if ($q === '') {
            return [];
        }

        $sql = "
        SELECT
            e.id,
            e.codigo_estudiante,
            p.numero_identificacion,
            CONCAT_WS(
                ' ',
                p.primer_nombre,
                p.segundo_nombre,
                p.primer_apellido,
                p.segundo_apellido
            ) AS nombre,
            (
                SELECT COUNT(*)
                FROM estudiante_carreras ec
                WHERE ec.estudiante_id = e.id
                  AND ec.activo = 1
                  AND ec.deleted_at IS NULL
            ) AS trayectorias
        FROM estudiantes e
        INNER JOIN personas p
            ON p.id = e.persona_id
        WHERE e.deleted_at IS NULL
          AND (
                p.numero_identificacion LIKE :q1
                OR e.codigo_estudiante LIKE :q2
                OR CONCAT_WS(
                    ' ',
                    p.primer_nombre,
                    p.segundo_nombre,
                    p.primer_apellido,
                    p.segundo_apellido
                ) LIKE :q3
          )
        ORDER BY
            p.primer_apellido ASC,
            p.segundo_apellido ASC,
            p.primer_nombre ASC,
            p.segundo_nombre ASC
        LIMIT 50
    ";

        $stmt = $this->db->prepare($sql);

        $like = '%' . $q . '%';

        $stmt->execute([
            'q1' => $like,
            'q2' => $like,
            'q3' => $like,
        ]);

        return $stmt->fetchAll();
    }
    public function student(int $id): ?array
    {
        $s = $this->db->prepare(
            "SELECT e.id,e.codigo_estudiante,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre FROM estudiantes e JOIN personas p ON p.id=e.persona_id 
            WHERE e.id=:id 
            AND e.deleted_at IS NULL
            "
        );
        $s->execute(['id' => $id]);
        return $s->fetch() ?: null;
    }
    public function trajectories(int $student): array
    {
        $s = $this->db->prepare(
            "SELECT ec.id,ec.carrera_id,ec.malla_id,ec.sede_id,ec.modalidad_academica_id,ec.nivel_referencial_id,ec.activo,c.nombre carrera,m.codigo malla_codigo,m.nombre malla,et.codigo estado_codigo,et.nombre estado,et.permite_matricula,se.nombre sede,mo.nombre modalidad,n.nombre nivel,
            (SELECT COUNT(*) FROM bloqueos_academicos b 
            JOIN estados_bloqueo_academico eb ON eb.id=b.estado_bloqueo_id 
            JOIN tipos_bloqueo_academico tb ON tb.id=b.tipo_bloqueo_id 
            WHERE b.estudiante_carrera_id=ec.id 
            AND b.activo=1 AND eb.codigo='ACTIVO' 
            AND tb.bloquea_matricula_carrera=1) bloqueos 
            FROM estudiante_carreras ec 
            JOIN carreras c ON c.id=ec.carrera_id 
            JOIN mallas_curriculares m ON m.id=ec.malla_id 
            JOIN estados_trayectoria_academica et ON et.id=ec.estado_trayectoria_id 
            LEFT JOIN sedes se ON se.id=ec.sede_id 
            LEFT JOIN modalidades_academicas mo ON mo.id=ec.modalidad_academica_id 
            LEFT JOIN niveles_academicos n ON n.id=ec.nivel_referencial_id 
            WHERE ec.estudiante_id=:e 
            AND ec.deleted_at IS NULL 
            ORDER BY ec.activo DESC,ec.fecha_inicio DESC,ec.id DESC
            "
        );
        $s->execute(['e' => $student]);
        return $s->fetchAll();
    }
    public function trajectory(int $id): ?array
    {
        $s = $this->db->prepare(
            "SELECT ec.*,e.codigo_estudiante,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) estudiante,c.nombre carrera,m.codigo malla_codigo,m.nombre malla,et.codigo estado_codigo,et.nombre estado,et.permite_matricula,se.nombre sede,mo.nombre modalidad 
            FROM estudiante_carreras ec 
            JOIN estudiantes e ON e.id=ec.estudiante_id 
            JOIN personas p ON p.id=e.persona_id 
            JOIN carreras c ON c.id=ec.carrera_id 
            JOIN mallas_curriculares m ON m.id=ec.malla_id 
            JOIN estados_trayectoria_academica et ON et.id=ec.estado_trayectoria_id 
            LEFT JOIN sedes se ON se.id=ec.sede_id 
            LEFT JOIN modalidades_academicas mo ON mo.id=ec.modalidad_academica_id 
            WHERE ec.id=:id 
            AND ec.deleted_at IS NULL"
        );
        $s->execute(['id' => $id]);
        return $s->fetch() ?: null;
    }
    public function compatibleOffers(int $trajectory): array
    {
        $t = $this->trajectory($trajectory);
        if (!$t) return [];
        $s = $this->db->prepare(
            "SELECT o.id,o.codigo,o.nombre,p.id periodo_id,p.codigo periodo_codigo,p.nombre periodo,p.fecha_inicio,p.fecha_fin,p.fecha_inicio_matricula,p.fecha_fin_matricula,eo.codigo estado_codigo,eo.nombre estado,eo.permite_matricula,s.nombre sede,mo.nombre modalidad,
            (SELECT COUNT(*) FROM secciones x JOIN estados_seccion ex ON ex.id=x.estado_seccion_id 
            WHERE x.oferta_academica_id=o.id 
            AND x.activo=1 
            AND x.deleted_at IS NULL 
            AND x.permite_matricula=1 
            AND ex.permite_matricula=1) secciones_disponibles,
            (SELECT m.id FROM matriculas m
            JOIN estados_matricula emx ON emx.id=m.estado_matricula_id
            WHERE m.estudiante_carrera_id=:t1
            AND m.periodo_academico_id=o.periodo_academico_id
            AND m.activo=1
            AND emx.codigo<>'ANULADA'
            ORDER BY m.id DESC LIMIT 1) matricula_existente 
            FROM ofertas_academicas o 
            JOIN periodos_academicos p ON p.id=o.periodo_academico_id 
            JOIN estados_oferta_academica eo ON eo.id=o.estado_oferta_id 
            JOIN estados_periodo_academico ep ON ep.id=p.estado_periodo_id
            LEFT JOIN sedes s ON s.id=o.sede_id 
            LEFT JOIN modalidades_academicas mo ON mo.id=o.modalidad_academica_id 
            WHERE o.activo=1
            AND p.activo=1 AND p.deleted_at IS NULL
            AND eo.permite_matricula=1
            AND ep.permite_matricula=1
            AND (p.fecha_inicio_matricula IS NULL OR CURDATE()>=p.fecha_inicio_matricula)
            AND (p.fecha_fin_matricula IS NULL OR CURDATE()<=p.fecha_fin_matricula)
            AND o.carrera_id=:c
            AND o.malla_id=:m 
            AND (o.sede_id IS NULL OR o.sede_id=:s) 
            AND (o.modalidad_academica_id IS NULL OR o.modalidad_academica_id=:mo) 
            ORDER BY p.fecha_inicio DESC,o.id DESC
            "
        );
        $s->execute(['t1' => $trajectory, 'c' => $t['carrera_id'], 'm' => $t['malla_id'], 's' => $t['sede_id'], 'mo' => $t['modalidad_academica_id']]);
        return $s->fetchAll();
    }
    private function approvedEvidence(int $trajectory, int $mallaAsignatura): ?array
    {
        $s = $this->db->prepare(
            "SELECT ma.id,ema.codigo estado,mas.asignatura_id,COALESCE(qn.nota_final,hia.nota_final) nota 
            FROM malla_asignaturas target 
            JOIN malla_asignaturas mas ON mas.asignatura_id=target.asignatura_id 
            JOIN matricula_asignaturas ma ON ma.malla_asignatura_id=mas.id 
            JOIN matriculas m ON m.id=ma.matricula_id 
            JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id 
            LEFT JOIN migracion_q10_historico_notas qn ON qn.matricula_asignatura_id=ma.id AND qn.estado='IMPORTADO' 
            LEFT JOIN historial_intentos_asignatura hia ON hia.matricula_asignatura_id=ma.id 
            WHERE target.id=:ma 
            AND m.estudiante_carrera_id=:t 
            AND ma.activo=1 
            AND (ema.codigo IN('APROBADA','RECONOCIDA') OR qn.nota_final>=7 OR hia.resultado IN('APROBADA','RECONOCIDA') OR hia.nota_final>=7) 
            ORDER BY ma.id DESC LIMIT 1"
        );
        $s->execute(['ma' => $mallaAsignatura, 't' => $trajectory]);
        $r = $s->fetch();
        if ($r) return ['source' => 'HISTORIAL', 'ref' => (int)$r['id'], 'detail' => $r['estado'] . ($r['nota'] !== null ? ' · nota ' . $r['nota'] : '')];
        $s = $this->db->prepare(
            "SELECT cmr.id FROM cambio_malla_reconocimientos cmr 
            JOIN solicitudes_cambio_malla sc ON sc.id=cmr.solicitud_cambio_malla_id 
            WHERE sc.estudiante_carrera_id=:t 
            AND cmr.malla_asignatura_destino_id=:ma 
            AND cmr.aprobado=1 
            ORDER BY cmr.id DESC LIMIT 1"
        );
        $s->execute(['t' => $trajectory, 'ma' => $mallaAsignatura]);
        $id = $s->fetchColumn();
        return $id ? ['source' => 'RECONOCIMIENTO', 'ref' => (int)$id, 'detail' => 'Reconocimiento de cambio de malla aprobado'] : null;
    }
    private function attemptInfo(int $trajectory, int $mallaAsignatura): array
    {
        $s = $this->db->prepare(
            "SELECT COALESCE(MAX(ma.numero_intento),0) max_intento,
                    SUM(CASE WHEN ema.codigo='REPROBADA' THEN 1 ELSE 0 END) reprobadas 
            FROM matricula_asignaturas ma 
            JOIN matriculas m ON m.id=ma.matricula_id
            JOIN estados_matricula em ON em.id=m.estado_matricula_id
            JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id 
            WHERE m.estudiante_carrera_id=:t 
            AND ma.malla_asignatura_id=:ma 
            AND ma.activo=1
            AND m.activo=1
            AND em.codigo IN('CONFIRMADA','EN_CURSO','FINALIZADA')
            AND ema.consume_intento=1"
        );
        $s->execute(['t' => $trajectory, 'ma' => $mallaAsignatura]);
        $r = $s->fetch() ?: ['max_intento' => 0, 'reprobadas' => 0];
        $next = max(1, (int)$r['max_intento'] + 1);
        return ['max' => (int)$r['max_intento'], 'reprobadas' => (int)$r['reprobadas'], 'next' => $next];
    }
    private function prerequisites(int $trajectory, int $target): array
    {
        $s = $this->db->prepare(
            "SELECT pr.prerrequisito_malla_asignatura_id,a.codigo,a.nombre 
            FROM malla_asignatura_prerrequisitos pr 
            JOIN malla_asignaturas ma ON ma.id=pr.prerrequisito_malla_asignatura_id 
            JOIN asignaturas a ON a.id=ma.asignatura_id 
            WHERE pr.malla_asignatura_id=:id 
            AND pr.activo=1 
            ORDER BY a.nombre"
        );
        $s->execute(['id' => $target]);
        $out = [];
        foreach ($s->fetchAll() as $r) {
            $ev = $this->approvedEvidence($trajectory, (int)$r['prerrequisito_malla_asignatura_id']);
            $r['cumplido'] = $ev !== null;
            $r['evidencia'] = $ev;
            $out[] = $r;
        }
        return $out;
    }
    public function proposal(int $trajectory, int $offer): array
    {
        $t = $this->trajectory($trajectory);
        if (!$t) throw new RuntimeException('Trayectoria no encontrada.');
        $q = $this->db->prepare(
            "SELECT o.*,eo.permite_matricula,p.nombre periodo,p.codigo periodo_codigo,p.fecha_inicio_matricula,p.fecha_fin_matricula,ep.permite_matricula periodo_permite_matricula,ep.nombre periodo_estado 
            FROM ofertas_academicas o 
            JOIN estados_oferta_academica eo ON eo.id=o.estado_oferta_id 
            JOIN periodos_academicos p ON p.id=o.periodo_academico_id
            JOIN estados_periodo_academico ep ON ep.id=p.estado_periodo_id
            WHERE o.id=:o 
            AND o.activo=1 AND p.activo=1 AND p.deleted_at IS NULL"
        );
        $q->execute(['o' => $offer]);
        $o = $q->fetch();
        if (!$o) throw new RuntimeException('Oferta no encontrada.');
        if ((int)$o['permite_matricula'] !== 1) {
            throw new RuntimeException(
                'La oferta académica seleccionada no se encuentra habilitada para matrícula.'
            );
        }
        if ((int)$o['periodo_permite_matricula'] !== 1) {
            throw new RuntimeException('El período académico no se encuentra en un estado que permita matrícula.');
        }
        $today = date('Y-m-d');
        if ($o['fecha_inicio_matricula'] !== null && $today < $o['fecha_inicio_matricula']) {
            throw new RuntimeException('La ventana de matrícula todavía no ha iniciado.');
        }
        if ($o['fecha_fin_matricula'] !== null && $today > $o['fecha_fin_matricula']) {
            throw new RuntimeException('La ventana de matrícula ya finalizó.');
        }
        if ((int)$o['carrera_id'] !== (int)$t['carrera_id'] || (int)$o['malla_id'] !== (int)$t['malla_id']) throw new RuntimeException('La oferta no corresponde a la carrera y malla de la trayectoria.');
        if ($o['sede_id'] !== null && $t['sede_id'] !== null && (int)$o['sede_id'] !== (int)$t['sede_id']) throw new RuntimeException('La sede de la oferta no coincide con la trayectoria.');
        if ($o['modalidad_academica_id'] !== null && $t['modalidad_academica_id'] !== null && (int)$o['modalidad_academica_id'] !== (int)$t['modalidad_academica_id']) throw new RuntimeException('La modalidad de la oferta no coincide con la trayectoria.');
        $s = $this->db->prepare(
            "SELECT ma.id malla_asignatura_id,ma.asignatura_id,a.codigo,a.nombre,n.nombre nivel,n.orden_nivel,ma.orden_en_nivel,ma.creditos,
            x.id seccion_id,x.codigo seccion_codigo,x.nombre seccion,pa.nombre paralelo,x.cupo_maximo,
            (SELECT COUNT(*) FROM matricula_asignaturas mx JOIN estados_matricula_asignatura ex ON ex.id=mx.estado_matricula_asignatura_id WHERE mx.seccion_id=x.id AND mx.activo=1 AND ex.codigo<>'ANULADA') ocupados 
            FROM malla_asignaturas ma 
            JOIN asignaturas a ON a.id=ma.asignatura_id 
            JOIN niveles_academicos n ON n.id=ma.nivel_academico_id 
            LEFT JOIN secciones x ON x.malla_asignatura_id=ma.id AND x.oferta_academica_id=:o AND x.activo=1 AND x.deleted_at IS NULL AND x.permite_matricula=1 AND EXISTS(SELECT 1 FROM estados_seccion es WHERE es.id=x.estado_seccion_id AND es.permite_matricula=1) 
            LEFT JOIN paralelos pa ON pa.id=x.paralelo_id 
            WHERE ma.malla_id=:m AND ma.activa=1 
            ORDER BY n.orden_nivel,ma.orden_en_nivel,a.nombre,x.id"
        );
        $s->execute(['o' => $offer, 'm' => $t['malla_id']]);
        $rows = $s->fetchAll();
        $priorStmt = $this->db->prepare("SELECT COUNT(*) FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id WHERE m.estudiante_carrera_id=:t AND m.activo=1 AND em.codigo IN('CONFIRMADA','EN_CURSO','FINALIZADA')");
        $priorStmt->execute(['t' => $trajectory]);
        $isInitial = (int)$priorStmt->fetchColumn() === 0;
        $referenceOrder = null;
        if ($t['nivel_referencial_id'] !== null) {
            $nr = $this->db->prepare("SELECT orden_nivel FROM niveles_academicos WHERE id=:id LIMIT 1");
            $nr->execute(['id' => $t['nivel_referencial_id']]);
            $value = $nr->fetchColumn();
            $referenceOrder = $value !== false ? (int)$value : null;
        }
        $subjects = [];
        foreach ($rows as $r) {
            $id = (int)$r['malla_asignatura_id'];
            if (!isset($subjects[$id])) {
                $approved = $this->approvedEvidence($trajectory, $id);
                $attempt = $this->attemptInfo($trajectory, $id);
                $pre = $this->prerequisites($trajectory, $id);
                $allPre = !array_filter($pre, fn($x) => !$x['cumplido']);
                $higherInitialLevel = $isInitial && $referenceOrder !== null && (int)$r['orden_nivel'] > $referenceOrder;
                $blocked = $approved !== null || $attempt['next'] > 3 || !$allPre || $higherInitialLevel || !(bool)$t['permite_matricula'] || (int)$t['activo'] !== 1;
                $reason = $approved ? 'Asignatura ya aprobada/reconocida'
                    : ($attempt['next'] > 3 ? 'Límite de 3 intentos alcanzado'
                    : (!$allPre ? 'Prerrequisitos pendientes'
                    : ($higherInitialLevel ? 'Nivel superior al nivel referencial de una matrícula inicial'
                    : (!(bool)$t['permite_matricula'] ? 'La trayectoria no permite matrícula'
                    : ((int)$t['activo'] !== 1 ? 'Trayectoria inactiva' : '')))));
                $subjects[$id] = ['malla_asignatura_id' => $id, 'codigo' => $r['codigo'], 'nombre' => $r['nombre'], 'nivel' => $r['nivel'], 'orden_nivel' => $r['orden_nivel'], 'creditos' => $r['creditos'], 'approved' => $approved, 'attempt' => $attempt, 'prerequisites' => $pre, 'eligible' => !$blocked, 'reason' => $reason, 'pending' => $attempt['max'] > 0 && !$approved, 'sections' => []];
            }
            if ($r['seccion_id']) {
                $available = $r['cupo_maximo'] === null || (int)$r['ocupados'] < (int)$r['cupo_maximo'];
                $subjects[$id]['sections'][] = ['id' => (int)$r['seccion_id'], 'codigo' => $r['seccion_codigo'], 'nombre' => $r['seccion'], 'paralelo' => $r['paralelo'], 'cupo_maximo' => $r['cupo_maximo'], 'ocupados' => (int)$r['ocupados'], 'available' => $available];
            }
        }
        foreach ($subjects as &$x) {
            if ($x['eligible'] && !array_filter($x['sections'], fn($s) => $s['available'])) {
                $x['eligible'] = false;
                $x['reason'] = 'No existe una sección disponible con cupo';
            }
        }
        unset($x);
        return ['trajectory' => $t, 'offer' => $o, 'subjects' => array_values($subjects)];
    }
    public function enrollment(int $id): ?array
    {
        $s = $this->db->prepare(
            "SELECT m.*,em.codigo estado_codigo,em.nombre estado,tm.nombre tipo,p.nombre periodo,o.nombre oferta,ec.estudiante_id,CONCAT_WS(' ',pe.primer_nombre,pe.segundo_nombre,pe.primer_apellido,pe.segundo_apellido) estudiante,c.nombre carrera,mc.nombre malla 
            FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id 
            JOIN tipos_matricula tm ON tm.id=m.tipo_matricula_id 
            JOIN periodos_academicos p ON p.id=m.periodo_academico_id 
            JOIN ofertas_academicas o ON o.id=m.oferta_academica_id 
            JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id 
            JOIN estudiantes e ON e.id=ec.estudiante_id 
            JOIN personas pe ON pe.id=e.persona_id 
            JOIN carreras c ON c.id=ec.carrera_id 
            JOIN mallas_curriculares mc ON mc.id=ec.malla_id 
            WHERE m.id=:id"
        );
        $s->execute(['id' => $id]);
        return $s->fetch() ?: null;
    }
    public function enrollmentSubjects(int $id): array
    {
        $s = $this->db->prepare(
            "SELECT ma.*,a.codigo,a.nombre,n.nombre nivel,x.codigo seccion_codigo,x.nombre seccion,ema.codigo estado_codigo,ema.nombre estado 
            FROM matricula_asignaturas ma 
            JOIN malla_asignaturas mas ON mas.id=ma.malla_asignatura_id 
            JOIN asignaturas a ON a.id=mas.asignatura_id 
            JOIN niveles_academicos n ON n.id=mas.nivel_academico_id 
            JOIN secciones x ON x.id=ma.seccion_id 
            JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id 
            WHERE ma.matricula_id=:m AND ma.activo=1 
            ORDER BY n.orden_nivel,mas.orden_en_nivel,a.nombre"
        );
        $s->execute(['m' => $id]);
        return $s->fetchAll();
    }
    public function createDraft(int $trajectory, int $offer, array $selected, int $actor): int
    {
        $p = $this->proposal($trajectory, $offer);
        $eligible = [];
        foreach ($p['subjects'] as $x) if ($x['eligible']) $eligible[(int)$x['malla_asignatura_id']] = $x;
        if (!$selected) throw new RuntimeException('Selecciona al menos una asignatura elegible.');
        $this->db->beginTransaction();
        try {
            // Bloquear las secciones elegidas evita sobreasignar cupos entre dos matrículas concurrentes.
            $sectionIds = array_values(array_unique(array_filter(array_map('intval', array_values($selected)))));
            if ($sectionIds) {
                $marks = implode(',', array_fill(0, count($sectionIds), '?'));
                $lock = $this->db->prepare("SELECT id FROM secciones WHERE id IN ($marks) FOR UPDATE");
                $lock->execute($sectionIds);
                if (count($lock->fetchAll()) !== count($sectionIds)) throw new RuntimeException('Una de las secciones seleccionadas ya no existe.');
            }
            // Revalidar oferta, ventana, secciones, cupos, prerrequisitos e intentos dentro de la transacción.
            $p = $this->proposal($trajectory, $offer);
            $eligible = [];
            foreach ($p['subjects'] as $x) if ($x['eligible']) $eligible[(int)$x['malla_asignatura_id']] = $x;
            $period = (int)$p['offer']['periodo_academico_id'];
            $q = $this->db->prepare("SELECT m.id FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id WHERE m.estudiante_carrera_id=:t AND m.periodo_academico_id=:p AND m.activo=1 AND em.codigo<>'ANULADA' ORDER BY m.id DESC LIMIT 1 FOR UPDATE");
            $q->execute(['t' => $trajectory, 'p' => $period]);
            $existing = (int)$q->fetchColumn();
            if ($existing) throw new RuntimeException('Ya existe una matrícula para esta trayectoria en el período seleccionado.');
            $typeCode = $this->db->prepare("SELECT COUNT(*) FROM matriculas WHERE estudiante_carrera_id=:t");
            $typeCode->execute(['t' => $trajectory]);
            $tipo = (int)$typeCode->fetchColumn() === 0 ? 'INICIAL' : 'RENOVACION';
            $type = $this->idByCode('tipos_matricula', $tipo);
            $state = $this->idByCode('estados_matricula', 'BORRADOR');
            $subjectState = $this->idByCode('estados_matricula_asignatura', 'MATRICULADA');
            $number = 'ORI-' . date('Ymd') . '-' . $trajectory . '-' . str_pad((string)random_int(1, 999999), 6, '0', STR_PAD_LEFT);
            $s = $this->db->prepare(
                "INSERT INTO matriculas(numero_matricula,estudiante_carrera_id,periodo_academico_id,oferta_academica_id,tipo_matricula_id,estado_matricula_id,fecha_solicitud,generada_automaticamente,creada_por_usuario_id,observacion,activo) 
                VALUES(:n,:t,:p,:o,:ti,:e,NOW(),1,:u,'Propuesta académica generada por Orion',1)"
            );
            $s->execute(['n' => $number, 't' => $trajectory, 'p' => $period, 'o' => $offer, 'ti' => $type, 'e' => $state, 'u' => $actor ?: null]);
            $mid = (int)$this->db->lastInsertId();
            if ($tipo === 'RENOVACION') {
                $prev = $this->db->prepare(
                    "SELECT m.id,m.periodo_academico_id 
                    FROM matriculas m 
                    JOIN periodos_academicos p ON p.id=m.periodo_academico_id 
                    WHERE m.estudiante_carrera_id=:t AND m.id<>:id AND p.fecha_inicio<(SELECT fecha_inicio FROM periodos_academicos WHERE id=:pd) 
                    ORDER BY p.fecha_inicio DESC,m.id DESC 
                    LIMIT 1"
                );
                $prev->execute(['t' => $trajectory, 'id' => $mid, 'pd' => $period]);
                $pr = $prev->fetch();
                if ($pr) {
                    $er = $this->db->prepare("SELECT id FROM estados_renovacion WHERE codigo='CALCULADA' AND activo=1 LIMIT 1");
                    $er->execute();
                    $erid = (int)$er->fetchColumn();
                    $nr = 'REN-' . date('Ymd') . '-' . $trajectory . '-' . str_pad((string)random_int(1, 999999), 6, '0', STR_PAD_LEFT);
                    $ri = $this->db->prepare(
                        "INSERT INTO renovaciones_matricula(numero_renovacion,estudiante_carrera_id,periodo_origen_id,periodo_destino_id,estado_renovacion_id,matricula_origen_id,matricula_destino_id,calculada_automaticamente,confirmada_manualmente,observacion) 
                        VALUES(:n,:t,:po,:pd,:e,:mo,:md,1,0,'Propuesta calculada por motor Orion')"
                    );
                    $ri->execute(['n' => $nr, 't' => $trajectory, 'po' => $pr['periodo_academico_id'], 'pd' => $period, 'e' => $erid, 'mo' => $pr['id'], 'md' => $mid]);
                    $rid = (int)$this->db->lastInsertId();
                    foreach ($p['subjects'] as $px) {
                        $ma = (int)$px['malla_asignatura_id'];
                        $sec = isset($selected[$ma]) ? (int)$selected[$ma] : null;
                        $rp = $this->db->prepare(
                            "INSERT INTO renovacion_asignaturas_propuestas(renovacion_id,malla_asignatura_id,seccion_propuesta_id,es_pendiente,prerrequisitos_cumplidos,bloqueada,motivo_bloqueo,incluir_en_matricula) 
                            VALUES(:r,:ma,:s,:pe,:pc,:b,:mot,:i)"
                        );
                        $rp->execute(['r' => $rid, 'ma' => $ma, 's' => $sec ?: null, 'pe' => $px['pending'] ? 1 : 0, 'pc' => !array_filter($px['prerequisites'], fn($z) => !$z['cumplido']) ? 1 : 0, 'b' => $px['eligible'] ? 0 : 1, 'mot' => $px['eligible'] ? null : $px['reason'], 'i' => $sec ? 1 : 0]);
                    }
                }
            }
            foreach ($selected as $ma => $section) {
                $ma = (int)$ma;
                $section = (int)$section;
                if (!$ma || !$section || !isset($eligible[$ma])) continue;
                $subject = $eligible[$ma];
                $valid = false;
                foreach ($subject['sections'] as $sec) if ((int)$sec['id'] === $section && $sec['available']) {
                    $valid = true;
                    break;
                }
                if (!$valid) throw new RuntimeException('Una de las secciones seleccionadas ya no está disponible.');
                $attempt = (int)$subject['attempt']['next'];
                $ins = $this->db->prepare(
                    "INSERT INTO matricula_asignaturas(matricula_id,seccion_id,malla_asignatura_id,estado_matricula_asignatura_id,numero_intento,materia_pendiente,reconocimiento_aplicado,creada_por_usuario_id,observacion,activo) 
                    VALUES(:m,:s,:ma,:e,:i,:pe,0,:u,'Propuesta de matrícula Orion',1)"
                );
                $ins->execute(['m' => $mid, 's' => $section, 'ma' => $ma, 'e' => $subjectState, 'i' => $attempt, 'pe' => $subject['pending'] ? 1 : 0, 'u' => $actor ?: null]);
                foreach ($subject['prerequisites'] as $pr) {
                    $vp = $this->db->prepare(
                        "INSERT INTO validacion_prerrequisitos_matricula(matricula_id,malla_asignatura_id,prerrequisito_malla_asignatura_id,cumplido,fuente_cumplimiento,referencia_id,detalle) 
                        VALUES(:m,:ma,:pr,:c,:f,:r,:d) 
                        ON DUPLICATE KEY UPDATE cumplido=VALUES(cumplido),fuente_cumplimiento=VALUES(fuente_cumplimiento),referencia_id=VALUES(referencia_id),detalle=VALUES(detalle)"
                    );
                    $vp->execute(['m' => $mid, 'ma' => $ma, 'pr' => $pr['prerrequisito_malla_asignatura_id'], 'c' => $pr['cumplido'] ? 1 : 0, 'f' => $pr['evidencia']['source'] ?? null, 'r' => $pr['evidencia']['ref'] ?? null, 'd' => $pr['evidencia']['detail'] ?? 'Prerrequisito no cumplido']);
                }
            }
            if (count($this->enrollmentSubjects($mid)) === 0) throw new RuntimeException('No se pudo agregar ninguna asignatura a la matrícula.');
            $h = $this->db->prepare(
                "INSERT INTO historial_estado_matricula(matricula_id,estado_anterior_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) 
                VALUES(:m,NULL,:e,'Borrador de matrícula creado desde motor académico Orion',:u)"
            );
            $h->execute(['m' => $mid, 'e' => $state, 'u' => $actor ?: null]);
            $this->db->commit();
            return $mid;
        } catch (Throwable $e) {
            $this->db->rollBack();
            throw $e;
        }
    }
    public function academicConfirm(int $id, int $actor): string
    {
        $m = $this->enrollment($id);
        if (!$m) throw new RuntimeException('Matrícula no encontrada.');
        if (!in_array($m['estado_codigo'], ['BORRADOR', 'PENDIENTE_VALIDACION', 'PENDIENTE_FINANCIERO'], true)) throw new RuntimeException('La matrícula ya no admite confirmación académica.');
        $subjects = $this->enrollmentSubjects($id);
        if (!$subjects) throw new RuntimeException('La matrícula no contiene asignaturas.');
        $s = $this->db->prepare(
            "SELECT eh.codigo,eh.habilita 
            FROM habilitaciones_matricula h 
            JOIN estados_habilitacion_matricula eh ON eh.id=h.estado_habilitacion_id 
            WHERE h.estudiante_carrera_id=:t AND h.periodo_academico_id=:p 
            LIMIT 1"
        );
        $s->execute(['t' => $m['estudiante_carrera_id'], 'p' => $m['periodo_academico_id']]);
        $fin = $s->fetch();
        $newCode = ($fin && (int)$fin['habilita'] === 1) ? 'CONFIRMADA' : 'PENDIENTE_FINANCIERO';
        $new = $this->idByCode('estados_matricula', $newCode);
        $old = (int)$m['estado_matricula_id'];
        $this->db->beginTransaction();
        try {
            if ($newCode === 'CONFIRMADA') {
                $u = $this->db->prepare("UPDATE matriculas SET estado_matricula_id=:e,fecha_confirmacion=NOW(),confirmada_por_usuario_id=:u WHERE id=:id");
            } else {
                $u = $this->db->prepare("UPDATE matriculas SET estado_matricula_id=:e,fecha_confirmacion=NULL,confirmada_por_usuario_id=:u WHERE id=:id");
            }
            $u->execute(['e' => $new, 'u' => $actor ?: null, 'id' => $id]);
            if ($newCode === 'CONFIRMADA') {
                $activeState = $this->db->prepare("SELECT id FROM estados_trayectoria_academica WHERE codigo='ACTIVA' AND activo=1 LIMIT 1");
                $activeState->execute();
                $activeId = (int)$activeState->fetchColumn();
                if ($activeId) {
                    $ut = $this->db->prepare("UPDATE estudiante_carreras ec JOIN estados_trayectoria_academica et ON et.id=ec.estado_trayectoria_id SET ec.estado_trayectoria_id=:e WHERE ec.id=:t AND et.codigo IN('PREMATRICULA','RENOVACION')");
                    $ut->execute(['e' => $activeId, 't' => $m['estudiante_carrera_id']]);
                }
            }
            $h = $this->db->prepare(
                "INSERT INTO historial_estado_matricula(matricula_id,estado_anterior_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) 
                VALUES(:m,:a,:n,:mot,:u)"
            );
            $h->execute(['m' => $id, 'a' => $old, 'n' => $new, 'mot' => $newCode === 'CONFIRMADA' ? 'Confirmación académica y habilitación financiera vigentes' : 'Confirmación académica realizada; pendiente habilitación financiera', 'u' => $actor ?: null]);
            $this->db->commit();
            return $newCode;
        } catch (Throwable $e) {
            $this->db->rollBack();
            throw $e;
        }
    }
    public function pendingAcademicConfirmations(): array
    {
        $s = $this->db->query("SELECT m.id,m.numero_matricula,em.codigo estado_codigo,em.nombre estado,p.nombre periodo,CONCAT_WS(' ',pe.primer_nombre,pe.segundo_nombre,pe.primer_apellido,pe.segundo_apellido) estudiante,e.codigo_estudiante,c.nombre carrera,(SELECT COUNT(*) FROM matricula_asignaturas ma WHERE ma.matricula_id=m.id AND ma.activo=1) asignaturas FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id JOIN periodos_academicos p ON p.id=m.periodo_academico_id JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id JOIN estudiantes e ON e.id=ec.estudiante_id JOIN personas pe ON pe.id=e.persona_id JOIN carreras c ON c.id=ec.carrera_id WHERE m.activo=1 AND em.codigo IN('BORRADOR','PENDIENTE_VALIDACION','PENDIENTE_FINANCIERO') ORDER BY p.fecha_inicio DESC,m.id DESC LIMIT 200");
        return $s->fetchAll();
    }

    public function bulkAcademicConfirm(array $ids, int $actor): array
    {
        $ok = 0; $pending = 0; $errors = [];
        foreach (array_values(array_unique(array_filter(array_map('intval', $ids)))) as $id) {
            try {
                $state = $this->academicConfirm($id, $actor);
                $state === 'CONFIRMADA' ? $ok++ : $pending++;
            } catch (Throwable $e) {
                $errors[] = 'Matrícula '.$id.': '.$e->getMessage();
            }
        }
        return ['confirmadas' => $ok, 'pendientes_financiero' => $pending, 'errores' => $errors];
    }

    private function idByCode(string $table, string $code): int
    {
        if (!in_array($table, ['tipos_matricula', 'estados_matricula', 'estados_matricula_asignatura'], true)) throw new RuntimeException('Catálogo inválido.');
        $s = $this->db->prepare("SELECT id FROM {$table} WHERE codigo=:c AND activo=1 LIMIT 1");
        $s->execute(['c' => $code]);
        $id = (int)$s->fetchColumn();
        if (!$id) throw new RuntimeException("No existe {$table}.{$code}.");
        return $id;
    }
}
