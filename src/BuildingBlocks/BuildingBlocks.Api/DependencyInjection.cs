using BuildingBlocks.Api.Authentication;
using BuildingBlocks.Api.ExceptionHandling;
using BuildingBlocks.Api.OpenApi;
using BuildingBlocks.Api.RateLimiting;
using BuildingBlocks.Api.Versioning;
using BuildingBlocks.Application.Abstractions;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace BuildingBlocks.Api;

public static class DependencyInjection
{
    /// <summary>
    /// Wires every API-layer cross-cutting concern in one call:
    /// exception handler, ProblemDetails, JWT auth (if configured), API versioning,
    /// rate limiting, OpenAPI, current-user accessor.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksApi(
        this IServiceCollection services,
        IConfiguration configuration,
        string serviceName)
    {
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

        services.AddExceptionHandler<GlobalExceptionHandler>();
        services.AddProblemDetails();

        services.AddBuildingBlocksApiVersioning();
        services.AddBuildingBlocksRateLimiting();
        services.AddBuildingBlocksOpenApi(serviceName);

        var jwtSection = configuration.GetSection(JwtAuthOptions.SectionName);
        if (jwtSection.Exists())
        {
            var jwt = jwtSection.Get<JwtAuthOptions>() ?? new JwtAuthOptions();
            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.Authority = jwt.Authority;
                    options.Audience = jwt.Audience;
                    options.RequireHttpsMetadata = jwt.RequireHttpsMetadata;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        ClockSkew = TimeSpan.FromSeconds(30),
                    };
                });
            services.AddAuthorization();
        }

        return services;
    }
}
