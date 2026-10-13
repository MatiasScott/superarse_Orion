<?php
declare(strict_types=1);
namespace App\Repositories;

use PDO;
use RuntimeException;
use Throwable;

final class HumanResourcesRepository
{
    public function __construct(private PDO $db){}

    public function employees(string $q=''): array
    {
        $sql="SELECT e.id,e.codigo_empleado,e.fecha_primer_ingreso,e.activo,
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
                    AND rl.id=(SELECT r2.id FROM relaciones_laborales r2 WHERE r2.empleado_id=e.id ORDER BY (r2.fecha_fin_real IS NULL) DESC,r2.fecha_inicio DESC,r2.id DESC LIMIT 1)
                LEFT JOIN estados_relacion_laboral er ON er.id=rl.estado_relacion_id
                LEFT JOIN asignaciones_laborales al ON al.relacion_laboral_id=rl.id AND al.activo=1 AND al.es_principal=1
                LEFT JOIN cargos c ON c.id=al.cargo_id
                LEFT JOIN unidades_organizacionales uo ON uo.id=al.unidad_organizacional_id
                LEFT JOIN sedes s ON s.id=al.sede_id
               WHERE e.deleted_at IS NULL AND p.deleted_at IS NULL";
        $params=[];
        if($q!==''){
            $sql.=" AND (e.codigo_empleado LIKE :q OR p.numero_identificacion LIKE :q OR p.primer_nombre LIKE :q OR p.segundo_nombre LIKE :q OR p.primer_apellido LIKE :q OR p.segundo_apellido LIKE :q)";
            $params['q']='%'.$q.'%';
        }
        $sql.=" GROUP BY e.id,e.codigo_empleado,e.fecha_primer_ingreso,e.activo,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,er.codigo,er.nombre,c.nombre,uo.nombre,s.nombre,rl.id ORDER BY p.primer_apellido,p.primer_nombre LIMIT 250";
        $s=$this->db->prepare($sql);$s->execute($params);return $s->fetchAll();
    }

    public function employee(int $id): ?array
    {
        $s=$this->db->prepare("SELECT e.*,p.tipo_identificacion_id,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,
            rl.id relacion_laboral_id,rl.tipo_contrato_id,rl.tipo_jornada_id,rl.estado_relacion_id,rl.fecha_inicio,rl.fecha_fin_prevista,rl.fecha_fin_real,rl.numero_contrato,rl.observacion,
            al.id asignacion_id,al.cargo_id,al.unidad_organizacional_id,al.sede_id
            FROM empleados e JOIN personas p ON p.id=e.persona_id
            LEFT JOIN relaciones_laborales rl ON rl.empleado_id=e.id AND rl.id=(SELECT r2.id FROM relaciones_laborales r2 WHERE r2.empleado_id=e.id ORDER BY (r2.fecha_fin_real IS NULL) DESC,r2.fecha_inicio DESC,r2.id DESC LIMIT 1)
            LEFT JOIN asignaciones_laborales al ON al.relacion_laboral_id=rl.id AND al.activo=1 AND al.es_principal=1
            WHERE e.id=:id AND e.deleted_at IS NULL AND p.deleted_at IS NULL LIMIT 1");
        $s->execute(['id'=>$id]);return $s->fetch()?:null;
    }

    public function employeeTypeIds(int $id):array{$s=$this->db->prepare("SELECT tipo_personal_id FROM empleado_tipos_personal WHERE empleado_id=:e AND activo=1");$s->execute(['e'=>$id]);return array_map('intval',array_column($s->fetchAll(),'tipo_personal_id'));}
    public function identificationTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_identificacion WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function personnelTypes():array{return $this->db->query("SELECT id,codigo,nombre,descripcion,genera_perfil_docente,genera_perfil_administrativo FROM tipos_personal WHERE activo=1 ORDER BY id")->fetchAll();}
    public function contractTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_contrato_laboral WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function workdayTypes():array{return $this->db->query("SELECT id,codigo,nombre,horas_semanales FROM tipos_jornada_laboral WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function relationStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_acceso_institucional FROM estados_relacion_laboral WHERE activo=1 ORDER BY id")->fetchAll();}
    public function positions():array{return $this->db->query("SELECT id,codigo,nombre,es_docente,es_administrativo FROM cargos WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}
    public function units():array{return $this->db->query("SELECT id,codigo,nombre FROM unidades_organizacionales WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}
    public function campuses():array{return $this->db->query("SELECT id,codigo,nombre FROM sedes WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}

    public function catalogs():array{return ['positions'=>$this->positions(),'units'=>$this->units(),'campuses'=>$this->campuses()];}
    public function createCatalog(string $type,array $d):void
    {
        $code=strtoupper(trim((string)($d['codigo']??'')));$name=trim((string)($d['nombre']??''));
        if($code===''||$name==='')throw new RuntimeException('Código y nombre son obligatorios.');
        $institution=(int)$this->scalar("SELECT id FROM instituciones WHERE codigo='SUPERARSE' AND activo=1 LIMIT 1");
        if($type==='cargo'){
            $s=$this->db->prepare("INSERT INTO cargos(codigo,nombre,descripcion,es_docente,es_administrativo,activo) VALUES(:c,:n,:d,:ed,:ea,1)");
            $s->execute(['c'=>$code,'n'=>$name,'d'=>trim((string)($d['descripcion']??''))?:null,'ed'=>!empty($d['es_docente'])?1:0,'ea'=>!empty($d['es_administrativo'])?1:0]);return;
        }
        if(!$institution)throw new RuntimeException('No se encontró la institución SUPERARSE.');
        if($type==='unidad'){
            $s=$this->db->prepare("INSERT INTO unidades_organizacionales(institucion_id,codigo,nombre,descripcion,activo) VALUES(:i,:c,:n,:d,1)");
            $s->execute(['i'=>$institution,'c'=>$code,'n'=>$name,'d'=>trim((string)($d['descripcion']??''))?:null]);return;
        }
        if($type==='sede'){
            $s=$this->db->prepare("INSERT INTO sedes(institucion_id,codigo,nombre,descripcion,activo) VALUES(:i,:c,:n,:d,1)");
            $s->execute(['i'=>$institution,'c'=>$code,'n'=>$name,'d'=>trim((string)($d['descripcion']??''))?:null]);return;
        }
        throw new RuntimeException('Catálogo no válido.');
    }

    public function createEmployee(array $d,int $actor): int
    {
        $this->db->beginTransaction();
        try{
            $s=$this->db->prepare("SELECT id FROM personas WHERE tipo_identificacion_id=:t AND numero_identificacion=:n AND deleted_at IS NULL LIMIT 1");
            $s->execute(['t'=>$d['tipo_identificacion_id'],'n'=>$d['numero_identificacion']]);
            $pid=(int)($s->fetchColumn()?:0);
            if($pid){
                $s=$this->db->prepare("SELECT id FROM empleados WHERE persona_id=:p AND deleted_at IS NULL LIMIT 1");$s->execute(['p'=>$pid]);
                if($s->fetchColumn())throw new RuntimeException('Esta persona ya tiene una ficha de Talento Humano.');
                $s=$this->db->prepare("UPDATE personas SET primer_nombre=:pn,segundo_nombre=:sn,primer_apellido=:pa,segundo_apellido=:sa,activo=1 WHERE id=:id");
                $s->execute(['pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null,'id'=>$pid]);
            }else{
                $s=$this->db->prepare("INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,segundo_nombre,primer_apellido,segundo_apellido,activo) VALUES(:t,:n,:pn,:sn,:pa,:sa,1)");
                $s->execute(['t'=>$d['tipo_identificacion_id'],'n'=>$d['numero_identificacion'],'pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null]);$pid=(int)$this->db->lastInsertId();
            }
            $s=$this->db->prepare("INSERT INTO empleados(persona_id,codigo_empleado,fecha_primer_ingreso,activo) VALUES(:p,:c,:f,1)");
            $tmp='TMP-'.bin2hex(random_bytes(8));$s->execute(['p'=>$pid,'c'=>$tmp,'f'=>$d['fecha_inicio']]);$eid=(int)$this->db->lastInsertId();
            $code='EMP-'.str_pad((string)$eid,6,'0',STR_PAD_LEFT);$this->db->prepare("UPDATE empleados SET codigo_empleado=:c WHERE id=:id")->execute(['c'=>$code,'id'=>$eid]);
            $this->insertTypes($eid,$d['tipos_personal'],$d['fecha_inicio']);
            $s=$this->db->prepare("INSERT INTO relaciones_laborales(empleado_id,tipo_contrato_id,tipo_jornada_id,estado_relacion_id,fecha_inicio,fecha_fin_prevista,numero_contrato,observacion,registrado_por_usuario_id) VALUES(:e,:tc,:tj,:er,:fi,:ff,:nc,:o,:a)");
            $s->execute(['e'=>$eid,'tc'=>$d['tipo_contrato_id']?:null,'tj'=>$d['tipo_jornada_id']?:null,'er'=>$d['estado_relacion_id'],'fi'=>$d['fecha_inicio'],'ff'=>$d['fecha_fin_prevista']?:null,'nc'=>$d['numero_contrato']?:null,'o'=>$d['observacion']?:null,'a'=>$actor]);$rid=(int)$this->db->lastInsertId();
            $this->db->prepare("INSERT INTO historial_estado_relacion_laboral(relacion_laboral_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:r,:e,'Alta inicial de personal',:a)")->execute(['r'=>$rid,'e'=>$d['estado_relacion_id'],'a'=>$actor]);
            $this->db->prepare("INSERT INTO asignaciones_laborales(relacion_laboral_id,cargo_id,unidad_organizacional_id,sede_id,fecha_inicio,es_principal,activo,creado_por_usuario_id) VALUES(:r,:c,:u,:s,:f,1,1,:a)")->execute(['r'=>$rid,'c'=>$d['cargo_id'],'u'=>$d['unidad_organizacional_id']?:null,'s'=>$d['sede_id']?:null,'f'=>$d['fecha_inicio'],'a'=>$actor]);
            if(!empty($d['solicitar_cuenta']))$this->createAccountRequests($pid,$rid,$d['tipos_personal'],$actor);
            $this->db->commit();return $eid;
        }catch(Throwable $e){$this->db->rollBack();throw $e;}
    }

    private function insertTypes(int $eid,array $ids,string $start):void
    {
        $s=$this->db->prepare("INSERT INTO empleado_tipos_personal(empleado_id,tipo_personal_id,fecha_inicio,activo) VALUES(:e,:t,:f,1)");
        foreach(array_unique(array_map('intval',$ids)) as $id)if($id>0)$s->execute(['e'=>$eid,'t'=>$id,'f'=>$start]);
    }

    private function createAccountRequests(int $pid,int $rid,array $typeIds,int $actor):void
    {
        $ids=array_values(array_unique(array_map('intval',$typeIds)));if(!$ids)return;
        $in=implode(',',array_fill(0,count($ids),'?'));
        $s=$this->db->prepare("SELECT genera_perfil_docente,genera_perfil_administrativo FROM tipos_personal WHERE id IN ($in)");$s->execute($ids);
        $doc=false;$adm=false;foreach($s->fetchAll() as $r){$doc=$doc||(bool)$r['genera_perfil_docente'];$adm=$adm||(bool)$r['genera_perfil_administrativo'];}
        $profiles=[];
        if($adm)$profiles[]='ADMINISTRATIVO';if($doc)$profiles[]='DOCENTE';if(!$profiles)return;
        $typeCreate=(int)$this->scalar("SELECT id FROM tipos_solicitud_cuenta WHERE codigo='CREACION' LIMIT 1");
        $typeAdd=(int)$this->scalar("SELECT id FROM tipos_solicitud_cuenta WHERE codigo='AGREGAR_PERFIL' LIMIT 1");
        $state=(int)$this->scalar("SELECT id FROM estados_solicitud_cuenta WHERE codigo='PENDIENTE' LIMIT 1");
        $origin=(int)$this->scalar("SELECT id FROM origenes_solicitud_cuenta WHERE codigo='TTHH' LIMIT 1");
        $existing=(bool)$this->scalar("SELECT COUNT(*) FROM usuarios u LEFT JOIN cuentas_institucionales ci ON ci.usuario_id=u.id AND ci.deleted_at IS NULL WHERE u.persona_id=".(int)$pid." AND (u.deleted_at IS NULL OR ci.id IS NOT NULL)");
        foreach($profiles as $i=>$code){
            $profile=(int)$this->scalar("SELECT id FROM perfiles WHERE codigo=".$this->db->quote($code)." LIMIT 1");
            $type=($existing||$i>0)?$typeAdd:$typeCreate;
            $number='TTHH-'.date('Ymd-His').'-'.strtoupper(bin2hex(random_bytes(3)));
            $s=$this->db->prepare("INSERT INTO solicitudes_cuentas(numero_solicitud,persona_id,tipo_solicitud_id,estado_solicitud_id,origen_solicitud_id,perfil_solicitado_id,origen_registro_id,solicitado_por_usuario_id,observacion) VALUES(:n,:p,:t,:e,:o,:pf,:r,:a,:obs)");
            $s->execute(['n'=>$number,'p'=>$pid,'t'=>$type,'e'=>$state,'o'=>$origin,'pf'=>$profile,'r'=>$rid,'a'=>$actor,'obs'=>'Solicitud generada automáticamente desde Talento Humano.']);$sid=(int)$this->db->lastInsertId();
            $this->db->prepare("INSERT INTO relacion_laboral_solicitudes_cuenta(relacion_laboral_id,solicitud_cuenta_id,tipo_vinculo) VALUES(:r,:s,'ALTA_PERSONAL')")->execute(['r'=>$rid,'s'=>$sid]);
        }
    }
    private function scalar(string $sql):mixed{return $this->db->query($sql)->fetchColumn();}

    public function accountRequests():array
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
}
