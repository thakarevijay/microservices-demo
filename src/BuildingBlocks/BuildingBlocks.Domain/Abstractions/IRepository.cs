namespace BuildingBlocks.Domain.Abstractions;

/// <summary>
/// Generic repository contract for an aggregate root.
/// Concrete service repositories should derive a more specific interface
/// (e.g. IOrderRepository) that extends this and exposes domain-meaningful queries.
/// </summary>
/// <remarks>
/// Repositories live behind an interface in the Domain layer; their implementation
/// is in Infrastructure. This keeps Domain pure (no EF dependency).
/// </remarks>
public interface IRepository<TAggregate, in TId>
    where TAggregate : AggregateRoot<TId>
    where TId : notnull
{
    Task<TAggregate?> GetByIdAsync(TId id, CancellationToken cancellationToken = default);

    Task AddAsync(TAggregate aggregate, CancellationToken cancellationToken = default);

    void Update(TAggregate aggregate);

    void Remove(TAggregate aggregate);
}
