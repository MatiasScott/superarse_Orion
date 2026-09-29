<?php
declare(strict_types=1);
namespace App\Controllers\Admin;

use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\AdminRepository;
use App\Services\AccessService;

final class IdentityAdminController
{
    private function repo():AdminRepository{return new AdminRepository(Container::get(Database::class)->connection());}
    private function csrf(Request $r):void{if(!Csrf::validate((string)$r->input('_csrf')))Response::abort(419,'CSRF inválido.');}
    private function actor():int{return (int)Session::get('auth_user')['id'];}

    public function users(Request $r):void{
        AccessService::require('admin.usuarios.ver');$repo=$this->repo();
        View::render('admin/usuarios/index',['title'=>'Usuarios','users'=>$repo->users(trim((string)$r->input('q',''))),'q'=>trim((string)$r->input('q',''))]);
    }
    public function userForm(Request $r):void{
        $id=(int)$r->input('id',0);AccessService::require($id?'admin.usuarios.editar':'admin.usuarios.crear');$repo=$this->repo();
        View::render('admin/usuarios/form',['title'=>$id?'Editar usuario':'Nuevo usuario','user'=>$id?$repo->user($id):null,'types'=>$repo->identificationTypes(),'states'=>$repo->userStates(),'profiles'=>$repo->profiles(),'roles'=>$repo->activeRoles(),'selectedProfiles'=>$id?$repo->userProfileIds($id):[],'selectedRoles'=>$id?$repo->userRoleIds($id):[]]);
    }
    public function userSave(Request $r):never{
        $this->csrf($r);$id=(int)$r->input('id',0);AccessService::require($id?'admin.usuarios.editar':'admin.usuarios.crear');
        $d=['tipo_identificacion_id'=>(int)$r->input('tipo_identificacion_id'),'numero_identificacion'=>trim((string)$r->input('numero_identificacion')),
            'primer_nombre'=>trim((string)$r->input('primer_nombre')),'segundo_nombre'=>trim((string)$r->input('segundo_nombre')),
            'primer_apellido'=>trim((string)$r->input('primer_apellido')),'segundo_apellido'=>trim((string)$r->input('segundo_apellido')),
            'estado_usuario_id'=>(int)$r->input('estado_usuario_id'),'activo'=>$r->input('activo'),'perfiles'=>(array)$r->input('perfiles',[]),'roles'=>(array)$r->input('roles',[])];
        if($d['numero_identificacion']===''||$d['primer_nombre']===''||$d['primer_apellido']==='')Response::abort(422,'Identificación, primer nombre y primer apellido son obligatorios.');
        $repo=$this->repo();$id?$repo->updateUser($id,$d,$this->actor()):$repo->createUser($d,$this->actor());Response::redirect('/admin/usuarios');
    }

    public function roles(Request $r):void{AccessService::require('admin.roles.ver');View::render('admin/roles/index',['title'=>'Roles','roles'=>$this->repo()->roles()]);}
    public function roleForm(Request $r):void{
        $id=(int)$r->input('id',0);AccessService::require($id?'admin.roles.editar':'admin.roles.crear');$repo=$this->repo();
        View::render('admin/roles/form',['title'=>$id?'Editar rol':'Nuevo rol','role'=>$id?$repo->role($id):null,'profiles'=>$repo->profiles()]);
    }
    public function roleSave(Request $r):never{
        $this->csrf($r);$id=(int)$r->input('id',0);AccessService::require($id?'admin.roles.editar':'admin.roles.crear');
        $d=['perfil_id'=>(int)$r->input('perfil_id',0),'codigo'=>trim((string)$r->input('codigo')),'nombre'=>trim((string)$r->input('nombre')),'descripcion'=>trim((string)$r->input('descripcion')),'activo'=>$r->input('activo')];
        if($d['nombre']===''||(!$id&&$d['codigo']===''))Response::abort(422,'Código y nombre son obligatorios.');
        $repo=$this->repo();$id?$repo->updateRole($id,$d):$repo->createRole($d);Response::redirect('/admin/roles');
    }
    public function permissions(Request $r):void{AccessService::require('admin.permisos.ver');View::render('admin/permisos/index',['title'=>'Permisos','permissions'=>$this->repo()->permissions()]);}
    public function rolePermissions(Request $r):void{
        AccessService::require('admin.roles.permisos');$id=(int)$r->input('id');$repo=$this->repo();$role=$repo->role($id);if(!$role)Response::abort(404,'Rol no encontrado.');
        View::render('admin/permisos/matrix',['title'=>'Permisos del rol','role'=>$role,'permissions'=>$repo->permissions(),'selected'=>$repo->rolePermissionIds($id)]);
    }
    public function rolePermissionsSave(Request $r):never{
        $this->csrf($r);AccessService::require('admin.roles.permisos');$id=(int)$r->input('id');$this->repo()->syncRolePermissions($id,(array)$r->input('permisos',[]));Response::redirect('/admin/roles');
    }
}
