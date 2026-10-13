<?php
declare(strict_types=1);
namespace App\Integrations\Microsoft;

use RuntimeException;

final class MicrosoftGraphClient
{
    private ?string $token=null;
    public function __construct(private string $tenant,private string $clientId,private string $clientSecret){}

    private function accessToken():string
    {
        if($this->token)return $this->token;
        $url='https://login.microsoftonline.com/'.rawurlencode($this->tenant).'/oauth2/v2.0/token';
        $body=http_build_query(['client_id'=>$this->clientId,'client_secret'=>$this->clientSecret,'scope'=>'https://graph.microsoft.com/.default','grant_type'=>'client_credentials'],'','&',PHP_QUERY_RFC3986);
        [$status,$data]=$this->requestRaw('POST',$url,$body,['Content-Type: application/x-www-form-urlencoded'],false);
        if($status!==200||empty($data['access_token']))throw new RuntimeException('No fue posible obtener token de aplicación Microsoft Graph. '.($data['error_description']??''));
        return $this->token=(string)$data['access_token'];
    }
    public function userByUpn(string $upn):?array
    {
        [$status,$data]=$this->graph('GET','/users/'.rawurlencode($upn).'?%24select=id,userPrincipalName,displayName');
        if($status===404)return null;
        if($status!==200)$this->fail($status,$data,'consultar usuario');
        return $data;
    }
    public function createUser(array $body):array
    {
        [$status,$data]=$this->graph('POST','/users',$body);
        if($status!==201)$this->fail($status,$data,'crear usuario');
        return $data;
    }
    public function subscribedSkus():array
    {
        [$status,$data]=$this->graph('GET','/subscribedSkus?%24select=skuId,skuPartNumber,capabilityStatus,consumedUnits,prepaidUnits');
        if($status!==200)$this->fail($status,$data,'consultar licencias');
        return $data['value']??[];
    }
    public function assignLicense(string $userId,string $skuId):array
    {
        [$status,$data]=$this->graph('POST','/users/'.rawurlencode($userId).'/assignLicense',['addLicenses'=>[['skuId'=>$skuId]],'removeLicenses'=>[]]);
        if($status!==200)$this->fail($status,$data,'asignar licencia');
        return $data;
    }
    public function resetPassword(string $userId,string $password):void
    {
        [$status,$data]=$this->graph('PATCH','/users/'.rawurlencode($userId),['passwordProfile'=>['forceChangePasswordNextSignIn'=>true,'password'=>$password]]);
        if($status!==204)$this->fail($status,$data,'restablecer contraseña');
    }
    private function graph(string $method,string $path,array|null $body=null):array
    {
        $headers=['Authorization: Bearer '.$this->accessToken(),'Accept: application/json'];$payload=null;
        if($body!==null){$payload=json_encode($body,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR);$headers[]='Content-Type: application/json';}
        return $this->requestRaw($method,'https://graph.microsoft.com/v1.0'.$path,$payload,$headers,true);
    }
    private function requestRaw(string $method,string $url,?string $payload,array $headers,bool $json):array
    {
        $ch=curl_init($url);$opts=[CURLOPT_CUSTOMREQUEST=>$method,CURLOPT_RETURNTRANSFER=>true,CURLOPT_HTTPHEADER=>$headers,CURLOPT_TIMEOUT=>30];
        if($payload!==null)$opts[CURLOPT_POSTFIELDS]=$payload;curl_setopt_array($ch,$opts);
        $raw=curl_exec($ch);$status=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);$err=curl_error($ch);curl_close($ch);
        if($raw===false)throw new RuntimeException('Error de comunicación con Microsoft: '.$err);
        $data=$raw===''?[]:json_decode($raw,true);
        if(!is_array($data))$data=['raw'=>$raw];return [$status,$data];
    }
    private function fail(int $status,array $data,string $action):never
    {
        $msg=$data['error']['message']??$data['error_description']??'Respuesta no esperada';$code=$data['error']['code']??'GRAPH_ERROR';
        throw new RuntimeException("Microsoft Graph no pudo $action [$status/$code]: $msg");
    }
}
