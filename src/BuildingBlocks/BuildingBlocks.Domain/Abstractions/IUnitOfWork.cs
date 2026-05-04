namespace BuildingBlocks.Domain.Abstractions;

/// <summary>
/// Atomic save boundary across one or more aggregates within a single bounded context.
/// Implemented by Infrastructure (typically wrapping the service's DbContext).
/// </summary>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
