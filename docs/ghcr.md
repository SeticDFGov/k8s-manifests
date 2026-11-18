# Imagens no GitHub Container Registry (GHCR)

As imagens da organização ficam em `ghcr.io/seticdfgov/*`, **privadas**. O CI de cada
repositório publica com o `GITHUB_TOKEN` do próprio workflow; o cluster baixa com o Secret
`ghcr-seticdfgov`, citado em `imagePullSecrets` de cada Deployment.

| Imagem | Repositório | Deployment |
|---|---|---|
| `ghcr.io/seticdfgov/gede-api` | SGDP-Service | `backend/deployment.yaml` |
| `ghcr.io/seticdfgov/gede-front` | SGDP-Angular | `frontend/deployment.yaml` |

## Secret de leitura (uma vez por namespace, fora do Git)

Este repositório é público: o Secret nunca entra aqui.

1. Token: PAT **clássico** com só o escopo `read:packages`, de uma conta de serviço da
   organização (não de uma pessoa: se ela sair, os deploys param). Anote a validade e
   troque o Secret antes de vencer.
2. Criar no namespace (quem tem permissão de escrita no cluster):

```bash
kubectl -n default create secret docker-registry ghcr-seticdfgov \
  --docker-server=ghcr.io \
  --docker-username=<conta-de-servico> \
  --docker-password=<PAT read:packages>
```

3. Conferir: `kubectl -n default get secret ghcr-seticdfgov`.

Trocar o token: apagar e criar de novo com o mesmo nome; os pods em execução não são
afetados (a credencial só é usada no próximo pull).

## Como funciona o deploy

Merge na `main` → o workflow gera a imagem `ghcr.io/seticdfgov/<imagem>:<commit>` → grava a
tag no Deployment deste repositório → o ArgoCD aplica. Se o pull falhar (Secret ausente ou
token vencido), os pods novos ficam em `ImagePullBackOff` e os atuais continuam no ar.

Histórico das imagens: https://github.com/orgs/SeticDFGov/packages
