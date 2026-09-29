<?php
declare(strict_types=1);
namespace App\Core;
final class Response {
 public static function redirect(string $p):never{header('Location: '.rtrim($_ENV['APP_URL']??'','/').'/'.ltrim($p,'/'));exit;}
 public static function abort(int $s,string $m=''):never{http_response_code($s);echo htmlspecialchars($m?:("HTTP ".$s));exit;}
}
