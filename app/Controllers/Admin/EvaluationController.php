<?php
declare(strict_types=1);

namespace App\Controllers\Admin;

use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\EvaluationRepository;
use App\Services\AccessService;

/** Diagnóstico de esquemas de evaluación, sin operaciones de escritura. */
final class EvaluationController
{
    private function repo(): EvaluationRepository
    {
        return new EvaluationRepository(Container::get(Database::class)->connection());
    }

    public function sections(Request $r): void
    {
        AccessService::require('academico.oferta.ver');
        $repo=$this->repo();
        View::render('admin/academico/evaluacion/sections', [
            'title'=>'Esquemas por sección',
            'sections'=>$repo->sectionAssignments(),
            'versions'=>$repo->assignableVersions(),
            'canReassign'=>array_reduce((array)Session::get('roles',[]),static fn(bool $ok,array $role):bool=>$ok || in_array(strtoupper((string)($role['codigo']??'')),['TIC','TICS','COORD_TICS','COORDINADOR_TICS','COORDINADOR_TIC','ADMIN_TICS','ADMIN_TIC','SOPORTE_TICS','SOPORTE_TIC'],true),false),
        ]);
    }

    public function assignSection(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        $actor=(int)(Session::get('auth_user')['id'] ?? 0);
        try {
            $this->repo()->assignVersionToSection(
                (int)$r->input('seccion_id'),(int)$r->input('esquema_version_id'),$actor
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Response::abort(422,$e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/secciones');
    }

    private function requireTics(): void
    {
        AccessService::requireAuth();
        $roles=(array)Session::get('roles', []);
        $allowed=false;
        foreach ($roles as $role) {
            $code=strtoupper((string)($role['codigo'] ?? ''));
            if (in_array($code, ['TIC','TICS','COORD_TICS','COORDINADOR_TICS','COORDINADOR_TIC','ADMIN_TICS','ADMIN_TIC','SOPORTE_TICS','SOPORTE_TIC'], true)) {
                $allowed=true;
                break;
            }
        }
        if (!$allowed) Response::abort(403, 'Solo el personal TICs puede reasignar esquemas.');
    }

    public function reassignSection(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        $this->requireTics();
        try {
            $this->repo()->reassignVersionToSection((int)$r->input('seccion_id'),(int)$r->input('esquema_version_id'),
                (int)(Session::get('auth_user')['id'] ?? 0),trim((string)$r->input('motivo')));
            Session::set('evaluacion_notice','Reasignación autorizada y registrada en el historial.');
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Session::set('evaluacion_error',$e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/secciones');
    }

    public function index(Request $r): void
    {
        AccessService::require('academico.oferta.ver');
        View::render('admin/academico/evaluacion/index', [
            'title'=>'Evaluación y calificaciones',
            'versions'=>$this->repo()->versions(),
        ]);
    }

    public function show(Request $r): void
    {
        AccessService::require('academico.oferta.ver');
        $id=(int)$r->input('id');
        if ($id<=0) Response::abort(404,'Versión de evaluación no encontrada.');
        $repo=$this->repo();
        $version=$repo->version($id);
        if (!$version) Response::abort(404,'Versión de evaluación no encontrada.');
        View::render('admin/academico/evaluacion/show', [
            'title'=>'Detalle del esquema de evaluación',
            'version'=>$version,
            'partials'=>$repo->partials($id),
            'parameters'=>$repo->parameters($id),
            'publicationMinimum'=>$repo->publicationMinimum((int)$version['esquema_evaluacion_id'],$id),
        ]);
    }

    public function cloneForm(Request $r): void
    {
        AccessService::require('academico.oferta.gestionar');
        $id=(int)$r->input('id');
        $version=$this->repo()->version($id);
        if (!$version) Response::abort(404,'Versión de origen no encontrada.');
        View::render('admin/academico/evaluacion/clone', [
            'title'=>'Crear borrador de evaluación','version'=>$version,
        ]);
    }

    public function cloneSave(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        try {
            $id=$this->repo()->cloneDraft((int)$r->input('id'),(string)$r->input('nombre_version'),(string)$r->input('vigente_desde'));
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Response::abort(422,$e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
    }

    public function weightsSave(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        $id=(int)$r->input('id');
        try {
            $this->repo()->updateDraftWeights($id,(array)$r->input('parciales',[]),(array)$r->input('parametros',[]));
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Response::abort(422,$e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
    }

    public function configureSave(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        $id=(int)$r->input('id');
        try {
            $this->repo()->configureDraft($id,(string)$r->input('operacion'),[
                'tipo'=>$r->input('tipo'), 'parcial_id'=>$r->input('parcial_id'),
                'parametro_id'=>$r->input('parametro_id'), 'nombre'=>$r->input('nombre'),
                'codigo'=>$r->input('codigo'), 'ponderacion'=>$r->input('ponderacion'),
            ]);
            Session::set('evaluacion_notice','Configuración del borrador guardada.');
        } catch (\InvalidArgumentException|\RuntimeException|\PDOException $e) {
            Session::set('evaluacion_error',$e instanceof \PDOException?'No se pudo guardar: verifica que el código sea único y no existan dependencias.':$e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
    }

    public function publishSave(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        $id = (int)$r->input('id');
        $actor = (int)(Session::get('auth_user')['id'] ?? 0);
        try {
            $this->repo()->publishDraft($id, $actor);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Session::set('evaluacion_error',$e->getMessage());
            Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
        }
        Session::set('evaluacion_notice','Versión publicada correctamente.');
        Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
    }

}
