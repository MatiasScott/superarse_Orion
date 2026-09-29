<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\{Request,Response,Session,View};

final class DashboardController
{
    public function index(Request $r): void
    {
        if(!Session::get('auth_user')) Response::redirect('/login');
        if(!Session::get('active_profile')) Response::redirect('/perfil');
        View::render('dashboard/authenticated',[
            'title'=>'Dashboard',
            'user'=>Session::get('auth_user'),
            'profile'=>Session::get('active_profile'),
            'roles'=>Session::get('roles',[]),
            'permissions'=>Session::get('permissions',[])
        ]);
    }
}
