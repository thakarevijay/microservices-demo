# 0004. Keycloak as identity provider

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Vijay

## Context

Five services need a consistent way to authenticate users and authorize service-to-service calls. Options ranged from rolling our own auth service (rejected immediately — no good outcomes) 
to Duende IdentityServer (commercial, .NET-native) to Keycloak (open source, JVM, OIDC/OAuth 2.0). Cost matters; the project runs on a small Civo cluster with no commercial licensing budget.

## Decision

Keycloak runs in-cluster as the identity provider, backed by its own Postgres instance (separate `Cluster` CR from app databases — different lifecycle, different backup needs).

- One realm per environment (`microservices-demo`).
- One OIDC client per service (`orders-api`, `catalog-api`, ...) using client credentials for service-to-service calls.
- One SPA client for the future frontend using Authorization Code + PKCE.
- JWT access tokens, ~15-minute lifetime, refresh tokens for SPA.
- Realm config managed via the Keycloak Operator's `KeycloakRealmImport` CR — realms live in git, not in click-ops.
- Services validate JWTs locally (signature + expiry + audience) using OIDC discovery from the Keycloak realm URL.
- Authorization is policy-based on the API side; roles and permissions are claims on the JWT.

API Gateway (YARP) terminates user-facing auth and forwards to services. Services re-validate the JWT (cheap) so they don't blindly trust the gateway.

## Consequences

- Free, open source, mature. Battle-tested at large scale.
- One more JVM workload to operate — non-trivial memory footprint (~600 MB with its DB).
- Realm-as-code via `KeycloakRealmImport` keeps environments reproducible.
- We never share a user table between services — the IdP is the single source of truth.
- Adding social login or LDAP later is a Keycloak realm config change, not a code change.

## Alternatives considered

- **Duende IdentityServer.** Excellent, .NET-native, but commercial. Rejected on cost.
- **Build our own auth service.** Months of work to do badly what Keycloak already does well. Rejected.
- **Cloud IdP (Auth0, Cognito, Azure AD B2C).** Pay-per-MAU; cluster runs on Civo so we'd be paying a separate vendor. Defer until the system has paying users.
