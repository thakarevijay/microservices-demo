namespace BuildingBlocks.Domain.Abstractions;

/// <summary>
/// Convenience base record for domain events.
/// Concrete events typically inherit and add immutable payload properties.
/// </summary>
public abstract record DomainEvent : IDomainEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();

    public DateTime OccurredOnUtc { get; init; } = DateTime.UtcNow;
}
