<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;
use RuntimeException;
use Throwable;

final class HumanResourcesRepository
{
    public function __construct(private PDO $db) {}

    public function employees(string $q = ''): array
    {
        $sql = "SELECT e.id,e.codigo_empleado,e.fecha_primer_ingreso,e.activo,
                     p.numero_identificacion,
                     CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,
                     GROUP_CONCAT(DISTINCT tp.nombre ORDER BY tp.nombre SEPARATOR ', ') tipos_personal,
                     er.codigo estado_codigo,er.nombre estado_relacion,
                     c.nombre cargo,uo.nombre unidad,s.nombre sede,
                     rl.id relacion_laboral_id,
                     (SELECT COUNT(*) FROM relacion_laboral_solicitudes_cuenta x
                       JOIN solicitudes_cuentas sc ON sc.id=x.solicitud_cuenta_id
                      WHERE x.relacion_laboral_id=rl.id) solicitudes_cuenta
                FROM empleados e
                JOIN personas p ON p.id=e.persona_id
                LEFT JOIN empleado_tipos_personal etp ON etp.empleado_id=e.id AND etp.activo=1
                LEFT JOIN tipos_personal tp ON tp.id=etp.tipo_personal_id
                LEFT JOIN relaciones_laborales rl ON rl.empleado_id=e.id
                    AND rl.id=(SELECT r2.id
                                FROM relaciones_laborales r2
                                WHERE r2.empleado_id=e.id
                                ORDER BY
                                r2.fecha_inicio DESC,
                                r2.id DESC LIMIT 1)
                LEFT JOIN estados_relacion_laboral er ON er.id=rl.estado_relacion_id
                LEFT JOIN asignaciones_laborales al ON al.relacion_laboral_id=rl.id AND al.activo=1 AND al.es_principal=1
                LEFT JOIN cargos c ON c.id=al.cargo_id
                LEFT JOIN unidades_organizacionales uo ON uo.id=al.unidad_organizacional_id
                LEFT JOIN sedes s ON s.id=al.sede_id
               WHERE e.deleted_at IS NULL AND p.deleted_at IS NULL";
        $params = [];
        if ($q !== '') {
            $sql .= " AND (e.codigo_empleado LIKE :q OR p.numero_identificacion LIKE :q OR p.primer_nombre LIKE :q OR p.segundo_nombre LIKE :q OR p.primer_apellido LIKE :q OR p.segundo_apellido LIKE :q)";
            $params['q'] = '%' . $q . '%';
        }
        $sql .= " GROUP BY e.id,e.codigo_empleado,e.fecha_primer_ingreso,e.activo,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,er.codigo,er.nombre,c.nombre,uo.nombre,s.nombre,rl.id ORDER BY p.primer_apellido,p.primer_nombre LIMIT 250";
        $s = $this->db->prepare($sql);
        $s->execute($params);
        return $s->fetchAll();
    }

    public function employee(int $id): ?array
    {
        $s = $this->db->prepare(
            "SELECT e.*,p.tipo_identificacion_id,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,
            rl.id relacion_laboral_id,
                (SELECT er.codigo
                FROM estados_relacion_laboral er
                WHERE er.id = rl.estado_relacion_id) AS estado_codigo,
                rl.tipo_contrato_id,
            rl.tipo_jornada_id,rl.estado_relacion_id,rl.fecha_inicio,rl.fecha_fin_prevista,rl.fecha_fin_real,rl.numero_contrato,rl.observacion, al.id asignacion_id,al.cargo_id,al.unidad_organizacional_id,al.sede_id
            FROM empleados e JOIN personas p ON p.id=e.persona_id
            LEFT JOIN relaciones_laborales rl ON rl.empleado_id=e.id
            AND rl.id=(SELECT r2.id
            FROM relaciones_laborales r2
            WHERE r2.empleado_id=e.id
            ORDER BY (r2.fecha_fin_real IS NULL)
            DESC,r2.fecha_inicio DESC,r2.id DESC LIMIT 1)
            LEFT JOIN asignaciones_laborales al
                ON al.id = (
                    SELECT a2.id
                    FROM asignaciones_laborales a2
                    WHERE a2.relacion_laboral_id = rl.id
                    AND a2.activo = 1
                    AND a2.es_principal = 1
                    ORDER BY a2.fecha_inicio DESC, a2.id DESC
                    LIMIT 1
                )
            WHERE e.id=:id AND e.deleted_at IS NULL
            AND p.deleted_at IS NULL LIMIT 1"
        );
        $s->execute(['id' => $id]);
        return $s->fetch() ?: null;
    }

    public function employeeTypeIds(int $id): array
    {
        $s = $this->db->prepare(
            "SELECT tipo_personal_id
            FROM empleado_tipos_personal
            WHERE empleado_id=:e
            AND activo=1"
        );
        $s->execute(['e' => $id]);
        return array_map(
            'intval',
            array_column($s->fetchAll(), 'tipo_personal_id')
        );
    }

    public function identificationTypes(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre
            FROM tipos_identificacion
            WHERE activo=1
            ORDER BY nombre"
        )->fetchAll();
    }

    public function personnelTypes(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre,descripcion,genera_perfil_docente,genera_perfil_administrativo
            FROM tipos_personal
            WHERE activo=1
            ORDER BY id"
        )->fetchAll();
    }

    public function contractTypes(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre
            FROM tipos_contrato_laboral
            WHERE activo=1
            ORDER BY nombre"
        )->fetchAll();
    }

    public function workdayTypes(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre,horas_semanales
            FROM tipos_jornada_laboral
            WHERE activo=1
            ORDER BY nombre"
        )->fetchAll();
    }

    public function relationStates(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre,permite_acceso_institucional
            FROM estados_relacion_laboral
            WHERE activo=1
            ORDER BY id"
        )->fetchAll();
    }

    public function positions(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre,es_docente,es_administrativo
            FROM cargos
            WHERE activo=1
            AND deleted_at IS NULL
            ORDER BY nombre"
        )->fetchAll();
    }

    public function units(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre
            FROM unidades_organizacionales
            WHERE activo=1
            AND deleted_at IS NULL
            ORDER BY nombre"
        )->fetchAll();
    }

    public function campuses(): array
    {
        return $this->db->query(
            "SELECT id,codigo,nombre
            FROM sedes
            WHERE activo=1
            AND deleted_at IS NULL
            ORDER BY nombre"
        )->fetchAll();
    }

    public function catalogs(): array
    {
        return ['positions' => $this->positions(), 'units' => $this->units(), 'campuses' => $this->campuses()];
    }

    public function createCatalog(string $type, array $d): void
    {
        $code = strtoupper(trim((string)($d['codigo'] ?? '')));
        $name = trim((string)($d['nombre'] ?? ''));
        if ($code === '' || $name === '') throw new RuntimeException('Código y nombre son obligatorios.');
        $institution = (int)$this->scalar(
            "SELECT id
            FROM instituciones
            WHERE codigo='SUPERARSE'
            AND activo=1 LIMIT 1"
        );
        if ($type === 'cargo') {
            $s = $this->db->prepare(
                "INSERT INTO cargos(codigo,nombre,descripcion,es_docente,es_administrativo,activo)
                VALUES(:c,:n,:d,:ed,:ea,1)"
            );
            $s->execute(
                [
                    'c' => $code,
                    'n' => $name,
                    'd' => trim((string)($d['descripcion'] ?? '')) ?: null,
                    'ed' => !empty($d['es_docente']) ? 1 : 0,
                    'ea' => !empty($d['es_administrativo']) ? 1 : 0
                ]
            );
            return;
        }
        if (!$institution) throw new RuntimeException('No se encontró la institución SUPERARSE.');
        if ($type === 'unidad') {
            $s = $this->db->prepare(
                "INSERT INTO unidades_organizacionales(institucion_id,codigo,nombre,descripcion,activo)
                VALUES(:i,:c,:n,:d,1)"
            );
            $s->execute(
                [
                    'i' => $institution,
                    'c' => $code,
                    'n' => $name,
                    'd' => trim((string)($d['descripcion'] ?? '')) ?: null
                ]
            );
            return;
        }
        if ($type === 'sede') {
            $s = $this->db->prepare(
                "INSERT INTO sedes(institucion_id,codigo,nombre,descripcion,activo)
                VALUES(:i,:c,:n,:d,1)"
            );
            $s->execute(
                [
                    'i' => $institution,
                    'c' => $code,
                    'n' => $name,
                    'd' => trim((string)($d['descripcion'] ?? '')) ?: null
                ]
            );
            return;
        }
        throw new RuntimeException('Catálogo no válido.');
    }

    public function createEmployee(array $d, int $actor): int
    {
        $this->db->beginTransaction();
        try {
            $s = $this->db->prepare(
                "SELECT id
                FROM personas
                WHERE tipo_identificacion_id=:t
                AND numero_identificacion=:n
                AND deleted_at IS NULL LIMIT 1"
            );
            $s->execute(
                [
                    't' => $d['tipo_identificacion_id'],
                    'n' => $d['numero_identificacion']
                ]
            );
            $pid = (int)($s->fetchColumn() ?: 0);
            if ($pid) {
                $s = $this->db->prepare("SELECT id
                FROM empleados
                WHERE persona_id=:p
                AND deleted_at IS NULL LIMIT 1");
                $s->execute(['p' => $pid]);
                if ($s->fetchColumn()) throw new RuntimeException('Esta persona ya tiene una ficha de Talento Humano.');
                $s = $this->db->prepare(
                    "UPDATE personas
                    SET primer_nombre=:pn,segundo_nombre=:sn,primer_apellido=:pa,segundo_apellido=:sa,activo=1
                    WHERE id=:id"
                );
                $s->execute(
                    [
                        'pn' => $d['primer_nombre'],
                        'sn' => $d['segundo_nombre'] ?: null,
                        'pa' => $d['primer_apellido'],
                        'sa' => $d['segundo_apellido'] ?: null,
                        'id' => $pid
                    ]
                );
            } else {
                $s = $this->db->prepare("INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,segundo_nombre,primer_apellido,segundo_apellido,activo)
                VALUES(:t,:n,:pn,:sn,:pa,:sa,1)");
                $s->execute(
                    [
                        't' => $d['tipo_identificacion_id'],
                        'n' => $d['numero_identificacion'],
                        'pn' => $d['primer_nombre'],
                        'sn' => $d['segundo_nombre'] ?: null,
                        'pa' => $d['primer_apellido'],
                        'sa' => $d['segundo_apellido'] ?: null
                    ]
                );
                $pid = (int)$this->db->lastInsertId();
            }
            $s = $this->db->prepare(
                "INSERT INTO empleados(persona_id,codigo_empleado,fecha_primer_ingreso,activo)
                VALUES(:p,:c,:f,1)"
            );
            $tmp = 'TMP-' . bin2hex(random_bytes(8));
            $s->execute(['p' => $pid, 'c' => $tmp, 'f' => $d['fecha_inicio']]);
            $eid = (int)$this->db->lastInsertId();
            $code = 'EMP-' . str_pad((string)$eid, 6, '0', STR_PAD_LEFT);
            $this->db->prepare(
                "UPDATE empleados
                SET codigo_empleado=:c
                WHERE id=:id"
            )->execute(
                [
                    'c' => $code,
                    'id' => $eid
                ]
            );
            $this->insertTypes($eid, $d['tipos_personal'], $d['fecha_inicio']);
            $s = $this->db->prepare(
                "INSERT INTO relaciones_laborales(
                    empleado_id,
                    tipo_contrato_id,
                    tipo_jornada_id,
                    estado_relacion_id,
                    fecha_inicio,
                    fecha_fin_prevista,
                    numero_contrato,
                    observacion,
                    registrado_por_usuario_id
                ) VALUES(:e,:tc,:tj,:er,:fi,:ff,:nc,:o,:a)"
            );
            $s->execute(
                [
                    'e' => $eid,
                    'tc' => $d['tipo_contrato_id'] ?: null,
                    'tj' => $d['tipo_jornada_id'] ?: null,
                    'er' => $d['estado_relacion_id'],
                    'fi' => $d['fecha_inicio'],
                    'ff' => $d['fecha_fin_prevista'] ?: null,
                    'nc' => $d['numero_contrato'] ?: null,
                    'o' => $d['observacion'] ?: null,
                    'a' => $actor
                ]
            );
            $rid = (int)$this->db->lastInsertId();
            $this->db->prepare(
                "INSERT INTO historial_estado_relacion_laboral(relacion_laboral_id,estado_nuevo_id,motivo,cambiado_por_usuario_id)
                VALUES(:r,:e,'Alta inicial de personal',:a)"
            )->execute(
                [
                    'r' => $rid,
                    'e' => $d['estado_relacion_id'],
                    'a' => $actor
                ]
            );
            $this->db->prepare(
                "INSERT INTO asignaciones_laborales(relacion_laboral_id,cargo_id,unidad_organizacional_id,sede_id,fecha_inicio,es_principal,activo,creado_por_usuario_id)
                VALUES(:r,:c,:u,:s,:f,1,1,:a)"
            )->execute(
                [
                    'r' => $rid,
                    'c' => $d['cargo_id'],
                    'u' => $d['unidad_organizacional_id'] ?: null,
                    's' => $d['sede_id'] ?: null,
                    'f' => $d['fecha_inicio'],
                    'a' => $actor
                ]
            );
            if (!empty($d['solicitar_cuenta']))
                $this->createAccountRequests($pid, $rid, $d['tipos_personal'], $actor);
            $this->db->commit();
            return $eid;
        } catch (Throwable $e) {
            $this->db->rollBack();
            throw $e;
        }
    }


    public function reentryEmployee(
        int $employeeId,
        array $d,
        int $actor
    ): int {
        if ($employeeId <= 0 || $actor <= 0) {
            throw new RuntimeException('Empleado o usuario inválido.');
        }

        $start = trim((string)($d['fecha_inicio'] ?? ''));
        $date = \DateTimeImmutable::createFromFormat('!Y-m-d', $start);

        if (!$date || $date->format('Y-m-d') !== $start) {
            throw new RuntimeException('Fecha de reingreso inválida.');
        }

        if ($start > date('Y-m-d')) {
            throw new RuntimeException('No se permiten reingresos futuros.');
        }

        $plannedEnd = trim((string)($d['fecha_fin_prevista'] ?? ''));

        if ($plannedEnd !== '') {
            $endDate = \DateTimeImmutable::createFromFormat('!Y-m-d', $plannedEnd);

            if (
                !$endDate || $endDate->format('Y-m-d') !== $plannedEnd
                || $plannedEnd < $start
            ) {
                throw new RuntimeException(
                    'La fecha prevista de finalización es inválida.'
                );
            }
        }

        $typeIds = array_values(array_unique(array_map(
            'intval',
            (array)($d['tipos_personal'] ?? [])
        )));

        if (!$typeIds || in_array(0, $typeIds, true)) {
            throw new RuntimeException(
                'Debe seleccionar una clasificación de personal válida.'
            );
        }

        $this->db->beginTransaction();

        try {
            // Bloquear la ficha existente.
            $s = $this->db->prepare(
                "SELECT e.id, e.persona_id
             FROM empleados e
             INNER JOIN personas p ON p.id = e.persona_id
             WHERE e.id = :id
               AND e.deleted_at IS NULL
               AND p.deleted_at IS NULL
             FOR UPDATE"
            );
            $s->execute(['id' => $employeeId]);
            $employee = $s->fetch(PDO::FETCH_ASSOC);

            if (!$employee) {
                throw new RuntimeException('Empleado no encontrado.');
            }

            // Bloquear todas sus relaciones laborales.
            $s = $this->db->prepare(
                "SELECT rl.id, rl.fecha_inicio, rl.fecha_fin_real,
                    er.codigo AS estado_codigo
             FROM relaciones_laborales rl
             INNER JOIN estados_relacion_laboral er
                ON er.id = rl.estado_relacion_id
             WHERE rl.empleado_id = :id
             ORDER BY rl.id
             FOR UPDATE"
            );
            $s->execute(['id' => $employeeId]);
            $relations = $s->fetchAll(PDO::FETCH_ASSOC);

            if (!$relations) {
                throw new RuntimeException(
                    'No existe una relación laboral anterior.'
                );
            }


            // Identificar la relación cronológicamente más reciente.
            $latestRelation = null;

            foreach ($relations as $relation) {
                if (
                    $latestRelation === null
                    || $relation['fecha_inicio'] > $latestRelation['fecha_inicio']
                    || (
                        $relation['fecha_inicio'] === $latestRelation['fecha_inicio']
                        && (int)$relation['id'] > (int)$latestRelation['id']
                    )
                ) {
                    $latestRelation = $relation;
                }
            }

            // Un reingreso solo procede después de una finalización.
            if (
                $latestRelation === null
                || $latestRelation['estado_codigo'] !== 'FINALIZADA'
            ) {
                throw new RuntimeException(
                    'El reingreso requiere que la última relación laboral esté FINALIZADA.'
                );
            }

            if (empty($latestRelation['fecha_fin_real'])) {
                throw new RuntimeException(
                    'La última relación laboral no tiene fecha real de finalización.'
                );
            }


            $lastEnd = null;

            foreach ($relations as $relation) {
                if (
                    in_array(
                        $relation['estado_codigo'],
                        ['PENDIENTE', 'ACTIVA', 'SUSPENDIDA'],
                        true
                    )
                ) {
                    throw new RuntimeException(
                        'El empleado ya tiene una relación laboral vigente.'
                    );
                }

                if ($relation['estado_codigo'] === 'FINALIZADA') {
                    if (!$relation['fecha_fin_real']) {
                        throw new RuntimeException(
                            'Existe una relación finalizada sin fecha de cierre.'
                        );
                    }

                    if (
                        $lastEnd === null
                        || $relation['fecha_fin_real'] > $lastEnd
                    ) {
                        $lastEnd = $relation['fecha_fin_real'];
                    }
                }
            }

            if ($lastEnd === null) {
                throw new RuntimeException(
                    'El empleado no tiene una relación finalizada para reingresar.'
                );
            }

            if ($start <= $lastEnd) {
                throw new RuntimeException(
                    'El reingreso debe ser posterior a la última finalización.'
                );
            }

            // Verificar que las relaciones anteriores no tengan
            // asignaciones abiertas ni fechas posteriores al reingreso.
            $s = $this->db->prepare(
                "SELECT a.id, a.fecha_inicio, a.fecha_fin, a.activo
                FROM asignaciones_laborales a
                INNER JOIN relaciones_laborales rl
                    ON rl.id = a.relacion_laboral_id
                WHERE rl.empleado_id = :empleado
                FOR UPDATE"
            );
            $s->execute(['empleado' => $employeeId]);

            foreach ($s->fetchAll(PDO::FETCH_ASSOC) as $assignment) {
                if (
                    (int)$assignment['activo'] === 1
                    || $assignment['fecha_fin'] === null
                    || $assignment['fecha_fin'] >= $start
                    || $assignment['fecha_inicio'] >= $start
                ) {
                    throw new RuntimeException(
                        'Existen asignaciones laborales anteriores abiertas '
                            . 'o incompatibles con la fecha de reingreso.'
                    );
                }
            }


            // Validar referencias a catálogos institucionales.
            $catalogChecks = [
                ['tipos_contrato_laboral', (int)($d['tipo_contrato_id'] ?? 0), false],
                ['tipos_jornada_laboral', (int)($d['tipo_jornada_id'] ?? 0), false],
                ['cargos', (int)($d['cargo_id'] ?? 0), true],
                ['unidades_organizacionales', (int)($d['unidad_organizacional_id'] ?? 0), false],
                ['sedes', (int)($d['sede_id'] ?? 0), false],
            ];

            foreach ($catalogChecks as [$table, $id, $required]) {
                if ($id <= 0) {
                    if ($required) {
                        throw new RuntimeException(
                            'Debe seleccionar un cargo válido.'
                        );
                    }
                    continue;
                }

                // El nombre de tabla proviene exclusivamente
                // de la lista fija definida en el servidor.

                $softDeleteTables = [
                    'cargos',
                    'unidades_organizacionales',
                    'sedes',
                ];

                $notDeleted = in_array($table, $softDeleteTables, true)
                    ? ' AND deleted_at IS NULL'
                    : '';

                $s = $this->db->prepare(
                    "SELECT id
                    FROM {$table}
                    WHERE id = :id
                    AND activo = 1
                    {$notDeleted}
                    LIMIT 1"
                );

                $s->execute(['id' => $id]);

                if (!$s->fetchColumn()) {
                    throw new RuntimeException(
                        "El catálogo {$table} contiene una selección inválida."
                    );
                }
            }

            // Verificar todas las clasificaciones seleccionadas.
            $placeholders = implode(',', array_fill(0, count($typeIds), '?'));

            $s = $this->db->prepare(
                "SELECT COUNT(*)
                FROM tipos_personal
                WHERE activo = 1
                AND id IN ({$placeholders})"
            );
            $s->execute($typeIds);

            if ((int)$s->fetchColumn() !== count($typeIds)) {
                throw new RuntimeException(
                    'Una o más clasificaciones de personal no son válidas.'
                );
            }


            // Comprobar que los períodos históricos de clasificación
            // no se superpongan con el nuevo reingreso.
            $s = $this->db->prepare(
                "SELECT id, fecha_inicio, fecha_fin, activo
             FROM empleado_tipos_personal
             WHERE empleado_id = :empleado
             FOR UPDATE"
            );

            $s->execute(['empleado' => $employeeId]);

            foreach ($s->fetchAll(PDO::FETCH_ASSOC) as $classification) {
                if (
                    $classification['fecha_inicio'] >= $start
                    || $classification['fecha_fin'] === null
                    || $classification['fecha_fin'] >= $start
                ) {
                    throw new RuntimeException(
                        'Existe una clasificación histórica incompatible '
                            . 'con la fecha de reingreso.'
                    );
                }
            }

            // No deben existir clasificaciones activas de relaciones anteriores.
            $s = $this->db->prepare(
                "SELECT id
             FROM empleado_tipos_personal
             WHERE empleado_id = :id
               AND activo = 1
             FOR UPDATE"
            );
            $s->execute(['id' => $employeeId]);

            if ($s->fetchColumn()) {
                throw new RuntimeException(
                    'Existen clasificaciones activas pendientes de revisión.'
                );
            }

            // Obtener el estado ACTIVA.
            $s = $this->db->prepare(
                "SELECT id
             FROM estados_relacion_laboral
             WHERE codigo = 'ACTIVA' AND activo = 1
             LIMIT 1"
            );
            $s->execute();
            $activeStateId = (int)$s->fetchColumn();

            if ($activeStateId <= 0) {
                throw new RuntimeException(
                    'El estado ACTIVA no está disponible.'
                );
            }

            // Registrar la nueva relación laboral.
            $s = $this->db->prepare(
                "INSERT INTO relaciones_laborales (
                empleado_id,
                tipo_contrato_id,
                tipo_jornada_id,
                estado_relacion_id,
                fecha_inicio,
                fecha_fin_prevista,
                numero_contrato,
                observacion,
                registrado_por_usuario_id
             ) VALUES (
                :empleado, :contrato, :jornada, :estado,
                :inicio, :fin, :numero, :observacion, :actor
             )"
            );

            $s->execute([
                'empleado' => $employeeId,
                'contrato' => $d['tipo_contrato_id'] ?: null,
                'jornada' => $d['tipo_jornada_id'] ?: null,
                'estado' => $activeStateId,
                'inicio' => $start,
                'fin' => $plannedEnd ?: null,
                'numero' => trim((string)($d['numero_contrato'] ?? '')) ?: null,
                'observacion' => trim((string)($d['observacion'] ?? '')) ?: null,
                'actor' => $actor,
            ]);

            $relationId = (int)$this->db->lastInsertId();

            // Crear nuevas clasificaciones sin reabrir las anteriores.
            $this->insertTypes($employeeId, $typeIds, $start);

            // Registrar el movimiento inicial del reingreso.
            $s = $this->db->prepare(
                "INSERT INTO historial_estado_relacion_laboral (
                relacion_laboral_id,
                estado_anterior_id,
                estado_nuevo_id,
                fecha_efectiva,
                motivo,
                cambiado_por_usuario_id
             ) VALUES (
                :relacion, NULL, :estado, :fecha, :motivo, :actor
             )"
            );
            $s->execute([
                'relacion' => $relationId,
                'estado' => $activeStateId,
                'fecha' => $start,
                'motivo' => 'Reingreso laboral de personal',
                'actor' => $actor,
            ]);

            // Registrar la nueva asignación principal.
            $s = $this->db->prepare(
                "INSERT INTO asignaciones_laborales (
                relacion_laboral_id,
                cargo_id,
                unidad_organizacional_id,
                sede_id,
                fecha_inicio,
                es_principal,
                activo,
                creado_por_usuario_id
             ) VALUES (
                :relacion, :cargo, :unidad, :sede,
                :inicio, 1, 1, :actor
             )"
            );
            $s->execute([
                'relacion' => $relationId,
                'cargo' => $d['cargo_id'],
                'unidad' => $d['unidad_organizacional_id'] ?: null,
                'sede' => $d['sede_id'] ?: null,
                'inicio' => $start,
                'actor' => $actor,
            ]);

            $this->db->commit();

            return $relationId;
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }

            throw $e;
        }
    }

    public function updateEmployee(int $id, array $d, int $actor): void
    {
        $this->db->beginTransaction();

        try {
            // Bloquear la ficha durante la actualización.
            $s = $this->db->prepare(
                "SELECT e.id, e.persona_id
             FROM empleados e
             JOIN personas p ON p.id = e.persona_id
             WHERE e.id = :id
               AND e.deleted_at IS NULL
               AND p.deleted_at IS NULL
             FOR UPDATE"
            );
            $s->execute(['id' => $id]);
            $employee = $s->fetch(PDO::FETCH_ASSOC);

            if (!$employee) {
                throw new RuntimeException('Empleado no encontrado.');
            }

            $pid = (int)$employee['persona_id'];

            // Bloquear también la persona asociada.
            $s = $this->db->prepare(
                "SELECT id FROM personas WHERE id = :id FOR UPDATE"
            );
            $s->execute(['id' => $pid]);

            // Impedir que la identificación pertenezca a otra persona.
            $s = $this->db->prepare(
                "SELECT id
             FROM personas
             WHERE tipo_identificacion_id = :t
               AND numero_identificacion = :n
               AND id <> :id
               AND deleted_at IS NULL
             LIMIT 1"
            );
            $s->execute([
                't' => $d['tipo_identificacion_id'],
                'n' => $d['numero_identificacion'],
                'id' => $pid
            ]);

            if ($s->fetchColumn()) {
                throw new RuntimeException(
                    'La identificación ya pertenece a otra persona.'
                );
            }

            $s = $this->db->prepare(
                "UPDATE personas
             SET tipo_identificacion_id = :t,
                 numero_identificacion = :n,
                 primer_nombre = :pn,
                 segundo_nombre = :sn,
                 primer_apellido = :pa,
                 segundo_apellido = :sa
             WHERE id = :id"
            );
            $s->execute([
                't' => $d['tipo_identificacion_id'],
                'n' => $d['numero_identificacion'],
                'pn' => $d['primer_nombre'],
                'sn' => $d['segundo_nombre'] ?: null,
                'pa' => $d['primer_apellido'],
                'sa' => $d['segundo_apellido'] ?: null,
                'id' => $pid
            ]);

            // Recuperar la relación laboral más reciente.
            $s = $this->db->prepare(
                "SELECT *
             FROM relaciones_laborales
             WHERE empleado_id = :id
             ORDER BY
                 (fecha_fin_real IS NULL) DESC,
                 fecha_inicio DESC,
                 id DESC
             LIMIT 1
             FOR UPDATE"
            );
            $s->execute(['id' => $id]);
            $relation = $s->fetch(PDO::FETCH_ASSOC);

            if (!$relation) {
                throw new RuntimeException(
                    'El empleado no tiene una relación laboral registrada.'
                );
            }

            $rid = (int)$relation['id'];
            $oldState = (int)$relation['estado_relacion_id'];
            $newState = (int)$d['estado_relacion_id'];

            if ($oldState !== $newState) {
                throw new RuntimeException(
                    'Los cambios de estado laboral deben realizarse desde el proceso de gestión de relaciones laborales.'
                );
            }

            // La fecha de inicio histórica no debe reescribirse.
            if ($d['fecha_inicio'] !== $relation['fecha_inicio']) {
                throw new RuntimeException(
                    'La fecha de inicio de la relación laboral no puede modificarse desde esta edición.'
                );
            }

            $effectiveDate = $d['fecha_efectiva'];

            if ($relation['fecha_fin_real'] !== null) {
                throw new RuntimeException(
                    'La relación laboral está finalizada. '
                        . 'Sus movimientos deben gestionarse desde el historial laboral.'
                );
            }

            if ($effectiveDate < $relation['fecha_inicio']) {
                throw new RuntimeException(
                    'La fecha efectiva no puede ser anterior al inicio de la relación laboral.'
                );
            }

            if (
                $relation['fecha_fin_real'] !== null
                && $effectiveDate > $relation['fecha_fin_real']
            ) {
                throw new RuntimeException(
                    'La fecha efectiva no puede ser posterior a la finalización de la relación laboral.'
                );
            }

            if ($effectiveDate > date('Y-m-d')) {
                throw new RuntimeException(
                    'Los movimientos con fecha futura estarán disponibles cuando se implemente su programación.'
                );
            }

            $s = $this->db->prepare(
                "UPDATE relaciones_laborales
             SET tipo_contrato_id = :tc,
                 tipo_jornada_id = :tj,
                 estado_relacion_id = :er,
                 fecha_fin_prevista = :ff,
                 numero_contrato = :nc,
                 observacion = :o
             WHERE id = :id"
            );
            $s->execute([
                'tc' => $d['tipo_contrato_id'] ?: null,
                'tj' => $d['tipo_jornada_id'] ?: null,
                'er' => $newState,
                'ff' => $d['fecha_fin_prevista'] ?: null,
                'nc' => $d['numero_contrato'] ?: null,
                'o' => $d['observacion'] ?: null,
                'id' => $rid
            ]);

            // Registrar únicamente transiciones reales.
            if ($oldState !== $newState) {
                $s = $this->db->prepare(
                    "INSERT INTO historial_estado_relacion_laboral
                 (
                     relacion_laboral_id,
                     estado_anterior_id,
                     estado_nuevo_id,
                     motivo,
                     cambiado_por_usuario_id
                 )
                 VALUES (:r, :old, :new, :motivo, :actor)"
                );
                $s->execute([
                    'r' => $rid,
                    'old' => $oldState,
                    'new' => $newState,
                    'motivo' => 'Cambio de estado desde Talento Humano',
                    'actor' => $actor
                ]);
            }

            // Sincronizar tipos de personal conservando historial.
            $this->syncEmployeeTypes(
                $id,
                $d['tipos_personal'],
                $actor,
                $d['fecha_efectiva']
            );


            // Recuperar todas las asignaciones principales de la relación.
            $s = $this->db->prepare(
                "SELECT *
                 FROM asignaciones_laborales
                 WHERE relacion_laboral_id = :r
                   AND es_principal = 1
                 ORDER BY fecha_inicio, id
                 FOR UPDATE"
            );
            $s->execute(['r' => $rid]);
            $assignments = $s->fetchAll(PDO::FETCH_ASSOC);

            $activeAssignments = array_values(array_filter(
                $assignments,
                static fn(array $row): bool =>
                (int)$row['activo'] === 1
            ));

            if (count($activeAssignments) !== 1) {
                throw new RuntimeException(
                    'La relación laboral debe tener exactamente '
                        . 'una asignación principal activa.'
                );
            }

            $assignment = $activeAssignments[0];

            if ($assignment['fecha_fin'] !== null) {
                throw new RuntimeException(
                    'La asignación principal activa tiene fecha de fin.'
                );
            }

            $changed =
                (int)$assignment['cargo_id'] !== (int)$d['cargo_id']
                || (int)($assignment['unidad_organizacional_id'] ?? 0)
                !== (int)$d['unidad_organizacional_id']
                || (int)($assignment['sede_id'] ?? 0)
                !== (int)$d['sede_id'];

            if ($changed) {
                if ($effectiveDate <= $assignment['fecha_inicio']) {
                    throw new RuntimeException(
                        'La fecha efectiva debe ser posterior al inicio '
                            . 'de la asignación principal vigente.'
                    );
                }

                // Evitar insertar un movimiento dentro de un período
                // histórico existente.
                foreach ($assignments as $row) {
                    if ((int)$row['id'] === (int)$assignment['id']) {
                        continue;
                    }

                    $start = $row['fecha_inicio'];
                    $end = $row['fecha_fin'];

                    if (
                        $start >= $effectiveDate
                        || ($end === null || $end > $effectiveDate)
                    ) {
                        throw new RuntimeException(
                            'El movimiento se superpone con una '
                                . 'asignación histórica. Revise las fechas.'
                        );
                    }
                }

                // Cerrar el período vigente.
                // fecha_fin es el límite exclusivo del período.
                $s = $this->db->prepare(
                    "UPDATE asignaciones_laborales
                     SET activo = 0,
                         fecha_fin = :fecha
                     WHERE id = :id
                       AND activo = 1"
                );
                $s->execute([
                    'fecha' => $effectiveDate,
                    'id' => $assignment['id']
                ]);

                if ($s->rowCount() !== 1) {
                    throw new RuntimeException(
                        'No se pudo cerrar la asignación anterior.'
                    );
                }

                // Crear la nueva asignación principal.
                $s = $this->db->prepare(
                    "INSERT INTO asignaciones_laborales
                     (
                         relacion_laboral_id,
                         cargo_id,
                         unidad_organizacional_id,
                         sede_id,
                         fecha_inicio,
                         fecha_fin,
                         es_principal,
                         activo,
                         creado_por_usuario_id
                     )
                     VALUES
                     (:r, :c, :u, :s, :f, NULL, 1, 1, :actor)"
                );

                $s->execute([
                    'r' => $rid,
                    'c' => $d['cargo_id'],
                    'u' => $d['unidad_organizacional_id'] ?: null,
                    's' => $d['sede_id'] ?: null,
                    'f' => $effectiveDate,
                    'actor' => $actor
                ]);
            }
            $this->db->commit();
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }


    public function relationStateHistory(int $employeeId, int $relationId): array
    {
        $stmt = $this->db->prepare(
            "SELECT
            h.id,
            h.fecha_efectiva,
            h.motivo,
            h.changed_at,
            ea.codigo AS estado_anterior,
            en.codigo AS estado_nuevo
         FROM historial_estado_relacion_laboral h
         INNER JOIN relaciones_laborales rl
             ON rl.id = h.relacion_laboral_id
         LEFT JOIN estados_relacion_laboral ea
             ON ea.id = h.estado_anterior_id
         INNER JOIN estados_relacion_laboral en
             ON en.id = h.estado_nuevo_id
         WHERE rl.empleado_id = :empleado
           AND rl.id = :relacion
         ORDER BY
            COALESCE(h.fecha_efectiva, DATE(h.changed_at)) DESC,
            h.id DESC"
        );

        $stmt->execute([
            'empleado' => $employeeId,
            'relacion' => $relationId,
        ]);

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function changeRelationState(
        int $employeeId,
        int $relationId,
        string $newStateCode,
        string $effectiveDate,
        string $reason,
        int $actor
    ): void {
        $date = \DateTimeImmutable::createFromFormat('!Y-m-d', $effectiveDate);

        if (!$date || $date->format('Y-m-d') !== $effectiveDate) {
            throw new RuntimeException('Fecha efectiva inválida.');
        }

        if ($effectiveDate > date('Y-m-d')) {
            throw new RuntimeException('No se permiten movimientos futuros.');
        }

        $reason = trim($reason);

        if ($reason === '' || mb_strlen($reason) > 255) {
            throw new RuntimeException(
                'El motivo es obligatorio y debe tener máximo 255 caracteres.'
            );
        }

        $transitions = [
            'PENDIENTE' => ['ACTIVA', 'ANULADA'],
            'ACTIVA' => ['SUSPENDIDA', 'FINALIZADA'],
            'SUSPENDIDA' => ['ACTIVA', 'FINALIZADA'],
        ];

        $this->db->beginTransaction();

        try {
            $s = $this->db->prepare(
                "SELECT rl.id, rl.empleado_id, rl.estado_relacion_id,
                    rl.fecha_inicio, rl.fecha_fin_real,
                    er.codigo AS estado_codigo
             FROM relaciones_laborales rl
             INNER JOIN estados_relacion_laboral er
                 ON er.id = rl.estado_relacion_id
             WHERE rl.id = :r AND rl.empleado_id = :e
             FOR UPDATE"
            );
            $s->execute(['r' => $relationId, 'e' => $employeeId]);
            $relation = $s->fetch(PDO::FETCH_ASSOC);

            if (!$relation) {
                throw new RuntimeException('Relación laboral no encontrada.');
            }

            $oldCode = $relation['estado_codigo'];

            if (!in_array($newStateCode, $transitions[$oldCode] ?? [], true)) {
                throw new RuntimeException(
                    "Transición laboral no permitida: {$oldCode} → {$newStateCode}."
                );
            }

            if ($effectiveDate < $relation['fecha_inicio']) {
                throw new RuntimeException(
                    'La fecha efectiva no puede ser anterior al inicio de la relación.'
                );
            }

            if ($relation['fecha_fin_real'] !== null) {
                throw new RuntimeException(
                    'No se puede modificar una relación laboral finalizada.'
                );
            }

            $s = $this->db->prepare(
                "SELECT MAX(fecha_efectiva)
             FROM historial_estado_relacion_laboral
             WHERE relacion_laboral_id = :r"
            );
            $s->execute(['r' => $relationId]);
            $lastEffectiveDate = $s->fetchColumn();

            if (
                $lastEffectiveDate !== null
                && $lastEffectiveDate !== false
                && $effectiveDate < $lastEffectiveDate
            ) {
                throw new RuntimeException(
                    'La fecha efectiva es anterior al último movimiento laboral.'
                );
            }

            $s = $this->db->prepare(
                "SELECT id
             FROM estados_relacion_laboral
             WHERE codigo = :codigo AND activo = 1
             LIMIT 1"
            );
            $s->execute(['codigo' => $newStateCode]);
            $newStateId = (int)$s->fetchColumn();

            if ($newStateId <= 0) {
                throw new RuntimeException('Estado laboral de destino no disponible.');
            }


            if ($newStateCode === 'FINALIZADA') {

                // Impedir una finalización anterior a cualquier asignación
                // registrada, incluso si ya está cerrada o es futura.
                $s = $this->db->prepare(
                    "SELECT id, fecha_inicio, fecha_fin
                    FROM asignaciones_laborales
                    WHERE relacion_laboral_id = :r
                    FOR UPDATE"
                );
                $s->execute(['r' => $relationId]);

                foreach ($s->fetchAll(PDO::FETCH_ASSOC) as $assignment) {
                    if (
                        $effectiveDate < $assignment['fecha_inicio']
                        || (
                            $assignment['fecha_fin'] !== null
                            && $effectiveDate < $assignment['fecha_fin']
                        )
                    ) {
                        throw new RuntimeException(
                            'La fecha de finalización contradice el historial de asignaciones.'
                        );
                    }
                }


                // Bloquear asignaciones abiertas de esta relación.
                $s = $this->db->prepare(
                    "SELECT id, fecha_inicio
                    FROM asignaciones_laborales
                    WHERE relacion_laboral_id = :r
                    AND activo = 1
                    FOR UPDATE"
                );
                $s->execute(['r' => $relationId]);
                $assignments = $s->fetchAll(PDO::FETCH_ASSOC);

                foreach ($assignments as $assignment) {
                    if ($effectiveDate < $assignment['fecha_inicio']) {
                        throw new RuntimeException(
                            'La finalización no puede ser anterior al inicio de una asignación activa.'
                        );
                    }
                }

                // Cerrar únicamente asignaciones abiertas.
                $s = $this->db->prepare(
                    "UPDATE asignaciones_laborales
         SET fecha_fin = :fecha,
             activo = 0
         WHERE relacion_laboral_id = :r
           AND activo = 1"
                );
                $s->execute([
                    'fecha' => $effectiveDate,
                    'r' => $relationId,
                ]);

                // Comprobar otras relaciones laborales vigentes.
                $s = $this->db->prepare(
                    "SELECT COUNT(*)
         FROM relaciones_laborales rl
         INNER JOIN estados_relacion_laboral er
             ON er.id = rl.estado_relacion_id
         WHERE rl.empleado_id = :empleado
           AND rl.id <> :relacion
           AND er.codigo IN ('PENDIENTE', 'ACTIVA', 'SUSPENDIDA')
           AND rl.fecha_fin_real IS NULL"
                );
                $s->execute([
                    'empleado' => $employeeId,
                    'relacion' => $relationId,
                ]);

                $otherRelations = (int)$s->fetchColumn();

                if ($otherRelations === 0) {

                    // Bloquear clasificaciones activas.
                    $s = $this->db->prepare(
                        "SELECT id, fecha_inicio
             FROM empleado_tipos_personal
             WHERE empleado_id = :empleado
               AND activo = 1
             FOR UPDATE"
                    );
                    $s->execute(['empleado' => $employeeId]);
                    $types = $s->fetchAll(PDO::FETCH_ASSOC);

                    foreach ($types as $type) {
                        if ($effectiveDate < $type['fecha_inicio']) {
                            throw new RuntimeException(
                                'La finalización no puede ser anterior al inicio de una clasificación activa.'
                            );
                        }
                    }

                    // Cerrar clasificaciones sin eliminar el historial.
                    $s = $this->db->prepare(
                        "UPDATE empleado_tipos_personal
             SET fecha_fin = :fecha,
                 activo = 0
             WHERE empleado_id = :empleado
               AND activo = 1"
                    );
                    $s->execute([
                        'fecha' => $effectiveDate,
                        'empleado' => $employeeId,
                    ]);
                }

                // Registrar fecha real de finalización.
                $s = $this->db->prepare(
                    "UPDATE relaciones_laborales
                    SET fecha_fin_real = :fecha
                    WHERE id = :r"
                );
                $s->execute([
                    'fecha' => $effectiveDate,
                    'r' => $relationId,
                ]);
            }


            $s = $this->db->prepare(
                "UPDATE relaciones_laborales
             SET estado_relacion_id = :estado
             WHERE id = :r"
            );
            $s->execute([
                'estado' => $newStateId,
                'r' => $relationId,
            ]);

            $s = $this->db->prepare(
                "INSERT INTO historial_estado_relacion_laboral
                (relacion_laboral_id, estado_anterior_id,
                 estado_nuevo_id, fecha_efectiva, motivo,
                 cambiado_por_usuario_id)
             VALUES
                (:r, :anterior, :nuevo, :fecha, :motivo, :actor)"
            );
            $s->execute([
                'r' => $relationId,
                'anterior' => $relation['estado_relacion_id'],
                'nuevo' => $newStateId,
                'fecha' => $effectiveDate,
                'motivo' => $reason,
                'actor' => $actor,
            ]);

            $this->db->commit();
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    private function insertTypes(int $eid, array $ids, string $start): void
    {
        $s = $this->db->prepare("INSERT INTO empleado_tipos_personal(empleado_id,tipo_personal_id,fecha_inicio,activo) VALUES(:e,:t,:f,1)");
        foreach (array_unique(array_map('intval', $ids)) as $id) if ($id > 0) $s->execute(['e' => $eid, 't' => $id, 'f' => $start]);
    }

    private function createAccountRequests(int $pid, int $rid, array $typeIds, int $actor): void
    {
        $ids = array_values(array_unique(array_map('intval', $typeIds)));
        if (!$ids) return;
        $in = implode(',', array_fill(0, count($ids), '?'));
        $s = $this->db->prepare("SELECT genera_perfil_docente,genera_perfil_administrativo FROM tipos_personal WHERE id IN ($in)");
        $s->execute($ids);
        $doc = false;
        $adm = false;
        foreach ($s->fetchAll() as $r) {
            $doc = $doc || (bool)$r['genera_perfil_docente'];
            $adm = $adm || (bool)$r['genera_perfil_administrativo'];
        }
        $profiles = [];
        if ($adm) $profiles[] = 'ADMINISTRATIVO';
        if ($doc) $profiles[] = 'DOCENTE';
        if (!$profiles) return;
        $typeCreate = (int)$this->scalar("SELECT id FROM tipos_solicitud_cuenta WHERE codigo='CREACION' LIMIT 1");
        $typeAdd = (int)$this->scalar("SELECT id FROM tipos_solicitud_cuenta WHERE codigo='AGREGAR_PERFIL' LIMIT 1");
        $state = (int)$this->scalar("SELECT id FROM estados_solicitud_cuenta WHERE codigo='PENDIENTE' LIMIT 1");
        $origin = (int)$this->scalar("SELECT id FROM origenes_solicitud_cuenta WHERE codigo='TTHH' LIMIT 1");
        $existing = (bool)$this->scalar("SELECT COUNT(*) FROM usuarios u LEFT JOIN cuentas_institucionales ci ON ci.usuario_id=u.id AND ci.deleted_at IS NULL WHERE u.persona_id=" . (int)$pid . " AND (u.deleted_at IS NULL OR ci.id IS NOT NULL)");
        foreach ($profiles as $i => $code) {
            $profile = (int)$this->scalar("SELECT id FROM perfiles WHERE codigo=" . $this->db->quote($code) . " LIMIT 1");
            $type = ($existing || $i > 0) ? $typeAdd : $typeCreate;
            $number = 'TTHH-' . date('Ymd-His') . '-' . strtoupper(bin2hex(random_bytes(3)));
            $s = $this->db->prepare("INSERT INTO solicitudes_cuentas(numero_solicitud,persona_id,tipo_solicitud_id,estado_solicitud_id,origen_solicitud_id,perfil_solicitado_id,origen_registro_id,solicitado_por_usuario_id,observacion) VALUES(:n,:p,:t,:e,:o,:pf,:r,:a,:obs)");
            $s->execute(['n' => $number, 'p' => $pid, 't' => $type, 'e' => $state, 'o' => $origin, 'pf' => $profile, 'r' => $rid, 'a' => $actor, 'obs' => 'Solicitud generada automáticamente desde Talento Humano.']);
            $sid = (int)$this->db->lastInsertId();
            $this->db->prepare("INSERT INTO relacion_laboral_solicitudes_cuenta(relacion_laboral_id,solicitud_cuenta_id,tipo_vinculo) VALUES(:r,:s,'ALTA_PERSONAL')")->execute(['r' => $rid, 's' => $sid]);
        }
    }
    private function scalar(string $sql): mixed
    {
        return $this->db->query($sql)->fetchColumn();
    }

    public function accountRequests(): array
    {
        return $this->db->query("SELECT sc.id,sc.numero_solicitud,sc.fecha_solicitud,esc.codigo estado_codigo,esc.nombre estado,
            tsc.nombre tipo,pf.nombre perfil,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,
            e.codigo_empleado
            FROM solicitudes_cuentas sc JOIN estados_solicitud_cuenta esc ON esc.id=sc.estado_solicitud_id
            JOIN tipos_solicitud_cuenta tsc ON tsc.id=sc.tipo_solicitud_id JOIN personas p ON p.id=sc.persona_id
            LEFT JOIN perfiles pf ON pf.id=sc.perfil_solicitado_id LEFT JOIN relacion_laboral_solicitudes_cuenta x ON x.solicitud_cuenta_id=sc.id
            LEFT JOIN relaciones_laborales rl ON rl.id=x.relacion_laboral_id LEFT JOIN empleados e ON e.id=rl.empleado_id
            JOIN origenes_solicitud_cuenta osc ON osc.id=sc.origen_solicitud_id
            WHERE osc.codigo='TTHH' ORDER BY sc.fecha_solicitud DESC,sc.id DESC LIMIT 250")->fetchAll();
    }


    private function syncEmployeeTypes(
        int $employeeId,
        array $typeIds,
        int $actor,
        string $effectiveDate
    ): void {
        $requested = array_values(array_unique(
            array_filter(
                array_map('intval', $typeIds),
                static fn(int $id): bool => $id > 0
            )
        ));

        if (!$requested) {
            throw new RuntimeException(
                'Debe seleccionar al menos un tipo de personal.'
            );
        }

        $s = $this->db->prepare(
            "SELECT id, tipo_personal_id, fecha_inicio, fecha_fin, activo
         FROM empleado_tipos_personal
         WHERE empleado_id = :e
         ORDER BY fecha_inicio, id
         FOR UPDATE"
        );
        $s->execute(['e' => $employeeId]);
        $rows = $s->fetchAll(PDO::FETCH_ASSOC);

        $current = [];

        foreach ($rows as $row) {
            if ((int)$row['activo'] === 1) {
                $current[] = (int)$row['tipo_personal_id'];
            }
        }

        sort($current);
        sort($requested);

        if ($current === $requested) {
            return;
        }

        $active = [];
        $toClose = [];
        $toInsert = [];

        foreach ($rows as $row) {
            $typeId = (int)$row['tipo_personal_id'];

            if ($row['fecha_inicio'] > $effectiveDate) {
                throw new RuntimeException(
                    'Existen clasificaciones posteriores a la fecha efectiva. '
                        . 'Se requiere regularizar primero el historial.'
                );
            }

            if ((int)$row['activo'] !== 1) {
                continue;
            }

            if (isset($active[$typeId])) {
                throw new RuntimeException(
                    'Se encontraron clasificaciones activas duplicadas.'
                );
            }

            if ($row['fecha_fin'] !== null) {
                throw new RuntimeException(
                    'Una clasificación activa tiene fecha de finalización.'
                );
            }

            $active[$typeId] = $row;

            if (!in_array($typeId, $requested, true)) {
                if ($effectiveDate <= $row['fecha_inicio']) {
                    throw new RuntimeException(
                        'La fecha efectiva debe ser posterior al inicio '
                            . 'de la clasificación que se desea finalizar.'
                    );
                }

                $toClose[] = (int)$row['id'];
            }
        }

        foreach ($requested as $typeId) {
            if (isset($active[$typeId])) {
                continue;
            }

            foreach ($rows as $row) {
                if ((int)$row['tipo_personal_id'] !== $typeId) {
                    continue;
                }

                // Impedir duplicados y solapamientos históricos.
                $start = $row['fecha_inicio'];
                $end = $row['fecha_fin'];

                if (
                    $start === $effectiveDate
                    || (
                        $start < $effectiveDate
                        && ($end === null || $end > $effectiveDate)
                    )
                ) {
                    throw new RuntimeException(
                        'La nueva clasificación coincide con un período '
                            . 'histórico existente.'
                    );
                }
            }

            $toInsert[] = $typeId;
        }

        // Solo después de completar las validaciones se modifica la BD.
        if ($toClose) {
            $close = $this->db->prepare(
                "UPDATE empleado_tipos_personal
             SET activo = 0, fecha_fin = :fecha
             WHERE id = :id AND activo = 1"
            );

            foreach ($toClose as $rowId) {
                $close->execute([
                    'fecha' => $effectiveDate,
                    'id' => $rowId
                ]);
            }
        }

        if ($toInsert) {
            $insert = $this->db->prepare(
                "INSERT INTO empleado_tipos_personal
                (empleado_id, tipo_personal_id, fecha_inicio, activo)
             VALUES (:e, :t, :f, 1)"
            );

            foreach ($toInsert as $typeId) {
                $insert->execute([
                    'e' => $employeeId,
                    't' => $typeId,
                    'f' => $effectiveDate
                ]);
            }
        }
    }
}
