<?php
declare(strict_types=1);
namespace App\Core;
final class App {
 public function __construct(private Router $router,private Database $database,private Config $config){}
 public function run():void{Container::set(Database::class,$this->database);Container::set(Config::class,$this->config);$this->router->dispatch(new Request());}
}
