using BuildingBlocks.Infrastructure.Outbox;
using MassTransit;

namespace BuildingBlocks.Infrastructure.Messaging;

/// <summary>
/// Default <see cref="IOutboxPublisher"/> backed by MassTransit's IPublishEndpoint.
/// </summary>
public sealed class MassTransitOutboxPublisher : IOutboxPublisher
{
    private readonly IPublishEndpoint _publishEndpoint;

    public MassTransitOutboxPublisher(IPublishEndpoint publishEndpoint) =>
        _publishEndpoint = publishEndpoint;

    public Task PublishAsync(object integrationEvent, CancellationToken cancellationToken = default) =>
        _publishEndpoint.Publish(integrationEvent, integrationEvent.GetType(), cancellationToken);
}
