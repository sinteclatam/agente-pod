#!/usr/bin/env bash
# PID 1 del contenedor. Despacha el subcomando de arranque; cualquier otra cosa se ejecuta tal cual
# (parámetros de inicialización), que es lo que usan los Jobs puntuales.
set -euo pipefail
BIN=/opt/agente/bin

case "${1:-agente}" in
  agente)      shift || true; exec "$BIN/agente.sh" "$@" ;;
  login)       shift || true; exec "$BIN/login.sh" "$@" ;;
  diagnostico) shift || true; exec "$BIN/diagnostico.sh" "$@" ;;
  ayuda|--help|-h)
    cat <<'AYUDA'
agente-pod — agente Claude Code autónomo para desplegar en Kubernetes

  agente        (por defecto) mantiene una sesión de Claude Remote Control
  login         flujo de inicio de sesión en claude.ai (para generar credenciales)
  diagnostico   versiones, claude doctor y permisos efectivos en el clúster
  <comando>     cualquier otra cosa se ejecuta tal cual
AYUDA
    ;;
  *) exec "$@" ;;
esac
