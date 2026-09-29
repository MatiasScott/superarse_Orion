<?php
declare(strict_types=1);
namespace App\Controllers\Auth;
use App\Core\{Config,Container,Request,View};
final class LoginController {public function show(Request $r):void{$c=Container::get(Config::class);View::render('auth/login',['title'=>'Ingresar a Orion','microsoftEnabled'=>$c->bool('MICROSOFT_LOGIN_ENABLED')],'layouts/guest');}}
