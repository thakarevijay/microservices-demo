namespace BuildingBlocks.Application.Cqrs;

/// <summary>
/// Categorized error returned from a failed Result.
/// The API layer maps Type → HTTP status code via ProblemDetails.
/// </summary>
public sealed record ErrorApp(string Code, string Message, ErrorType Type)
{
    public static readonly ErrorApp None = new(string.Empty, string.Empty, ErrorType.Failure);

    public static ErrorApp NotFound(string code, string message) => new(code, message, ErrorType.NotFound);

    public static ErrorApp Validation(string code, string message) => new(code, message, ErrorType.Validation);

    public static ErrorApp Conflict(string code, string message) => new(code, message, ErrorType.Conflict);

    public static ErrorApp Unauthorized(string code, string message) => new(code, message, ErrorType.Unauthorized);

    public static ErrorApp Forbidden(string code, string message) => new(code, message, ErrorType.Forbidden);

    public static ErrorApp Failure(string code, string message) => new(code, message, ErrorType.Failure);
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
