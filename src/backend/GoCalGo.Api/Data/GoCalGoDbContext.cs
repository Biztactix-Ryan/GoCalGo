using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Data
{
    public class GoCalGoDbContext(DbContextOptions<GoCalGoDbContext> options) : DbContext(options)
    {
        public DbSet<Event> Events => Set<Event>();
        public DbSet<EventBuff> EventBuffs => Set<EventBuff>();
        public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
        public DbSet<EventFlag> EventFlags => Set<EventFlag>();
        public DbSet<ScheduledNotification> ScheduledNotifications => Set<ScheduledNotification>();
        public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Event>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(500);
                entity.Property(e => e.Heading).IsRequired().HasMaxLength(1000);
                entity.Property(e => e.ImageUrl).IsRequired().HasMaxLength(2000);
                entity.Property(e => e.LinkUrl).IsRequired().HasMaxLength(2000);
                entity.Property(e => e.EventType)
                    .HasConversion<string>()
                    .HasMaxLength(50);
                entity.HasMany(e => e.Buffs)
                    .WithOne(b => b.Event)
                    .HasForeignKey(b => b.EventId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<EventBuff>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Text).IsRequired().HasMaxLength(1000);
                entity.Property(e => e.IconUrl).HasMaxLength(2000);
                entity.Property(e => e.Category)
                    .HasConversion<string>()
                    .HasMaxLength(50);
                entity.Property(e => e.Resource).HasMaxLength(500);
                entity.Property(e => e.Disclaimer).HasMaxLength(2000);
            });

            modelBuilder.Entity<DeviceToken>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Token).IsRequired().HasMaxLength(500);
                entity.Property(e => e.Platform).IsRequired().HasMaxLength(50);
                entity.Property(e => e.Timezone).HasMaxLength(100);
                entity.HasIndex(e => e.Token).IsUnique();
            });

            modelBuilder.Entity<EventFlag>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.EventId).IsRequired().HasMaxLength(200);
                entity.Property(e => e.DeviceToken).IsRequired().HasMaxLength(500);
                entity.HasIndex(e => new { e.EventId, e.DeviceToken }).IsUnique();
            });

            modelBuilder.Entity<ScheduledNotification>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.EventId).IsRequired().HasMaxLength(200);
                entity.Property(e => e.EventName).IsRequired().HasMaxLength(500);
                entity.Property(e => e.Status)
                    .HasConversion<string>()
                    .HasMaxLength(50);
                entity.HasIndex(e => new { e.Status, e.ScheduledAtUtc });
                entity.HasIndex(e => new { e.EventId, e.DeviceTokenId });
            });

            modelBuilder.Entity<NotificationPreference>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.DeviceToken).IsRequired().HasMaxLength(500);
                entity.Property(e => e.EnabledEventTypes).IsRequired().HasMaxLength(1000);
                entity.HasIndex(e => e.DeviceToken).IsUnique();
            });
        }
    }
}
