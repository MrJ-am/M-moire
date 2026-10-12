#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Résolution par le SDK verrouillé : ni révision copiée ni téléchargement.
FIREFOX_BIN="$(cd "$SCRIPT_DIR/.." && node -e 'process.stdout.write(require("playwright").firefox.executablePath())')"
FIREFOX_DIR="$(dirname -- "$FIREFOX_BIN")"
FIREFOX_REAL="$FIREFOX_DIR/firefox.real"
LD_SO="/gnu/store/z1kd5nisk0mqacsyrdbzm0cbp6wvgsrs-profile/lib/ld-linux-x86-64.so.2"
LIBS="/gnu/store/z1kd5nisk0mqacsyrdbzm0cbp6wvgsrs-profile/lib:/gnu/store/zzpbp6rr43smwxzvzd4qd317z5j7qblj-gcc-11.4.0-lib/lib"

if [[ ! -d "$FIREFOX_DIR" ]]; then
  echo "Firefox Playwright introuvable dans $FIREFOX_DIR" >&2
  echo "Préparer le navigateur verrouillé depuis vps-infrastructure." >&2
  exit 1
fi

if [[ -f "$FIREFOX_REAL" ]]; then
  target="$FIREFOX_REAL"
else
  target="$FIREFOX_BIN"
fi

if [[ ! -f "$target" ]]; then
  echo "Binaire Firefox introuvable: $target" >&2
  exit 1
fi

patchelf --set-interpreter "$LD_SO" "$target"

if [[ ! -f "$FIREFOX_REAL" ]]; then
  mv "$FIREFOX_BIN" "$FIREFOX_REAL"
fi

cat > "$FIREFOX_BIN" <<WRAP
#!/bin/sh
set -e
DIR=\
\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)
export LD_LIBRARY_PATH="\$DIR:$LIBS:\${LD_LIBRARY_PATH:-}"
cd "\$DIR"
exec "$FIREFOX_REAL" "\$@"
WRAP

chmod +x "$FIREFOX_BIN"
"$FIREFOX_BIN" --version >/dev/null

echo "Playwright Firefox patché (wrapper actif)."
