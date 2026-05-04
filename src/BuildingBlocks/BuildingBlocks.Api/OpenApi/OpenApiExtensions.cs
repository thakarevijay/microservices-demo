using Microsoft.Extensions.DependencyInjection;
using Microsoft.OpenApi.Models;

namespace BuildingBlocks.Api.OpenApi;

public static class OpenApiExtensions
{
    /// <summary>
    /// Swashbuckle Swagger setup with a Bearer security scheme so the UI lets you
    /// paste a JWT and try authenticated endpoints.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksOpenApi(
        this IServiceCollection services,
        string serviceName,
        string version = "v1")
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc(version, new OpenApiInfo
            {
                Title = serviceName,
                Version = version,
            });

            var jwtScheme = new OpenApiSecurityScheme
            {
                Name = "Authorization",
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                In = ParameterLocation.Header,
                Description = "Paste a JWT (without the 'Bearer ' prefix).",
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer",
                },
            };

            options.AddSecurityDefinition("Bearer", jwtScheme);
            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                [jwtScheme] = Array.Empty<string>(),
            });
        });

        return services;
    }
}
