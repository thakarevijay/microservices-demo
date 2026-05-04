namespace BuildingBlocks.Application.Abstractions;

/// <summary>
/// Abstraction over <see cref="DateTime"/> so handlers and entities can be tested
/// with a fixed clock. Always returns UTC.
/// </summary>
public interface IDateTimeProvider
{
    DateTime UtcNow { get; }

    DateTimeOffset OffsetUtcNow { get; }
}
