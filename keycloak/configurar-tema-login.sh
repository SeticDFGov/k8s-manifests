#!/usr/bin/env bash
# Liga o tema de login do SGDP (keycloak/tema-sgdp, a mesma tela de login do front) no realm, e
# deixa as telas do Keycloak em português.
#
# O tema em si chega ao pod pelo ArgoCD (ConfigMap montado em /opt/keycloak/themes/sgdp); qual
# tema o realm usa mora no banco do Keycloak, por isso é este script que escolhe. Só muda os
# quatro campos abaixo; rodar de novo não muda nada.
#
#   KC_ADMIN_USER=admin ./configurar-tema-login.sh            simulação: mostra o que mudaria
#   KC_ADMIN_USER=admin APLICAR=1 ./configurar-tema-login.sh  grava
#   VOLTAR=1 APLICAR=1 ...                                    volta ao tema padrão do Keycloak
set -euo pipefail

KC_URL="${KC_URL:-http://keycloak.10.233.159.150.nip.io/keycloak}"; KC_URL="${KC_URL%/}"
REALM="${KC_REALM:-SISTEMA_GEDE}"
APLICAR="${APLICAR:-0}"

command -v jq >/dev/null || { echo "Precisa do jq."; exit 1; }
if [[ -z "${KC_ADMIN_PASS:-}" ]]; then
  : "${KC_ADMIN_USER:?Informe KC_ADMIN_USER}"; read -rsp "Senha de $KC_ADMIN_USER no Keycloak: " KC_ADMIN_PASS; echo
fi
TOKEN=$(curl -fsS "$KC_URL/realms/master/protocol/openid-connect/token" -d grant_type=password -d client_id=admin-cli \
  --data-urlencode "username=$KC_ADMIN_USER" --data-urlencode "password=$KC_ADMIN_PASS" | jq -r .access_token)
H=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
API="$KC_URL/admin/realms/$REALM"

ATUAL=$(curl -fsS "${H[@]}" "$API")

# O tema precisa existir no servidor antes de o realm apontar para ele (senão o Keycloak cai
# no padrão sem avisar). A lista vem do próprio servidor.
if [[ "${VOLTAR:-0}" != 1 ]]; then
  temas=$(curl -fsS "${H[@]}" "$KC_URL/admin/serverinfo" | jq -r '.themes.login[].name')
  grep -qx sgdp <<<"$temas" || { echo "O tema sgdp ainda não está no servidor (o ArgoCD já aplicou o ConfigMap e o pod reiniciou?)."; exit 1; }
fi

NOVO=$(jq --arg voltar "${VOLTAR:-0}" '
  if $voltar == "1" then .loginTheme = ""
  else .loginTheme = "sgdp"
     | .internationalizationEnabled = true
     | .supportedLocales = ((.supportedLocales // []) + ["pt-BR"] | unique)
     | .defaultLocale = "pt-BR"
  end' <<<"$ATUAL")

campos='{loginTheme, internationalizationEnabled, supportedLocales: ((.supportedLocales // []) | sort), defaultLocale}'
antes=$(jq -S "$campos" <<<"$ATUAL"); depois=$(jq -S "$campos" <<<"$NOVO")

if [[ "$antes" == "$depois" ]]; then echo "O realm $REALM já está com esse tema. Nada a mudar."; exit 0; fi
echo "Mudanças no realm $REALM:"
diff <(echo "$antes") <(echo "$depois") | grep '^[<>]' | sed 's/^</  antes: /; s/^>/  depois:/' || true

if [[ "$APLICAR" == 1 ]]; then
  corpo=$(jq '{loginTheme, internationalizationEnabled, supportedLocales, defaultLocale}' <<<"$NOVO")
  c=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT "${H[@]}" "$API" --data "$corpo")
  [[ "$c" == 204 ]] && echo "Gravado." || { echo "Falha ao gravar (HTTP $c)."; exit 1; }
else
  echo "Simulação: nada foi gravado. Para gravar: APLICAR=1 $0"
fi
