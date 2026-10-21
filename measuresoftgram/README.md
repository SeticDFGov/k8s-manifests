# MeasureSoftGram (MSG)

Front + Service (Django) + Postgres do https://github.com/fga-eps-mds, servido em
https://msgram.10.233.159.150.nip.io (TLS com o certificado padrão do Traefik).

## Secrets (criar UMA vez com admin, fora do Git)

```bash
kubectl create namespace measuresoftgram

kubectl -n measuresoftgram create secret generic msgram-postgres \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)"

kubectl -n measuresoftgram create secret generic msgram-service \
  --from-literal=SECRET_KEY="$(openssl rand -base64 48)" \
  --from-literal=GITHUB_TOKEN_ENCRYPTION_KEYS="$(python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')" \
  --from-literal=GITHUB_CLIENT_ID=<client-id> \
  --from-literal=GITHUB_SECRET=<client-secret>
```

## Imagens

O front embute `NEXT_PUBLIC_*` no bundle em build-time, então a imagem precisa
ser buildada com:

```
NEXT_PUBLIC_API_URL=https://msgram.10.233.159.150.nip.io/api
NEXT_PUBLIC_LOGIN_REDIRECT_URL=https://msgram.10.233.159.150.nip.io
NEXT_PUBLIC_GITHUB_CLIENT_ID=<client-id>
```
