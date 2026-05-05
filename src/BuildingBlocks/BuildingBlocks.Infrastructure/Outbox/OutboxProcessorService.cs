using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BuildingBlocks.Infrastructure.Outbox;

/// <summary>
/// Background service that drains unpublished outbox messages and ships them to the bus.
/// Skeleton implementation — services pass their concrete <see cref="DbContext"/> type via
/// <typeparamref name="TDbContext"/> when registering the hosted service.
/// </summary>
public sealed class OutboxProcessorService<TDbContext> : BackgroundService
    where TDbContext : DbContext
{
    private readonly TimeSpan _pollInterval = TimeSpan.FromSeconds(5);
    private const int _batchSize = 50;
    private const int _maxRetries = 5;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OutboxProcessorService<TDbContext>> _logger;

    public OutboxProcessorService(
        IServiceScopeFactory scopeFactory,
        ILogger<OutboxProcessorService<TDbContext>> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessBatchAsync(stoppingToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Outbox processor batch failed");
            }

            await Task.Delay(_pollInterval, stoppingToken).ConfigureAwait(false);
        }
    }

    private async Task ProcessBatchAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<TDbContext>();
        var publisher = scope.ServiceProvider.GetRequiredService<IOutboxPublisher>();

        var messages = await db.Set<OutboxMessage>()
            .Where(m => m.ProcessedOnUtc == null && m.RetryCount < _maxRetries)
            .OrderBy(m => m.OccurredOnUtc)
            .Take(_batchSize)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var message in messages)
        {
            try
            {
                var type = Type.GetType(message.Type)
                    ?? throw new InvalidOperationException($"Cannot resolve outbox message type '{message.Type}'.");

                var deserialized = JsonSerializer.Deserialize(message.Content, type)
                    ?? throw new InvalidOperationException($"Failed to deserialize outbox message {message.Id}.");

                await publisher.PublishAsync(deserialized, cancellationToken).ConfigureAwait(false);
                message.ProcessedOnUtc = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                message.RetryCount++;
                message.Error = ex.Message;
                _logger.LogWarning(
                    ex,
                    "Failed to publish outbox message {MessageId}, retry {RetryCount}",
                    message.Id,
                    message.RetryCount);
            }
        }

        if (messages.Count > 0)
        {
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        }
    }
}
