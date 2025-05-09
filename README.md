# Dev lab

This project initiate a devlab with all the tools required to develop on you work stations (Windows, Linux, WSL) where ever you are (work, home).

## First installation

In order to use your services. You must start step-ca and configure your workstation to trust it.

## Start dev lab

Launch step-ca ony
```bash
docker-compose up coredns step-ca
```

retrieve hash of the Root CA
```bash
docker compose exec step-ca step certificate fingerprint certs/root_ca.crt
```

in my case
```fingerprint
c17042b68c517e9671462ee4a91d937578b8d4af04e0327e200ea83d9d760e7f
```

## Configure your CA on your workstation

### Linux/WSL

```
wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb
```

```
~/homelab$ step ca bootstrap --ca-url https://localhost:9000 --fingerprint  c17042b68c517e9671462ee4a91d937578b8d4af04e0327e200ea83d9d760e7f --install
```

```
The root certificate has been saved in /home/f/.step/certs/root_ca.crt.
The authority configuration has been saved in /home/f/.step/config/defaults.json.
Installing the root certificate in the system truststore... done.
```

### Windows

Install step client on windows
```
scoop bucket add smallstep https://github.com/smallstep/scoop-bucket.git
scoop install smallstep/step
```

Add CA it to your windows client
```ps
PS C:\Users\user> step ca bootstrap --ca-url https://localhost:9000 --fingerprint c17042b68c517e9671462ee4a91d937578b8d4af04e0327e200ea83d9d760e7f 
```

which return
```
The root certificate has been saved in C:\Users\montmassonfr\.step\certs\root_ca.crt.
The authority configuration has been saved in C:\Users\montmassonfr\.step\config\defaults.json.
```

Add it in firefox
```ps
PS C:\Users\user> step certificate install --firefox C:\Users\montmassonfr\.step\certs\root_ca.crt
```

```
Certificate C:\Users\montmassonfr\.step\certs\root_ca.crt has been installed.
X.509v3 Root CA Certificate (ECDSA P-256) [Serial: 2385...8800]
  Subject:     Smallstep Root CA
  Issuer:      Smallstep Root CA
  Valid from:  2025-03-24T09:59:10Z
          to:  2035-03-22T09:59:10Z
```

## Test

### in your browser
Now you can browse https://localhost:9000/health withouth error


### with humao.rest-client
```http
GET https://localhost:9000/health
```

which return
```json
{"status":"ok"}
```

### with openssl directly 

Below is the same command only with openssl CLI
```shell
openssl s_client -quiet -connect localhost:9000 2>/dev/null <<EOF
GET /health HTTP/1.1
Host: localhost:9000

EOF
```

which return
```
HTTP/1.1 200 OK
Content-Type: application/json
X-Request-Id: 12f2c40f-bf84-46dc-8fe0-c1076420d00c
Date: Mon, 14 Apr 2025 15:15:52 GMT
Content-Length: 16
Connection: close

{"status":"ok"}
```

## Now you can start the whole stack

```bash
docker-compose up -d
```

Then launch the [homepage](https://homepage.localhost/).

Enjoy...