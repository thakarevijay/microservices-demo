# CI/CD setup guide — step by step

Follow these once, in order. Total time: ~30 min the first time.

## 0. Prereqs

On WSL2 (Ubuntu), confirm you have:

```bash
docker --version && kubectl version --client && minikube version \
  && terraform --version && ansible --version && dotnet --version
```

`minikube start` should already be running.

## 1. Drop the new files into your repo

```
microservices-demo/
├── .github/workflows/ci.yml              ← from ci.yml
├── .github/workflows/cd.yml              ← from cd.yml
├── scripts/setup-github-runner.sh        ← from setup-github-runner.sh
└── scripts/deploy-local.sh               ← from deploy-local.sh
```

```bash
cd ~/Study/microservices-demo
mkdir -p .github/workflows scripts
# copy the four files into the paths above
chmod +x scripts/*.sh
```

## 2. Make Terraform accept a variable image tag

Edit `terraform/variables.tf` (or wherever you put variables):

```hcl
variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Image tag to deploy. Set by CD to the commit SHA."
}
```

Find every place that sets `image = "orders-api:latest"` / `"products-api:latest"` in your deployment resources and change them to:

```hcl
image = "orders-api:${var.image_tag}"
# and
image = "products-api:${var.image_tag}"
```

Then confirm your deployments have:

```yaml
imagePullPolicy: IfNotPresent   # must NOT be Always
```

(If yours says `Always`, K8s will try to pull from a registry that has no copy of your locally-built image and fail with `ErrImagePull`.)

## 3. Commit & push the workflow files

```bash
git checkout -b feat/cicd
git add .github scripts terraform
git commit -m "ci: add GitHub Actions CI + CD pipelines"
git push -u origin feat/cicd
```

Open a PR — **CI runs on GitHub-hosted runners** and should pass. Merge when green.

## 4. Register the self-hosted runner (one-time)

### 4a. Get a runner token

GitHub → your repo → **Settings → Actions → Runners → New self-hosted runner**.
Copy the token from the `./config.sh` command shown on that page (the long `A...` string after `--token`).

### 4b. Install the runner

```bash
cd ~/Study/microservices-demo
./scripts/setup-github-runner.sh https://github.com/<your-user>/microservices-demo <TOKEN>
```

The script will:
1. Check `docker`, `kubectl`, `minikube`, `terraform`, `ansible`, `dotnet` are present.
2. Download the runner to `~/actions-runner`.
3. Register it with labels `self-hosted,wsl2,minikube,Linux,X64`.
4. Install it as a systemd service (if systemd is enabled) or tell you how to run it in tmux.

### 4c. Enable systemd in WSL2 (recommended, if not already)

```powershell
# In PowerShell, check WSL version:
wsl --version
```

If WSL is >= 0.67.6, inside WSL:

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Then in PowerShell:

```powershell
wsl --shutdown
```

Re-open WSL, re-run the runner setup script. It will install as a service.

### 4d. Verify

- GitHub → Settings → Actions → Runners → your runner shows **Idle** (green dot).
- Locally:
  ```bash
  sudo ~/actions-runner/svc.sh status    # if systemd
  # or
  tmux attach -t gh-runner                # if manual
  ```

## 5. Trigger CD

```bash
git checkout main
git pull
# Make any change under src/ and push, or:
gh workflow run cd.yml   # manual trigger
```

Watch it in GitHub → Actions. The deploy job will run on your WSL2 runner.

### What you should see

1. "Preflight — minikube & kubectl" → green.
2. Two `docker build` lines for orders-api and products-api.
3. `terraform apply` output with "Plan: 0 to add, 2 to change, 0 to destroy" (the image tags update).
4. `rollout status` waits for new pods.
5. Ansible smoke tests run.
6. The run summary shows the pod table.

Then hit `http://localhost:5001/products` and `http://localhost:5002/orders` — new version served.

## 6. Sanity check — kill the new pods and watch it self-heal

```bash
kubectl -n microservices get pods
kubectl -n microservices delete pod -l app=orders-api
kubectl -n microservices rollout status deployment/orders-api
```

## 7. Housekeeping

- **Turn on Dependabot**: `.github/dependabot.yml` with `nuget`, `docker`, `terraform`, and `github-actions` ecosystems.
- **Turn on CodeQL**: Settings → Security → Code scanning → Set up → Default.
- **Branch protection on `main`**: require `CI gate` to pass, require at least 1 review, no force-push.
- **Secrets to add later** (when you migrate to cloud):
  - `GHCR_PAT` (or OIDC)
  - `KUBECONFIG` (base64)
  - `TF_API_TOKEN` if you move state to Terraform Cloud

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ErrImagePull` on deploy | `imagePullPolicy: Always` | Set to `IfNotPresent` |
| CD stuck "Waiting for runner" | WSL2 stopped or runner crashed | `sudo ~/actions-runner/svc.sh start` or `wsl` to wake WSL |
| `minikube docker-env` produces nothing | Driver mismatch | `minikube delete && minikube start --driver=docker` |
| `terraform apply` hangs on "still creating..." | K8s resource stuck | `kubectl -n microservices describe pod <name>` — usually an image pull or liveness probe issue |
| Smoke tests fail after deploy | Port-forwards not active on runner | Runner doesn't need port-forwards — smoke tests should hit the Ingress inside the cluster, e.g. `kubectl run curl --rm -it ...` or resolve the Ingress IP |

## Next steps (once this is solid)

1. Add `release-please` for semantic versioning on tags.
2. Add a `staging` branch / environment → preview deploys on a 2nd minikube profile.
3. Publish images to GHCR (start the cloud migration path).
4. Add `cosign sign` + `cosign verify` in a validating admission webhook.
