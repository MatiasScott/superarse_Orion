<?php
declare(strict_types=1);
namespace App\Controllers\Admin;
use App\Core\{Container,Csrf,Database,Request,Response,Session,View}; use App\Integrations\Microsoft\MicrosoftGraphClient; use App\Repositories\TicProvisioningRepository; use App\Services\{AccessService,TicProvisioningService};
final class TicProvisioningController
{
 private function repo():TicProvisioningRepository{return new TicProvisioningRepository(Container::get(Database::class)->connection());}
 private function graph():MicrosoftGraphClient{return new MicrosoftGraphClient((string)($_ENV['MICROSOFT_TENANT_ID']??''),(string)($_ENV['MICROSOFT_CLIENT_ID']??''),(string)($_ENV['MICROSOFT_CLIENT_SECRET']??''));}
 private function service():TicProvisioningService{return new TicProvisioningService($this->repo(),$this->graph());}
 private function actor():int{return (int)Session::get('auth_user')['id'];}
 private function csrf(Request $r):void{if(!Csrf::validate((string)$r->input('_csrf')))Response::abort(419,'CSRF inválido.');}
 public function index(Request $r):void{AccessService::require('tic.cuentas.ver');$filter=strtoupper(trim((string)($r->input('estado')?:'ACTIVAS')));View::render('admin/tic/index',['title'=>'TIC · Cuentas institucionales','requests'=>$this->repo()->requests($filter),'filter'=>$filter]);}
 public function accounts(Request $r):void{AccessService::require('tic.cuentas.ver');View::render('admin/tic/accounts',['title'=>'Cuentas institucionales','accounts'=>$this->repo()->accounts()]);}
 public function account(Request $r):void{AccessService::require('tic.cuentas.ver');$id=(int)$r->input('id');$repo=$this->repo();$account=$repo->account($id);if(!$account)Response::abort(404,'Cuenta institucional no encontrada.');View::render('admin/tic/account',['title'=>$account['email_institucional'],'account'=>$account,'events'=>$repo->accountEvents($id)]);}
 public function show(Request $r):void{AccessService::require('tic.cuentas.ver');$id=(int)$r->input('id');$repo=$this->repo();$req=$repo->request($id);if(!$req)Response::abort(404,'Solicitud no encontrada.');$repo->setReview($id,$this->actor());View::render('admin/tic/show',['title'=>'Solicitud '.$req['numero_solicitud'],'request'=>$repo->request($id),'usernames'=>$repo->usernames($id),'automaticLicense'=>$repo->defaultLicenseForProfile($req['perfil_solicitado_id']?(int)$req['perfil_solicitado_id']:null)]);}
 public function validateUsernames(Request $r):never{$this->csrf($r);AccessService::require('tic.cuentas.aprobar');$id=(int)$r->input('id');$this->service()->validateCandidates($id);Response::redirect('/admin/tic/solicitud?id='.$id);}
 public function selectUsername(Request $r):never{$this->csrf($r);AccessService::require('tic.cuentas.aprobar');$id=(int)$r->input('id');$this->repo()->selectCandidate($id,(int)$r->input('candidate_id'));Response::redirect('/admin/tic/solicitud?id='.$id);}
 public function licenses(Request $r):void{AccessService::require('tic.licencias.gestionar');$error=null;$skus=[];try{$skus=$this->service()->skus();}catch(\Throwable $e){$error=$e->getMessage();}View::render('admin/tic/licenses',['title'=>'Licencias Microsoft 365','licenses'=>$this->repo()->licenseTypes(),'skus'=>$skus,'error'=>$error]);}
 public function licenseSave(Request $r):never{$this->csrf($r);AccessService::require('tic.licencias.gestionar');$this->repo()->saveSku((int)$r->input('license_id'),trim((string)$r->input('sku_id')));Response::redirect('/admin/tic/licencias');}
 public function provision(Request $r):void{$this->csrf($r);AccessService::require('tic.cuentas.aprobar');$id=(int)$r->input('id');try{$result=$this->service()->provision($id,$this->actor(),null);View::render('admin/tic/result',['title'=>'Cuenta provisionada','result'=>$result]);}catch(\Throwable $e){View::render('admin/tic/result',['title'=>'Error de provisionamiento','error'=>$e->getMessage(),'request_id'=>$id]);}}
 public function resetPassword(Request $r):void{$this->csrf($r);AccessService::require('tic.cuentas.password_reset');$id=(int)$r->input('id');try{$this->service()->resetPassword($id,$this->actor());View::render('admin/tic/password-result',['title'=>'Contraseña restablecida','account'=>$this->repo()->account($id)]);}catch(\Throwable $e){View::render('admin/tic/password-result',['title'=>'No se pudo restablecer la contraseña','error'=>$e->getMessage(),'account'=>$this->repo()->account($id)]);}}
}
