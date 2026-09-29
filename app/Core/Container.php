<?php
declare(strict_types=1);
namespace App\Core;
final class Container {private static array $i=[];public static function set(string $k,mixed $v):void{self::$i[$k]=$v;}public static function get(string $k):mixed{return self::$i[$k]??throw new \RuntimeException("Dependencia no registrada: $k");}}
