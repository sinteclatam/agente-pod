#!/usr/bin/env bash
# Deja $HOME (el volumen persistente) listo para trabajar. Es idempotente: en un reinicio
# respeta lo que ya existe, porque ahí vive el estado de la sesión y las credenciales renovadas.
set -euo pipefail

WORKDIR=${WORKDIR:-/home/agente/workspace}
CREDENCIALES_DIR=${CREDENCIALES_DIR:-/secretos}
ORDINAL=${HOSTNAME##*-}

mkdir -p "$HOME/.claude" "$HOME/.config" "$HOME/.cache" "$WORKDIR"
chmod 700 "$HOME/.claude"

# --- Credenciales de claude.ai -------------------------------------------------------------
# Remote Control exige un login completo de claude.ai: ni ANTHROPIC_API_KEY ni el token de
# `claude setup-token` sirven (esos solo pueden pedirle cosas al modelo). Por eso se siembra el
# fichero que produce `claude auth login`, y solo la primera vez: después Claude Code lo renueva
# solo y esa versión renovada, que vive en el volumen, es la buena.
if [ ! -s "$HOME/.claude/.credentials.json" ]; then
  for origen in "$CREDENCIALES_DIR/credentials-$ORDINAL.json" "$CREDENCIALES_DIR/credentials.json"; do
    if [ -s "$origen" ]; then
      install -m 600 "$origen" "$HOME/.claude/.credentials.json"
      echo "[preparar] credenciales sembradas desde $(basename "$origen")"
      break
    fi
  done
fi

if [ -s "$HOME/.claude/.credentials.json" ]; then
  if ! jq -e '.claudeAiOauth.accessToken' "$HOME/.claude/.credentials.json" >/dev/null 2>&1; then
    echo "[preparar] AVISO: las credenciales no parecen un login de claude.ai (falta claudeAiOauth)."
    echo "[preparar]        Remote Control las va a rechazar. Regenéralas con 'bin/credenciales.sh'."
  fi
else
  echo "[preparar] ERROR: no hay credenciales de claude.ai en $CREDENCIALES_DIR ni en el volumen." >&2
  echo "[preparar]        Crea el Secret 'agente-pod-credenciales' (ver docs/OPERACION.md)." >&2
  exit 1
fi

# --- Diálogos de primer arranque -------------------------------------------------------------
# Sin esto el proceso se queda esperando a un humano: asistente de bienvenida, confirmación del
# modo bypass, aviso de Remote Control y diálogo de confianza del directorio.
CFG="$HOME/.claude.json"
[ -s "$CFG" ] || echo '{}' > "$CFG"
jq --arg dir "$WORKDIR" '
    .theme //= "dark"
  | .hasCompletedOnboarding = true
  | .bypassPermissionsModeAccepted = true
  | .remoteDialogSeen = true
  | .projects //= {}
  | .projects[$dir] //= {}
  | .projects[$dir].hasTrustDialogAccepted = true
  | .projects[$dir].hasCompletedProjectOnboarding = true
  | .projects[$dir].allowedTools //= []
  | .projects[$dir].history //= []
' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
chmod 600 "$CFG"

# --- Ajustes del agente ------------------------------------------------------------------------
mkdir -p "$WORKDIR/.claude"
[ -s "$WORKDIR/.claude/settings.json" ] || cat > "$WORKDIR/.claude/settings.json" <<'AJUSTES'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "includeCoAuthoredBy": false
}
AJUSTES
[ -s "$WORKDIR/CLAUDE.md" ] || cp /opt/agente/contexto/CLAUDE.md "$WORKDIR/CLAUDE.md"

# --- GitHub y git --------------------------------------------------------------------------------
if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
  export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
  gh auth setup-git 2>/dev/null || echo "[preparar] AVISO: 'gh auth setup-git' falló; revisa el token."
else
  echo "[preparar] AVISO: sin GH_TOKEN, el agente no podrá clonar ni hacer push en repos privados."
fi
git config --global user.name  "${GIT_USER_NAME:-agente-pod}"
git config --global user.email "${GIT_USER_EMAIL:-agente-pod@sinteclatam.com}"
git config --global --add safe.directory '*'
git config --global init.defaultBranch main

echo "[preparar] listo · workdir=$WORKDIR · uid=$(id -u) · claude=$(claude --version)"
