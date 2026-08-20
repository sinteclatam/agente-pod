#!/usr/bin/env bash
# Aplica los manifiestos y deja tantos agentes como diga AGENTES en el ConfigMap.
set -euo pipefail
cd "$(dirname "$0")/.."

NS=${NS:-agentes}
CONTEXTO=$(kubectl config current-context)

if [ "${1:-}" != "--si" ]; then
  echo "Clúster:   $CONTEXTO"
  echo "Namespace: $NS"
  read -r -p "¿Aplicar aquí? [s/N] " respuesta
  [[ "$respuesta" =~ ^[sSyY]$ ]] || { echo "cancelado"; exit 1; }
fi

for secreto in agente-pod-credenciales agente-pod-tokens; do
  kubectl -n "$NS" get secret "$secreto" >/dev/null 2>&1 \
    || echo "AVISO: falta el Secret '$secreto' — el pod no arrancará (ver docs/OPERACION.md)"
done

kubectl apply -k k8s/

AGENTES=$(kubectl -n "$NS" get configmap agente-pod-config -o jsonpath='{.data.AGENTES}')
: "${AGENTES:=1}"
echo "Agentes pedidos en el ConfigMap: $AGENTES"
kubectl -n "$NS" scale statefulset agente-pod --replicas="$AGENTES"
kubectl -n "$NS" rollout status statefulset/agente-pod --timeout=600s

echo
kubectl -n "$NS" get pods -l app.kubernetes.io/name=agente-pod
echo
echo "Sesiones en claude.ai:"
"$(dirname "$0")/urls.sh" || true
