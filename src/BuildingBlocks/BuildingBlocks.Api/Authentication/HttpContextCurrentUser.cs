using System.Security.Claims;
using BuildingBlocks.Application.Abstractions;
using Microsoft.AspNetCore.Http;

namespace BuildingBlocks.Api.Authentication;

/// <summary>
/// <see cref="ICurrentUser"/> backed by HttpContext claims.
/// Expects standard OIDC claims emitted by Keycloak (sub, preferred_username, email).
/// </summary>
public sealed class HttpContextCurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public HttpContextCurrentUser(IHttpContextAccessor httpContextAccessor) =>
        _httpContextAccessor = httpContextAccessor;

    private ClaimsPrincipal? Principal => _httpContextAccessor.HttpContext?.User;

    public Guid? UserId
    {
        get
        {
            var sub = Principal?.FindFirstValue(ClaimTypes.NameIdentifier)
                   ?? Principal?.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    public string? UserName =>
        Principal?.FindFirstValue("preferred_username")
        ?? Principal?.Identity?.Name;

    public string? Email => Principal?.FindFirstValue(ClaimTypes.Email)
                         ?? Principal?.FindFirstValue("email");

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated ?? false;

    public bool IsInRole(string role) => Principal?.IsInRole(role) ?? false;

    public bool HasPermission(string permission) =>
        Principal?.Claims.Any(c => c.Type == "permission" && c.Value == permission) ?? false;
}
