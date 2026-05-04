namespace BuildingBlocks.Contracts;

/// <summary>
/// Convenience base record for integration events. Concrete events inherit and
/// add immutable payload properties.
/// </summary>
public abstract record IntegrationEvent : IIntegrationEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();

    public DateTime OccurredOnUtc { get; init; } = DateTime.UtcNow;

    public virtual int Version => 1;
}
