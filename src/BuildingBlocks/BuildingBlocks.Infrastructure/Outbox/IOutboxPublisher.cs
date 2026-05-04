namespace BuildingBlocks.Infrastructure.Outbox;

/// <summary>
/// Publishes a deserialized integration event to the message bus.
/// MassTransit-backed implementation lives in the service infrastructure.
/// </summary>
public interface IOutboxPublisher
{
    Task PublishAsync(object integrationEvent, CancellationToken cancellationToken = default);
}
