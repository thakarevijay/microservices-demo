namespace BuildingBlocks.Infrastructure.Messaging;

public sealed class RabbitMqOptions
{
    public const string SectionName = "RabbitMq";

    public string Host { get; set; } = "rabbitmq";

    public string VirtualHost { get; set; } = "/";

    public string Username { get; set; } = "guest";

    public string Password { get; set; } = "guest";

    public ushort Port { get; set; } = 5672;
}
