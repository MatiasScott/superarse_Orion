<?php
declare(strict_types=1);
namespace App\Integrations\Microsoft;

final class MicrosoftOidcClient
{
    public function __construct(
        private string $tenant,
        private string $clientId,
        private string $clientSecret,
        private string $redirectUri
    ) {}

    public function authorizationUrl(string $state,string $nonce,string $challenge):string
    {
        $q=http_build_query([
            'client_id'=>$this->clientId,'response_type'=>'code','redirect_uri'=>$this->redirectUri,
            'response_mode'=>'query','scope'=>'openid profile email','state'=>$state,'nonce'=>$nonce,
            'code_challenge'=>$challenge,'code_challenge_method'=>'S256'
        ],'','&',PHP_QUERY_RFC3986);
        return "https://login.microsoftonline.com/".rawurlencode($this->tenant)."/oauth2/v2.0/authorize?".$q;
    }

    public function redeem(string $code,string $verifier):array
    {
        $url="https://login.microsoftonline.com/".rawurlencode($this->tenant)."/oauth2/v2.0/token";
        $body=http_build_query([
            'client_id'=>$this->clientId,'client_secret'=>$this->clientSecret,'grant_type'=>'authorization_code',
            'code'=>$code,'redirect_uri'=>$this->redirectUri,'scope'=>'openid profile email',
            'code_verifier'=>$verifier
        ],'','&',PHP_QUERY_RFC3986);
        $ch=curl_init($url);
        curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>$body,CURLOPT_RETURNTRANSFER=>true,
            CURLOPT_HTTPHEADER=>['Content-Type: application/x-www-form-urlencoded'],CURLOPT_TIMEOUT=>20]);
        $raw=curl_exec($ch);$status=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);$err=curl_error($ch);curl_close($ch);
        if($raw===false||$status<200||$status>=300)throw new \RuntimeException('Microsoft token endpoint rechazó la autenticación. '.$err);
        $data=json_decode($raw,true,512,JSON_THROW_ON_ERROR);
        if(empty($data['id_token']))throw new \RuntimeException('Microsoft no devolvió id_token.');
        return $data;
    }

    public function validateIdToken(string $jwt,string $expectedNonce):array
    {
        [$h,$p,$s]=array_pad(explode('.',$jwt),3,null);
        if(!$h||!$p||!$s)throw new \RuntimeException('ID token inválido.');
        $header=json_decode(self::b64($h),true,512,JSON_THROW_ON_ERROR);
        $claims=json_decode(self::b64($p),true,512,JSON_THROW_ON_ERROR);
        if(($header['alg']??'')!=='RS256'||empty($header['kid']))throw new \RuntimeException('Algoritmo de token no permitido.');

        $keys=$this->jwks();
        $jwk=null;foreach($keys['keys']??[] as $k)if(($k['kid']??null)===$header['kid']){$jwk=$k;break;}
        if(!$jwk)throw new \RuntimeException('No se encontró la clave de firma Microsoft.');
        $pem=$this->jwkToPem($jwk);
        if(openssl_verify("$h.$p",self::b64($s),$pem,OPENSSL_ALGO_SHA256)!==1)throw new \RuntimeException('Firma Microsoft inválida.');

        $now=time();$issuer="https://login.microsoftonline.com/".$this->tenant."/v2.0";
        if(($claims['aud']??null)!==$this->clientId)throw new \RuntimeException('Audience inválido.');
        if(($claims['iss']??null)!==$issuer)throw new \RuntimeException('Issuer inválido.');
        if(($claims['tid']??null)!==$this->tenant)throw new \RuntimeException('Tenant inválido.');
        if(($claims['nonce']??null)!==$expectedNonce)throw new \RuntimeException('Nonce inválido.');
        if((int)($claims['exp']??0)<$now-60||(int)($claims['nbf']??0)>$now+60)throw new \RuntimeException('Token expirado o aún no válido.');
        if(empty($claims['oid']))throw new \RuntimeException('Microsoft no devolvió Object ID.');
        return $claims;
    }

    private function jwks():array
    {
        $url="https://login.microsoftonline.com/".rawurlencode($this->tenant)."/discovery/v2.0/keys";
        $ch=curl_init($url);curl_setopt_array($ch,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15]);
        $raw=curl_exec($ch);$status=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);curl_close($ch);
        if($raw===false||$status!==200)throw new \RuntimeException('No fue posible obtener las claves públicas de Microsoft.');
        return json_decode($raw,true,512,JSON_THROW_ON_ERROR);
    }

    private function jwkToPem(array $jwk):string
    {
        $n=self::b64($jwk['n']);$e=self::b64($jwk['e']);
        $mod="\x02".$this->asn1Len(strlen($n)+(ord($n[0])>127?1:0)).(ord($n[0])>127?"\x00":"").$n;
        $exp="\x02".$this->asn1Len(strlen($e)).$e;
        $rsa="\x30".$this->asn1Len(strlen($mod.$exp)).$mod.$exp;
        $bit="\x03".$this->asn1Len(strlen($rsa)+1)."\x00".$rsa;
        $alg=hex2bin('300d06092a864886f70d0101010500');
        $seq="\x30".$this->asn1Len(strlen($alg.$bit)).$alg.$bit;
        return "-----BEGIN PUBLIC KEY-----\n".chunk_split(base64_encode($seq),64,"\n")."-----END PUBLIC KEY-----\n";
    }
    private function asn1Len(int $l):string{if($l<128)return chr($l);$t=ltrim(pack('N',$l),"\x00");return chr(0x80|strlen($t)).$t;}
    private static function b64(string $s):string{return base64_decode(strtr($s,'-_','+/').str_repeat('=',(4-strlen($s)%4)%4),true)?:'';}
}
