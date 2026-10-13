<?php
declare(strict_types=1);
namespace App\Repositories;

use PDO;
use RuntimeException;
use Throwable;

final class AdmissionsRepository
{
    public function __construct(private PDO $db){}
    private function scalar(string $sql):mixed{return $this->db->query($sql)->fetchColumn();}
    public function identificationTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_identificacion WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function channels():array{return $this->db->query("SELECT id,codigo,nombre FROM canales_admision WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function entryTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_ingreso_estudiante WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function careers():array{return $this->db->query("SELECT c.id,c.codigo,c.nombre FROM carreras c JOIN estados_carrera e ON e.id=c.estado_carrera_id WHERE c.activo=1 AND c.deleted_at IS NULL AND e.permite_nuevos_ingresos=1 ORDER BY c.nombre")->fetchAll();}
    public function campuses():array{return $this->db->query("SELECT id,codigo,nombre FROM sedes WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}
    public function modalities():array{return $this->db->query("SELECT id,codigo,nombre FROM modalidades_academicas WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function contactTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_contacto_estudiante WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function occupations():array{return $this->db->query("SELECT id,codigo,nombre FROM ocupaciones_estudiante WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function financing():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_financiamiento_estudios WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function familyEducation():array{return $this->db->query("SELECT id,codigo,nombre FROM niveles_formacion_familiar WHERE activo=1 ORDER BY orden_nivel,nombre")->fetchAll();}
    public function schoolTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_colegio WHERE activo=1 ORDER BY nombre")->fetchAll();}

    public function applications(string $q='',string $status=''):array
    {
        $sql="SELECT sa.id,sa.numero_solicitud,sa.fecha_solicitud,esa.codigo estado_codigo,esa.nombre estado,
                     a.codigo_aspirante,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,
                     tie.nombre tipo_ingreso,c.nombre carrera,s.nombre sede,ma.nombre modalidad,
                     cv.estudiante_id,ascu.solicitud_cuenta_id
                FROM solicitudes_admision sa
                JOIN estados_solicitud_admision esa ON esa.id=sa.estado_solicitud_id
                JOIN aspirantes a ON a.id=sa.aspirante_id JOIN personas p ON p.id=a.persona_id
                LEFT JOIN tipos_ingreso_estudiante tie ON tie.id=sa.tipo_ingreso_id
                LEFT JOIN solicitud_admision_carreras sac ON sac.solicitud_admision_id=sa.id AND sac.seleccionada=1
                LEFT JOIN carreras c ON c.id=sac.carrera_id LEFT JOIN sedes s ON s.id=sac.sede_id LEFT JOIN modalidades_academicas ma ON ma.id=sac.modalidad_academica_id
                LEFT JOIN conversiones_admision_estudiante cv ON cv.solicitud_admision_id=sa.id
                LEFT JOIN admision_solicitudes_cuenta ascu ON ascu.solicitud_admision_id=sa.id
               WHERE a.deleted_at IS NULL";
        $params=[];
        if($q!==''){$sql.=" AND (sa.numero_solicitud LIKE :q OR a.codigo_aspirante LIKE :q OR p.numero_identificacion LIKE :q OR CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) LIKE :q)";$params['q']='%'.$q.'%';}
        if($status!==''){$sql.=" AND esa.codigo=:st";$params['st']=$status;}
        $sql.=" ORDER BY sa.fecha_solicitud DESC,sa.id DESC LIMIT 300";$s=$this->db->prepare($sql);$s->execute($params);return $s->fetchAll();
    }
    public function application(int $id):?array
    {
        $s=$this->db->prepare("SELECT sa.*,esa.codigo estado_codigo,esa.nombre estado,a.id aspirante_id,a.codigo_aspirante,a.estado_aspirante_id,p.id persona_id,p.tipo_identificacion_id,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,ca.carrera_id,ca.sede_id,ca.modalidad_academica_id,c.nombre carrera,se.nombre sede,ma.nombre modalidad,cv.estudiante_id,ascu.solicitud_cuenta_id,sc.numero_solicitud solicitud_cuenta_numero,esc.nombre solicitud_cuenta_estado FROM solicitudes_admision sa JOIN estados_solicitud_admision esa ON esa.id=sa.estado_solicitud_id JOIN aspirantes a ON a.id=sa.aspirante_id JOIN personas p ON p.id=a.persona_id LEFT JOIN solicitud_admision_carreras ca ON ca.solicitud_admision_id=sa.id AND ca.seleccionada=1 LEFT JOIN carreras c ON c.id=ca.carrera_id LEFT JOIN sedes se ON se.id=ca.sede_id LEFT JOIN modalidades_academicas ma ON ma.id=ca.modalidad_academica_id LEFT JOIN conversiones_admision_estudiante cv ON cv.solicitud_admision_id=sa.id LEFT JOIN admision_solicitudes_cuenta ascu ON ascu.solicitud_admision_id=sa.id LEFT JOIN solicitudes_cuentas sc ON sc.id=ascu.solicitud_cuenta_id LEFT JOIN estados_solicitud_cuenta esc ON esc.id=sc.estado_solicitud_id WHERE sa.id=:id LIMIT 1");$s->execute(['id'=>$id]);return $s->fetch()?:null;
    }
    public function applicationHistory(int $id):array{$s=$this->db->prepare("SELECT h.changed_at,ea.nombre estado_anterior,en.nombre estado_nuevo,h.motivo,CONCAT_WS(' ',p.primer_nombre,p.primer_apellido) actor FROM historial_estado_solicitud_admision h LEFT JOIN estados_solicitud_admision ea ON ea.id=h.estado_anterior_id JOIN estados_solicitud_admision en ON en.id=h.estado_nuevo_id LEFT JOIN usuarios u ON u.id=h.cambiado_por_usuario_id LEFT JOIN personas p ON p.id=u.persona_id WHERE h.solicitud_admision_id=:id ORDER BY h.changed_at DESC,h.id DESC");$s->execute(['id'=>$id]);return $s->fetchAll();}

    public function createApplication(array $d,int $actor):int
    {
        $this->db->beginTransaction();try{
            $s=$this->db->prepare("SELECT id FROM personas WHERE tipo_identificacion_id=:t AND numero_identificacion=:n AND deleted_at IS NULL LIMIT 1");$s->execute(['t'=>$d['tipo_identificacion_id'],'n'=>$d['numero_identificacion']]);$pid=(int)($s->fetchColumn()?:0);
            if($pid){$this->db->prepare("UPDATE personas SET primer_nombre=:pn,segundo_nombre=:sn,primer_apellido=:pa,segundo_apellido=:sa,activo=1 WHERE id=:id")->execute(['pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null,'id'=>$pid]);}
            else{$s=$this->db->prepare("INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,segundo_nombre,primer_apellido,segundo_apellido,activo) VALUES(:t,:n,:pn,:sn,:pa,:sa,1)");$s->execute(['t'=>$d['tipo_identificacion_id'],'n'=>$d['numero_identificacion'],'pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null]);$pid=(int)$this->db->lastInsertId();}
            $s=$this->db->prepare("SELECT id FROM aspirantes WHERE persona_id=:p AND deleted_at IS NULL LIMIT 1");$s->execute(['p'=>$pid]);$aid=(int)($s->fetchColumn()?:0);
            $aspState=(int)$this->scalar("SELECT id FROM estados_aspirante WHERE codigo='EN_PROCESO' LIMIT 1");
            if(!$aid){$tmp='TMP-'.bin2hex(random_bytes(6));$s=$this->db->prepare("INSERT INTO aspirantes(persona_id,estado_aspirante_id,codigo_aspirante,canal_admision_id,observacion,activo) VALUES(:p,:e,:c,:ca,:o,1)");$s->execute(['p'=>$pid,'e'=>$aspState,'c'=>$tmp,'ca'=>$d['canal_admision_id']?:null,'o'=>$d['observacion']?:null]);$aid=(int)$this->db->lastInsertId();$this->db->prepare("UPDATE aspirantes SET codigo_aspirante=:c WHERE id=:id")->execute(['c'=>'ASP-'.str_pad((string)$aid,6,'0',STR_PAD_LEFT),'id'=>$aid]);$this->db->prepare("INSERT INTO historial_estado_aspirante(aspirante_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:a,:e,'Registro inicial de admisión',:u)")->execute(['a'=>$aid,'e'=>$aspState,'u'=>$actor]);}
            else{$this->db->prepare("UPDATE aspirantes SET estado_aspirante_id=:e,canal_admision_id=:c,fecha_ultima_interaccion=NOW(),observacion=:o WHERE id=:id")->execute(['e'=>$aspState,'c'=>$d['canal_admision_id']?:null,'o'=>$d['observacion']?:null,'id'=>$aid]);}
            $state=(int)$this->scalar("SELECT id FROM estados_solicitud_admision WHERE codigo='ENVIADA' LIMIT 1");$tmp='ADM-TMP-'.bin2hex(random_bytes(5));$s=$this->db->prepare("INSERT INTO solicitudes_admision(numero_solicitud,aspirante_id,estado_solicitud_id,tipo_ingreso_id,observacion) VALUES(:n,:a,:e,:t,:o)");$s->execute(['n'=>$tmp,'a'=>$aid,'e'=>$state,'t'=>$d['tipo_ingreso_id']?:null,'o'=>$d['observacion']?:null]);$sid=(int)$this->db->lastInsertId();$number='ADM-'.date('Ymd').'-'.str_pad((string)$sid,6,'0',STR_PAD_LEFT);$this->db->prepare("UPDATE solicitudes_admision SET numero_solicitud=:n WHERE id=:id")->execute(['n'=>$number,'id'=>$sid]);
            $this->db->prepare("INSERT INTO historial_estado_solicitud_admision(solicitud_admision_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:s,:e,'Solicitud registrada y enviada',:u)")->execute(['s'=>$sid,'e'=>$state,'u'=>$actor]);
            if($d['carrera_id'])$this->db->prepare("INSERT INTO solicitud_admision_carreras(solicitud_admision_id,carrera_id,sede_id,modalidad_academica_id,prioridad,seleccionada) VALUES(:s,:c,:se,:m,1,1)")->execute(['s'=>$sid,'c'=>$d['carrera_id'],'se'=>$d['sede_id']?:null,'m'=>$d['modalidad_id']?:null]);
            $this->db->commit();return $sid;
        }catch(Throwable $e){$this->db->rollBack();throw $e;}
    }

    public function setReview(int $id,int $actor):void{$this->transition($id,'EN_REVISION',$actor,'Solicitud tomada en revisión por Admisiones.');}
    public function reject(int $id,int $actor,string $reason):void{if(trim($reason)==='')throw new RuntimeException('El motivo de rechazo es obligatorio.');$this->transition($id,'RECHAZADA',$actor,$reason,true);}
    private function transition(int $id,string $code,int $actor,string $reason,bool $reject=false):void
    {
        $a=$this->application($id);if(!$a)throw new RuntimeException('Solicitud no encontrada.');$new=(int)$this->scalar("SELECT id FROM estados_solicitud_admision WHERE codigo=".$this->db->quote($code)." LIMIT 1");
        $sql="UPDATE solicitudes_admision SET estado_solicitud_id=:e".($code==='EN_REVISION'?",fecha_revision=NOW(),revisado_por_usuario_id=:u":",fecha_resolucion=NOW(),resuelto_por_usuario_id=:u").($reject?",motivo_rechazo=:r":"")." WHERE id=:id";$p=['e'=>$new,'u'=>$actor,'id'=>$id];if($reject)$p['r']=$reason;$this->db->prepare($sql)->execute($p);
        $this->db->prepare("INSERT INTO historial_estado_solicitud_admision(solicitud_admision_id,estado_anterior_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:s,:o,:n,:m,:u)")->execute(['s'=>$id,'o'=>$a['estado_solicitud_id'],'n'=>$new,'m'=>$reason,'u'=>$actor]);
        if($reject){$asp=(int)$this->scalar("SELECT id FROM estados_aspirante WHERE codigo='NO_ADMITIDO' LIMIT 1");$this->db->prepare("UPDATE aspirantes SET estado_aspirante_id=:e WHERE id=:a")->execute(['e'=>$asp,'a'=>$a['aspirante_id']]);}
    }

    public function approve(int $id,int $actor):int
    {
        $this->db->beginTransaction();try{
            $a=$this->application($id);if(!$a)throw new RuntimeException('Solicitud no encontrada.');if($a['estado_codigo']==='APROBADA' && $a['estudiante_id']){$this->db->commit();return (int)$a['estudiante_id'];}
            if(!$a['carrera_id'])throw new RuntimeException('La solicitud debe tener una carrera seleccionada antes de aprobarse.');
            $approved=(int)$this->scalar("SELECT id FROM estados_solicitud_admision WHERE codigo='APROBADA' LIMIT 1");
            $this->db->prepare("UPDATE solicitudes_admision SET estado_solicitud_id=:e,fecha_resolucion=NOW(),resuelto_por_usuario_id=:u WHERE id=:id")->execute(['e'=>$approved,'u'=>$actor,'id'=>$id]);
            $this->db->prepare("INSERT INTO historial_estado_solicitud_admision(solicitud_admision_id,estado_anterior_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:s,:o,:n,'Solicitud aprobada por Admisiones',:u)")->execute(['s'=>$id,'o'=>$a['estado_solicitud_id'],'n'=>$approved,'u'=>$actor]);
            $asp=(int)$this->scalar("SELECT id FROM estados_aspirante WHERE codigo='ADMITIDO' LIMIT 1");$this->db->prepare("UPDATE aspirantes SET estado_aspirante_id=:e,fecha_ultima_interaccion=NOW() WHERE id=:a")->execute(['e'=>$asp,'a'=>$a['aspirante_id']]);
            $s=$this->db->prepare("SELECT id FROM estudiantes WHERE persona_id=:p AND deleted_at IS NULL LIMIT 1");$s->execute(['p'=>$a['persona_id']]);$eid=(int)($s->fetchColumn()?:0);
            if(!$eid){$st=(int)$this->scalar("SELECT id FROM estados_estudiante WHERE codigo='PREMATRICULADO' LIMIT 1");$tmp='TMP-'.bin2hex(random_bytes(6));$s=$this->db->prepare("INSERT INTO estudiantes(persona_id,estado_estudiante_id,codigo_estudiante,fecha_ingreso,activo) VALUES(:p,:e,:c,CURDATE(),1)");$s->execute(['p'=>$a['persona_id'],'e'=>$st,'c'=>$tmp]);$eid=(int)$this->db->lastInsertId();$this->db->prepare("UPDATE estudiantes SET codigo_estudiante=:c WHERE id=:id")->execute(['c'=>'EST-'.str_pad((string)$eid,6,'0',STR_PAD_LEFT),'id'=>$eid]);$this->db->prepare("INSERT INTO historial_estado_estudiante(estudiante_id,estado_nuevo_id,motivo,cambiado_por_usuario_id) VALUES(:e,:s,'Conversión desde admisión aprobada',:u)")->execute(['e'=>$eid,'s'=>$st,'u'=>$actor]);}
            $s=$this->db->prepare("SELECT id FROM conversiones_admision_estudiante WHERE solicitud_admision_id=:s LIMIT 1");$s->execute(['s'=>$id]);if(!$s->fetchColumn())$this->db->prepare("INSERT INTO conversiones_admision_estudiante(solicitud_admision_id,estudiante_id,convertido_por_usuario_id,observacion) VALUES(:s,:e,:u,'Conversión automática por aprobación de admisión')")->execute(['s'=>$id,'e'=>$eid,'u'=>$actor]);
            $this->ensureAccountRequest($a,$id,$actor);
            $this->db->commit();return $eid;
        }catch(Throwable $e){$this->db->rollBack();throw $e;}
    }
    private function ensureAccountRequest(array $a,int $admissionId,int $actor):void
    {
        $s=$this->db->prepare("SELECT solicitud_cuenta_id FROM admision_solicitudes_cuenta WHERE solicitud_admision_id=:s LIMIT 1");$s->execute(['s'=>$admissionId]);if($s->fetchColumn())return;
        $existing=(bool)$this->scalar("SELECT COUNT(*) FROM usuarios u LEFT JOIN cuentas_institucionales ci ON ci.usuario_id=u.id AND ci.deleted_at IS NULL WHERE u.persona_id=".(int)$a['persona_id']." AND (u.deleted_at IS NULL OR ci.id IS NOT NULL)");
        $type=(int)$this->scalar("SELECT id FROM tipos_solicitud_cuenta WHERE codigo=".$this->db->quote($existing?'AGREGAR_PERFIL':'CREACION')." LIMIT 1");$state=(int)$this->scalar("SELECT id FROM estados_solicitud_cuenta WHERE codigo='PENDIENTE' LIMIT 1");$origin=(int)$this->scalar("SELECT id FROM origenes_solicitud_cuenta WHERE codigo='ADMISIONES' LIMIT 1");$profile=(int)$this->scalar("SELECT id FROM perfiles WHERE codigo='ESTUDIANTE' LIMIT 1");$license=(int)$this->scalar("SELECT id FROM tipos_licencia_institucional WHERE codigo='A1_ESTUDIANTE' LIMIT 1");
        $number='ADM-CUENTA-'.date('Ymd-His').'-'.strtoupper(bin2hex(random_bytes(2)));$s=$this->db->prepare("INSERT INTO solicitudes_cuentas(numero_solicitud,persona_id,tipo_solicitud_id,estado_solicitud_id,origen_solicitud_id,perfil_solicitado_id,tipo_licencia_solicitada_id,origen_registro_id,solicitado_por_usuario_id,observacion) VALUES(:n,:p,:t,:e,:o,:pf,:l,:r,:u,'Solicitud generada automáticamente desde Admisiones.')");$s->execute(['n'=>$number,'p'=>$a['persona_id'],'t'=>$type,'e'=>$state,'o'=>$origin,'pf'=>$profile,'l'=>$license?:null,'r'=>$admissionId,'u'=>$actor]);$cid=(int)$this->db->lastInsertId();$this->db->prepare("INSERT INTO admision_solicitudes_cuenta(solicitud_admision_id,solicitud_cuenta_id) VALUES(:a,:c)")->execute(['a'=>$admissionId,'c'=>$cid]);
    }

    public function students(string $q=''):array
    {
        $sql="SELECT e.id,e.codigo_estudiante,e.fecha_ingreso,ee.codigo estado_codigo,ee.nombre estado,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,ci.email_institucional FROM estudiantes e JOIN estados_estudiante ee ON ee.id=e.estado_estudiante_id JOIN personas p ON p.id=e.persona_id LEFT JOIN usuarios u ON u.persona_id=p.id AND u.deleted_at IS NULL LEFT JOIN cuentas_institucionales ci ON ci.usuario_id=u.id AND ci.deleted_at IS NULL WHERE e.deleted_at IS NULL";$params=[];if($q!==''){$sql.=" AND (e.codigo_estudiante LIKE :q_codigo OR p.numero_identificacion LIKE :q_identificacion OR CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) LIKE :q_nombre OR ci.email_institucional LIKE :q_correo)";$busqueda='%'.$q.'%';$params=['q_codigo'=>$busqueda,'q_identificacion'=>$busqueda,'q_nombre'=>$busqueda,'q_correo'=>$busqueda];}$sql.=" ORDER BY p.primer_apellido,p.primer_nombre LIMIT 300";$s=$this->db->prepare($sql);$s->execute($params);return $s->fetchAll();
    }
    public function student(int $id):?array{$s=$this->db->prepare("SELECT e.*,ee.codigo estado_codigo,ee.nombre estado,p.numero_identificacion,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,ci.email_institucional FROM estudiantes e JOIN estados_estudiante ee ON ee.id=e.estado_estudiante_id JOIN personas p ON p.id=e.persona_id LEFT JOIN usuarios u ON u.persona_id=p.id AND u.deleted_at IS NULL LEFT JOIN cuentas_institucionales ci ON ci.usuario_id=u.id AND ci.deleted_at IS NULL WHERE e.id=:id AND e.deleted_at IS NULL LIMIT 1");$s->execute(['id'=>$id]);return $s->fetch()?:null;}
    public function contacts(int $id):array{$s=$this->db->prepare("SELECT ec.*,tc.nombre tipo FROM estudiante_contactos ec JOIN tipos_contacto_estudiante tc ON tc.id=ec.tipo_contacto_id WHERE ec.estudiante_id=:e AND ec.activo=1 AND ec.deleted_at IS NULL ORDER BY ec.es_principal DESC,ec.id DESC");$s->execute(['e'=>$id]);return $s->fetchAll();}
    public function socio(int $id):?array{$s=$this->db->prepare("SELECT s.*, DATE_ADD(s.vigente_desde, INTERVAL ".$this->socioUpdateMonths()." MONTH) proxima_actualizacion,o.nombre ocupacion,f.nombre financiamiento,tc.nombre tipo_colegio,np.nombre formacion_padre,nm.nombre formacion_madre FROM estudiante_datos_socioeconomicos s LEFT JOIN ocupaciones_estudiante o ON o.id=s.ocupacion_id LEFT JOIN tipos_financiamiento_estudios f ON f.id=s.financiamiento_estudios_id LEFT JOIN tipos_colegio tc ON tc.id=s.tipo_colegio_id LEFT JOIN niveles_formacion_familiar np ON np.id=s.nivel_formacion_padre_id LEFT JOIN niveles_formacion_familiar nm ON nm.id=s.nivel_formacion_madre_id WHERE s.estudiante_id=:e AND s.vigente_hasta IS NULL ORDER BY s.vigente_desde DESC,s.id DESC LIMIT 1");$s->execute(['e'=>$id]);return $s->fetch()?:null;}
    public function socioHistory(int $id):array{$months=$this->socioUpdateMonths();$s=$this->db->prepare("SELECT s.*, DATE_ADD(s.vigente_desde, INTERVAL ".$months." MONTH) proxima_actualizacion, CASE WHEN s.vigente_hasta IS NOT NULL THEN 'HISTORICA' WHEN DATE_ADD(s.vigente_desde, INTERVAL ".$months." MONTH) <= CURDATE() THEN 'REQUIERE_ACTUALIZACION' ELSE 'VIGENTE' END estado_ficha,o.nombre ocupacion,f.nombre financiamiento,tc.nombre tipo_colegio,np.nombre formacion_padre,nm.nombre formacion_madre,CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) registrado_por FROM estudiante_datos_socioeconomicos s LEFT JOIN ocupaciones_estudiante o ON o.id=s.ocupacion_id LEFT JOIN tipos_financiamiento_estudios f ON f.id=s.financiamiento_estudios_id LEFT JOIN tipos_colegio tc ON tc.id=s.tipo_colegio_id LEFT JOIN niveles_formacion_familiar np ON np.id=s.nivel_formacion_padre_id LEFT JOIN niveles_formacion_familiar nm ON nm.id=s.nivel_formacion_madre_id LEFT JOIN usuarios u ON u.id=s.registrado_por_usuario_id LEFT JOIN personas p ON p.id=u.persona_id WHERE s.estudiante_id=:e ORDER BY s.vigente_desde DESC,s.id DESC");$s->execute(['e'=>$id]);return $s->fetchAll();}

    private function socioUpdateMonths():int
    {
        $s=$this->db->query("SELECT valor_defecto_texto FROM parametros_sistema WHERE codigo='SOCIOECONOMICO_ACTUALIZACION_MESES' AND activo=1 LIMIT 1");
        $months=(int)($s->fetchColumn()?:6);
        return max(1,min(60,$months));
    }
    public function addContact(int $student,array $d):void{$this->db->prepare("INSERT INTO estudiante_contactos(estudiante_id,tipo_contacto_id,nombres,apellidos,parentesco,telefono,correo,direccion,es_principal,activo) VALUES(:e,:t,:n,:a,:p,:tel,:c,:d,:pr,1)")->execute(['e'=>$student,'t'=>$d['tipo'],'n'=>$d['nombres'],'a'=>$d['apellidos']?:null,'p'=>$d['parentesco']?:null,'tel'=>$d['telefono']?:null,'c'=>$d['correo']?:null,'d'=>$d['direccion']?:null,'pr'=>$d['principal']?1:0]);}
    public function saveSocio(int $student,array $d,int $actor):void{$this->db->prepare("UPDATE estudiante_datos_socioeconomicos SET vigente_hasta=CURDATE() WHERE estudiante_id=:e AND vigente_hasta IS NULL")->execute(['e'=>$student]);$this->db->prepare("INSERT INTO estudiante_datos_socioeconomicos(estudiante_id,ocupacion_id,financiamiento_estudios_id,recibe_bono_desarrollo_humano,nivel_formacion_padre_id,nivel_formacion_madre_id,ingresos_hogar,numero_miembros_hogar,tipo_colegio_id,tiene_ayuda_economica,valor_ayuda_economica,vigente_desde,registrado_por_usuario_id) VALUES(:e,:o,:f,:b,:np,:nm,:i,:m,:tc,:a,:v,CURDATE(),:u)")->execute(['e'=>$student,'o'=>$d['ocupacion']?:null,'f'=>$d['financiamiento']?:null,'b'=>$d['bono'],'np'=>$d['nivel_padre']?:null,'nm'=>$d['nivel_madre']?:null,'i'=>$d['ingresos']?:null,'m'=>$d['miembros']?:null,'tc'=>$d['tipo_colegio']?:null,'a'=>$d['ayuda'],'v'=>$d['valor_ayuda']?:null,'u'=>$actor]);}
}
