<?php
declare(strict_types=1);
namespace App\Repositories;
use PDO; use RuntimeException; use Throwable;
final class CapacityRequestRepository {
 public function __construct(private PDO $db) {}
 public function pendingCount(): int {return (int)$this->db->query("SELECT COUNT(*) FROM solicitudes_ampliacion_cupos WHERE estado='PENDIENTE'")->fetchColumn();}
 public function all(): array {return $this->db->query("SELECT r.*,s.codigo seccion_codigo,s.nombre seccion_nombre,s.cupo_maximo FROM solicitudes_ampliacion_cupos r JOIN secciones s ON s.id=r.seccion_id ORDER BY (r.estado='PENDIENTE') DESC,r.solicitado_en DESC LIMIT 150")->fetchAll();}
 public function request(int $section,int $quantity,string $reason,int $actor): void {
  if($section<1||$quantity<1||$quantity>100||mb_strlen($reason)<10||$actor<1)throw new RuntimeException('Indica entre 1 y 100 cupos, y una justificación de al menos 10 caracteres.');
  $this->db->beginTransaction();try{
   $s=$this->db->prepare('SELECT id,cupo_maximo FROM secciones WHERE id=? AND activo=1 AND deleted_at IS NULL FOR UPDATE');$s->execute([$section]);$sec=$s->fetch();if(!$sec)throw new RuntimeException('Sección inexistente o inactiva.');
   $q=$this->db->prepare("SELECT COUNT(DISTINCT ma.matricula_id) FROM matricula_asignaturas ma JOIN estados_matricula_asignatura em ON em.id=ma.estado_matricula_asignatura_id JOIN matriculas m ON m.id=ma.matricula_id JOIN estados_matricula emm ON emm.id=m.estado_matricula_id WHERE ma.seccion_id=? AND ma.activo=1 AND m.activo=1 AND em.codigo<>'ANULADA' AND emm.codigo<>'ANULADA'");$q->execute([$section]);$occupied=(int)$q->fetchColumn();
   if($sec['cupo_maximo']===null || (int)$sec['cupo_maximo']<=0)throw new RuntimeException('La sección no tiene un cupo autorizado válido.');
   if($occupied<(int)$sec['cupo_maximo'])throw new RuntimeException('La sección aún tiene cupos disponibles.');
   $q=$this->db->prepare("SELECT COUNT(*) FROM solicitudes_ampliacion_cupos WHERE seccion_id=? AND estado='PENDIENTE'");$q->execute([$section]);if((int)$q->fetchColumn()>0)throw new RuntimeException('Ya existe una solicitud pendiente para esta sección.');
   $i=$this->db->prepare("INSERT INTO solicitudes_ampliacion_cupos(seccion_id,cantidad_solicitada,motivo,solicitado_por_usuario_id) VALUES(?,?,?,?)");$i->execute([$section,$quantity,$reason,$actor]);$this->db->commit();
  }catch(Throwable $e){$this->db->rollBack();throw $e;}
 }
 public function resolve(int $id,bool $approve,string $note,int $actor): void {
  if($id<1||$actor<1||mb_strlen($note)<5)throw new RuntimeException('La resolución requiere una observación de al menos 5 caracteres.');
  $this->db->beginTransaction();try{
   $q=$this->db->prepare('SELECT * FROM solicitudes_ampliacion_cupos WHERE id=? FOR UPDATE');$q->execute([$id]);$r=$q->fetch();if(!$r||$r['estado']!=='PENDIENTE')throw new RuntimeException('La solicitud ya fue resuelta o no existe.');
   if((int)$r['solicitado_por_usuario_id']===$actor)throw new RuntimeException('No puedes aprobar o rechazar tu propia solicitud.');
   $q=$this->db->prepare('SELECT cupo_maximo FROM secciones WHERE id=? AND activo=1 AND deleted_at IS NULL FOR UPDATE');$q->execute([(int)$r['seccion_id']]);$old=$q->fetchColumn();if($old===false||$old===null)throw new RuntimeException('La sección no tiene un cupo válido.');
   $new=(int)$old+($approve?(int)$r['cantidad_solicitada']:0);if($new>100000)throw new RuntimeException('Cupo resultante fuera de rango.');
   if($approve){$u=$this->db->prepare('UPDATE secciones SET cupo_maximo=? WHERE id=?');$u->execute([$new,(int)$r['seccion_id']]);}
   $u=$this->db->prepare("UPDATE solicitudes_ampliacion_cupos SET estado=?,resuelto_por_usuario_id=?,resuelto_en=NOW(),observacion_resolucion=?,cupo_anterior=?,cupo_nuevo=? WHERE id=? AND estado='PENDIENTE'");
   $u->execute([$approve?'APROBADA':'RECHAZADA',$actor,$note,(int)$old,$new,$id]);$this->db->commit();
  }catch(Throwable $e){$this->db->rollBack();throw $e;}
 }
}
