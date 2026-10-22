# MeasureSoftGram (MSG)

Front + Service (Django) do https://github.com/fga-eps-mds, servido em
https://msgram.10.233.159.150.nip.io (TLS com o certificado padrão do Traefik).

O banco é o mesmo Postgres do extrator SES (`10.230.81.119`, base
`db_centralrelacionamento`), isolado no schema `msgram` via
`PGOPTIONS=-c search_path=msgram` (ver `configmap.yaml`).

## Banco (UMA vez, com o DBA / owner da base)

Usa o mesmo usuário da base, `ADM_CENTRALRELACIONAMENTO`. Só o schema precisa
ser criado (o Django não cria schema no migrate):

```sql
CREATE SCHEMA IF NOT EXISTS msgram AUTHORIZATION "ADM_CENTRALRELACIONAMENTO";
```

Não usar `ALTER ROLE ... SET search_path`: o role é compartilhado com o extrator.
O schema do MSG vem só do `PGOPTIONS` no `configmap.yaml`.

## Secrets (criar UMA vez com admin, fora do Git)

```bash
kubectl create namespace measuresoftgram

kubectl -n measuresoftgram create secret generic msgram-postgres \
  --from-literal=POSTGRES_USER=ADM_CENTRALRELACIONAMENTO \
  --from-literal=POSTGRES_PASSWORD='<senha do ADM_CENTRALRELACIONAMENTO>'

kubectl -n measuresoftgram create secret generic msgram-service \
  --from-literal=SECRET_KEY="$(openssl rand -base64 48)" \
  --from-literal=GITHUB_TOKEN_ENCRYPTION_KEYS="$(openssl rand -base64 32 | tr '+/' '-_')" \
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
