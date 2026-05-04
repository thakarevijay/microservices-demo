namespace BuildingBlocks.Api.Authentication;

public sealed class JwtAuthOptions
{
    public const string SectionName = "Jwt";

    /// <summary>OIDC authority (e.g. https://keycloak.example.com/realms/microservices-demo).</summary>
    public string Authority { get; set; } = string.Empty;

    /// <summary>Expected audience claim (typically the service's client id).</summary>
    public string Audience { get; set; } = string.Empty;

    /// <summary>Set false in dev only.</summary>
    public bool RequireHttpsMetadata { get; set; } = true;
}
