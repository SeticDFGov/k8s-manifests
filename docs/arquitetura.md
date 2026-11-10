# Arquitetura do ambiente da VM ceticsv0002

Aplicações e serviços da SUBGD que rodam na VM ceticsv0002 (k3s): o GeDê e os demais
sistemas do mesmo servidor. O GitHub desenha os diagramas abaixo (Mermaid); para editar,
basta mudar o texto.

 O GitHub desenha os diagramas abaixo (Mermaid); para
editar, basta mudar o texto.

## Visão geral

```mermaid
---
config:
  layout: elk
---
flowchart TB
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
      back["API .NET<br/>meu-backend-service (3 réplicas)"]
      kc["Keycloak 26.6.1<br/>realm SISTEMA_GEDE<br/>/keycloak · tema sgdp"]
      olhar["Olhar DF"]
      extrator["Extrator SES/IGES<br/>(agendado a cada 2 h)"]
      extratorApi["Extrator API"]
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

## GeDê e o módulo PGIA

O GeDê é uma das aplicações do ambiente. O módulo de Governança de IA (PGIA, Decreto nº
48.901/2026) concentra a maior parte das regras e dos dados dele.

```mermaid
---
config:
  layout: elk
---
flowchart TB
  %% ---------- Quem usa ----------
  subgraph pessoas["Quem usa o PGIA"]
    agente(["Agente público<br/>(sem papel: registra uso de IA<br/>e avisa incidente, art. 13)"])
    orgaoP(["Órgão: pgia_orgao<br/>Responsável de IA, Encarregado de Dados,<br/>Curador de Dados de Negócio"])
    sgdiP(["SGDI: pgia_sgdi<br/>(órgão central)"])
    cgticP(["Secretaria do CGTIC: pgia_cgtic"])
    audP(["Auditoria externa: pgia_auditoria"])
    adminP(["Administrador do GeDê"])
    cidadao(["Cidadão<br/>(sem login)"])
  end

  %% ---------- Acesso ----------
  subgraph acesso["Acesso"]
    kc["Keycloak · realm SISTEMA_GEDE<br/>role pgia do client-subgd = acesso ao módulo<br/>grupo /ORGAOS/sigla do órgão = unidade"]
    ad[("AD gdfnet.df")]
    me["GET /api/Auth/me<br/>módulos liberados + papel PGIA<br/>(papel gravado ou designação vigente)"]
  end

  %% ---------- Front ----------
  subgraph front["Front GeDê (subgd.df.gov.br)"]
    inicio["Tela inicial: cards dos módulos<br/>Governança Estratégica · Governança de IA (PGIA) ·<br/>Supervisão Contínua · Demandas e Projetos · Administração"]
    trilha["/pgia: trilha numerada por papel<br/>(passos ligados aos artigos do decreto)"]
    publico["/transparencia-ia (pública)<br/>Registro Público e pedidos de informação"]
  end

  %% ---------- Áreas do PGIA ----------
  subgraph areas["Áreas do PGIA"]
    aOrgao["Órgão<br/>dados e pessoas · designações (titular e suplente) ·<br/>inventário de sistemas de IA e classificação de risco (arts. 15 a 17) ·<br/>incidentes · contratações (art. 25) e legados (art. 37) ·<br/>relatórios semestrais · capacitação · pedidos do cidadão (art. 23) · prazos"]
    aSgdi["SGDI<br/>dados dos órgãos · pessoas e acessos · homologação ·<br/>plataformas de IA generativa · apuração de incidentes ·<br/>Registro Público · AIA · relatório anual · auditorias ·<br/>não conformidades · normas · autorizações excepcionais"]
    aCgtic["CGTIC<br/>casos de Alto Risco e Risco Excessivo ·<br/>deliberações · histórico (PDF)"]
    aAud["Auditoria<br/>auditorias designadas"]
    aUso["Uso de IA e aviso de incidente<br/>(qualquer pessoa autenticada)"]
  end

  %% ---------- API ----------
  subgraph api["API GeDê (subgd-api.df.gov.br) · rotas do PGIA"]
    rOrgao["api/pgia/orgao"]
    rSistema["api/pgia/sistema"]
    rIncidente["api/pgia/incidente"]
    rConf["api/pgia/conformidade"]
    rGov["api/pgia/governanca"]
    rDoc["api/pgia/documento"]
    rAdmin["api/pgia/admin"]
    rPub["api/pgia/publico<br/>(anônima, 30 req/min por IP)"]
  end

  %% ---------- Dados ----------
  subgraph banco["PostgreSQL 10.230.81.119 · banco db_subtdcr"]
    tOrg[("Órgãos e pessoas<br/>pgia_orgao · pgia_agente_info ·<br/>pgia_responsavel_ia · pgia_encarregado_dados ·<br/>pgia_curador_dados · Users · Unidades")]
    tSis[("Sistemas e riscos<br/>pgia_sistema_ia · pgia_classificacao_risco ·<br/>pgia_risco_outro · pgia_aia · pgia_contrato_ia ·<br/>pgia_instrumento_legado")]
    tGov[("Governança<br/>pgia_deliberacao_cgtic · pgia_plataforma_ia_generativa ·<br/>pgia_autorizacao_excepcional · pgia_norma_complementar ·<br/>pgia_auditoria_tecnica · pgia_nao_conformidade")]
    tOp[("Operação e transparência<br/>pgia_incidente · pgia_registro_uso_ia · pgia_capacitacao ·<br/>pgia_relatorio_semestral · pgia_relatorio_anual ·<br/>pgia_prazo_conformidade · pgia_solicitacao_cidadao")]
    tDoc[("Documentos e anexos<br/>pgia_documento · pgia_documento_arquivo (arquivo no banco)")]
  end

  %% ---------- Ligações ----------
  agente & orgaoP & sgdiP & cgticP & audP & adminP --> kc
  kc --> ad
  kc --> me --> inicio --> trilha
  cidadao --> publico --> rPub
  trilha --> aOrgao & aSgdi & aCgtic & aAud & aUso
  aOrgao --> rOrgao & rSistema & rIncidente & rConf & rDoc
  aSgdi --> rGov & rAdmin & rDoc
  aCgtic --> rGov
  aAud --> rGov
  aUso --> rConf & rIncidente
  rOrgao --> tOrg
  rAdmin --> tOrg
  rSistema --> tSis
  rGov --> tGov & tSis
  rIncidente --> tOp
  rConf --> tOp
  rDoc --> tDoc
  rPub --> tSis & tOp
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
