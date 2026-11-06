<?php
declare(strict_types=1);

namespace App\Controllers\Admin;

use App\Core\{Container,Database,Request,Response,View};
use App\Repositories\EvaluationRepository;
use App\Services\AccessService;

/** Diagnóstico de esquemas de evaluación, sin operaciones de escritura. */
final class EvaluationController
{
    private function repo(): EvaluationRepository
    {
        return new EvaluationRepository(Container::get(Database::class)->connection());
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
}
