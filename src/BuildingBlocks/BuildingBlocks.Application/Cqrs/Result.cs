namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Represents the outcome of a command/query: success or one or more errors.
/// Avoids throwing exceptions for expected failure modes (validation, conflict, not-found).
/// </summary>
public class Result
{
    protected Result(bool isSuccess, IReadOnlyList<ErrorApp> errors)
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

    public IReadOnlyList<ErrorApp> Errors { get; }

    public ErrorApp FirstError => Errors[0];

    public static Result Success() => new(true, Array.Empty<ErrorApp>());

    public static Result Failure(ErrorApp error) => new(false, new[] { error });

    public static Result Failure(IReadOnlyList<ErrorApp> errors) => new(false, errors);

    public static Result<T> Success<T>(T value) => Result<T>.Success(value);

    public static Result<T> Failure<T>(ErrorApp error) => Result<T>.Failure(error);
}

/// <summary>
/// A <see cref="Result"/> that carries a value on success.
/// </summary>
public sealed class Result<T> : Result
{
    private readonly T? _value;

    private Result(T value) : base(true, Array.Empty<ErrorApp>()) => _value = value;

    private Result(IReadOnlyList<ErrorApp> errors) : base(false, errors) => _value = default;

    public T Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException("Cannot access Value of a failed Result.");

    public static Result<T> Success(T value) => new(value);

    public static new Result<T> Failure(ErrorApp error) => new(new[] { error });

    public static new Result<T> Failure(IReadOnlyList<ErrorApp> errors) => new(errors);

    public static implicit operator Result<T>(T value) => Success(value);
}
