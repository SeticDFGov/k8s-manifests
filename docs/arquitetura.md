# Arquitetura do SGDP (esboço)

Esboço inicial, para ir completando. O GitHub desenha os diagramas abaixo (Mermaid); para
editar, basta mudar o texto. Itens marcados com "?" ainda precisam ser confirmados.

## Visão geral

```mermaid
flowchart LR
  %% ---------- Pessoas ----------
  usuario(["Servidores do GDF<br/>(navegador)"])
  cidadao(["Cidadão<br/>(páginas públicas)"])
  equipe(["Equipe SUBGD<br/>(rede do GDF ou VPN)"])

  %% ---------- Fora do cluster ----------
  subgraph rede["Rede do GDF"]
    ad[("Active Directory<br/>gdfnet.df<br/>Catálogo Global 3268")]
    pg[("PostgreSQL<br/>10.230.81.119:5432<br/>db_subtdcr · db_centralrelacionamento")]
    buriti[("AD buriti.df.gov.br<br/>(sem rota ainda)")]
  end

  subgraph externos["Fontes externas"]
    ses["SES-DF<br/>interno.saude.df.gov.br"]
    iges["IGESDF<br/>api.igesdf.org.br"]
  end

  subgraph github["GitHub (SeticDFGov)"]
    repoFront["SGDP-Angular"]
    repoBack["SGDP-Service (.NET)"]
    repoK8s["k8s-manifests<br/>(GitOps)"]
    ci["GitHub Actions<br/>build + tag da imagem"]
  end
  dockerhub[("Docker Hub<br/>sousacomz/*")]

  %% ---------- VM ----------
  subgraph vm["VM ceticsv0002 · 10.233.159.150 · k3s nó único"]
    traefik{{"Traefik (ingress)<br/>subgd.df.gov.br<br/>subgd-api.df.gov.br<br/>*.10.233.159.150.nip.io"}}

    subgraph ns_default["namespace default"]
      front["Front Angular (SSR)<br/>meu-front-deployment"]
      back["API .NET<br/>meu-backend-service"]
      kc["Keycloak 26.6.1<br/>realm SISTEMA_GEDE<br/>/keycloak · tema sgdp"]
      olhar["Olhar DF"]
      extrator["Extrator SES/IGES<br/>(agendado a cada 2 h)"]
      extratorApi["Extrator API"]
      fastapi["fastapi-ldap-svc ?<br/>(fora do Git)"]
      static["static-svc ?<br/>(fora do Git)"]
    end

    subgraph ns_msgram["namespace measuresoftgram"]
      msgram["MeasureSoftGram<br/>front + service"]
    end

    subgraph ns_mon["namespace monitoring + grafana"]
      vm_metrics["VictoriaMetrics"]
      exporters["node-exporter<br/>kube-state-metrics"]
      grafana["Grafana"]
    end

    subgraph ns_argocd["namespace argocd"]
      argocd["ArgoCD<br/>app-of-apps (root.yaml)"]
    end
  end

  %% ---------- Acesso ----------
  usuario -->|HTTPS| traefik
  cidadao -->|HTTPS| traefik
  equipe --> traefik
  traefik -->|"subgd.df.gov.br /"| front
  traefik -->|"subgd-api.df.gov.br /"| back
  traefik -->|"subgd-api /keycloak<br/>(/keycloak/admin bloqueado)"| kc
  traefik -->|"subgd-api /autenticar, /escuta-ativa,<br/>/jovem-candango, /atendimentos..."| fastapi
  traefik -->|"subgd-api /static"| static
  traefik -->|"subgd-api /argocd"| argocd
  traefik -->|"olhardf.*.nip.io"| olhar
  traefik -->|"msgram.*.nip.io"| msgram
  traefik -->|"grafana.*.nip.io"| grafana
  traefik -->|"keycloak.*.nip.io<br/>(console admin)"| kc

  %% ---------- Autenticação ----------
  front -. "login OIDC<br/>Authorization Code + PKCE" .-> kc
  back -. "valida o JWT<br/>(chaves do realm)" .-> kc
  kc -->|"LDAP (federação, leitura)"| ad
  kc -.->|"2º provedor (planejado)"| buriti

  %% ---------- Dados ----------
  front -->|"REST + Bearer"| back
  back --> pg
  kc --> pg
  extrator --> ses
  extrator --> iges
  extrator --> pg
  extratorApi --> pg
  olhar --> extratorApi
  msgram --> pg

  %% ---------- Monitoramento ----------
  exporters --> vm_metrics
  grafana --> vm_metrics

  %% ---------- Entrega (CD) ----------
  repoFront --> ci
  repoBack --> ci
  ci -->|imagem| dockerhub
  ci -->|"grava a tag"| repoK8s
  argocd -->|"lê (sync automático)"| repoK8s
  argocd -->|aplica| ns_default
  vm -. "puxa as imagens" .-> dockerhub
```

## Login (OIDC)

```mermaid
sequenceDiagram
  autonumber
  actor P as Pessoa
  participant F as Front (subgd.df.gov.br)
  participant K as Keycloak (subgd-api/keycloak)
  participant AD as AD gdfnet.df
  participant A as API .NET

  P->>F: abre /auth
  F->>K: redireciona (code_challenge S256, state, nonce)
  K->>P: tela de login (tema sgdp)
  P->>K: e-mail e senha da rede do GDF
  K->>AD: confere a senha (LDAP)
  K->>F: volta em /auth/callback com o código
  F->>K: troca o código pelo token (code_verifier)
  F->>A: GET /api/Auth/me (Bearer)
  A->>A: valida o JWT (emissor público, chaves do Keycloak)
  A->>F: perfil, módulos e papéis
```

## Entrega contínua (GitOps)

```mermaid
flowchart LR
  dev["merge na main<br/>(front ou back)"] --> ci["GitHub Actions"]
  ci --> img["imagem no Docker Hub<br/>tag = commit"]
  ci --> tag["commit em k8s-manifests<br/>(frontend/ ou backend/)"]
  tag --> argo["ArgoCD<br/>(confere a cada 3 min)"]
  argo --> k3s["k3s aplica<br/>(prune + selfHeal)"]
```

## A completar

- O que são `fastapi-ldap-svc` e `static-svc`: estão no ingress do `subgd-ingress`, mas não têm
  manifesto no repositório.
- Se o Keycloak e a API usam o mesmo servidor PostgreSQL (o Keycloak lê do secret `db-credentials`).
- MCP do SGDP e testes e2e (ainda pelo login antigo, `/api/Auth/token`).
- Backups (banco, volumes do Grafana e do VictoriaMetrics).
- Segundo provedor LDAP gravável (OU no domínio raiz, StartTLS 389) para senha temporária.
