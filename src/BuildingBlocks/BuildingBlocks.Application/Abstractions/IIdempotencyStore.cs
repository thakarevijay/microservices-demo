namespace BuildingBlocks.Application.Abstractions;

/// <summary>
/// Stores an idempotency key + serialized response so repeated requests with the
/// same key return the cached response instead of re-executing the handler.
/// </summary>
/// <remarks>
/// Backed by Redis or a Postgres table in concrete services.
/// </remarks>
public interface IIdempotencyStore
{
    Task<string?> GetAsync(string key, CancellationToken cancellationToken = default);

    Task SetAsync(string key, string serializedResponse, TimeSpan ttl, CancellationToken cancellationToken = default);
}
