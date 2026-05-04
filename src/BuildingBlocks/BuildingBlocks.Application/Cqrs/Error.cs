namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Categorized error returned from a failed Result.
/// The API layer maps Type → HTTP status code via ProblemDetails.
/// </summary>
public sealed record Error(string Code, string Message, ErrorType Type)
{
    public static readonly Error None = new(string.Empty, string.Empty, ErrorType.Failure);

    public static Error NotFound(string code, string message) => new(code, message, ErrorType.NotFound);

    public static Error Validation(string code, string message) => new(code, message, ErrorType.Validation);

    public static Error Conflict(string code, string message) => new(code, message, ErrorType.Conflict);

    public static Error Unauthorized(string code, string message) => new(code, message, ErrorType.Unauthorized);

    public static Error Forbidden(string code, string message) => new(code, message, ErrorType.Forbidden);

    public static Error Failure(string code, string message) => new(code, message, ErrorType.Failure);
}

public enum ErrorType
{
    Failure = 0,        // 500
    Validation = 1,     // 400
    NotFound = 2,       // 404
    Conflict = 3,       // 409
    Unauthorized = 4,   // 401
    Forbidden = 5,      // 403
}
