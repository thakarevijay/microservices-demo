using System.Text.Json;
using BuildingBlocks.Domain;
using BuildingBlocks.Domain.Abstractions;
using BuildingBlocks.Infrastructure.Outbox;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BuildingBlocks.Infrastructure.Persistence;

/// <summary>
/// Base DbContext that:
/// 1. Registers the outbox table.
/// 2. On SaveChanges, dispatches in-process domain events via MediatR
///    AND serializes integration events into the outbox table within the same transaction.
/// </summary>
/// <remarks>
/// Service DbContexts inherit, register their own aggregates, and call
/// <c>builder.ApplyConfiguration(new OutboxMessageConfiguration())</c> in OnModelCreating.
/// </remarks>
public abstract class BaseDbContext : DbContext, IUnitOfWork
{
    private readonly IPublisher _mediator;

    protected BaseDbContext(DbContextOptions options, IPublisher mediator) : base(options)
    {
        _mediator = mediator;
    }

    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfiguration(new OutboxMessageConfiguration());
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var aggregates = ChangeTracker.Entries()
            .Where(e => e.Entity is AggregateRoot<Guid>
                     || e.Entity.GetType().BaseType?.IsGenericType == true
                        && e.Entity.GetType().BaseType.GetGenericTypeDefinition() == typeof(AggregateRoot<>))
            .Select(e => e.Entity)
            .ToList();

        var domainEvents = aggregates
            .SelectMany(a =>
            {
                var prop = a.GetType().GetProperty(nameof(AggregateRoot<Guid>.DomainEvents));
                return prop?.GetValue(a) as IEnumerable<IDomainEvent> ?? Array.Empty<IDomainEvent>();
            })
            .ToList();

        // Clear before dispatch to avoid re-raising on subsequent saves.
        foreach (var aggregate in aggregates)
        {
            var clear = aggregate.GetType().GetMethod(nameof(AggregateRoot<Guid>.ClearDomainEvents));
            clear?.Invoke(aggregate, null);
        }

        // 1. In-process dispatch (handlers run in the same transaction).
        foreach (var domainEvent in domainEvents)
        {
            await _mediator.Publish(domainEvent, cancellationToken).ConfigureAwait(false);
        }

        // 2. Persist integration events to outbox in the same SaveChanges.
        //    Concrete services translate domain events → integration events in
        //    domain event handlers and add them to OutboxMessages there.

        return await base.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Helper for domain event handlers to enqueue an integration event for the outbox.
    /// </summary>
    public void AddOutboxMessage(object integrationEvent)
    {
        ArgumentNullException.ThrowIfNull(integrationEvent);

        OutboxMessages.Add(new OutboxMessage
        {
            Type = integrationEvent.GetType().AssemblyQualifiedName ?? integrationEvent.GetType().FullName!,
            Content = JsonSerializer.Serialize(integrationEvent, integrationEvent.GetType()),
        });
    }
}
