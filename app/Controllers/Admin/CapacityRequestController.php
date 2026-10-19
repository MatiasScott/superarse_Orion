<?php
declare(strict_types=1);
namespace App\Controllers\Admin;
use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\CapacityRequestRepository;
use App\Services\AccessService;
use Throwable;
final class CapacityRequestController {
 private function repo():CapacityRequestRepository{return new CapacityRequestRepository(Container::get(Database::class)->connection());}
 private function actor():int{return (int)(Session::get('auth_user')['id']??0);}
 private function csrf(Request $r):void{if(!Csrf::validate((string)$r->input('_csrf')))Response::abort(419,'CSRF inválido.');}
 public function index(Request $r):void{AccessService::require('tic.cuentas.aprobar');View::render('admin/tic/cupos',['title'=>'Solicitudes de ampliación de cupos','requests'=>$this->repo()->all(),'flash'=>Session::get('capacity_flash')]);Session::set('capacity_flash',null);}
 public function academicIndex(Request $r):void{
  AccessService::require('academico.matriculas.ver');
  $db=Container::get(Database::class)->connection();
  $period=(int)$r->input('periodo'); $search=trim((string)$r->input('buscar'));
  $periods=$db->query("SELECT id,nombre FROM periodos_academicos WHERE deleted_at IS NULL ORDER BY fecha_inicio DESC LIMIT 30")->fetchAll();
  if($period===0 && $periods){$period=(int)$periods[0]['id'];}
  $sql="SELECT s.id,s.codigo,s.nombre,s.cupo_maximo,s.permite_matricula,p.codigo paralelo,oa.nombre oferta_nombre,pa.nombre periodo_nombre,
   (SELECT COUNT(DISTINCT ma.matricula_id) FROM matricula_asignaturas ma JOIN estados_matricula_asignatura em ON em.id=ma.estado_matricula_asignatura_id WHERE ma.seccion_id=s.id AND ma.activo=1 AND em.codigo<>'ANULADA') ocupados,
   (SELECT COUNT(*) FROM solicitudes_ampliacion_cupos sc WHERE sc.seccion_id=s.id AND sc.estado='PENDIENTE') pendientes
   FROM secciones s JOIN ofertas_academicas oa ON oa.id=s.oferta_academica_id JOIN periodos_academicos pa ON pa.id=oa.periodo_academico_id LEFT JOIN paralelos p ON p.id=s.paralelo_id WHERE s.deleted_at IS NULL AND s.activo=1 AND oa.periodo_academico_id=:periodo";
  $params=['periodo'=>$period];
  if($search!==''){$sql.=" AND (s.codigo LIKE :q1 OR s.nombre LIKE :q2 OR oa.nombre LIKE :q3)";$params['q1']='%'.$search.'%';$params['q2']='%'.$search.'%';$params['q3']='%'.$search.'%';}
  $sql.=' ORDER BY oa.nombre,s.nombre,s.id LIMIT 300';
  $q=$db->prepare($sql);$q->execute($params);
  $flash=Session::get('capacity_flash');Session::set('capacity_flash',null);
  View::render('admin/academico/cupos/index',['title'=>'Control de cupos','sections'=>$q->fetchAll(),'periods'=>$periods,'period'=>$period,'search'=>$search,'flash'=>$flash]);
 }
 public function request(Request $r):never{
  $this->csrf($r);AccessService::require('academico.matriculas.gestionar');$id=(int)$r->input('seccion_id');
  try{$this->repo()->request($id,(int)$r->input('cantidad'),trim((string)$r->input('motivo')),$this->actor());Session::set('capacity_flash',['type'=>'success','message'=>'Solicitud enviada a Coordinación TICs.']);}
  catch(Throwable $e){Session::set('capacity_flash',['type'=>'error','message'=>$e->getMessage()]);}
  Response::redirect('/admin/academico/cupos');
 }
 public function form(Request $r):void{
  AccessService::require('academico.matriculas.gestionar');$id=(int)$r->input('seccion_id');
  $db=Container::get(Database::class)->connection();$q=$db->prepare("SELECT s.id,s.codigo,s.nombre,s.cupo_maximo,(SELECT COUNT(*) FROM matricula_asignaturas ma JOIN estados_matricula_asignatura em ON em.id=ma.estado_matricula_asignatura_id WHERE ma.seccion_id=s.id AND ma.activo=1 AND em.codigo<>'ANULADA') ocupados FROM secciones s WHERE s.id=? AND s.deleted_at IS NULL");$q->execute([$id]);$section=$q->fetch();if(!$section)Response::abort(404,'Sección no encontrada.');
  $flash=Session::get('capacity_flash');Session::set('capacity_flash',null);
  View::render('admin/academico/cupos/request',['title'=>'Solicitud de cupos adicionales','section'=>$section,'flash'=>$flash]);
 }
 public function resolve(Request $r):never{
  $this->csrf($r);AccessService::require('tic.cuentas.aprobar');
  try{$this->repo()->resolve((int)$r->input('id'),(string)$r->input('decision')==='APROBAR',trim((string)$r->input('observacion')),$this->actor());Session::set('capacity_flash',['type'=>'success','message'=>'Solicitud resuelta correctamente.']);}
  catch(Throwable $e){Session::set('capacity_flash',['type'=>'error','message'=>$e->getMessage()]);}
  Response::redirect('/admin/tic/cupos');
 }
}
