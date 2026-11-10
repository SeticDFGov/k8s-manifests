#!/usr/bin/env bash
# Gera docs/arquitetura-vm-ceticsv0002.pdf a partir dos diagramas de docs/arquitetura.md e de arquitetura.html.
# Precisa de node (npx) e chromium. Rode de dentro de docs/fonte-pdf.
set -euo pipefail
cd "$(dirname "$0")"
awk '/^```mermaid/{n++; f=sprintf("d%d.mmd",n); on=1; next} /^```/{on=0} on{print > f}' ../arquitetura.md
for f in d*.mmd; do n=${f%.mmd}; n=${n#d}; c=cfg-elk.json; [[ -f cfg-d$n.json ]] && c=cfg-d$n.json
  PUPPETEER_SKIP_DOWNLOAD=1 npx -y @mermaid-js/mermaid-cli@11 -p pp.json -c $c -i d$n.mmd -o d$n.svg -b white
done
chromium --headless=new --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
  --print-to-pdf=../arquitetura-vm-ceticsv0002.pdf "file://$PWD/arquitetura.html"
rm -f d*.mmd d*.svg
