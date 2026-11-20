# Adote uma Praça

Portal do programa Adote uma Praça (SEPE-DF). Código em `SeticDFGov/adote-uma-praca-front` e `SeticDFGov/adote-uma-praca-api` (privados); imagens privadas no GHCR (`ghcr.io/seticdfgov/adote-uma-praca-*`).

| Ambiente | Namespace | Host | Quem atualiza a tag |
|---|---|---|---|
| Homologação | `adote-hml` | `hml-adoteumapraca.df.gov.br` | Merge no `main` de cada repositório (`sha-<commit>`) |
| Produção | `adote-prd` | `adoteumapraca.df.gov.br` | Release `vX.Y.Z` de cada repositório (mesma imagem de homologação, marcada com a versão) |

`base/` é única. Os overlays mudam só namespace, host, tags das imagens e configuração do ambiente.

## Rede e certificado

Os dois domínios apontam para o proxy reverso da infra (`10.230.81.124`), que guarda os certificados (Let's Encrypt) e repassa ao Traefik da VM. O cluster só roteia pelo host: `/api` para a API e `/` para o front. Não há certificado no cluster.

## Isolamento (cada namespace)

- `limites.yaml`: ResourceQuota (requests 500m e 1 GiB; limits 2 CPU e 2 GiB; 10 pods) e LimitRange com padrões para contêiner sem `resources`. A VM é a mesma do GeDê.
- `rede.yaml`: só o Traefik (`kube-system`) e os pods do próprio namespace chegam aos pods. Homologação e produção não se enxergam. A saída (banco, gov.br, SEI) é livre.

## Banco

Homologação e produção usam o mesmo banco externo, cada uma com o seu usuário e os seus schemas (`DB_SCHEMA` no ConfigMap de cada overlay; suporte na API desde o PR #4 do `adote-uma-praca-api`):

- Homologação: usuário `usr_adote_hml`, dono dos schemas `adote_hml` (tabelas) e `adote_hml_fila` (fila do pg-boss).
- Produção: usuário `usr_adote_prd`, dono dos schemas `adote_prd` e `adote_prd_fila`.

Os usuários não precisam (nem devem) poder criar schemas no banco, nem ter acesso ao `public`. O Job de migração cria as tabelas dentro dos schemas.

## Segredos (criar uma vez por namespace, fora do Git)

Este repositório é público. Nada de segredo aqui. **Crie os namespaces e os Secrets antes do primeiro sync**: sem eles o Job de migração não sobe e a sincronização fica parada.

```bash
for ns in adote-hml adote-prd; do kubectl create namespace $ns; done

# Leitura das imagens privadas do GHCR: o mesmo token do GeDê (docs/ghcr.md),
# de uma conta com acesso de leitura aos repositórios do Adote
kubectl -n adote-hml create secret docker-registry ghcr-seticdfgov \
  --docker-server=ghcr.io --docker-username=<conta> --docker-password=<PAT read:packages>

# Configuração sensível da API
kubectl -n adote-hml create secret generic adote-api-segredos \
  --from-literal=DATABASE_URL='postgres://usr_adote_hml:<senha>@<host>:5432/<banco>' \
  --from-literal=SESSAO_SEGREDO="$(openssl rand -hex 32)" \
  --from-literal=ADMIN_CPF_INICIAL='<CPF do primeiro administrador da SEPE>'
```

Repetir em `adote-prd` com os valores de produção (banco e `SESSAO_SEGREDO` próprios; nunca os de homologação).

Obrigatórios para a API subir: `DATABASE_URL` e `SESSAO_SEGREDO` (32 caracteres ou mais). Os demais entram no mesmo Secret quando existirem (recriar o Secret e reiniciar a API: `kubectl -n <ns> rollout restart deploy/adote-api`):

| Chave | Sem ela |
|---|---|
| `GOVBR_CLIENT_ID`, `GOVBR_CLIENT_SECRET` | `/api/auth/login` responde 503 (login gov.br desligado). Homologação usa o gov.br de staging; produção, o de produção, cada um com a URL de retorno do seu host |
| `SEI_SIGLA_SISTEMA`, `SEI_IDENTIFICACAO_SERVICO` ou `SEI_CHAVE_ACESSO` | envios ao SEI ficam "adiados" |
| `SMTP_URL` | e-mail desligado |
| `ADMIN_CPF_INICIAL` | nenhum administrador criado no primeiro boot |

As migrações do banco rodam num Job (hook `Sync`, onda 1) a cada sincronização: depois do ConfigMap (onda 0) e antes da API (onda 2). A fila e as tarefas agendadas (pg-boss) usam o próprio banco.
