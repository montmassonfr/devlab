# Dev lab

This project initiate a devlab with all the tools required to develop on you work station where ever you are.

## First installation

In order to use your own ca you must start step-ca and configure your workstation to trust it.

## Start dev lab

Launch step-ca ony
```bash
docker-compose up step-ca
```

retrieve hash of the Root CA
```bash
docker compose exec step-ca step certificate fingerprint certs/root_ca.crt
```

in my case
```fingerprint
c17042b68c517e9671462ee4a91d937578b8d4af04e0327e200ea83d9d760e7f
```

## Configure your CA on your client

### Your WSL Distribution

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

### Your Win workstation

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

## test

Now you can browse https://localhost:9000/health withouth error

```http
GET https://localhost:9000/health
```

which return
```json
{"status":"ok"}
```
