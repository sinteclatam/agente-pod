#!/usr/bin/env bash
# Enlaces de las sesiones de Remote Control, uno por agente.
set -uo pipefail
NS=${NS:-agentes}
for pod in $(kubectl -n "$NS" get pods -l app.kubernetes.io/name=agente-pod -o name 2>/dev/null); do
  url=$(kubectl -n "$NS" logs "${pod#pod/}" --tail=400 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
        | grep -Eo 'https://claude\.ai/code[^ ]*' | tail -1)
  printf '%-20s %s\n' "${pod#pod/}" "${url:-(todavía sin conectar)}"
done
