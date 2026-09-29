<?php
declare(strict_types=1);
namespace App\Core;
final class Session {
 public static function start():void{if(session_status()===PHP_SESSION_ACTIVE)return;session_name($_ENV['SESSION_NAME']??'orion_session');session_set_cookie_params(['httponly'=>true,'secure'=>filter_var($_ENV['SESSION_SECURE']??false,FILTER_VALIDATE_BOOL),'samesite'=>$_ENV['SESSION_SAMESITE']??'Lax','path'=>'/']);session_start();}
 public static function get(string $k,mixed $d=null):mixed{return $_SESSION[$k]??$d;}
 public static function set(string $k,mixed $v):void{$_SESSION[$k]=$v;}
 public static function regenerate():void{session_regenerate_id(true);}
}
