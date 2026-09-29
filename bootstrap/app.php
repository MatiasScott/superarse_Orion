<?php
declare(strict_types=1);
use App\Core\{App,Config,Database,ErrorHandler,Router,Session};
use Dotenv\Dotenv;
define('BASE_PATH', dirname(__DIR__));
require BASE_PATH.'/vendor/autoload.php';
if(is_file(BASE_PATH.'/.env')) Dotenv::createImmutable(BASE_PATH)->safeLoad();
date_default_timezone_set($_ENV['APP_TIMEZONE']??'America/Guayaquil');
ErrorHandler::register(filter_var($_ENV['APP_DEBUG']??false,FILTER_VALIDATE_BOOL));
Session::start();
$config=new Config($_ENV); $database=new Database($config); $router=new Router();
require BASE_PATH.'/app/Routes/web.php';
return new App($router,$database,$config);
