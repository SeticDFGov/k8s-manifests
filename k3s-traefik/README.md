# Traefik do k3s

O Traefik vem empacotado no k3s e é configurado por um `HelmChartConfig` chamado `traefik`
em `kube-system`. Desde 2026-11 ele é aplicado pelo ArgoCD (`argocd/apps/traefik-config.yaml`).

Só pode existir **um** com esse nome. Não criar outro à mão nem em
`/var/lib/rancher/k3s/server/manifests/` na VM: o k3s reaplica os arquivos de lá e brigaria
com o ArgoCD (cada lado desfaz o outro e o Traefik reinicia em ciclo).

Toda mudança reinstala o chart e reinicia o Traefik (alguns segundos fora do ar para todos
os sites). Fazer o merge fora do horário de uso.

Versões em 2026-11-18: k3s v1.33.5, Traefik 3.3.6 (`rancher/mirrored-library-traefik:3.3.6`).

## O que está configurado

- **Plugin do Sablier** (MeasureSoftGram sob demanda). O Traefik baixa o plugin de
  plugins.traefik.io no boot; erro de download = o pod não chega a plugins.traefik.io / github.com.
- **Log de acesso em JSON**. Cabeçalhos descartados, exceto `X-Forwarded-For` e `User-Agent`.
- **`externalTrafficPolicy: Local`** no Service do Traefik: o log mostra o IP de quem conectou
  na VM (o proxy da infra) em vez de `10.42.0.1`. O IP do usuário final depende de o proxy
  enviar `X-Forwarded-For`.

## Ver as requisições

```bash
# ao vivo
kubectl -n kube-system logs -f deploy/traefik | grep '"RequestHost"'

# host, entrypoint (web = 80/HTTP, websecure = 443/HTTPS), origem, IP real, caminho, status, tempo
kubectl -n kube-system logs deploy/traefik --since=10m | grep '^{' | \
  jq -r '[.RequestHost, .entryPointName, .ClientHost, ."request_X-Forwarded-For", .RequestMethod, .RequestPath, .DownstreamStatus, ((.Duration/1e6|floor|tostring)+"ms")] | @tsv'
```

`ClientHost` deve ser o proxy da infra (10.230.81.124/.125); o IP do usuário vem em
`X-Forwarded-For`.

## Conferir

```bash
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -E 'sablier|accesslog'
kubectl -n kube-system logs deploy/traefik | grep -i plugin
```
