<?php
declare(strict_types=1);
namespace App\Controllers\Admin;
use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\AcademicEnrollmentRepository;
use App\Services\AccessService;
use RuntimeException;
use Throwable;

final class AcademicEnrollmentController
{
    private function repo(): AcademicEnrollmentRepository { return new AcademicEnrollmentRepository(Container::get(Database::class)->connection()); }
    private function actor(): int { return (int)(Session::get('auth_user')['id'] ?? 0); }
    private function csrf(Request $r): void { if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419, 'CSRF inválido.'); }
    private function flash(string $type, string $message): void { Session::set('academic_enrollment_flash', ['type'=>$type,'message'=>$message]); }
    private function takeFlash(): ?array { $f=Session::get('academic_enrollment_flash'); Session::set('academic_enrollment_flash', null); return is_array($f)?$f:null; }

    public function index(Request $r): void
    {
        AccessService::require('academico.matriculas.ver');
        $q=trim((string)$r->input('q')); $repo=$this->repo();
        $filters = [
            'buscar'=>trim((string)$r->input('buscar')),
            'estado'=>trim((string)$r->input('estado')),
            'periodo'=>(int)$r->input('periodo'),
            'carrera'=>(int)$r->input('carrera'),
        ];
        View::render('admin/academico/matriculas/index',[
            'title'=>'Matrículas y renovación','q'=>$q,
            'students'=>$q!==''?$repo->searchStudents($q):[],
            'pending'=>AccessService::can('academico.matriculas.confirmar')?$repo->pendingAcademicConfirmations():[],
            'history'=>$repo->enrollmentHistory($filters,(int)$r->input('pagina',1)),
            'historyFilters'=>$repo->enrollmentHistoryFilters(),
            'selectedFilters'=>$filters,
            'flash'=>$this->takeFlash(),
        ]);
    }
    public function student(Request $r): void
    {
        AccessService::require('academico.matriculas.ver'); $id=(int)$r->input('id'); $x=$this->repo(); $student=$x->student($id);
        if(!$student) Response::abort(404,'Estudiante no encontrado.');
        View::render('admin/academico/matriculas/student',['title'=>'Matrícula del estudiante','student'=>$student,'trajectories'=>$x->trajectories($id),'flash'=>$this->takeFlash()]);
    }
    public function proposal(Request $r): void
    {
        AccessService::require('academico.matriculas.gestionar'); $trajectory=(int)$r->input('trayectoria_id'); $offer=(int)$r->input('oferta_id'); $x=$this->repo(); $t=$x->trajectory($trajectory);
        if(!$t) Response::abort(404,'Trayectoria no encontrada.');
        $offers=$x->compatibleOffers($trajectory); $proposal=null; $error=null; $existingEnrollment=null;
        if($offer){
            foreach($offers as $availableOffer){
                if((int)$availableOffer['id']===$offer && !empty($availableOffer['matricula_existente'])){
                    $existingEnrollment=$x->enrollment((int)$availableOffer['matricula_existente']);
                    break;
                }
            }
            if(!$existingEnrollment){ try{$proposal=$x->proposal($trajectory,$offer);}catch(RuntimeException $e){$error=$e->getMessage();} }
        }
        View::render('admin/academico/matriculas/proposal',['title'=>'Propuesta de matrícula','trajectory'=>$t,'offers'=>$offers,'selectedOffer'=>$offer,'proposal'=>$proposal,'existingEnrollment'=>$existingEnrollment,'businessError'=>$error,'flash'=>$this->takeFlash()]);
    }
    public function create(Request $r): never
    {
        $this->csrf($r); AccessService::require('academico.matriculas.gestionar'); $trajectory=(int)$r->input('trayectoria_id'); $offer=(int)$r->input('oferta_id');
        $raw=(array)$r->input('seccion',[]); $selected=[]; foreach($raw as $ma=>$section) if((int)$section>0) $selected[(int)$ma]=(int)$section;
        try{$id=$this->repo()->createDraft($trajectory,$offer,$selected,$this->actor()); Response::redirect('/admin/academico/matriculas/ver?id='.$id);}
        catch(RuntimeException $e){$this->flash('error',$e->getMessage()); Response::redirect('/admin/academico/matriculas/propuesta?trayectoria_id='.$trajectory.($offer?'&oferta_id='.$offer:''));}
    }
    public function show(Request $r): void
    {
        AccessService::require('academico.matriculas.ver'); $id=(int)$r->input('id'); $x=$this->repo(); $m=$x->enrollment($id);
        if(!$m) Response::abort(404,'Matrícula no encontrada.');
        View::render('admin/academico/matriculas/show',['title'=>'Detalle de matrícula','enrollment'=>$m,'subjects'=>$x->enrollmentSubjects($id),'flash'=>$this->takeFlash()]);
    }
    public function confirm(Request $r): never
    {
        $this->csrf($r); AccessService::require('academico.matriculas.confirmar'); $id=(int)$r->input('id');
        try{$state=$this->repo()->academicConfirm($id,$this->actor()); $this->flash('success',$state==='CONFIRMADA'?'Matrícula confirmada y trayectoria activada.':'Selección académica confirmada; la matrícula queda pendiente de habilitación financiera.');}
        catch(RuntimeException $e){$this->flash('error',$e->getMessage());}
        Response::redirect('/admin/academico/matriculas/ver?id='.$id);
    }
    public function bulkConfirm(Request $r): never
    {
        $this->csrf($r); AccessService::require('academico.matriculas.confirmar'); $ids=(array)$r->input('matriculas',[]);
        if(!$ids){$this->flash('error','Selecciona al menos una matrícula.'); Response::redirect('/admin/academico/matriculas');}
        $result=$this->repo()->bulkAcademicConfirm($ids,$this->actor());
        $msg='Confirmadas: '.$result['confirmadas'].' · Pendientes financiero: '.$result['pendientes_financiero'];
        if($result['errores']) $msg.=' · Errores: '.implode(' | ',array_slice($result['errores'],0,5));
        $this->flash($result['errores']?'error':'success',$msg); Response::redirect('/admin/academico/matriculas');
    }
}
