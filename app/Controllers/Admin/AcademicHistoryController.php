<?php
declare(strict_types=1);
namespace App\Controllers\Admin;
use App\Core\{Container,Database,Request,Response,View};
use App\Repositories\AcademicHistoryRepository;
use App\Services\AccessService;
final class AcademicHistoryController {
 private function repo():AcademicHistoryRepository{return new AcademicHistoryRepository(Container::get(Database::class)->connection());}
 public function student(Request $r):void{AccessService::require('academico.historial.ver');$id=(int)$r->input('id');if($id<=0)Response::abort(422,'Estudiante inválido.');$x=$this->repo();$student=$x->student($id);if(!$student)Response::abort(404,'Estudiante no encontrado.');$trajectories=$x->trajectories($id);$enrollments=$x->enrollments($id);$subjects=$x->subjects($id);$details=$x->gradeDetails($id);$byTrajectory=[];foreach($trajectories as $t){$tid=(int)$t['id'];$byTrajectory[$tid]=['trajectory'=>$t,'periods'=>[]];}foreach($enrollments as $m){$tid=(int)$m['estudiante_carrera_id'];if(!isset($byTrajectory[$tid]))continue;$m['subjects']=[];$byTrajectory[$tid]['periods'][(int)$m['id']]=$m;}foreach($subjects as $s){$mid=(int)$s['matricula_id'];foreach($byTrajectory as &$block){if(isset($block['periods'][$mid])){$s['details']=$details[(int)$s['id']]??[];$block['periods'][$mid]['subjects'][]=$s;break;}}unset($block);}View::render('admin/academico/historial/student',['title'=>'Historial académico','student'=>$student,'history'=>$byTrajectory]);}
}
