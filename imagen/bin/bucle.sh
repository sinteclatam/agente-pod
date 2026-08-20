#!/usr/bin/env bash
# Mantiene viva la sesión de Remote Control. Claude Code se cierra solo si pasa ~10 min sin red,
# así que el bucle lo vuelve a levantar; y al reiniciar retoma la sesión anterior con --continue.
set -uo pipefail

WORKDIR=${WORKDIR:-/home/agente/workspace}
NOMBRE=${NOMBRE:-${HOSTNAME:-agente-pod}}
MODO_PERMISOS=${MODO_PERMISOS:-bypassPermissions}
MODO_SESION=${MODO_SESION:-continua}
SESIONES_MAX=${SESIONES_MAX:-1}
ESPERA=${ESPERA_REINTENTO:-15}
MARCA="$HOME/.claude/.sesion-remota-abierta"

cd "$WORKDIR" || exit 1

while true; do
  ARGS=(--permission-mode "$MODO_PERMISOS")
  CONTINUANDO=no
  if [ "$MODO_SESION" = "servidor" ]; then
    # Varias sesiones concurrentes servidas por un solo proceso. Ojo: --capacity no se puede
    # combinar con --continue, así que en este modo NO se retoma la sesión anterior al reiniciar.
    ARGS+=(--name "$NOMBRE" --capacity "$SESIONES_MAX" --spawn same-dir)
  elif [ -f "$MARCA" ]; then
    ARGS+=(--continue)
    CONTINUANDO=si
  else
    ARGS+=(--name "$NOMBRE")
  fi

  echo "[agente] $(date -Is) arrancando: claude remote-control ${ARGS[*]}"
  # Si aguanta 25 s es que conectó: dejamos la marca para retomar esta misma sesión al reiniciar.
  ( sleep 25; touch "$MARCA" ) & TEMPORIZADOR=$!
  INICIO=$(date +%s)
  claude remote-control "${ARGS[@]}"
  CODIGO=$?
  kill "$TEMPORIZADOR" 2>/dev/null
  DURACION=$(( $(date +%s) - INICIO ))

  if [ "$CONTINUANDO" = "si" ] && [ "$DURACION" -lt 20 ]; then
    echo "[agente] no se pudo retomar la sesión previa (código $CODIGO); en el próximo intento abro una nueva"
    rm -f "$MARCA"
  fi
  echo "[agente] $(date -Is) el proceso terminó (código $CODIGO, duró ${DURACION}s); reintento en ${ESPERA}s"
  sleep "$ESPERA"
done
