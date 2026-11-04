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

# 360s was lifted from the role's sonarqube_ready_timeout_seconds, which is
# the POD-PROBE budget. Reaching UP on a cold PVC takes materially longer
# (measured: still STARTING at 7 minutes on a freshly provisioned volume), so
# the two must not share a number. Overridable per caller if needed.
READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-900}"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
"${kc[@]}" patch deployment sonarqube --type=merge -p \
  "{\"spec\":{\"replicas\":1},\"metadata\":{\"annotations\":{\"sonarqube.ffreis/last-scaled-up\":\"${now}\"}}}"

# TWO waits, because POD READINESS IS NOT APPLICATION READINESS here.
#
# The Deployment's readinessProbe (ffreis-home-infra, role `sonarqube`) is an
# httpGet on /api/system/status with NO body check — and SonarQube answers
# that with HTTP 200 while still reporting {"status":"STARTING"}. So
# readyReplicas flips to 1 minutes before the server can serve an analysis.
# Measured 2026-11-04: pod 1/1 Ready at 4m47s while the API still said
# STARTING, and a scan launched in that window dies on a connection the
# scanner reports as a token or network problem.
#
# Waiting on readyReplicas alone was therefore a race this job won only when
# the server happened to be warm — which is most of the time, since it scales
# from zero only after an idle period, and is exactly why it looked flaky
# rather than broken.
echo "waiting for the sonarqube pod to be ready..."
deadline=$(( $(date +%s) + READY_TIMEOUT_SECONDS ))
until [[ "$("${kc[@]}" get deployment sonarqube -o jsonpath='{.status.readyReplicas}')" == "1" ]]; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "::error::sonarqube pod did not become ready within ${READY_TIMEOUT_SECONDS}s" >&2
    exit 1
  fi
  sleep 5
done
echo "pod ready; waiting for sonarqube itself to report UP..."

# Reached in-cluster by service DNS — this job runs on a self-hosted runner
# pod in the same cluster, which is the same path the scanner itself uses.
status_url="http://sonarqube.ci.svc.cluster.local:9000/api/system/status"
until curl -fsS --max-time 10 "${status_url}" 2>/dev/null | grep -q '"status":"UP"'; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "::error::sonarqube never reported UP within ${READY_TIMEOUT_SECONDS}s. Last status: $(curl -fsS --max-time 10 "${status_url}" 2>/dev/null || echo unreachable)" >&2
    echo "::notice::STARTING for a long time means a cold PVC or an IO-starved node, not a broken server. A 'create process timeout' in the local-path provisioner log is the usual root cause." >&2
    exit 1
  fi
  sleep 5
done
echo "sonarqube UP"
