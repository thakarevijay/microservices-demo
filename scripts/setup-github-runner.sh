#!/usr/bin/env bash
# setup-github-runner.sh
# Install & configure a GitHub Actions self-hosted runner inside WSL2
# for the microservices-demo repo.
#
# Usage:
#   ./setup-github-runner.sh <repo_url> <registration_token>
#
# Get the registration token from:
#   GitHub → your repo → Settings → Actions → Runners → "New self-hosted runner"
#   (the token is valid for ~1 hour; you register once then the runner re-auths itself)
#
# Prereqs on WSL2 (Ubuntu):
#   - docker (inside minikube docker daemon; the host docker is not used for images)
#   - minikube running (`minikube start`)
#   - kubectl, terraform, ansible, dotnet 8 SDK on PATH
#   - git, curl, jq

set -euo pipefail

### --- args ---
REPO_URL="${1:-}"
RUNNER_TOKEN="${2:-}"

if [[ -z "$REPO_URL" || -z "$RUNNER_TOKEN" ]]; then
  cat >&2 <<EOF
Usage: $0 <repo_url> <registration_token>

Example:
  $0 https://github.com/your-user/microservices-demo AAXXXXXXXXXXXXXXXXXXXX

Get a token at:
  https://github.com/<owner>/<repo>/settings/actions/runners/new
EOF
  exit 1
fi

### --- config ---
RUNNER_VERSION="${RUNNER_VERSION:-2.319.1}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
RUNNER_NAME="${RUNNER_NAME:-wsl2-minikube-$(hostname)}"
RUNNER_LABELS="self-hosted,wsl2,minikube,Linux,X64"

### --- preflight ---
echo "==> Preflight checks"
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need curl
need tar
need docker
need kubectl
need minikube
need terraform
need ansible
need dotnet

if ! minikube status >/dev/null 2>&1; then
  echo "WARN: minikube is not running. The runner will fail deploys until you 'minikube start'." >&2
fi

### --- download runner ---
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -f "./config.sh" ]]; then
  echo "==> Downloading actions-runner v${RUNNER_VERSION}"
  TARBALL="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  curl -fsSL -o "$TARBALL" \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"
  tar xzf "$TARBALL"
  rm -f "$TARBALL"
fi

### --- configure ---
if [[ -f ".runner" ]]; then
  echo "==> Runner already configured. Re-registering with --replace."
fi

./config.sh \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --work "_work" \
  --unattended \
  --replace

### --- install as systemd service if systemd is active, else give tmux instructions ---
if [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
  echo "==> systemd detected — installing as a service"
  sudo ./svc.sh install "$USER"
  sudo ./svc.sh start
  sudo ./svc.sh status
  cat <<EOF

Runner is installed as a systemd service.
  Stop:    sudo $RUNNER_DIR/svc.sh stop
  Start:   sudo $RUNNER_DIR/svc.sh start
  Status:  sudo $RUNNER_DIR/svc.sh status
  Logs:    journalctl -u actions.runner.* -f

EOF
else
  cat <<EOF

==> systemd NOT detected (older WSL, or systemd not enabled in /etc/wsl.conf).

To enable systemd in WSL2 (recommended):
  1. Put this in /etc/wsl.conf:
       [boot]
       systemd=true
  2. In PowerShell: wsl --shutdown
  3. Re-open WSL and re-run this script.

Or run the runner manually in a tmux / screen session:
  cd $RUNNER_DIR
  tmux new -s gh-runner './run.sh'
  # detach: Ctrl-b then d
  # reattach: tmux attach -t gh-runner

EOF
fi

echo "==> Done. Verify in GitHub: $REPO_URL/settings/actions/runners"