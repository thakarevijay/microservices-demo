namespace BuildingBlocks.Infrastructure.Outbox;

/// <summary>
/// A serialized integration event awaiting publication to the message bus.
/// Persisted in the same transaction as the aggregate change that produced it,
/// then drained asynchronously by <c>OutboxProcessorService</c>.
/// </summary>
public sealed class OutboxMessage
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public DateTime OccurredOnUtc { get; init; } = DateTime.UtcNow;

    public string Type { get; init; } = string.Empty;

    public string Content { get; init; } = string.Empty;

    public DateTime? ProcessedOnUtc { get; set; }

    public string? Error { get; set; }

    public int RetryCount { get; set; }
}
