namespace BuildingBlocks.Contracts;

/// <summary>
/// Marker for events published across service boundaries via the message bus.
/// Concrete events live in service-specific Contracts namespaces (e.g. Orders.Contracts).
/// </summary>
/// <remarks>
/// Treat every integration event as a public API contract:
/// - never remove or rename fields;
/// - additions must be optional / nullable;
/// - bump <see cref="Version"/> when introducing a breaking change.
/// </remarks>
public interface IIntegrationEvent
{
    Guid EventId { get; }

    DateTime OccurredOnUtc { get; }

    int Version { get; }
}
