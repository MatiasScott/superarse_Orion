<?php
declare(strict_types=1);
namespace App\Controllers\Admin;

use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\HumanResourcesRepository;
use App\Services\AccessService;

final class HumanResourcesController
{
    private function repo():HumanResourcesRepository{return new HumanResourcesRepository(Container::get(Database::class)->connection());}
    private function actor():int{return (int)Session::get('auth_user')['id'];}
    private function csrf(Request $r):void{if(!Csrf::validate((string)$r->input('_csrf')))Response::abort(419,'CSRF inválido.');}

    public function index(Request $r):void{
        AccessService::require('tthh.personal.ver');$q=trim((string)$r->input('q',''));
        View::render('admin/tthh/index',['title'=>'Talento Humano','employees'=>$this->repo()->employees($q),'q'=>$q]);
    }
    public function form(Request $r):void{
        AccessService::require('tthh.personal.crear');$repo=$this->repo();
        View::render('admin/tthh/form',['title'=>'Registrar personal','types'=>$repo->identificationTypes(),'personnelTypes'=>$repo->personnelTypes(),'contracts'=>$repo->contractTypes(),'workdays'=>$repo->workdayTypes(),'states'=>$repo->relationStates(),'positions'=>$repo->positions(),'units'=>$repo->units(),'campuses'=>$repo->campuses()]);
    }
    public function save(Request $r):never{
        $this->csrf($r);AccessService::require('tthh.personal.crear');
        $d=['tipo_identificacion_id'=>(int)$r->input('tipo_identificacion_id'),'numero_identificacion'=>trim((string)$r->input('numero_identificacion')),
            'primer_nombre'=>trim((string)$r->input('primer_nombre')),'segundo_nombre'=>trim((string)$r->input('segundo_nombre')),
            'primer_apellido'=>trim((string)$r->input('primer_apellido')),'segundo_apellido'=>trim((string)$r->input('segundo_apellido')),
            'tipos_personal'=>(array)$r->input('tipos_personal',[]),'tipo_contrato_id'=>(int)$r->input('tipo_contrato_id',0),'tipo_jornada_id'=>(int)$r->input('tipo_jornada_id',0),
            'estado_relacion_id'=>(int)$r->input('estado_relacion_id'),'fecha_inicio'=>trim((string)$r->input('fecha_inicio')),'fecha_fin_prevista'=>trim((string)$r->input('fecha_fin_prevista')),
            'numero_contrato'=>trim((string)$r->input('numero_contrato')),'cargo_id'=>(int)$r->input('cargo_id'),'unidad_organizacional_id'=>(int)$r->input('unidad_organizacional_id',0),'sede_id'=>(int)$r->input('sede_id',0),
            'observacion'=>trim((string)$r->input('observacion')),'solicitar_cuenta'=>$r->input('solicitar_cuenta')];
        if(!$d['tipo_identificacion_id']||$d['numero_identificacion']===''||$d['primer_nombre']===''||$d['primer_apellido']===''||!$d['tipos_personal']||!$d['estado_relacion_id']||$d['fecha_inicio']===''||!$d['cargo_id'])Response::abort(422,'Completa identificación, nombres, tipo de personal, fecha/estado de relación y cargo.');
        $this->repo()->createEmployee($d,$this->actor());Response::redirect('/admin/tthh');
    }
    public function requests(Request $r):void{AccessService::require('tthh.solicitudes.ver');View::render('admin/tthh/requests',['title'=>'Solicitudes de cuenta','requests'=>$this->repo()->accountRequests()]);}
    public function catalogs(Request $r):void{AccessService::require('tthh.catalogos.gestionar');View::render('admin/tthh/catalogs',['title'=>'Catálogos TTHH','catalogs'=>$this->repo()->catalogs()]);}
    public function catalogSave(Request $r):never{
        $this->csrf($r);AccessService::require('tthh.catalogos.gestionar');$type=trim((string)$r->input('tipo'));
        $this->repo()->createCatalog($type,['codigo'=>$r->input('codigo'),'nombre'=>$r->input('nombre'),'descripcion'=>$r->input('descripcion'),'es_docente'=>$r->input('es_docente'),'es_administrativo'=>$r->input('es_administrativo')]);
        Response::redirect('/admin/tthh/catalogos');
    }
}
