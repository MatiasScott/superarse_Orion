<?php
declare(strict_types=1);
namespace App\Controllers;
use App\Core\{Request,View};
final class HomeController {public function index(Request $r):void{View::render('dashboard/index',['title'=>'Orion']);}}
