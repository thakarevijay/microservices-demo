using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BuildingBlocks.Infrastructure.Outbox;

public sealed class OutboxMessageConfiguration : IEntityTypeConfiguration<OutboxMessage>
{
    public void Configure(EntityTypeBuilder<OutboxMessage> builder)
    {
        builder.ToTable("outbox_messages");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.Type)
            .HasMaxLength(500)
            .IsRequired();

        builder.Property(m => m.Content)
            .HasColumnType("jsonb")
            .IsRequired();

        builder.Property(m => m.OccurredOnUtc).IsRequired();

        builder.Property(m => m.Error).HasMaxLength(4000);

        builder.HasIndex(m => m.ProcessedOnUtc);
    }
}
