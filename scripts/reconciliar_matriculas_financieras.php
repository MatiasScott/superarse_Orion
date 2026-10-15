<?php
declare(strict_types=1);
/** Orion v0.10.9: preflight por defecto; --execute aplica confirmaciones pendientes. */
use App\Core\Config;
use App\Core\Database;
use App\Repositories\FinanceRepository;
use Dotenv\Dotenv;
define('BASE_PATH', dirname(__DIR__));
require BASE_PATH.'/vendor/autoload.php';
if(is_file(BASE_PATH.'/.env'))Dotenv::createImmutable(BASE_PATH)->safeLoad();
date_default_timezone_set($_ENV['APP_TIMEZONE']??'America/Guayaquil');
$pdo=(new Database(new Config($_ENV)))->connection();
$execute=in_array('--execute',$argv,true);
$actor=0;
foreach($argv as $arg){if(str_starts_with($arg,'--actor='))$actor=(int)substr($arg,8);}
if($execute&&$actor<=0){fwrite(STDERR,"Para ejecutar indica --actor=ID_USUARIO_ADMINISTRATIVO (auditoría).\n");exit(1);}
$sql="SELECT m.id matricula_id,m.numero_matricula,m.estudiante_carrera_id,m.periodo_academico_id FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id JOIN habilitaciones_financieras h ON h.estudiante_carrera_id=m.estudiante_carrera_id AND h.periodo_academico_id=m.periodo_academico_id JOIN estados_habilitacion_financiera eh ON eh.id=h.estado_habilitacion_financiera_id WHERE m.activo=1 AND em.codigo='PENDIENTE_FINANCIERO' AND eh.habilita_matricula=1 AND (h.fecha_hasta IS NULL OR h.fecha_hasta>=NOW()) ORDER BY m.id";
$rows=$pdo->query($sql)->fetchAll();
echo ($execute?'EJECUTAR':'PREVISUALIZAR').': '.count($rows)." matrículas elegibles\n";
$finance=new FinanceRepository($pdo);
$seen=[];$errors=0;
foreach($rows as $r){
 echo 'Matrícula '.$r['matricula_id'].' · '.$r['numero_matricula']."\n";
 if(!$execute)continue;
 $key=$r['estudiante_carrera_id'].':'.$r['periodo_academico_id'];
 if(isset($seen[$key]))continue;
 $seen[$key]=true;
 try{echo '  Confirmadas: '.$finance->confirmEnabledEnrollments((int)$r['estudiante_carrera_id'],(int)$r['periodo_academico_id'],$actor)."\n";}
 catch(Throwable $e){$errors++;fwrite(STDERR,'  ERROR: '.$e->getMessage()."\n");}
}
exit($errors?1:0);
