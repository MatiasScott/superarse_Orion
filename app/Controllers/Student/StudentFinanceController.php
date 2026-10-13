<?php
declare(strict_types=1);
namespace App\Controllers\Student;
use App\Core\{Container,Csrf,Database,Request,Response,Session,View};
use App\Repositories\FinanceRepository;
use App\Services\AccessService;
use PDO;
use Throwable;
use RuntimeException;

final class StudentFinanceController {
 private function db():PDO{return Container::get(Database::class)->connection();}
 private function actor():int{return (int)(Session::get('auth_user')['id']??0);}
 private function authorize():int {
  AccessService::requireAuth();
  if((Session::get('active_profile')['codigo']??'')!=='ESTUDIANTE')Response::abort(403,'Selecciona el perfil Estudiante.');
  $s=$this->db()->prepare('SELECT e.id FROM estudiantes e JOIN usuarios u ON u.persona_id=e.persona_id WHERE u.id=:u AND u.deleted_at IS NULL AND e.deleted_at IS NULL LIMIT 1');
  $s->execute(['u'=>$this->actor()]);$id=(int)$s->fetchColumn();
  if(!$id)Response::abort(403,'La cuenta no está vinculada a una ficha de estudiante.');return $id;
 }
 private function owns(int $order,int $student):bool {
  $s=$this->db()->prepare('SELECT 1 FROM ordenes_pago o JOIN estudiante_carreras ec ON ec.id=o.estudiante_carrera_id WHERE o.id=:o AND ec.estudiante_id=:e LIMIT 1');$s->execute(['o'=>$order,'e'=>$student]);return(bool)$s->fetchColumn();
 }
 private function message(?string $message=null):?string {if($message!==null){Session::set('student_finance_flash',$message);return null;}$m=Session::get('student_finance_flash');Session::set('student_finance_flash',null);return is_string($m)?$m:null;}
 public function index(Request $r):void {
  $student=$this->authorize();$db=$this->db();
  $s=$db->prepare("SELECT o.id,o.numero_orden,o.total_pagar,o.saldo_pendiente,eo.nombre estado,eo.codigo estado_codigo,pa.nombre periodo,c.nombre carrera FROM ordenes_pago o JOIN estudiante_carreras ec ON ec.id=o.estudiante_carrera_id JOIN carreras c ON c.id=ec.carrera_id JOIN periodos_academicos pa ON pa.id=o.periodo_academico_id JOIN estados_orden_pago eo ON eo.id=o.estado_orden_pago_id WHERE ec.estudiante_id=:e ORDER BY o.id DESC");$s->execute(['e'=>$student]);$orders=$s->fetchAll(PDO::FETCH_ASSOC);
  $selected=(int)$r->input('id');if(!$selected&&$orders)$selected=(int)$orders[0]['id'];
  if($selected&&!$this->owns($selected,$student))Response::abort(404,'Orden no encontrada.');
  $repo=new FinanceRepository($db);$order=$selected?$repo->order($selected):null;
  $installments=$selected?$repo->installments($selected):[];$payments=$selected?$repo->payments($selected):[];
  View::render('student/finance/index',['title'=>'Mi estado financiero','orders'=>$orders,'order'=>$order,'installments'=>$installments,'payments'=>$payments,'media'=>$repo->paymentCatalog()['media'],'flash'=>$this->message()]);
 }
 public function register(Request $r):never {
  $student=$this->authorize();if(!Csrf::validate((string)$r->input('_csrf')))Response::abort(419,'CSRF inválido.');
  $order=(int)$r->input('orden_id');if(!$this->owns($order,$student))Response::abort(404,'Orden no encontrada.');
  $db=$this->db();$dest=null;
  try {
   $cuota=(int)$r->input('cuota_id');$amount=(float)$r->input('monto');$date=(string)$r->input('fecha_pago');$medium=(int)$r->input('medio_pago_id');$ref=trim((string)$r->input('referencia'));
   if($medium<=0)throw new RuntimeException('Selecciona el medio de pago.');
   $check=$db->prepare('SELECT 1 FROM medios_pago WHERE id=:id AND activo=1');$check->execute(['id'=>$medium]);if(!$check->fetchColumn())throw new RuntimeException('Medio de pago inválido.');
   if(!isset($_FILES['comprobante'])||($_FILES['comprobante']['error']??UPLOAD_ERR_NO_FILE)!==UPLOAD_ERR_OK)throw new RuntimeException('Adjunta un comprobante PDF, JPG o PNG.');
   $f=$_FILES['comprobante'];if((int)$f['size']<=0||(int)$f['size']>10*1024*1024||!is_uploaded_file($f['tmp_name']))throw new RuntimeException('El archivo debe tener un tamaño máximo de 10 MB.');
   $mime=(new \finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);$types=['application/pdf'=>'pdf','image/jpeg'=>'jpg','image/png'=>'png'];if(!isset($types[$mime]))throw new RuntimeException('Solo se permiten PDF, JPG y PNG.');
   $uuid=sprintf('%s-%s-%s-%s-%s',bin2hex(random_bytes(4)),bin2hex(random_bytes(2)),bin2hex(random_bytes(2)),bin2hex(random_bytes(2)),bin2hex(random_bytes(6)));
   $name=$uuid.'.'.$types[$mime];$folder='storage/uploads/financiero/'.date('Y/m');$dir=BASE_PATH.'/'.$folder;
   if(!is_dir($dir)&&!mkdir($dir,0775,true)&&!is_dir($dir))throw new RuntimeException('No se pudo preparar el almacenamiento.');
   $dest=$dir.'/'.$name;if(!move_uploaded_file($f['tmp_name'],$dest))throw new RuntimeException('No se pudo guardar el comprobante.');
   $db->beginTransaction();
   $stmt=$db->prepare("INSERT INTO archivos(uuid,nombre_original,nombre_interno,ruta_relativa,extension,mime_type,tamano_bytes,hash_sha256,almacenamiento_codigo,creado_por_usuario_id) VALUES(:u,:o,:n,:r,:e,:m,:t,:h,'PRINCIPAL',:usr)");
   $stmt->execute(['u'=>$uuid,'o'=>basename((string)$f['name']),'n'=>$name,'r'=>$folder.'/'.$name,'e'=>$types[$mime],'m'=>$mime,'t'=>$f['size'],'h'=>hash_file('sha256',$dest),'usr'=>$this->actor()]);$fileId=(int)$db->lastInsertId();
   $repo=new FinanceRepository($db);$payment=$repo->registerPayment($order,$cuota,$amount,$date,$medium,$fileId,$ref,$this->actor());
   $stmt=$db->prepare("UPDATE pagos SET origen_pago_id=(SELECT id FROM origenes_pago WHERE codigo='ESTUDIANTE' LIMIT 1),registrado_por_financiero=0,observacion='Registrado por estudiante; pendiente de revisión' WHERE id=:id");$stmt->execute(['id'=>$payment]);
   $db->commit();$this->message('Comprobante recibido. Quedará pendiente hasta que Financiero lo revise.');
  }catch(Throwable $e){if($db->inTransaction())$db->rollBack();if($dest&&is_file($dest))@unlink($dest);$this->message('No se pudo registrar: '.$e->getMessage());}
  Response::redirect('/estudiante/financiero?id='.$order);
 }
 public function proof(Request $r):never {
  $student=$this->authorize();$id=(int)$r->input('pago_id');$db=$this->db();
  $s=$db->prepare('SELECT a.ruta_relativa,a.nombre_original,a.mime_type,a.hash_sha256 FROM pagos p JOIN ordenes_pago o ON o.id=p.orden_pago_id JOIN estudiante_carreras ec ON ec.id=o.estudiante_carrera_id JOIN archivos a ON a.id=p.comprobante_archivo_id WHERE p.id=:p AND ec.estudiante_id=:e LIMIT 1');$s->execute(['p'=>$id,'e'=>$student]);$f=$s->fetch(PDO::FETCH_ASSOC);if(!$f)Response::abort(404,'Comprobante no encontrado.');
  $relative=str_replace('\\','/',(string)$f['ruta_relativa']);$root=realpath(BASE_PATH.'/storage/uploads/financiero');$path=realpath(BASE_PATH.'/'.$relative);
  if(!$root||!str_starts_with($relative,'storage/uploads/financiero/')||!$path||!str_starts_with($path,$root.DIRECTORY_SEPARATOR)||!is_file($path))Response::abort(404,'Archivo no disponible.');
  $mime=(new \finfo(FILEINFO_MIME_TYPE))->file($path);if(!in_array($mime,['application/pdf','image/jpeg','image/png'],true)||$mime!==$f['mime_type'])Response::abort(415,'Archivo inválido.');
  if(!empty($f['hash_sha256'])&&!hash_equals(strtolower((string)$f['hash_sha256']),hash_file('sha256',$path)))Response::abort(409,'Integridad del archivo inválida.');
  $name=preg_replace('/[^a-zA-Z0-9._-]/','_',basename((string)$f['nombre_original']));if(!$name)$name='comprobante-'.$id;
  header('Content-Type: '.$mime);header('Content-Disposition: '.((string)$r->input('descargar')==='1'?'attachment':'inline').'; filename="'.$name.'"');header('X-Content-Type-Options: nosniff');header('Content-Security-Policy: sandbox');header('Cache-Control: private, no-store');readfile($path);exit;
 }
}
