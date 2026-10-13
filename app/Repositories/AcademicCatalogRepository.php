<?php
declare(strict_types=1);
namespace App\Repositories;
use PDO;
use RuntimeException;

final class AcademicCatalogRepository
{
    public function __construct(private PDO $db){}

    public function institution():array
    {
        $r=$this->db->query("SELECT id,codigo,nombre FROM instituciones WHERE activo=1 AND deleted_at IS NULL ORDER BY id LIMIT 1")->fetch();
        if(!$r) throw new RuntimeException('No existe una institución activa en Orion.');
        return $r;
    }
    public function careerTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_carrera WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function careerStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_nuevos_ingresos FROM estados_carrera WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function curriculumStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_nuevos_estudiantes,es_historica FROM estados_malla WHERE activo=1 ORDER BY nombre")->fetchAll();}
    public function modalities():array{return $this->db->query("SELECT id,codigo,nombre,descripcion,activo FROM modalidades_academicas ORDER BY nombre")->fetchAll();}

    public function campuses():array
    {
        return $this->db->query("SELECT s.*,i.nombre institucion FROM sedes s JOIN instituciones i ON i.id=s.institucion_id WHERE s.deleted_at IS NULL ORDER BY s.activo DESC,s.nombre")->fetchAll();
    }
    public function campus(int $id):?array
    {
        $s=$this->db->prepare("SELECT * FROM sedes WHERE id=:id AND deleted_at IS NULL");$s->execute(['id'=>$id]);return $s->fetch()?:null;
    }
    public function saveCampus(array $d):int
    {
        $inst=$this->institution();
        if($d['id']){
            $s=$this->db->prepare("UPDATE sedes SET codigo=:codigo,nombre=:nombre,descripcion=:descripcion,activo=:activo WHERE id=:id AND deleted_at IS NULL");
            $s->execute(['codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'descripcion'=>$d['descripcion']?:null,'activo'=>$d['activo'],'id'=>$d['id']]);return (int)$d['id'];
        }
        $s=$this->db->prepare("INSERT INTO sedes(institucion_id,codigo,nombre,descripcion,activo) VALUES(:institucion,:codigo,:nombre,:descripcion,:activo)");
        $s->execute(['institucion'=>$inst['id'],'codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'descripcion'=>$d['descripcion']?:null,'activo'=>$d['activo']]);return (int)$this->db->lastInsertId();
    }

    public function careers():array
    {
        return $this->db->query("SELECT c.*,t.nombre tipo,e.nombre estado,e.permite_nuevos_ingresos,(SELECT COUNT(*) FROM mallas_curriculares m WHERE m.carrera_id=c.id AND m.activo=1 AND m.deleted_at IS NULL) mallas FROM carreras c LEFT JOIN tipos_carrera t ON t.id=c.tipo_carrera_id JOIN estados_carrera e ON e.id=c.estado_carrera_id WHERE c.deleted_at IS NULL ORDER BY c.activo DESC,c.nombre")->fetchAll();
    }
    public function career(int $id):?array
    {
        $s=$this->db->prepare("SELECT * FROM carreras WHERE id=:id AND deleted_at IS NULL");$s->execute(['id'=>$id]);return $s->fetch()?:null;
    }
    public function saveCareer(array $d):int
    {
        $inst=$this->institution();
        $p=['tipo'=>$d['tipo']?:null,'estado'=>$d['estado'],'codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'titulo'=>$d['titulo']?:null,'abreviatura'=>$d['abreviatura']?:null,'niveles'=>$d['niveles']?:null,'inicio'=>$d['inicio']?:null,'fin'=>$d['fin']?:null,'activo'=>$d['activo']];
        if($d['id']){
            $p['id']=$d['id'];$s=$this->db->prepare("UPDATE carreras SET tipo_carrera_id=:tipo,estado_carrera_id=:estado,codigo=:codigo,nombre=:nombre,titulo_otorgado=:titulo,abreviatura=:abreviatura,numero_niveles=:niveles,fecha_inicio_vigencia=:inicio,fecha_fin_vigencia=:fin,activo=:activo WHERE id=:id AND deleted_at IS NULL");$s->execute($p);return (int)$d['id'];
        }
        $p['institucion']=$inst['id'];$s=$this->db->prepare("INSERT INTO carreras(institucion_id,tipo_carrera_id,estado_carrera_id,codigo,nombre,titulo_otorgado,abreviatura,numero_niveles,fecha_inicio_vigencia,fecha_fin_vigencia,activo) VALUES(:institucion,:tipo,:estado,:codigo,:nombre,:titulo,:abreviatura,:niveles,:inicio,:fin,:activo)");$s->execute($p);return (int)$this->db->lastInsertId();
    }

    public function curricula():array
    {
        return $this->db->query("SELECT m.*,c.nombre carrera,e.nombre estado,e.permite_nuevos_estudiantes FROM mallas_curriculares m JOIN carreras c ON c.id=m.carrera_id JOIN estados_malla e ON e.id=m.estado_malla_id WHERE m.deleted_at IS NULL ORDER BY m.activo DESC,c.nombre,m.fecha_inicio_vigencia DESC")->fetchAll();
    }
    public function curriculum(int $id):?array
    {
        $s=$this->db->prepare("SELECT * FROM mallas_curriculares WHERE id=:id AND deleted_at IS NULL");$s->execute(['id'=>$id]);return $s->fetch()?:null;
    }
    public function saveCurriculum(array $d):int
    {
        $p=['carrera'=>$d['carrera'],'estado'=>$d['estado'],'codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'version'=>$d['version']?:null,'descripcion'=>$d['descripcion']?:null,'inicio'=>$d['inicio'],'fin'=>$d['fin']?:null,'activo'=>$d['activo']];
        if($d['id']){$p['id']=$d['id'];$s=$this->db->prepare("UPDATE mallas_curriculares SET carrera_id=:carrera,estado_malla_id=:estado,codigo=:codigo,nombre=:nombre,version=:version,descripcion=:descripcion,fecha_inicio_vigencia=:inicio,fecha_fin_vigencia=:fin,activo=:activo WHERE id=:id AND deleted_at IS NULL");$s->execute($p);return (int)$d['id'];}
        $s=$this->db->prepare("INSERT INTO mallas_curriculares(carrera_id,estado_malla_id,codigo,nombre,version,descripcion,fecha_inicio_vigencia,fecha_fin_vigencia,activo) VALUES(:carrera,:estado,:codigo,:nombre,:version,:descripcion,:inicio,:fin,:activo)");$s->execute($p);return (int)$this->db->lastInsertId();
    }

    public function saveModality(array $d):int
    {
        if($d['id']){$s=$this->db->prepare("UPDATE modalidades_academicas SET codigo=:codigo,nombre=:nombre,descripcion=:descripcion,activo=:activo WHERE id=:id");$s->execute(['codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'descripcion'=>$d['descripcion']?:null,'activo'=>$d['activo'],'id'=>$d['id']]);return (int)$d['id'];}
        $s=$this->db->prepare("INSERT INTO modalidades_academicas(codigo,nombre,descripcion,activo) VALUES(:codigo,:nombre,:descripcion,:activo)");$s->execute(['codigo'=>$d['codigo'],'nombre'=>$d['nombre'],'descripcion'=>$d['descripcion']?:null,'activo'=>$d['activo']]);return (int)$this->db->lastInsertId();
    }
}
