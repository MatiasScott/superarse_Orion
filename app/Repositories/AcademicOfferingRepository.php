<?php
declare(strict_types=1);
namespace App\Repositories;
use PDO;
use RuntimeException;
final class AcademicOfferingRepository{
 public function __construct(private PDO $db){}
 public function periods():array{return $this->db->query("SELECT p.*,t.nombre tipo,e.nombre estado,e.permite_matricula,e.permite_calificacion FROM periodos_academicos p LEFT JOIN tipos_periodo_academico t ON t.id=p.tipo_periodo_id JOIN estados_periodo_academico e ON e.id=p.estado_periodo_id WHERE p.deleted_at IS NULL ORDER BY p.fecha_inicio DESC,p.id DESC")->fetchAll();}
 public function period(int $id):?array{$s=$this->db->prepare("SELECT * FROM periodos_academicos WHERE id=:id AND deleted_at IS NULL");$s->execute(['id'=>$id]);return $s->fetch()?:null;}
 public function periodTypes():array{return $this->db->query("SELECT id,codigo,nombre FROM tipos_periodo_academico WHERE activo=1 ORDER BY nombre")->fetchAll();}
 public function periodStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_matricula,permite_calificacion FROM estados_periodo_academico WHERE activo=1 ORDER BY id")->fetchAll();}
 private function institutionId():int{$id=(int)$this->db->query("SELECT id FROM instituciones WHERE activo=1 AND deleted_at IS NULL ORDER BY id LIMIT 1")->fetchColumn();if(!$id)throw new RuntimeException('No existe una institución activa.');return$id;}
 public function savePeriod(array $d):int{
  if($d['end']<$d['start'])throw new RuntimeException('La fecha fin no puede ser anterior a la fecha de inicio.');
  foreach([['ms','me','matrícula'],['gs','ge','calificaciones']] as [$a,$b,$label])if($d[$a]&&$d[$b]&&$d[$b]<$d[$a])throw new RuntimeException('La fecha fin de '.$label.' no puede ser anterior a su inicio.');
  if($d['id']){$s=$this->db->prepare("UPDATE periodos_academicos SET tipo_periodo_id=:t,estado_periodo_id=:e,codigo=:c,nombre=:n,fecha_inicio=:fi,fecha_fin=:ff,fecha_inicio_matricula=:mi,fecha_fin_matricula=:mf,fecha_inicio_calificaciones=:ci,fecha_fin_calificaciones=:cf,activo=:a WHERE id=:id AND deleted_at IS NULL");$s->execute(['t'=>$d['type']?:null,'e'=>$d['state'],'c'=>$d['code'],'n'=>$d['name'],'fi'=>$d['start'],'ff'=>$d['end'],'mi'=>$d['ms']?:null,'mf'=>$d['me']?:null,'ci'=>$d['gs']?:null,'cf'=>$d['ge']?:null,'a'=>$d['active'],'id'=>$d['id']]);return$d['id'];}
  $s=$this->db->prepare("INSERT INTO periodos_academicos(institucion_id,tipo_periodo_id,estado_periodo_id,codigo,nombre,fecha_inicio,fecha_fin,fecha_inicio_matricula,fecha_fin_matricula,fecha_inicio_calificaciones,fecha_fin_calificaciones,activo) VALUES(:i,:t,:e,:c,:n,:fi,:ff,:mi,:mf,:ci,:cf,:a)");$s->execute(['i'=>$this->institutionId(),'t'=>$d['type']?:null,'e'=>$d['state'],'c'=>$d['code'],'n'=>$d['name'],'fi'=>$d['start'],'ff'=>$d['end'],'mi'=>$d['ms']?:null,'mf'=>$d['me']?:null,'ci'=>$d['gs']?:null,'cf'=>$d['ge']?:null,'a'=>$d['active']]);return(int)$this->db->lastInsertId();
 }
 public function offers():array{return $this->db->query("SELECT o.*,p.nombre periodo,p.codigo periodo_codigo,c.nombre carrera,m.nombre malla,m.codigo malla_codigo,s.nombre sede,mo.nombre modalidad,e.nombre estado,e.permite_matricula,(SELECT COUNT(*) FROM secciones x WHERE x.oferta_academica_id=o.id AND x.deleted_at IS NULL) secciones FROM ofertas_academicas o JOIN periodos_academicos p ON p.id=o.periodo_academico_id JOIN carreras c ON c.id=o.carrera_id JOIN mallas_curriculares m ON m.id=o.malla_id LEFT JOIN sedes s ON s.id=o.sede_id LEFT JOIN modalidades_academicas mo ON mo.id=o.modalidad_academica_id JOIN estados_oferta_academica e ON e.id=o.estado_oferta_id ORDER BY p.fecha_inicio DESC,c.nombre,o.id DESC")->fetchAll();}
 public function offer(int $id):?array{$s=$this->db->prepare("SELECT o.*,p.nombre periodo,c.nombre carrera,m.nombre malla,s.nombre sede,mo.nombre modalidad,e.nombre estado FROM ofertas_academicas o JOIN periodos_academicos p ON p.id=o.periodo_academico_id JOIN carreras c ON c.id=o.carrera_id JOIN mallas_curriculares m ON m.id=o.malla_id LEFT JOIN sedes s ON s.id=o.sede_id LEFT JOIN modalidades_academicas mo ON mo.id=o.modalidad_academica_id JOIN estados_oferta_academica e ON e.id=o.estado_oferta_id WHERE o.id=:id");$s->execute(['id'=>$id]);return$s->fetch()?:null;}
 public function offerStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_matricula FROM estados_oferta_academica WHERE activo=1 ORDER BY id")->fetchAll();}
 public function careers():array{return $this->db->query("SELECT id,codigo,nombre FROM carreras WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}
 public function curricula():array{return $this->db->query("SELECT m.id,m.carrera_id,m.codigo,m.nombre,c.nombre carrera FROM mallas_curriculares m JOIN carreras c ON c.id=m.carrera_id WHERE m.activo=1 AND m.deleted_at IS NULL ORDER BY c.nombre,m.nombre")->fetchAll();}
 public function campuses():array{return $this->db->query("SELECT id,codigo,nombre FROM sedes WHERE activo=1 AND deleted_at IS NULL ORDER BY nombre")->fetchAll();}
 public function modalities():array{return $this->db->query("SELECT id,codigo,nombre FROM modalidades_academicas WHERE activo=1 ORDER BY nombre")->fetchAll();}
 public function saveOffer(array $d):int{
  $q=$this->db->prepare("SELECT carrera_id FROM mallas_curriculares WHERE id=:m AND activo=1 AND deleted_at IS NULL");$q->execute(['m'=>$d['curriculum']]);if((int)$q->fetchColumn()!==$d['career'])throw new RuntimeException('La malla seleccionada no pertenece a la carrera.');
  if($d['id']){$s=$this->db->prepare("UPDATE ofertas_academicas SET periodo_academico_id=:p,carrera_id=:c,malla_id=:m,sede_id=:s,modalidad_academica_id=:mo,estado_oferta_id=:e,codigo=:co,nombre=:n,fecha_publicacion=:fp,activo=:a WHERE id=:id");$s->execute(['p'=>$d['period'],'c'=>$d['career'],'m'=>$d['curriculum'],'s'=>$d['campus']?:null,'mo'=>$d['modality']?:null,'e'=>$d['state'],'co'=>$d['code'],'n'=>$d['name'],'fp'=>$d['published']?:null,'a'=>$d['active'],'id'=>$d['id']]);return$d['id'];}
  $s=$this->db->prepare("INSERT INTO ofertas_academicas(periodo_academico_id,carrera_id,malla_id,sede_id,modalidad_academica_id,estado_oferta_id,codigo,nombre,fecha_publicacion,activo) VALUES(:p,:c,:m,:s,:mo,:e,:co,:n,:fp,:a)");$s->execute(['p'=>$d['period'],'c'=>$d['career'],'m'=>$d['curriculum'],'s'=>$d['campus']?:null,'mo'=>$d['modality']?:null,'e'=>$d['state'],'co'=>$d['code'],'n'=>$d['name'],'fp'=>$d['published']?:null,'a'=>$d['active']]);return(int)$this->db->lastInsertId();
 }
 public function curriculumSubjectsForOffer(int $offer):array{$s=$this->db->prepare("SELECT ma.id,a.codigo,a.nombre,n.nombre nivel,n.orden_nivel FROM ofertas_academicas o JOIN malla_asignaturas ma ON ma.malla_id=o.malla_id AND ma.activa=1 JOIN asignaturas a ON a.id=ma.asignatura_id JOIN niveles_academicos n ON n.id=ma.nivel_academico_id WHERE o.id=:o ORDER BY n.orden_nivel,ma.orden_en_nivel,a.nombre");$s->execute(['o'=>$offer]);return$s->fetchAll();}
 public function sections(int $offer):array{$s=$this->db->prepare("SELECT x.*,a.codigo asignatura_codigo,a.nombre asignatura,n.nombre nivel,p.nombre paralelo,e.nombre estado,e.permite_matricula FROM secciones x JOIN malla_asignaturas ma ON ma.id=x.malla_asignatura_id JOIN asignaturas a ON a.id=ma.asignatura_id JOIN niveles_academicos n ON n.id=ma.nivel_academico_id LEFT JOIN paralelos p ON p.id=x.paralelo_id JOIN estados_seccion e ON e.id=x.estado_seccion_id WHERE x.oferta_academica_id=:o AND x.deleted_at IS NULL ORDER BY n.orden_nivel,a.nombre,x.codigo");$s->execute(['o'=>$offer]);return$s->fetchAll();}
 public function sectionStates():array{return $this->db->query("SELECT id,codigo,nombre,permite_matricula FROM estados_seccion WHERE activo=1 ORDER BY id")->fetchAll();}
 public function parallels():array{return $this->db->query("SELECT id,codigo,nombre FROM paralelos WHERE activo=1 ORDER BY id")->fetchAll();}
 public function saveSection(array $d):int{
  $q=$this->db->prepare("SELECT COUNT(*) FROM ofertas_academicas o JOIN malla_asignaturas ma ON ma.malla_id=o.malla_id WHERE o.id=:o AND ma.id=:ma AND ma.activa=1");$q->execute(['o'=>$d['offer'],'ma'=>$d['subject']]);if(!(int)$q->fetchColumn())throw new RuntimeException('La asignatura no pertenece a la malla de esta oferta.');
  // Política institucional: un único paralelo A y cupos calculados en backend.
  $rule=$this->db->prepare("SELECT c.nombre carrera,n.orden_nivel nivel FROM ofertas_academicas o JOIN carreras c ON c.id=o.carrera_id JOIN malla_asignaturas ma ON ma.id=:ma AND ma.malla_id=o.malla_id JOIN niveles_academicos n ON n.id=ma.nivel_academico_id WHERE o.id=:o");
  $rule->execute(['ma'=>$d['subject'],'o'=>$d['offer']]);
  $context=$rule->fetch(PDO::FETCH_ASSOC);
  if (!$context) throw new RuntimeException('No se pudo determinar carrera y nivel de la sección.');
  $parallel=$this->db->query("SELECT id FROM paralelos WHERE UPPER(TRIM(codigo))='A' AND activo=1 ORDER BY id LIMIT 1")->fetchColumn();
  if (!$parallel) throw new RuntimeException('No está configurado el paralelo A en Orion.');
  $d['parallel']=(int)$parallel;
  $career=strtolower(trim((string)$context['carrera']));
  $career=preg_replace('/[áàäâ]/u','a',$career);
  $d['capacity']=(str_contains($career,'topografia') && (int)$context['nivel']===1)?25:50;
  $s=$this->db->prepare("INSERT INTO secciones(oferta_academica_id,malla_asignatura_id,paralelo_id,estado_seccion_id,codigo,nombre,cupo_maximo,permite_matricula,fecha_apertura,fecha_cierre,activo) VALUES(:o,:ma,:p,:e,:c,:n,:cu,:pm,:fa,:fc,1)");$s->execute(['o'=>$d['offer'],'ma'=>$d['subject'],'p'=>$d['parallel']?:null,'e'=>$d['state'],'c'=>$d['code'],'n'=>$d['name'],'cu'=>$d['capacity']?:null,'pm'=>$d['allow'],'fa'=>$d['open']?:null,'fc'=>$d['close']?:null]);return(int)$this->db->lastInsertId();
 }
}
