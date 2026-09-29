<?php
declare(strict_types=1);
namespace App\Core;
use PDO;
final class Database {
 private ?PDO $pdo=null;
 public function __construct(private Config $config){}
 public function connection():PDO{
  if($this->pdo)return $this->pdo;
  $dsn=sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',$this->config->get('DB_HOST','127.0.0.1'),$this->config->get('DB_PORT','3306'),$this->config->get('DB_DATABASE','superarse_siga'));
  return $this->pdo=new PDO($dsn,(string)$this->config->get('DB_USERNAME','root'),(string)$this->config->get('DB_PASSWORD',''),[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
 }
}
