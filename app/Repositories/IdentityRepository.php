<?php
declare(strict_types=1);

namespace App\Repositories;

use PDO;

final class IdentityRepository
{
    public function __construct(private PDO $db) {}

    public function findUserByIdentification(string $identification): ?array
    {
        $sql = "SELECT u.id usuario_id,u.persona_id,u.estado_usuario_id,u.requiere_actualizacion_datos,
                       u.activo usuario_activo,p.numero_identificacion,p.primer_nombre,p.segundo_nombre,
                       p.primer_apellido,p.segundo_apellido,p.activo persona_activa,
                       eu.codigo estado_codigo,eu.permite_acceso
                  FROM usuarios u
                  JOIN personas p ON p.id=u.persona_id
                  JOIN estados_usuario eu ON eu.id=u.estado_usuario_id
                 WHERE p.numero_identificacion=:identificacion
                   AND u.deleted_at IS NULL AND p.deleted_at IS NULL
                 LIMIT 1";
        $s=$this->db->prepare($sql);
        $s->execute(['identificacion'=>$identification]);
        return $s->fetch() ?: null;
    }

    public function profiles(int $userId): array
    {
        $sql="SELECT p.id,p.codigo,p.nombre,p.descripcion,p.ruta_inicio,p.orden_visual
                FROM usuario_perfiles up
                JOIN perfiles p ON p.id=up.perfil_id
               WHERE up.usuario_id=:uid AND up.activo=1 AND p.activo=1
                 AND (up.fecha_fin IS NULL OR up.fecha_fin>NOW())
               ORDER BY p.orden_visual,p.nombre";
        $s=$this->db->prepare($sql); $s->execute(['uid'=>$userId]);
        return $s->fetchAll();
    }

    public function roles(int $userId, ?int $profileId=null): array
    {
        $sql="SELECT DISTINCT r.id,r.codigo,r.nombre,r.es_sistema
                FROM usuario_roles ur
                JOIN roles r ON r.id=ur.rol_id
               WHERE ur.usuario_id=:uid AND ur.activo=1 AND r.activo=1
                 AND r.deleted_at IS NULL
                 AND (ur.fecha_fin IS NULL OR ur.fecha_fin>NOW())";
        $params=['uid'=>$userId];
        if($profileId!==null){
            $sql.=" AND (r.perfil_id IS NULL OR r.perfil_id=:pid)";
            $params['pid']=$profileId;
        }
        $sql.=" ORDER BY r.nombre";
        $s=$this->db->prepare($sql);$s->execute($params);return $s->fetchAll();
    }

    public function permissions(int $userId, ?int $profileId=null): array
    {
        if ($this->isSuperAdmin($userId,$profileId)) return ['*'];
        $sql="SELECT DISTINCT pe.codigo
                FROM usuario_roles ur
                JOIN roles r ON r.id=ur.rol_id
                JOIN rol_permisos rp ON rp.rol_id=r.id AND rp.permitido=1
                JOIN permisos pe ON pe.id=rp.permiso_id AND pe.activo=1
               WHERE ur.usuario_id=:uid AND ur.activo=1 AND r.activo=1
                 AND r.deleted_at IS NULL
                 AND (ur.fecha_fin IS NULL OR ur.fecha_fin>NOW())";
        $params=['uid'=>$userId];
        if($profileId!==null){$sql.=" AND (r.perfil_id IS NULL OR r.perfil_id=:pid)";$params['pid']=$profileId;}
        $s=$this->db->prepare($sql);$s->execute($params);
        return array_column($s->fetchAll(),'codigo');
    }

    public function isSuperAdmin(int $userId, ?int $profileId=null): bool
    {
        foreach($this->roles($userId,$profileId) as $r) if($r['codigo']==='SUPER_ADMIN') return true;
        return false;
    }

    public function touchLogin(int $userId): void
    {
        $s=$this->db->prepare("UPDATE usuarios SET ultimo_acceso_at=NOW() WHERE id=:id");
        $s->execute(['id'=>$userId]);
    }

    public function createSession(int $userId, ?int $profileId, string $uuid, ?int $authTypeId): int
    {
        $s=$this->db->prepare("INSERT INTO sesiones_usuario
            (usuario_id,perfil_actual_id,session_uuid,tipo_autenticacion_id,ip,user_agent,inicio_at,ultimo_movimiento_at,activa)
            VALUES (:uid,:pid,:uuid,:auth,:ip,:ua,NOW(),NOW(),1)");
        $s->execute([
            'uid'=>$userId,'pid'=>$profileId,'uuid'=>$uuid,'auth'=>$authTypeId,
            'ip'=>$_SERVER['REMOTE_ADDR']??null,'ua'=>substr($_SERVER['HTTP_USER_AGENT']??'',0,500)
        ]);
        return (int)$this->db->lastInsertId();
    }

    public function authTypeId(string $code): ?int
    {
        $s=$this->db->prepare("SELECT id FROM tipos_autenticacion WHERE codigo=:c AND activo=1 LIMIT 1");
        $s->execute(['c'=>$code]); $v=$s->fetchColumn(); return $v===false?null:(int)$v;
    }

    public function closeSession(int $sessionId): void
    {
        $s=$this->db->prepare("UPDATE sesiones_usuario SET activa=0,cierre_at=NOW() WHERE id=:id");
        $s->execute(['id'=>$sessionId]);
    }

    public function changeSessionProfile(int $sessionId, ?int $from, int $to): void
    {
        $this->db->beginTransaction();
        try{
            $s=$this->db->prepare("UPDATE sesiones_usuario SET perfil_actual_id=:pid,ultimo_movimiento_at=NOW() WHERE id=:id AND activa=1");
            $s->execute(['pid'=>$to,'id'=>$sessionId]);
            $h=$this->db->prepare("INSERT INTO historial_cambio_perfil(sesion_id,perfil_origen_id,perfil_destino_id) VALUES(:sid,:ori,:des)");
            $h->execute(['sid'=>$sessionId,'ori'=>$from,'des'=>$to]);
            $this->db->commit();
        }catch(\Throwable $e){$this->db->rollBack();throw $e;}
    }

    public function bootstrapDeveloperAdmin(string $identification, string $firstName, string $lastName): int
    {
        $existing=$this->findUserByIdentification($identification);
        if($existing) return (int)$existing['usuario_id'];

        $this->db->beginTransaction();
        try{
            $tipo=(int)$this->db->query("SELECT id FROM tipos_identificacion WHERE codigo='CEDULA' LIMIT 1")->fetchColumn();
            $estado=(int)$this->db->query("SELECT id FROM estados_usuario WHERE codigo='ACTIVO' LIMIT 1")->fetchColumn();
            $perfil=(int)$this->db->query("SELECT id FROM perfiles WHERE codigo='ADMINISTRATIVO' LIMIT 1")->fetchColumn();

            $s=$this->db->prepare("INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,primer_apellido,activo)
                                   VALUES(:t,:n,:pn,:pa,1)");
            $s->execute(['t'=>$tipo,'n'=>$identification,'pn'=>$firstName,'pa'=>$lastName]);
            $person=(int)$this->db->lastInsertId();

            $s=$this->db->prepare("INSERT INTO usuarios(persona_id,estado_usuario_id,activo) VALUES(:p,:e,1)");
            $s->execute(['p'=>$person,'e'=>$estado]); $user=(int)$this->db->lastInsertId();

            $s=$this->db->prepare("INSERT INTO usuario_perfiles(usuario_id,perfil_id,activo) VALUES(:u,:p,1)");
            $s->execute(['u'=>$user,'p'=>$perfil]);

            $s=$this->db->prepare("INSERT INTO roles(perfil_id,codigo,nombre,descripcion,es_sistema,activo)
                VALUES(:p,'SUPER_ADMIN','Super Administrador','Acceso global de administración Orion',1,1)
                ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)");
            $s->execute(['p'=>$perfil]); $role=(int)$this->db->lastInsertId();

            $s=$this->db->prepare("INSERT INTO usuario_roles(usuario_id,rol_id,activo) VALUES(:u,:r,1)
                ON DUPLICATE KEY UPDATE activo=1,fecha_fin=NULL");
            $s->execute(['u'=>$user,'r'=>$role]);

            $this->db->commit(); return $user;
        }catch(\Throwable $e){$this->db->rollBack();throw $e;}
    }
}
