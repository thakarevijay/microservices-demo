using BuildingBlocks.Domain.Abstractions;

namespace BuildingBlocks.Domain;

/// <summary>
/// Marks the consistency boundary of a cluster of domain objects.
/// Aggregate roots are the only entities loaded/saved through repositories.
/// </summary>
public abstract class AggregateRoot<TId> : Entity<TId>
    where TId : notnull
{
    private readonly List<IDomainEvent> _domainEvents = new();

    protected AggregateRoot(TId id) : base(id)
    {
    }

    protected AggregateRoot()
    {
    }

    /// <summary>
    /// Domain events queued by this aggregate during the current transaction.
    /// The infrastructure layer reads and clears these on SaveChanges.
    /// </summary>
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected void RaiseDomainEvent(IDomainEvent domainEvent) =>
        _domainEvents.Add(domainEvent);

    public void ClearDomainEvents() => _domainEvents.Clear();
}
