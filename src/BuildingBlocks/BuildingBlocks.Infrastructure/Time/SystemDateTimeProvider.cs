using BuildingBlocks.Application.Abstractions;

namespace BuildingBlocks.Infrastructure.Time;

public sealed class SystemDateTimeProvider : IDateTimeProvider
{
    public DateTime UtcNow => DateTime.UtcNow;

    public DateTimeOffset OffsetUtcNow => DateTimeOffset.UtcNow;
}
