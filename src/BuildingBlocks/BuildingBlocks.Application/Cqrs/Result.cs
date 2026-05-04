namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Represents the outcome of a command/query: success or one or more errors.
/// Avoids throwing exceptions for expected failure modes (validation, conflict, not-found).
/// </summary>
public class Result
{
    protected Result(bool isSuccess, IReadOnlyList<Error> errors)
    {
        if (isSuccess && errors.Count > 0)
        {
            throw new InvalidOperationException("A successful result cannot contain errors.");
        }

        if (!isSuccess && errors.Count == 0)
        {
            throw new InvalidOperationException("A failed result must contain at least one error.");
        }

        IsSuccess = isSuccess;
        Errors = errors;
    }

    public bool IsSuccess { get; }

    public bool IsFailure => !IsSuccess;

    public IReadOnlyList<Error> Errors { get; }

    public Error FirstError => Errors[0];

    public static Result Success() => new(true, Array.Empty<Error>());

    public static Result Failure(Error error) => new(false, new[] { error });

    public static Result Failure(IReadOnlyList<Error> errors) => new(false, errors);

    public static Result<T> Success<T>(T value) => Result<T>.Success(value);

    public static Result<T> Failure<T>(Error error) => Result<T>.Failure(error);
}

/// <summary>
/// A <see cref="Result"/> that carries a value on success.
/// </summary>
public sealed class Result<T> : Result
{
    private readonly T? _value;

    private Result(T value) : base(true, Array.Empty<Error>()) => _value = value;

    private Result(IReadOnlyList<Error> errors) : base(false, errors) => _value = default;

    public T Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException("Cannot access Value of a failed Result.");

    public static Result<T> Success(T value) => new(value);

    public static new Result<T> Failure(Error error) => new(new[] { error });

    public static new Result<T> Failure(IReadOnlyList<Error> errors) => new(errors);

    public static implicit operator Result<T>(T value) => Success(value);
}
