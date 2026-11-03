#!/usr/bin/env bash
# Configura o client do SGDP no Keycloak para o login OIDC no navegador (Authorization Code
# com PKCE S256): o front leva a pessoa à tela de login do Keycloak e volta em /auth/callback;
# a senha deixa de passar pela API.
#
# A configuração do client mora no banco do Keycloak (não nos manifestos), por isso é este
# script e não o ArgoCD que a aplica. Só ACRESCENTA o que falta (URLs de volta, origem, PKCE,
# fluxo padrão); nada é apagado. Rodar de novo não muda nada.
#
#   KC_ADMIN_USER=admin ./configurar-client-oidc.sh            simulação: mostra o que mudaria
#   KC_ADMIN_USER=admin APLICAR=1 ./configurar-client-oidc.sh  grava
#   INCLUIR_LOCAL=1 ...                    também aceita http://localhost:4200 (desenvolvimento)
#   DESLIGAR_ROPC=1 APLICAR=1 ...          no fim da transição: desliga o login com senha pela API
#                                          (Direct access grants). Só depois que o front, o MCP,
#                                          o teste de carga e os e2e não usarem mais.
set -euo pipefail

KC_URL="${KC_URL:-http://keycloak.10.233.159.150.nip.io/keycloak}"; KC_URL="${KC_URL%/}"
REALM="${KC_REALM:-SISTEMA_GEDE}"
CLIENT="${KC_CLIENT:-client-subgd}"
FRONT="${FRONT_URL:-https://subgd.df.gov.br}"; FRONT="${FRONT%/}"
APLICAR="${APLICAR:-0}"

command -v jq >/dev/null || { echo "Precisa do jq."; exit 1; }
if [[ -z "${KC_ADMIN_PASS:-}" ]]; then
  : "${KC_ADMIN_USER:?Informe KC_ADMIN_USER}"; read -rsp "Senha de $KC_ADMIN_USER no Keycloak: " KC_ADMIN_PASS; echo
fi
TOKEN=$(curl -fsS "$KC_URL/realms/master/protocol/openid-connect/token" -d grant_type=password -d client_id=admin-cli \
  --data-urlencode "username=$KC_ADMIN_USER" --data-urlencode "password=$KC_ADMIN_PASS" | jq -r .access_token)
H=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
API="$KC_URL/admin/realms/$REALM"

ATUAL=$(curl -fsS "${H[@]}" "$API/clients?clientId=$CLIENT" | jq '.[0] // empty')
[[ -n "$ATUAL" ]] || { echo "Client $CLIENT não encontrado no realm $REALM."; exit 1; }
CID=$(jq -r .id <<<"$ATUAL")

ORIGENS=("$FRONT"); [[ "${INCLUIR_LOCAL:-0}" == 1 ]] && ORIGENS+=("http://localhost:4200")
VOLTAS=$(printf '%s\n' "${ORIGENS[@]}" | jq -R '. + "/auth/callback"' | jq -s .)
SAIDAS=$(printf '%s\n' "${ORIGENS[@]}" | jq -R '. + "/auth"' | jq -s .)
WEB=$(printf '%s\n' "${ORIGENS[@]}" | jq -R . | jq -s .)

NOVO=$(jq --argjson voltas "$VOLTAS" --argjson saidas "$SAIDAS" --argjson web "$WEB" \
          --arg ropc "${DESLIGAR_ROPC:-0}" '
  .standardFlowEnabled = true
  | .implicitFlowEnabled = false
  | .redirectUris = ((.redirectUris // []) + $voltas | unique)
  | .webOrigins = ((.webOrigins // []) + $web | unique)
  | .attributes = (.attributes // {})
  | .attributes["pkce.code.challenge.method"] = "S256"
  | .attributes["post.logout.redirect.uris"] =
      (((.attributes["post.logout.redirect.uris"] // "") | split("##") | map(select(. != ""))) + $saidas
        | unique | join("##"))
  | if $ropc == "1" then .directAccessGrantsEnabled = false else . end
' <<<"$ATUAL")

# Comparação sem a ordem das listas (o Keycloak devolve as URLs em outra ordem)
campos='{publicClient, standardFlowEnabled, implicitFlowEnabled, directAccessGrantsEnabled,
  redirectUris: ((.redirectUris // []) | sort), webOrigins: ((.webOrigins // []) | sort),
  pkce: .attributes["pkce.code.challenge.method"],
  postLogout: ((.attributes["post.logout.redirect.uris"] // "") | split("##") | map(select(. != "")) | sort)}'
antes=$(jq -S "$campos" <<<"$ATUAL"); depois=$(jq -S "$campos" <<<"$NOVO")

[[ "$(jq -r .publicClient <<<"$ATUAL")" == true ]] || \
  echo "Atenção: o client não é público. O login no navegador precisa de client público (sem segredo); confira."

if [[ "$antes" == "$depois" ]]; then echo "O client $CLIENT já está configurado. Nada a mudar."; exit 0; fi
echo "Mudanças no client $CLIENT (realm $REALM):"
diff <(echo "$antes") <(echo "$depois") | grep '^[<>]' | sed 's/^</  antes: /; s/^>/  depois:/' || true

if [[ "$APLICAR" == 1 ]]; then
  c=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT "${H[@]}" "$API/clients/$CID" --data "$NOVO")
  [[ "$c" == 204 ]] && echo "Gravado." || { echo "Falha ao gravar (HTTP $c)."; exit 1; }
else
  echo "Simulação: nada foi gravado. Para gravar: APLICAR=1 $0"
fi
