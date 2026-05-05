# 0001. Clean Architecture + CQRS + DDD

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Vijay

## Context

The existing OrdersApi and ProductsApi services are flat single-project apps with all logic, configuration, and HTTP handling in `Program.cs`. As the system grows to five services (Orders, Catalog, Basket, Payments, Products) 
with shared concerns (auth, messaging, observability, persistence), the flat layout will not scale: it mixes business rules with infrastructure concerns, 
makes testing painful, and forces every developer to re-derive cross-cutting plumbing per service.

We need a layered structure that:

1. Keeps business rules independent of HTTP, EF, RabbitMQ, etc.
2. Separates command (write) and query (read) paths so they can evolve independently.
3. Encodes invariants in domain types rather than service-layer if-checks.
4. Makes it obvious where a new piece of logic belongs.

## Decision

Every microservice is structured as four projects per Clean Architecture, plus shared `BuildingBlocks.*` infrastructure:

```
src/Services/<Name>/
  <Name>.Domain/         # entities, value objects, domain events, repository interfaces
  <Name>.Application/    # CQRS handlers (Commands, Queries), DTOs, validators
  <Name>.Infrastructure/ # EF/Dapper, MassTransit, repository impls, outbox
  <Name>.Api/            # composition root: DI, endpoints, middleware
```

Dependency rule: arrows point inward. `Domain` depends on nothing. `Application` depends on `Domain`. `Infrastructure` and `Api` depend on `Application`. Tests are added per layer.

CQRS via MediatR: each user-driven action is a `Command` or `Query` with a single handler. Pipeline behaviors in `BuildingBlocks.Application` (Logging → Validation → UnitOfWork) wrap every handler. Read models may diverge from write models when query patterns demand it; same database is fine until proven otherwise.

DDD: business logic lives in aggregate roots (`AggregateRoot<TId>`) with private setters and intent-revealing methods (`Order.Place()`, `Order.Cancel()`). Value objects (`Money`, `Address`, `OrderId`) replace primitives where the primitive carries meaning. Domain events are raised from aggregates and dispatched in-process within the same transaction; integration events cross service boundaries via the outbox.

## Consequences

- New developers have a single, consistent place to look for any class of logic.
- Unit testing the domain becomes trivial — no DB, no HTTP, no DI.
- Some boilerplate is unavoidable: each command has a Command + Handler + Validator at minimum. We accept this in exchange for predictability.
- The first service (Orders) doubles as a reference implementation. Patterns refined there propagate to Catalog, Basket, etc.
- Rejecting "service per repo" means every service shares `BuildingBlocks.*` via project references. We must keep BuildingBlocks deliberately small and avoid putting business types there.

## Alternatives considered

- **Keep the flat layout, just split files.** Doesn't address coupling between business rules and infrastructure; same trap, more files.
- **Vertical slice architecture (no Clean layers, just feature folders).** Cleaner for small services, but loses the strict dependency direction we want at the boundary between domain and infrastructure. Useful pattern *within* the Application layer (one folder per command/query) and we adopt that locally.
- **Event sourcing.** Significant tax on tooling, replay, and testing. Not justified by current audit requirements.
