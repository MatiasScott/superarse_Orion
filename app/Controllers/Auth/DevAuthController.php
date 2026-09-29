<?php
declare(strict_types=1);

namespace App\Controllers\Auth;

use App\Core\{Config,Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\IdentityRepository;
use App\Services\AuthService;

final class DevAuthController
{
    private function allowed(): bool
    {
        $c=Container::get(Config::class);
        return $c->get('APP_ENV')==='local' && $c->bool('DEV_LOGIN_ENABLED');
    }

    private function service(): AuthService
    {
        $db=Container::get(Database::class)->connection();
        return new AuthService(new IdentityRepository($db));
    }

    public function form(Request $r): void
    {
        if(!$this->allowed()) Response::abort(404,'Página no encontrada.');
        View::render('auth/dev-login',['title'=>'Acceso local Orion','error'=>Session::get('dev_error')],'layouts/guest');
        unset($_SESSION['dev_error']);
    }

    public function login(Request $r): never
    {
        if(!$this->allowed()) Response::abort(404,'Página no encontrada.');
        if(!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        $key=(string)$r->input('dev_key');
        $expected=(string)Container::get(Config::class)->get('DEV_LOGIN_KEY','');
        if($expected==='' || !hash_equals($expected,$key)){Session::set('dev_error','Clave local incorrecta.');Response::redirect('/dev/login');}
        try{
            $result=$this->service()->loginDeveloper(trim((string)$r->input('identificacion')));
            Response::redirect($result['selected'] ? '/dashboard' : '/perfil');
        }catch(\Throwable $e){Session::set('dev_error',$e->getMessage());Response::redirect('/dev/login');}
    }

    public function bootstrap(Request $r): never
    {
        if(!$this->allowed()) Response::abort(404,'Página no encontrada.');
        if(!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        $expected=(string)Container::get(Config::class)->get('DEV_LOGIN_KEY','');
        if($expected==='' || !hash_equals($expected,(string)$r->input('dev_key'))) Response::abort(403,'Clave local incorrecta.');
        $db=Container::get(Database::class)->connection();
        $repo=new IdentityRepository($db);
        $id=trim((string)$r->input('identificacion'));
        $repo->bootstrapDeveloperAdmin($id,trim((string)$r->input('primer_nombre')),trim((string)$r->input('primer_apellido')));
        (new AuthService($repo))->loginDeveloper($id);
        Response::redirect('/dashboard');
    }

    public function logout(Request $r): never
    {
        if(!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        $this->service()->logout();
        Response::redirect('/login');
    }
}
