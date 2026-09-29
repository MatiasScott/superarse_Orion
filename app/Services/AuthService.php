<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Session;
use App\Repositories\IdentityRepository;

final class AuthService
{
    public function __construct(private IdentityRepository $repo) {}

    public function loginDeveloper(string $identification): array
    {
        $user=$this->repo->findUserByIdentification($identification);
        if(!$user || !$user['usuario_activo'] || !$user['persona_activa'] || !$user['permite_acceso'])
            throw new \RuntimeException('Usuario inexistente, inactivo o sin acceso.');

        $profiles=$this->repo->profiles((int)$user['usuario_id']);
        if(!$profiles) throw new \RuntimeException('El usuario no tiene perfiles activos.');

        Session::regenerate();
        $profile=count($profiles)===1?$profiles[0]:null;
        $uuid=self::uuid();
        $sid=$this->repo->createSession((int)$user['usuario_id'],$profile? (int)$profile['id']:null,$uuid,$this->repo->authTypeId('LOCAL_EMERGENCIA'));
        $this->repo->touchLogin((int)$user['usuario_id']);

        Session::set('auth_user',[
            'id'=>(int)$user['usuario_id'],
            'persona_id'=>(int)$user['persona_id'],
            'identificacion'=>$user['numero_identificacion'],
            'nombre'=>trim($user['primer_nombre'].' '.($user['segundo_nombre']??'').' '.$user['primer_apellido'].' '.($user['segundo_apellido']??'')),
        ]);
        Session::set('db_session_id',$sid);
        Session::set('profiles',$profiles);

        if($profile) $this->selectProfile((int)$profile['id'],false);
        return ['profiles'=>$profiles,'selected'=>$profile];
    }

    public function selectProfile(int $profileId,bool $writeHistory=true): array
    {
        $user=Session::get('auth_user');
        if(!$user) throw new \RuntimeException('Sesión no autenticada.');
        $profiles=$this->repo->profiles((int)$user['id']);
        $selected=null;
        foreach($profiles as $p) if((int)$p['id']===$profileId){$selected=$p;break;}
        if(!$selected) throw new \RuntimeException('Perfil no autorizado.');

        $old=Session::get('active_profile');
        if($writeHistory && Session::get('db_session_id'))
            $this->repo->changeSessionProfile((int)Session::get('db_session_id'),$old?(int)$old['id']:null,$profileId);

        Session::set('active_profile',$selected);
        Session::set('roles',$this->repo->roles((int)$user['id'],$profileId));
        Session::set('permissions',$this->repo->permissions((int)$user['id'],$profileId));
        return $selected;
    }

    public function logout(): void
    {
        if(Session::get('db_session_id')) $this->repo->closeSession((int)Session::get('db_session_id'));
        $_SESSION=[];
        if(ini_get('session.use_cookies')){
            $p=session_get_cookie_params();
            setcookie(session_name(),'',time()-42000,$p['path'],$p['domain']??'',(bool)$p['secure'],(bool)$p['httponly']);
        }
        session_destroy();
    }

    private static function uuid(): string
    {
        $d=random_bytes(16);$d[6]=chr((ord($d[6])&0x0f)|0x40);$d[8]=chr((ord($d[8])&0x3f)|0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s',str_split(bin2hex($d),4));
    }
}
