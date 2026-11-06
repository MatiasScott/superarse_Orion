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

    public function publishSave(Request $r): never
    {
        if (!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        AccessService::require('academico.oferta.gestionar');
        $id = (int)$r->input('id');
        $actor = (int)(Session::get('auth_user')['id'] ?? 0);
        try {
            $this->repo()->publishDraft($id, $actor);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            Response::abort(422, $e->getMessage());
        }
        Response::redirect('/admin/academico/evaluacion/ver?id='.$id);
    }

}
