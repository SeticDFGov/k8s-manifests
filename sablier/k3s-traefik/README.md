# Traefik do k3s para o Sablier

O Traefik vem empacotado no k3s e é configurado por um `HelmChartConfig` chamado `traefik`
em `kube-system`. Só pode existir UM com esse nome, por isso este arquivo não vai pelo
ArgoCD: aplicar por cima de uma configuração que já existe apagaria o que está nela.

## Antes de aplicar (admin)

```bash
# 1. Já existe configuração do Traefik?
kubectl get helmchartconfig -n kube-system
ls /var/lib/rancher/k3s/server/manifests/   # na VM, como root

# 2. Versão do Traefik (o plugin espera Traefik v3)
kubectl get deploy traefik -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```

- **Não existe `HelmChartConfig traefik`:** aplicar este arquivo.
- **Existe** (por um arquivo em `/var/lib/rancher/k3s/server/manifests/` ou criado à mão):
  juntar o `valuesContent` deste arquivo com o que já está lá, no mesmo lugar onde ele
  mora. Um arquivo em `server/manifests` é reaplicado pelo k3s e desfaz um `kubectl apply`.

```bash
kubectl apply -f helmchartconfig.yaml
```

O k3s reinstala o chart e o Traefik reinicia (alguns segundos fora do ar para todos os
ingresses). Fazer fora do horário de uso.

Versões em 2026-11-18: k3s v1.33.5, Traefik 3.3.6 (`rancher/mirrored-library-traefik:3.3.6`).
O README do plugin não diz a versão mínima do Traefik para o middleware CRD (cita v3.6
só para configuração por labels no Docker). Se o plugin não carregar no 3.3.6, o caminho é
atualizar o k3s, que traz um Traefik mais novo.

## Conferir

```bash
kubectl logs -n kube-system deploy/traefik | grep -i plugin
```

Erro de download do plugin = o pod do Traefik não chega a plugins.traefik.io / github.com
(liberar a saída ou usar plugin local).
