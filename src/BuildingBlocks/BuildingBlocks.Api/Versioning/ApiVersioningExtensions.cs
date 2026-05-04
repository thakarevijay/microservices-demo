using Asp.Versioning;
using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Api.Versioning;

public static class ApiVersioningExtensions
{
    /// <summary>
    /// URL-segment-based API versioning ( <c>/v1/orders</c> ) with a default of v1.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksApiVersioning(this IServiceCollection services)
    {
        services.AddApiVersioning(options =>
        {
            options.DefaultApiVersion = new ApiVersion(1, 0);
            options.AssumeDefaultVersionWhenUnspecified = true;
            options.ReportApiVersions = true;
            options.ApiVersionReader = new UrlSegmentApiVersionReader();
        })
        .AddApiExplorer(options =>
        {
            options.GroupNameFormat = "'v'VVV";
            options.SubstituteApiVersionInUrl = true;
        });

        return services;
    }
}
