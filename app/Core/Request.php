<?php
declare(strict_types=1);
namespace App\Core;
final class Request {
 public function method():string{return strtoupper($_SERVER['REQUEST_METHOD']??'GET');}
 public function path():string{$u=parse_url($_SERVER['REQUEST_URI']??'/',PHP_URL_PATH)?:'/';$d=str_replace('\\','/',dirname($_SERVER['SCRIPT_NAME']??''));if($d!=='/'&&$d!=='.'&&str_starts_with($u,$d))$u=substr($u,strlen($d))?:'/';return '/'.trim($u,'/');}
 public function input(string $k,mixed $d=null):mixed{return $_POST[$k]??$_GET[$k]??$d;}
}
