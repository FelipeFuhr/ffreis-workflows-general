#!/usr/bin/env bash
# Scale the fleet's self-hosted SonarQube (ffreis-home-infra's scale-to-zero
# `sonarqube` role, in the `ci` k3s namespace) up from 0 replicas and wait for
# it to become ready. Moved here from tf-sonar.yml so every language's sonar
# workflow shares one copy instead of re-deriving it (terraform was the only
# one that had it).
#
# Only works from a job already running on this fleet's self-hosted runner
# pool — it reads the pod's own mounted ServiceAccount token (RBAC: the
# `sonarqube-scaler` Role, get+patch on exactly this one Deployment, bound to
# the `ci` namespace's `default` ServiceAccount) rather than assuming any
# kubeconfig exists. A GitHub-hosted runner (used for some public repos on
# some languages, to keep fork-PR code off the homelab cluster) cannot reach
# `sonarqube.ci.svc.cluster.local` or present that token at all; this script
# then fails cleanly via its own `kubectl` connection error, which the
# composite action treats as "local rescue unavailable" rather than crashing.
set -euo pipefail

krel="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLO "https://dl.k8s.io/release/${krel}/bin/linux/amd64/kubectl"
curl -fsSLO "https://dl.k8s.io/release/${krel}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

kc=(kubectl --server=https://kubernetes.default.svc
    --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
    -n ci)

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
"${kc[@]}" patch deployment sonarqube --type=merge -p \
  "{\"spec\":{\"replicas\":1},\"metadata\":{\"annotations\":{\"sonarqube.ffreis/last-scaled-up\":\"${now}\"}}}"

# Cold-boot budget matches ffreis-home-infra's own
# sonarqube_ready_timeout_seconds default (see that role's defaults/main.yml).
echo "waiting for sonarqube to become ready..."
deadline=$(( $(date +%s) + 360 ))
until [[ "$("${kc[@]}" get deployment sonarqube -o jsonpath='{.status.readyReplicas}')" == "1" ]]; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "::error::sonarqube did not become ready within 360s" >&2
    exit 1
  fi
  sleep 5
done
echo "sonarqube ready"
