<?php
declare(strict_types=1);
namespace App\Repositories;
use PDO; use RuntimeException; use Throwable;
final class CohortCapacityRepository {
 public function __construct(private PDO $db){}
 public function all():array {return $this->db->query("SELECT r.*,oa.nombre oferta_nombre,c.nombre carrera_nombre,n.nombre nivel_nombre,p.codigo paralelo FROM solicitudes_cupos_cohorte r JOIN ofertas_academicas oa ON oa.id=r.oferta_academica_id JOIN carreras c ON c.id=oa.carrera_id JOIN niveles_academicos n ON n.id=r.nivel_academico_id JOIN paralelos p ON p.id=r.paralelo_id ORDER BY (r.estado='PENDIENTE') DESC,r.solicitado_en DESC LIMIT 150")->fetchAll();}
 private function sections(int $offer,int $level,int $parallel):array {
  $q=$this->db->prepare("SELECT s.id,s.cupo_maximo FROM secciones s JOIN malla_asignaturas ma ON ma.id=s.malla_asignatura_id WHERE s.oferta_academica_id=? AND ma.nivel_academico_id=? AND s.paralelo_id=? AND s.activo=1 AND s.deleted_at IS NULL ORDER BY s.id FOR UPDATE");$q->execute([$offer,$level,$parallel]);return $q->fetchAll();
 }
 private function occupied(int $offer,int $level,int $parallel):int {
  $q=$this->db->prepare("SELECT COUNT(DISTINCT m.estudiante_carrera_id) FROM secciones s JOIN malla_asignaturas mas ON mas.id=s.malla_asignatura_id JOIN matricula_asignaturas ma ON ma.seccion_id=s.id AND ma.activo=1 JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id JOIN matriculas m ON m.id=ma.matricula_id AND m.activo=1 JOIN estados_matricula em ON em.id=m.estado_matricula_id WHERE s.oferta_academica_id=? AND mas.nivel_academico_id=? AND s.paralelo_id=? AND s.activo=1 AND s.deleted_at IS NULL AND em.codigo IN ('CONFIRMADA','EN_CURSO','PENDIENTE_FINANCIERO','PENDIENTE_VALIDACION') AND ema.codigo<>'ANULADA'");$q->execute([$offer,$level,$parallel]);return (int)$q->fetchColumn();
 }
 public function request(int $offer,int $level,int $parallel,int $quantity,string $reason,int $actor):void {
  if(min($offer,$level,$parallel,$actor)<1||$quantity<1||$quantity>100||mb_strlen($reason)<10)throw new RuntimeException('Datos inválidos: solicita entre 1 y 100 cupos y justifica con al menos 10 caracteres.');
  $this->db->beginTransaction();try{
   $lock=$this->db->prepare('SELECT id FROM ofertas_academicas WHERE id=? FOR UPDATE');$lock->execute([$offer]);if(!$lock->fetchColumn())throw new RuntimeException('Oferta no encontrada.');
   $sections=$this->sections($offer,$level,$parallel);if(!$sections)throw new RuntimeException('No hay secciones activas en la cohorte.');
   $caps=array_unique(array_map(static fn($s)=>(int)$s['cupo_maximo'],$sections));if(count($caps)!==1||min($caps)<1)throw new RuntimeException('Los cupos de las asignaturas no coinciden. Requieren conciliación antes de solicitar.');
   $capacity=(int)reset($caps);if($this->occupied($offer,$level,$parallel)<$capacity)throw new RuntimeException('La cohorte todavía tiene cupos disponibles.');
   $q=$this->db->prepare("SELECT COUNT(*) FROM solicitudes_cupos_cohorte WHERE oferta_academica_id=? AND nivel_academico_id=? AND paralelo_id=? AND estado='PENDIENTE'");$q->execute([$offer,$level,$parallel]);if((int)$q->fetchColumn()>0)throw new RuntimeException('Ya existe una solicitud pendiente para esta cohorte.');
   $q=$this->db->prepare('INSERT INTO solicitudes_cupos_cohorte(oferta_academica_id,nivel_academico_id,paralelo_id,cantidad_solicitada,motivo,solicitado_por_usuario_id,cupo_anterior) VALUES(?,?,?,?,?,?,?)');$q->execute([$offer,$level,$parallel,$quantity,$reason,$actor,$capacity]);$this->db->commit();
  }catch(Throwable $e){$this->db->rollBack();throw $e;}
 }
 public function resolve(int $id,bool $approve,string $note,int $actor):void {
  if($id<1||$actor<1||mb_strlen($note)<5)throw new RuntimeException('Se requiere observación de al menos 5 caracteres.');
  $this->db->beginTransaction();try{
   $q=$this->db->prepare('SELECT * FROM solicitudes_cupos_cohorte WHERE id=? FOR UPDATE');$q->execute([$id]);$r=$q->fetch();if(!$r||$r['estado']!=='PENDIENTE')throw new RuntimeException('Solicitud inexistente o ya resuelta.');
   if((int)$r['solicitado_por_usuario_id']===$actor)throw new RuntimeException('No puedes resolver tu propia solicitud.');
   $lock=$this->db->prepare('SELECT id FROM ofertas_academicas WHERE id=? FOR UPDATE');$lock->execute([(int)$r['oferta_academica_id']]);
   $sections=$this->sections((int)$r['oferta_academica_id'],(int)$r['nivel_academico_id'],(int)$r['paralelo_id']);if(!$sections)throw new RuntimeException('La cohorte no tiene secciones activas.');
   $caps=array_unique(array_map(static fn($s)=>(int)$s['cupo_maximo'],$sections));if(count($caps)!==1)throw new RuntimeException('Cupos inconsistentes: requiere conciliación.');
   $old=(int)reset($caps);if($old<1||$old>100000)throw new RuntimeException('Cupo fuera de rango.');
   $new=$old+($approve?(int)$r['cantidad_solicitada']:0);if($new>100000)throw new RuntimeException('El cupo resultante supera el límite técnico.');
   if($approve){$update=$this->db->prepare('UPDATE secciones SET cupo_maximo=? WHERE id=?');foreach($sections as $s){$update->execute([$new,(int)$s['id']]);}}
   $q=$this->db->prepare("UPDATE solicitudes_cupos_cohorte SET estado=?,resuelto_por_usuario_id=?,resuelto_en=NOW(),observacion_resolucion=?,cupo_anterior=?,cupo_nuevo=? WHERE id=? AND estado='PENDIENTE'");$q->execute([$approve?'APROBADA':'RECHAZADA',$actor,$note,$old,$new,$id]);$this->db->commit();
  }catch(Throwable $e){$this->db->rollBack();throw $e;}
 }
}
