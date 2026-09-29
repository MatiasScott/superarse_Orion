<?php
declare(strict_types=1);
namespace App\Core;
use Throwable;
final class ErrorHandler {
 public static function register(bool $debug):void{set_exception_handler(function(Throwable $e)use($debug){http_response_code(500);$d=BASE_PATH.'/storage/logs';@mkdir($d,0775,true);@file_put_contents($d.'/orion-'.date('Y-m-d').'.log','['.date('c').'] '.$e.PHP_EOL,FILE_APPEND);echo $debug?'<pre>'.htmlspecialchars((string)$e).'</pre>':'Orion encontro un error interno.';});}
}
