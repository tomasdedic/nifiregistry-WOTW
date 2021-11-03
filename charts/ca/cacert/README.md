### Self-Signed CA certificate
Soubor config.json (Je mozne pouzit prilozeny)
```
{
  "days" : 825,
  "keySize" : 2048,
  "keyPairAlgorithm" : "RSA",
  "signingAlgorithm" : "SHA256WITHRSA",
  "dn" : "CN=nifi-ca,OU=NIFI",
  "keyStore" : "nifi-ca-keystore.jks",
  "keyStoreType" : "jks",
  "keyStorePassword" : "v9j4ANtJEiy3qayl1m5WGDPDP2IKtxQH6SKRKpsCZ/E",
  "keyPassword" : "v9j4ANtJEiy3qayl1m5WGDPDP2IKtxQH6SKRKpsCZ/E",
  "token" : "sixteenCharacters",
  "caHostname" : "nifi-ca",
  "port" : 9090,
  "dnPrefix" : "CN=",
  "dnSuffix" : ", OU=NIFI",
  "reorderDn" : true,
  "additionalCACertificate" : "",
  "domainAlternativeNames" : null
}
```

Soubor openssl.conf
```
[ req ]
default_bits           = 2048
default_keyfile        = usercert.key
distinguished_name     = req_distinguished_name
prompt                 = no

[ req_distinguished_name ]
OU                     = NIFI
CN                     = nifi-ca

[ v3_ca ]
keyUsage               = critical,cRLSign,keyCertSign,digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment,keyAgreement,keyCertSign,cRLSign
basicConstraints       = CA:TRUE
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
extendedKeyUsage       = clientAuth,serverAuth
```

### Vytvoreni JKS
Jako HESLO uvedte to, ktere je uvedeno v config.json v .keyStorePassword a .keyPassword (Hesla musi byt idealne shodna)
```bash
openssl req -x509 -extensions v3_ca -newkey rsa:2048 -keyout rootCA.key -out rootCA.crt -days 3650 -config openssl.conf -passout pass:PASSWORD
openssl pkcs12 -export -in rootCA.crt -inkey rootCA.key -out rootCA.p12 -name nifi-key -passin pass:PASSWORD -passout pass:PASSWORD
keytool -importkeystore -srckeystore rootCA.p12 -srcstoretype PKCS12 -destkeystore nifi-ca-keystore.jks -deststoretype JKS -alias nifi-key -srckeypass PASSWORD -destkeypass PASSWORD -srcstorepass PASSWORD -deststorepass PASSWORD
```




### Extrahovani JKS do PEM formatu pokud bychom to potrebovali
```bash
keytool -importkeystore -srckeystore nifi-ca-keystore.jks -destkeystore nifi-ca.p12 -srcstoretype jks -deststoretype pkcs12
openssl pkcs12 -in nifi-ca.p12 -out nifi-ca.pem
```
