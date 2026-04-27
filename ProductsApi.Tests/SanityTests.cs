using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace ProductsApi.Tests;

public class SanityTests
{
    [Fact]
    public void Math_Works()
    {
        (2 + 2).Should().Be(4);
    }
}

public class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_Returns200()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/health");
        var body = await response.Content.ReadAsStringAsync();

        response.IsSuccessStatusCode.Should().BeTrue(
            $"expected 2xx but got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
    }

    [Fact]
    public async Task Version_ReturnsCommitInfo()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/version");
        var body = await response.Content.ReadAsStringAsync();

        response.IsSuccessStatusCode.Should().BeTrue(
            $"expected 2xx but got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        body.Should().Contain("orders-api");  // or "products-api" in ProductsApi.Tests
    }
}