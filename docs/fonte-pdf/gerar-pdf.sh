#!/usr/bin/env bash
# Gera docs/arquitetura-gede.pdf a partir dos diagramas de docs/arquitetura.md e de arquitetura.html.
# Precisa de node (npx) e chromium. Rode de dentro de docs/fonte-pdf.
set -euo pipefail
cd "$(dirname "$0")"
awk '/^```mermaid/{n++; f=sprintf("d%d.mmd",n); on=1; next} /^```/{on=0} on{print > f}' ../arquitetura.md
for n in 1 2 3; do
  PUPPETEER_SKIP_DOWNLOAD=1 npx -y @mermaid-js/mermaid-cli@11 -p pp.json -c cfg-elk.json -i d$n.mmd -o d$n.svg -b white
done
chromium --headless=new --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
  --print-to-pdf=../arquitetura-gede.pdf "file://$PWD/arquitetura.html"
rm -f d*.mmd d*.svg
