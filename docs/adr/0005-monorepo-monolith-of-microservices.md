# 0005. Monorepo with shared BuildingBlocks and per-service Helm charts

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Vijay

## Context

The repo already exists as a monorepo (`thakarevijay/microservices-demo`) with CI/CD, GitOps via ArgoCD, and a single GHCR registry. Splitting into per-service repos would require duplicating CI/CD, 
ArgoCD wiring, and shared infrastructure code. The project is one developer's portfolio/learning system — coordination overhead of polyrepo isn't worth the isolation it buys.

## Decision

Stay monorepo. Within it:

- `src/BuildingBlocks/*` — five shared library projects, referenced by every service via project references (not NuGet). Versioned with the repo.
- `src/Services/<Name>/*` — four projects per service (Domain, Application, Infrastructure, Api).
- `src/Gateways/Web.Gateway/` — YARP-based API gateway.
- `tests/<Name>/*` — per-service test projects.
- `deploy/helm/library/` — shared Helm library chart (Deployment, Service, HPA, PDB, NetworkPolicy boilerplate).
- `deploy/helm/charts/<name>/` — thin per-service charts that depend on the library chart.
- `deploy/argocd/` — ApplicationSet per environment.
- `deploy/platform/` — platform-stack Applications (Sealed Secrets, cert-manager, CNPG, RabbitMQ, KEDA, Keycloak, kube-prometheus-stack, ELK, OTel Collector).
- `docs/adr/` — architecture decision records.

CI is path-filtered: changes under `src/Services/Orders/` only rebuild `orders-api`. Shared `BuildingBlocks` changes trigger a full rebuild because they affect every service.

Images are tagged per service per commit: `ghcr.io/thakarevijay/orders-api:<sha>`. There is no global repo version.

## Consequences

- Single source of truth, single PR can update a service and its Helm chart together.
- Refactoring across services (e.g. adding a new pipeline behavior to BuildingBlocks) is one PR, not five.
- BuildingBlocks must be kept deliberately small and cross-cutting — no business types ever go in there.
- If the project ever grows to a team larger than two, polyrepo becomes a real conversation. ADR will be re-opened then.
- Self-hosted runner / GitHub Actions minutes scale with monorepo size; path filters keep this manageable for now.

## Alternatives considered

- **Polyrepo (one repo per service + a platform repo).** Better isolation, much more coordination cost. Rejected for current scale.
- **Single repo, no BuildingBlocks (copy-paste cross-cutting per service).** Drift inevitable. Rejected.
- **NuGet-published BuildingBlocks (versioned package).** Useful when there are external consumers; for one-repo-one-team, project references are simpler.
