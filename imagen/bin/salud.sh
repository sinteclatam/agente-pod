#!/usr/bin/env bash
# Sondas del contenedor.
#   vivo  → el andamiaje está en pie (tmux y el bucle). No mira si hay conexión: entre reintentos
#           hay segundos sin proceso de claude, y reiniciar el pod por eso sería un falso positivo.
#   listo → además hay sesión conectada con Remote Control.
# Un pod 'Running' que nunca pasa a 'Ready' es un agente que no logra conectar: mira los logs.
set -uo pipefail
export TMUX_TMPDIR=${TMUX_TMPDIR:-/tmp}

tmux has-session -t agente 2>/dev/null || exit 1

case "${1:-vivo}" in
  vivo)
    pgrep -f "claude remote-control" >/dev/null && exit 0
    pgrep -f "bin/bucle.sh" >/dev/null || exit 1
    ;;
  listo)
    tmux capture-pane -p -t agente 2>/dev/null | grep -qi "connected" || exit 1
    ;;
  *)
    echo "uso: salud.sh {vivo|listo}" >&2; exit 2 ;;
esac
