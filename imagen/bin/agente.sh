#!/usr/bin/env bash
# Arranque normal del pod: prepara el volumen, lanza el bucle dentro de tmux (que le da la
# pseudo-terminal que necesita la interfaz de Claude Code) y vuelca la salida a los logs del pod.
set -euo pipefail

export TMUX_TMPDIR=${TMUX_TMPDIR:-/tmp}
SESION=agente
LOG=${LOG:-/tmp/agente.log}

/opt/agente/bin/preparar-home.sh

: > "$LOG"
tmux new-session -d -s "$SESION" -x 200 -y 50 -c "${WORKDIR:-/home/agente/workspace}" /opt/agente/bin/bucle.sh
tmux pipe-pane -o -t "$SESION" "cat >> $LOG"

terminar() {
  echo "[agente] señal recibida, cerrando la sesión"
  tmux kill-session -t "$SESION" 2>/dev/null || true
  exit 0
}
trap terminar TERM INT

tail -n +1 -F "$LOG" &
TAIL=$!

# Si tmux muere, salimos con error para que Kubernetes reinicie el pod.
while tmux has-session -t "$SESION" 2>/dev/null; do
  sleep 5 & wait $!
done

kill "$TAIL" 2>/dev/null || true
echo "[agente] la sesión de tmux desapareció; salgo para que el pod se reinicie" >&2
exit 1
