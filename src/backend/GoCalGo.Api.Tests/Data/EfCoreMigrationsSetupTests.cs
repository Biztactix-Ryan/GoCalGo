using GoCalGo.Api.Data;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Data
{
    public class EfCoreMigrationsSetupTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void DbContext_IsRegisteredInDI()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext? context = scope.ServiceProvider.GetService<GoCalGoDbContext>();

            Assert.NotNull(context);
        }

        [Fact]
        public void DbContext_UsesNpgsqlProvider()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext context = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();

            Assert.Equal("Npgsql.EntityFrameworkCore.PostgreSQL", context.Database.ProviderName);
        }

        [Fact]
        public void DbContext_HasConnectionStringConfigured()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext context = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
            string? connectionString = context.Database.GetConnectionString();

            Assert.NotNull(connectionString);
            Assert.Contains("Host=", connectionString);
            Assert.Contains("Database=", connectionString);
        }

        [Fact]
        public void DbContextOptions_AreResolvable()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            DbContextOptions<GoCalGoDbContext>? options =
                scope.ServiceProvider.GetService<DbContextOptions<GoCalGoDbContext>>();

            Assert.NotNull(options);
        }
    }
}
