<?php
declare(strict_types=1);
namespace App\Controllers\Auth;
use App\Core\{Config,Container,Database,Response,Session};
use App\Integrations\Microsoft\MicrosoftOidcClient;
use App\Repositories\{IdentityRepository,MicrosoftIdentityRepository};
use App\Services\MicrosoftAuthService;

final class MicrosoftAuthController
{
    private function cfg():Config{return Container::get(Config::class);}
    private function enabled():bool{return $this->cfg()->bool('MICROSOFT_LOGIN_ENABLED');}
    private function client():MicrosoftOidcClient{
        $c=$this->cfg();return new MicrosoftOidcClient((string)$c->get('MICROSOFT_TENANT_ID'),(string)$c->get('MICROSOFT_CLIENT_ID'),
          (string)$c->get('MICROSOFT_CLIENT_SECRET'),(string)$c->get('MICROSOFT_REDIRECT_URI'));
    }
    public function redirect():never{
        if(!$this->enabled())Response::abort(404,'Microsoft SSO no está habilitado.');
        $state=bin2hex(random_bytes(32));$nonce=bin2hex(random_bytes(32));$verifier=self::verifier();$challenge=self::b64(hash('sha256',$verifier,true));
        Session::set('ms_oauth',['state'=>$state,'nonce'=>$nonce,'verifier'=>$verifier,'created'=>time()]);
        header('Location: '.$this->client()->authorizationUrl($state,$nonce,$challenge));exit;
    }
    public function callback():never{
        if(!$this->enabled())Response::abort(404,'Microsoft SSO no está habilitado.');
        $flow=Session::get('ms_oauth');unset($_SESSION['ms_oauth']);
        if(!$flow||time()-(int)$flow['created']>600)Response::abort(401,'Flujo Microsoft expirado.');
        if(isset($_GET['error']))Response::abort(401,'Microsoft rechazó el inicio de sesión: '.htmlspecialchars((string)($_GET['error_description']??$_GET['error'])));
        if(empty($_GET['state'])||!hash_equals((string)$flow['state'],(string)$_GET['state']))Response::abort(401,'State OAuth inválido.');
        if(empty($_GET['code']))Response::abort(401,'Microsoft no devolvió código de autorización.');
        try{
            $tokens=$this->client()->redeem((string)$_GET['code'],(string)$flow['verifier']);
            $claims=$this->client()->validateIdToken((string)$tokens['id_token'],(string)$flow['nonce']);
            $db=Container::get(Database::class)->connection();$identity=new IdentityRepository($db);
            $result=(new MicrosoftAuthService($identity,new MicrosoftIdentityRepository($db)))->login($claims,(string)$this->cfg()->get('MICROSOFT_TENANT_ID'));
            Response::redirect($result['selected']?'/dashboard':'/perfil');
        }catch(\Throwable $e){Response::abort(401,$e->getMessage());}
    }
    private static function verifier():string{return self::b64(random_bytes(64));}
    private static function b64(string $s):string{return rtrim(strtr(base64_encode($s),'+/','-_'),'=');}
}
