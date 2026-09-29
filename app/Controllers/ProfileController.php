<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\IdentityRepository;
use App\Services\AuthService;

final class ProfileController
{
    public function index(Request $r): void
    {
        if(!Session::get('auth_user')) Response::redirect('/login');
        View::render('profile/select',['title'=>'Seleccionar perfil','profiles'=>(new IdentityRepository(Container::get(Database::class)->connection()))->profiles((int)Session::get('auth_user')['id'])]);
    }

    public function select(Request $r): never
    {
        if(!Session::get('auth_user')) Response::redirect('/login');
        if(!Csrf::validate((string)$r->input('_csrf'))) Response::abort(419,'CSRF inválido.');
        $repo=new IdentityRepository(Container::get(Database::class)->connection());
        (new AuthService($repo))->selectProfile((int)$r->input('perfil_id'));
        Response::redirect('/dashboard');
    }
}
