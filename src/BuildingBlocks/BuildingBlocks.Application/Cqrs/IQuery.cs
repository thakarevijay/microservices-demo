using MediatR;

namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Marker for a read-only query that returns <typeparamref name="TResponse"/>.
/// Queries must not mutate state.
/// </summary>
public interface IQuery<TResponse> : IRequest<Result<TResponse>>
{
}

public interface IQueryHandler<in TQuery, TResponse> : IRequestHandler<TQuery, Result<TResponse>>
    where TQuery : IQuery<TResponse>
{
}
