using BuildingBlocks.Application.Cqrs;
using BuildingBlocks.Domain.Abstractions;
using MediatR;

namespace BuildingBlocks.Application.Behaviors;

/// <summary>
/// Wraps every command in a single SaveChanges call, so a successful handler
/// always commits its aggregate changes atomically with the outbox messages
/// the infrastructure layer enqueues during SaveChanges.
/// </summary>
/// <remarks>
/// Queries (IQuery&lt;T&gt;) skip this behavior — they must not mutate state.
/// </remarks>
public sealed class UnitOfWorkBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly IUnitOfWork _unitOfWork;

    public UnitOfWorkBehavior(IUnitOfWork unitOfWork) => _unitOfWork = unitOfWork;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        // Skip queries.
        if (!IsCommand(typeof(TRequest)))
        {
            return await next().ConfigureAwait(false);
        }

        var response = await next().ConfigureAwait(false);

        // Only commit if the result was successful (or wasn't a Result type).
        if (response is Result result && result.IsFailure)
        {
            return response;
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return response;
    }

    private static bool IsCommand(Type requestType) =>
        typeof(ICommand).IsAssignableFrom(requestType)
        || requestType.GetInterfaces().Any(i =>
            i.IsGenericType && i.GetGenericTypeDefinition() == typeof(ICommand<>));
}
