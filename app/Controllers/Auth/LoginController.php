<?php
declare(strict_types=1);

namespace App\Controllers\Auth;

use App\Core\{Config,Container,Request,Session,View};

final class LoginController
{
    public function show(Request $request): void
    {
        if(Session::get('auth_user')){ header('Location: '.rtrim($_ENV['APP_URL']??'','/').'/dashboard'); exit; }
        $config=Container::get(Config::class);
        View::render('auth/login',[
            'title'=>'Ingresar a Orion',
            'microsoftEnabled'=>$config->bool('MICROSOFT_LOGIN_ENABLED'),
            'devEnabled'=>$config->get('APP_ENV')==='local' && $config->bool('DEV_LOGIN_ENABLED')
        ],'layouts/guest');
    }
}
