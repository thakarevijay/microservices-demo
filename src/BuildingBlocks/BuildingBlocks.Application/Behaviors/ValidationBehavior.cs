using BuildingBlocks.Application.Cqrs;
using FluentValidation;
using MediatR;

namespace BuildingBlocks.Application.Behaviors;

/// <summary>
/// Runs every registered FluentValidation <see cref="IValidator{TRequest}"/> for the request.
/// On any failure, short-circuits with a <see cref="Result"/> failure (no exception).
/// </summary>
/// <remarks>
/// Only fires for requests whose response is a <see cref="Result"/> or <see cref="Result{T}"/>.
/// </remarks>
public sealed class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators) =>
        _validators = validators;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!_validators.Any())
        {
            return await next().ConfigureAwait(false);
        }

        var context = new ValidationContext<TRequest>(request);
        var failures = (await Task.WhenAll(
                _validators.Select(v => v.ValidateAsync(context, cancellationToken)))
                .ConfigureAwait(false))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count == 0)
        {
            return await next().ConfigureAwait(false);
        }

        var errors = failures
            .Select(f => ErrorApp.Validation(f.PropertyName, f.ErrorMessage))
            .ToArray();

        // If TResponse is Result or Result<T>, return a failure; otherwise rethrow.
        if (typeof(TResponse) == typeof(Result))
        {
            return (TResponse)(object)Result.Failure(errors);
        }

        if (typeof(TResponse).IsGenericType
            && typeof(TResponse).GetGenericTypeDefinition() == typeof(Result<>))
        {
            var resultType = typeof(TResponse).GetGenericArguments()[0];
            var failureMethod = typeof(Result<>)
                .MakeGenericType(resultType)
                .GetMethod(nameof(Result<object>.Failure), new[] { typeof(IReadOnlyList<ErrorApp>) })!;
            return (TResponse)failureMethod.Invoke(null, new object[] { errors })!;
        }

        throw new ValidationException(failures);
    }
}
