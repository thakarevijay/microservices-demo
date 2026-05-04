namespace BuildingBlocks.Application.Abstractions;

/// <summary>
/// Ambient information about the authenticated caller for the current request.
/// Implementation lives in the API layer (reads from HttpContext claims).
/// </summary>
public interface ICurrentUser
{
    Guid? UserId { get; }

    string? UserName { get; }

    string? Email { get; }

    bool IsAuthenticated { get; }

    bool IsInRole(string role);

    bool HasPermission(string permission);
}
