# 0002. Hybrid EF Core (writes) + Dapper (reads)

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Vijay

## Context

The team's first instinct was to replace EF Core with Dapper across the board, citing performance and "more control." On closer inspection, the actual constraints are:

- The write side persists DDD aggregates with private setters, value objects, owned types, and domain events that must be dispatched on SaveChanges. EF Core handles all of this with built-in change tracking, identity map, and a transactional unit of work.
- The read side serves API queries that rarely map cleanly to aggregates — they want flat projections, joins across tables, and minimal allocations.
- Migrations need to live somewhere; rolling our own with FluentMigrator/DbUp is real work.
- EF Core 8 with `AsNoTracking` and compiled queries is within ~10–20% of Dapper for typical workloads.

## Decision

Each service uses both, scoped to the side of CQRS where it fits:

- **Command side** uses EF Core. Aggregates are loaded and saved through EF; the base `DbContext` (in `BuildingBlocks.Infrastructure`) implements `IUnitOfWork`, dispatches domain events, and persists outbox messages in the same transaction.
- **Query side** uses Dapper directly against a read connection. Query handlers receive a connection factory and write SQL by hand, returning flat DTOs.
- **Migrations** are owned by EF Core (`dotnet ef migrations add ...`). Dapper queries assume the schema EF produces.

Both libraries are listed in `Directory.Packages.props`; each service's `Infrastructure` project references whichever it needs.

## Consequences

- Two data-access styles to learn, but each is used where it's strongest.
- EF's identity map + change tracking remain available for aggregate consistency.
- Dapper queries can be tuned independently without fighting EF's query translator.
- The outbox + transactional event dispatch story stays simple (it lives inside `SaveChangesAsync`).
- Schema changes are driven by EF migrations; Dapper SQL needs review when the schema changes (test coverage on query handlers compensates).

## Alternatives considered

- **Pure EF Core.** Forces awkward read models (projection types in DbContext just for queries) and gives up some perf on the read path. Rejected.
- **Pure Dapper.** Forces hand-rolled change tracking, identity map, migrations, and outbox transactionality on the write path. Rejected — too much wheel-reinventing for too little gain.
- **EF Core for everything, no Dapper.** Acceptable as a fallback; we reserve the right to drop Dapper from a service that doesn't actually need it.
