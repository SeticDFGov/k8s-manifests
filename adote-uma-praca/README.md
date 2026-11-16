# Adote uma Praça

Portal do programa Adote uma Praça (SEPE-DF). Código em `SeticDFGov/adote-uma-praca-front` e `SeticDFGov/adote-uma-praca-api` (privados).

| Ambiente | Namespace | Host | Quem atualiza a tag |
|---|---|---|---|
| Homologação | `adote-hml` | `adoteumapraca-hml.10.233.159.150.nip.io` | Merge no `main` de cada repositório |
| Produção | `adote-prd` | `adoteumapraca.df.gov.br` (DNS a providenciar) | Release `vX.Y.Z` de cada repositório |

`base/` é única. Os overlays mudam só namespace, host, tags das imagens e configuração do ambiente.

## Segredos (criar uma vez por namespace, fora do Git)

Este repositório é público. Nada de segredo aqui.

```bash
# Leitura das imagens privadas do GHCR (token com read:packages)
kubectl -n adote-hml create secret docker-registry ghcr-adote \
  --docker-server=ghcr.io --docker-username=<usuario> --docker-password=<token>

# Configuração sensível da API
kubectl -n adote-hml create secret generic adote-api-segredos \
  --from-literal=DATABASE_URL='postgres://adote_hml:<senha>@<host>:5432/adote_hml' \
  --from-literal=SESSAO_SEGREDO='<64 caracteres aleatórios>' \
  --from-literal=GOVBR_CLIENT_ID='<id do credenciamento gov.br>' \
  --from-literal=GOVBR_CLIENT_SECRET='<segredo gov.br>' \
  --from-literal=SEI_SIGLA_SISTEMA='<sigla>' \
  --from-literal=SEI_IDENTIFICACAO_SERVICO='<identificação>' \
  --from-literal=SEI_CHAVE_ACESSO='<chave>' \
  --from-literal=ADMIN_CPF_INICIAL='<CPF do primeiro administrador da SEPE>'
```

Repetir em `adote-prd` com os valores de produção. As migrações do banco rodam num Job `PreSync` antes de cada sincronização.
