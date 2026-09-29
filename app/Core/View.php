<?php
declare(strict_types=1);
namespace App\Core;
final class View {
 public static function render(string $v,array $data=[],string $layout='layouts/app'):void{extract($data,EXTR_SKIP);ob_start();require BASE_PATH.'/app/Views/'.$v.'.php';$content=ob_get_clean();require BASE_PATH.'/app/Views/'.$layout.'.php';}
}
