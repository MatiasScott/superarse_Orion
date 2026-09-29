<?php
declare(strict_types=1);
namespace App\Core;
final class Config {
 public function __construct(private array $values){}
 public function get(string $key,mixed $default=null):mixed{return $this->values[$key]??$default;}
 public function bool(string $key,bool $default=false):bool{$v=$this->get($key);return $v===null?$default:filter_var($v,FILTER_VALIDATE_BOOL);}
}
