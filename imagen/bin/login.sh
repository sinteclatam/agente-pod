#!/usr/bin/env bash
# Inicio de sesión en claude.ai. Está pensado para correrse FUERA del clúster
# (docker run -it ...), porque necesita que un humano pegue el código del navegador.
# El resultado —el fichero de credenciales— es lo que después se guarda como Secret.
set -euo pipefail

SALIDA=${SALIDA:-/salida}
mkdir -p "$HOME/.claude"

cat <<'AVISO'
────────────────────────────────────────────────────────────────────────
 Inicio de sesión en claude.ai para el agente

 1. Abre la URL que aparece abajo en tu navegador.
 2. Entra con la cuenta que tiene la suscripción (Pro, Max, Team o Enterprise).
 3. Copia el código que te muestra y pégalo aquí.

 Remote Control NO funciona con ANTHROPIC_API_KEY ni con el token de
 'claude setup-token': hace falta este login completo.
────────────────────────────────────────────────────────────────────────
AVISO

claude auth login
claude auth status

if [ -d "$SALIDA" ] && [ -w "$SALIDA" ]; then
  install -m 600 "$HOME/.claude/.credentials.json" "$SALIDA/credentials.json"
  echo
  echo "Credenciales guardadas en $SALIDA/credentials.json"
  echo "Crea el Secret con:"
  echo "  kubectl -n agentes create secret generic agente-pod-credenciales \\"
  echo "    --from-file=credentials.json=./credenciales/credentials.json"
else
  echo
  echo "Sin volumen de salida montado. Las credenciales están en $HOME/.claude/.credentials.json"
fi
