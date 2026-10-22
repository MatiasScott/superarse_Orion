<?php
declare(strict_types=1);
/** Orion v0.11.32 Fase 2D. Diagnóstico local, SOLO LECTURA. */
require dirname(__DIR__) . '/vendor/autoload.php';
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;
Dotenv::createImmutable(dirname(__DIR__))->safeLoad();
$path = $argv[1] ?? dirname(__DIR__) . '/Estudiantes.xlsx';
if (!is_file($path)) { fwrite(STDERR, "No existe Excel: $path\nUso: php scripts/conciliacion_estudiantes_v01132.php ruta/al/Estudiantes.xlsx\n"); exit(1); }
if (!class_exists(ZipArchive::class)) { fwrite(STDERR, "Habilita extension PHP zip en php.ini\n"); exit(1); }
$zip=new ZipArchive(); if($zip->open($path)!==true) throw new RuntimeException('No se pudo abrir XLSX');
$ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
$shared=[];
$ss=$zip->getFromName('xl/sharedStrings.xml');
if($ss!==false){$xml=new SimpleXMLElement($ss); foreach($xml->children($ns)->si as $si){$txt='';foreach($si->xpath('.//*[local-name()="t"]') as $t)$txt.=(string)$t;$shared[]=$txt;}}
$sheet=$zip->getFromName('xl/worksheets/sheet1.xml');if($sheet===false)throw new RuntimeException('No se encontro hoja 1');
$doc=new SimpleXMLElement($sheet);$rows=$doc->xpath('//*[local-name()="sheetData"]/*[local-name()="row"]');
function colIndex(string $ref):int{$letters=preg_replace('/\d+/','',$ref);$n=0;foreach(str_split($letters) as $c)$n=$n*26+ord($c)-64;return $n-1;}
function parseRow(SimpleXMLElement $row,array $shared):array{$out=[];foreach($row->xpath('./*[local-name()="c"]') as $c){$a=$c->attributes();$ref=(string)$a['r'];$typ=(string)$a['t'];$v=$c->xpath('./*[local-name()="v"]');$val=$v?(string)$v[0]:'';if($typ==='s')$val=$shared[(int)$val]??'';if($typ==='inlineStr'){$ts=$c->xpath('.//*[local-name()="t"]');$val=implode('',array_map('strval',$ts));}$out[colIndex($ref)]=trim($val);}return $out;}
$headers=parseRow($rows[0],$shared);$index=[];foreach($headers as $i=>$h)$index[mb_strtoupper(trim($h))]=$i;
function field(array $r,array $idx,string $name):string{return (string)($r[$idx[mb_strtoupper($name)]??-1]??'');}
function norm(string $v):string{$v=mb_strtoupper(trim($v),'UTF-8');$v=strtr($v,['Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N']);return preg_replace('/\s+/u',' ',$v);}
$db=(new Database(new Config($_ENV)))->connection();
$persons=[];foreach($db->query('SELECT numero_identificacion FROM personas WHERE deleted_at IS NULL') as $r){$key=trim((string)$r['numero_identificacion']);if($key!=='')$persons[$key]=true;}
$programs=[];foreach($db->query('SELECT nombre FROM carreras WHERE activo=1 AND deleted_at IS NULL') as $r)$programs[norm($r['nombre'])]=true;
$levels=[];foreach($db->query('SELECT codigo,nombre FROM niveles_academicos WHERE activo=1') as $r){$levels[norm($r['nombre'])]=true;$levels[norm($r['codigo'])]=true;}
$counts=['filas'=>0,'identificacion_vacia'=>0,'identificacion_repetida_excel'=>0,'persona_existente'=>0,'persona_nueva'=>0,'programa_sin_coincidencia_exacta'=>0,'nivel_vacio'=>0,'nivel_sin_coincidencia_exacta'=>0,'con_beca'=>0,'con_ingresos_hogar'=>0];$seen=[];$unknownPrograms=[];$unknownLevels=[];$statuses=[];$periods=[];
foreach(array_slice($rows,1) as $row){$r=parseRow($row,$shared);if(!array_filter($r,fn($v)=>$v!==''))continue;$counts['filas']++;
$id=trim(field($r,$index,'Número de identificación'));if($id==='')$counts['identificacion_vacia']++;else{if(isset($seen[$id]))$counts['identificacion_repetida_excel']++;$seen[$id]=true;$counts[isset($persons[$id])?'persona_existente':'persona_nueva']++;}
$p=norm(field($r,$index,'Programa'));if($p!==''&&!isset($programs[$p])){$counts['programa_sin_coincidencia_exacta']++;$unknownPrograms[$p]=($unknownPrograms[$p]??0)+1;}
$l=norm(field($r,$index,'Nivel'));if($l==='')$counts['nivel_vacio']++;elseif(!isset($levels[$l])){$counts['nivel_sin_coincidencia_exacta']++;$unknownLevels[$l]=($unknownLevels[$l]??0)+1;}
$b=norm(field($r,$index,'Tiene Beca'));if(in_array($b,['SI','SÍ','YES','1'],true))$counts['con_beca']++;
if(field($r,$index,'Ingresos del Hogar')!=='')$counts['con_ingresos_hogar']++;
foreach(['Estado'=>&$statuses,'Período'=>&$periods] as $k=>&$dest){$v=norm(field($r,$index,$k));if($v!=='')$dest[$v]=($dest[$v]??0)+1;}unset($dest);
}
arsort($unknownPrograms);arsort($unknownLevels);arsort($statuses);arsort($periods);
echo "ORION v0.11.32 | FASE 2D | CONCILIACION SOLO LECTURA\nArchivo: ".basename($path)."\nNo se muestran identificaciones ni datos personales.\n\n";
foreach($counts as $k=>$v)printf("%-40s %d\n",$k,$v);
foreach(['Programas sin coincidencia exacta'=>$unknownPrograms,'Niveles sin coincidencia exacta'=>$unknownLevels,'Estados Excel'=>$statuses,'Periodos Excel'=>$periods] as $label=>$items){echo "\n$label (hasta 35):\n";$n=0;foreach($items as $k=>$v){printf("  %-55s %d\n",mb_substr($k,0,55),$v);if(++$n>=35)break;}}
echo "\nFIN: ninguna escritura en MySQL, Moodle ni Microsoft 365.\n";
