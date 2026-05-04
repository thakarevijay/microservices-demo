using MediatR;

namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Marker for a command that mutates state and returns no value.
/// </summary>
public interface ICommand : IRequest<Result>
{
}

/// <summary>
/// Marker for a command that mutates state and returns <typeparamref name="TResponse"/>.
/// </summary>
public interface ICommand<TResponse> : IRequest<Result<TResponse>>
{
}

/// <summary>
/// Handler for a command with no return value.
/// </summary>
public interface ICommandHandler<in TCommand> : IRequestHandler<TCommand, Result>
    where TCommand : ICommand
{
}

/// <summary>
/// Handler for a command that returns <typeparamref name="TResponse"/>.
/// </summary>
public interface ICommandHandler<in TCommand, TResponse> : IRequestHandler<TCommand, Result<TResponse>>
    where TCommand : ICommand<TResponse>
{
}
