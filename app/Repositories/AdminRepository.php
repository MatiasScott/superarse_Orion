<?php
declare(strict_types=1);
namespace App\Repositories;
use PDO;

final class AdminRepository
{
    public function __construct(private PDO $db){}

    public function users(string $q=''): array {
        $sql="SELECT u.id,u.persona_id,p.numero_identificacion,
                     CONCAT_WS(' ',p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido) nombre,
                     eu.codigo estado_codigo,eu.nombre estado_nombre,eu.permite_acceso,
                     u.activo,u.ultimo_acceso_at,u.created_at,
                     GROUP_CONCAT(DISTINCT pf.nombre ORDER BY pf.orden_visual SEPARATOR ', ') perfiles
                FROM usuarios u
                JOIN personas p ON p.id=u.persona_id
                JOIN estados_usuario eu ON eu.id=u.estado_usuario_id
                LEFT JOIN usuario_perfiles up ON up.usuario_id=u.id AND up.activo=1
                LEFT JOIN perfiles pf ON pf.id=up.perfil_id AND pf.activo=1
               WHERE u.deleted_at IS NULL AND p.deleted_at IS NULL";
        $params=[];
        if($q!==''){
            $sql.=" AND (p.numero_identificacion LIKE :q OR p.primer_nombre LIKE :q OR p.segundo_nombre LIKE :q OR p.primer_apellido LIKE :q OR p.segundo_apellido LIKE :q)";
            $params['q']='%'.$q.'%';
        }
        $sql.=" GROUP BY u.id,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido,
                       eu.codigo,eu.nombre,eu.permite_acceso,u.activo,u.ultimo_acceso_at,u.created_at
                ORDER BY p.primer_apellido,p.primer_nombre LIMIT 200";
        $s=$this->db->prepare($sql);$s->execute($params);return $s->fetchAll();
    }

    public function user(int $id): ?array {
        $s=$this->db->prepare("SELECT u.*,p.tipo_identificacion_id,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,
          p.primer_apellido,p.segundo_apellido,p.activo persona_activa,eu.codigo estado_codigo
          FROM usuarios u JOIN personas p ON p.id=u.persona_id JOIN estados_usuario eu ON eu.id=u.estado_usuario_id
          WHERE u.id=:id AND u.deleted_at IS NULL AND p.deleted_at IS NULL LIMIT 1");
        $s->execute(['id'=>$id]);return $s->fetch()?:null;
    }
    public function identificationTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_identificacion WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function userStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_acceso FROM estados_usuario WHERE activo=1 ORDER BY id")->fetchAll();}
    public function profiles():array{return $this->db->query("SELECT id,codigo,nombre,descripcion,ruta_inicio FROM perfiles WHERE activo=1 ORDER BY orden_visual,nombre")->fetchAll();}
    public function roles():array{return $this->db->query("SELECT r.id,r.codigo,r.nombre,r.descripcion,r.es_sistema,r.activo,p.nombre perfil_nombre,p.id perfil_id,
      (SELECT COUNT(*) FROM rol_permisos rp WHERE rp.rol_id=r.id AND rp.permitido=1) permisos
      FROM roles r LEFT JOIN perfiles p ON p.id=r.perfil_id WHERE r.deleted_at IS NULL ORDER BY r.nombre")->fetchAll();}
    public function activeRoles():array{return $this->db->query("SELECT r.id,r.codigo,r.nombre,r.perfil_id,p.nombre perfil_nombre FROM roles r LEFT JOIN perfiles p ON p.id=r.perfil_id WHERE r.deleted_at IS NULL AND r.activo=1 ORDER BY r.nombre")->fetchAll();}
    public function userProfileIds(int $uid):array{$s=$this->db->prepare("SELECT perfil_id FROM usuario_perfiles WHERE usuario_id=:u AND activo=1");$s->execute(['u'=>$uid]);return array_map('intval',array_column($s->fetchAll(),'perfil_id'));}
    public function userRoleIds(int $uid):array{$s=$this->db->prepare("SELECT rol_id FROM usuario_roles WHERE usuario_id=:u AND activo=1");$s->execute(['u'=>$uid]);return array_map('intval',array_column($s->fetchAll(),'rol_id'));}

    public function createUser(array $d,int $actor):int {
        $this->db->beginTransaction();
        try{
            $s=$this->db->prepare("INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,segundo_nombre,primer_apellido,segundo_apellido,activo)
              VALUES(:tipo,:ident,:pn,:sn,:pa,:sa,1)");
            $s->execute(['tipo'=>$d['tipo_identificacion_id'],'ident'=>$d['numero_identificacion'],'pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null]);
            $pid=(int)$this->db->lastInsertId();
            $s=$this->db->prepare("INSERT INTO usuarios(persona_id,estado_usuario_id,activo) VALUES(:p,:e,1)");
            $s->execute(['p'=>$pid,'e'=>$d['estado_usuario_id']]);$uid=(int)$this->db->lastInsertId();
            $this->syncProfiles($uid,$d['perfiles']??[],$actor);
            $this->syncRoles($uid,$d['roles']??[],$actor);
            $this->db->commit();return $uid;
        }catch(\Throwable $e){$this->db->rollBack();throw $e;}
    }

    public function updateUser(int $uid,array $d,int $actor):void {
        $u=$this->user($uid);if(!$u)throw new \RuntimeException('Usuario no encontrado.');
        $this->db->beginTransaction();
        try{
            $s=$this->db->prepare("UPDATE personas SET tipo_identificacion_id=:tipo,numero_identificacion=:ident,primer_nombre=:pn,segundo_nombre=:sn,primer_apellido=:pa,segundo_apellido=:sa WHERE id=:id");
            $s->execute(['tipo'=>$d['tipo_identificacion_id'],'ident'=>$d['numero_identificacion'],'pn'=>$d['primer_nombre'],'sn'=>$d['segundo_nombre']?:null,'pa'=>$d['primer_apellido'],'sa'=>$d['segundo_apellido']?:null,'id'=>$u['persona_id']]);
            $s=$this->db->prepare("UPDATE usuarios SET estado_usuario_id=:e,activo=:a WHERE id=:id");
            $s->execute(['e'=>$d['estado_usuario_id'],'a'=>isset($d['activo'])?1:0,'id'=>$uid]);
            $this->syncProfiles($uid,$d['perfiles']??[],$actor);
            $this->syncRoles($uid,$d['roles']??[],$actor);
            $this->db->commit();
        }catch(\Throwable $e){$this->db->rollBack();throw $e;}
    }

    private function syncProfiles(int $uid,array $ids,int $actor):void {
        $ids=array_values(array_unique(array_map('intval',$ids)));
        $this->db->prepare("UPDATE usuario_perfiles SET activo=0,fecha_fin=COALESCE(fecha_fin,NOW()) WHERE usuario_id=:u")->execute(['u'=>$uid]);
        $s=$this->db->prepare("INSERT INTO usuario_perfiles(usuario_id,perfil_id,activo,fecha_inicio,fecha_fin,asignado_por_usuario_id)
          VALUES(:u,:p,1,NOW(),NULL,:a) ON DUPLICATE KEY UPDATE activo=1,fecha_fin=NULL,asignado_por_usuario_id=VALUES(asignado_por_usuario_id)");
        foreach($ids as $id)$s->execute(['u'=>$uid,'p'=>$id,'a'=>$actor]);
    }
    private function syncRoles(int $uid,array $ids,int $actor):void {
        $ids=array_values(array_unique(array_map('intval',$ids)));
        $this->db->prepare("UPDATE usuario_roles SET activo=0,fecha_fin=COALESCE(fecha_fin,NOW()) WHERE usuario_id=:u")->execute(['u'=>$uid]);
        $s=$this->db->prepare("INSERT INTO usuario_roles(usuario_id,rol_id,activo,fecha_inicio,fecha_fin,asignado_por_usuario_id)
          VALUES(:u,:r,1,NOW(),NULL,:a) ON DUPLICATE KEY UPDATE activo=1,fecha_fin=NULL,asignado_por_usuario_id=VALUES(asignado_por_usuario_id)");
        foreach($ids as $id)$s->execute(['u'=>$uid,'r'=>$id,'a'=>$actor]);
    }

    public function createRole(array $d):int {
        $s=$this->db->prepare("INSERT INTO roles(perfil_id,codigo,nombre,descripcion,es_sistema,activo) VALUES(:p,:c,:n,:d,0,1)");
        $s->execute(['p'=>$d['perfil_id']?:null,'c'=>strtoupper(trim($d['codigo'])),'n'=>trim($d['nombre']),'d'=>trim($d['descripcion'])?:null]);return (int)$this->db->lastInsertId();
    }
    public function role(int $id):?array{$s=$this->db->prepare("SELECT * FROM roles WHERE id=:id AND deleted_at IS NULL");$s->execute(['id'=>$id]);return $s->fetch()?:null;}
    public function updateRole(int $id,array $d):void{
        $r=$this->role($id);if(!$r)throw new \RuntimeException('Rol no encontrado.');
        if($r['es_sistema'] && $r['codigo']==='SUPER_ADMIN') throw new \RuntimeException('El rol SUPER_ADMIN es protegido.');
        $s=$this->db->prepare("UPDATE roles SET perfil_id=:p,nombre=:n,descripcion=:d,activo=:a WHERE id=:id");
        $s->execute(['p'=>$d['perfil_id']?:null,'n'=>trim($d['nombre']),'d'=>trim($d['descripcion'])?:null,'a'=>isset($d['activo'])?1:0,'id'=>$id]);
    }
    public function permissions():array{return $this->db->query("SELECT pe.id,pe.codigo,pe.nombre,pe.descripcion,pe.activo,m.codigo modulo_codigo,m.nombre modulo_nombre,m.orden_visual FROM permisos pe JOIN modulos m ON m.id=pe.modulo_id ORDER BY m.orden_visual,m.nombre,pe.nombre")->fetchAll();}
    public function rolePermissionIds(int $rid):array{$s=$this->db->prepare("SELECT permiso_id FROM rol_permisos WHERE rol_id=:r AND permitido=1");$s->execute(['r'=>$rid]);return array_map('intval',array_column($s->fetchAll(),'permiso_id'));}
    public function syncRolePermissions(int $rid,array $ids):void{
        $r=$this->role($rid);if(!$r)throw new \RuntimeException('Rol no encontrado.');
        if($r['codigo']==='SUPER_ADMIN')throw new \RuntimeException('SUPER_ADMIN usa acceso global y no requiere matriz de permisos.');
        $ids=array_values(array_unique(array_map('intval',$ids)));
        $this->db->beginTransaction();
        try{
            $this->db->prepare("DELETE FROM rol_permisos WHERE rol_id=:r")->execute(['r'=>$rid]);
            $s=$this->db->prepare("INSERT INTO rol_permisos(rol_id,permiso_id,permitido) VALUES(:r,:p,1)");
            foreach($ids as $id)$s->execute(['r'=>$rid,'p'=>$id]);
            $this->db->commit();
        }catch(\Throwable $e){$this->db->rollBack();throw $e;}
    }
}
