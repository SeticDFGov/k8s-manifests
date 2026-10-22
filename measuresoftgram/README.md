# MeasureSoftGram (MSG)

Front + Service (Django) do https://github.com/fga-eps-mds, servido em
https://msgram.10.233.159.150.nip.io (TLS com o certificado padrão do Traefik).

O banco é o mesmo Postgres do extrator SES (`10.230.81.119`, base
`db_centralrelacionamento`), isolado no schema `msgram` via
`PGOPTIONS=-c search_path=msgram` (ver `configmap.yaml`).

## Banco (UMA vez, com o DBA / owner da base)

Usuário próprio, com acesso só ao schema `msgram`, para o MSG não enxergar os
dados do extrator no `public`:

```sql
CREATE ROLE msgram LOGIN PASSWORD '<senha forte>';
CREATE SCHEMA msgram AUTHORIZATION msgram;
ALTER ROLE msgram SET search_path = msgram;
REVOKE ALL ON SCHEMA public FROM msgram;
```

## Secrets (criar UMA vez com admin, fora do Git)

```bash
kubectl create namespace measuresoftgram

kubectl -n measuresoftgram create secret generic msgram-postgres \
  --from-literal=POSTGRES_USER=msgram \
  --from-literal=POSTGRES_PASSWORD='<senha do role msgram>'

kubectl -n measuresoftgram create secret generic msgram-service \
  --from-literal=SECRET_KEY="$(openssl rand -base64 48)" \
  --from-literal=GITHUB_TOKEN_ENCRYPTION_KEYS="$(python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')" \
  --from-literal=GITHUB_CLIENT_ID=<client-id> \
  --from-literal=GITHUB_SECRET=<client-secret>
```

## Imagens

- Service: imagem oficial `measuresoftgram/service`.
- Front: buildada pelo fork `SeticDFGov/MeasureSoftGram-Front`
  (`.github/workflows/setic-deploy.yml`), porque o Next.js embute `NEXT_PUBLIC_*`
  no bundle em build-time:

```
NEXT_PUBLIC_API_URL=https://msgram.10.233.159.150.nip.io/api
NEXT_PUBLIC_LOGIN_REDIRECT_URL=https://msgram.10.233.159.150.nip.io
NEXT_PUBLIC_GITHUB_CLIENT_ID=<client-id>
```
