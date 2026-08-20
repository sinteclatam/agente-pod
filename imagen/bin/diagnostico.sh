#!/usr/bin/env bash
# Radiografía del contenedor: versiones, salud de Claude Code y permisos reales en el clúster.
set -uo pipefail
echo "=== versiones ==="
claude --version; kubectl version --client=true 2>/dev/null | head -1; helm version --short
gh --version | head -1; git --version; tmux -V
echo; echo "=== identidad ==="
id; echo "HOME=$HOME"; echo "namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo '(sin token de SA)')"
echo; echo "=== claude doctor ==="
claude doctor 2>&1 | head -30
echo; echo "=== permisos en el clúster ==="
for verbo_recurso in "get pods" "create deployments" "delete deployments" "create pods/exec" "get secrets" "list nodes"; do
  set -- $verbo_recurso
  printf '%-28s %s\n' "$1 $2" "$(kubectl auth can-i "$1" "$2" 2>/dev/null || echo '?')"
done
