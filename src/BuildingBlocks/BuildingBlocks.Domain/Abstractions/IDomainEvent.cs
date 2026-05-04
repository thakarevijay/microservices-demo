namespace BuildingBlocks.Domain.Abstractions;

/// <summary>
/// Marker interface for events raised inside a bounded context.
/// Domain events are dispatched in-process within the same transaction
/// as the aggregate change that produced them.
/// </summary>
/// <remarks>
/// Do NOT publish domain events across service boundaries — that is what
/// integration events (in BuildingBlocks.Contracts) are for.
/// </remarks>
public interface IDomainEvent
{
    Guid EventId { get; }

    DateTime OccurredOnUtc { get; }
}
