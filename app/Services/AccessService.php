<?php
declare(strict_types=1);
namespace App\Services;
use App\Core\{Response,Session};

final class AccessService
{
    public static function requireAuth(): void
    {
        if(!Session::get('auth_user')) Response::redirect('/login');
        if(!Session::get('active_profile')) Response::redirect('/perfil');
    }
    public static function can(string $permission): bool
    {
        $p=(array)Session::get('permissions',[]);
        return in_array('*',$p,true) || in_array($permission,$p,true);
    }
    public static function require(string $permission): void
    {
        self::requireAuth();
        if(!self::can($permission)) Response::abort(403,'No tienes permiso para realizar esta acción.');
    }
}
