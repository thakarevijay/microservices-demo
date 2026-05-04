# Architecture Decision Records

Numbered, dated records of architecturally significant decisions.

## Conventions

- One file per decision: `NNNN-short-slug.md` (e.g. `0001-clean-architecture-cqrs-ddd.md`).
- Numbers are zero-padded and never reused, even if the decision is later superseded.
- A superseded ADR is left in place; the replacement ADR links back to it and the old one is updated with a `**Status: Superseded by 00NN**` line at the top.
- Every ADR follows the template below.

## Template

```markdown
# NNNN. Title

**Status:** Accepted | Proposed | Superseded by 00NN | Deprecated
**Date:** YYYY-MM-DD
**Deciders:** names

## Context
What is the problem? Why does it need a decision now?

## Decision
What did we decide? Be specific.

## Consequences
What changes because of this? Trade-offs, follow-on work, things that get harder.

## Alternatives considered
What else did we look at, and why did we reject it?
```

## Index

| # | Title | Status |
|---|---|---|
| 0001 | Clean Architecture + CQRS + DDD | Accepted |
| 0002 | Hybrid EF Core (writes) + Dapper (reads) | Accepted |
| 0003 | ELK for cluster observability | Accepted |
| 0004 | Keycloak as identity provider | Accepted |
| 0005 | Monorepo with per-service Helm charts | Accepted |
