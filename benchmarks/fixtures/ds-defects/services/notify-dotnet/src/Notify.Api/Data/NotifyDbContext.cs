using MassTransit;
using Microsoft.EntityFrameworkCore;

namespace Notify.Api.Data;

public sealed class NotifyDbContext(DbContextOptions<NotifyDbContext> options) : DbContext(options)
{
    public DbSet<ContactPreference> Preferences => Set<ContactPreference>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.AddInboxStateEntity();
        b.AddOutboxMessageEntity();
        b.AddOutboxStateEntity();
        b.Entity<ContactPreference>().HasKey(p => new { p.CustomerId, p.Channel });
    }
}

public sealed class ContactPreference
{
    public string CustomerId { get; set; } = "";
    public string Channel { get; set; } = "";
    public bool Enabled { get; set; }
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public DateTimeOffset UpdatedAt { get; set; }
}
