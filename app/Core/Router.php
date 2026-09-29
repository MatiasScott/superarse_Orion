<?php
declare(strict_types=1);
namespace App\Core;
final class Router {
 private array $routes=[];
 public function get(string $p,callable|array $h):void{$this->routes['GET'][$this->n($p)]=$h;}
 public function post(string $p,callable|array $h):void{$this->routes['POST'][$this->n($p)]=$h;}
 public function dispatch(Request $r):mixed{$h=$this->routes[$r->method()][$this->n($r->path())]??null;if(!$h)Response::abort(404,'Pagina no encontrada.');if(is_array($h)){[$c,$m]=$h;return(new $c)->$m($r);}return $h($r);}
 private function n(string $p):string{$p='/'.trim($p,'/');return $p==='//'?'/':$p;}
}
