#!/usr/bin/env bash
# Genera las credenciales de claude.ai para el agente, fuera del clúster.
# Remote Control necesita un login completo de claude.ai: ni ANTHROPIC_API_KEY ni el token de
# 'claude setup-token' sirven. Como el login lo tiene que hacer una persona con un navegador,
# se hace aquí una sola vez y el resultado viaja al clúster como Secret.
set -euo pipefail

IMAGEN=${IMAGEN:-ghcr.io/sinteclatam/agente-pod:latest}
SALIDA=${SALIDA:-.credenciales}
NS=${NS:-agentes}
CONTENEDOR=agente-pod-login
CLAVE=${1:-credentials.json}   # usa credentials-0.json, credentials-1.json... para una cuenta por agente

command -v docker >/dev/null || { echo "hace falta docker" >&2; exit 1; }
docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true
mkdir -p "$SALIDA"

docker run -it --name "$CONTENEDOR" "$IMAGEN" login

docker cp "$CONTENEDOR:/home/agente/.claude/.credentials.json" "$SALIDA/$CLAVE"
docker rm -f "$CONTENEDOR" >/dev/null
chmod 600 "$SALIDA/$CLAVE"

if ! jq -e '.claudeAiOauth.accessToken' "$SALIDA/$CLAVE" >/dev/null 2>&1; then
  echo "AVISO: el fichero no tiene 'claudeAiOauth'. Remote Control lo va a rechazar." >&2
fi

cat <<FIN

Credenciales en $SALIDA/$CLAVE (no las subas a git: .gitignore ya las excluye).

Crea o actualiza el Secret con:

  kubectl -n $NS create secret generic agente-pod-credenciales \\
    --from-file=$CLAVE=$SALIDA/$CLAVE \\
    --dry-run=client -o yaml | kubectl apply -f -

FIN
