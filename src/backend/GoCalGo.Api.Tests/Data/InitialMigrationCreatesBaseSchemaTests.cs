using GoCalGo.Api.Data;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Data
{
    public class InitialMigrationCreatesBaseSchemaTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void MigrationsAssembly_ContainsAtLeastOneMigration()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext context = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();

            IMigrationsAssembly migrationsAssembly = context.GetService<IMigrationsAssembly>()!;
            Assert.NotEmpty(migrationsAssembly.Migrations);
        }

        [Fact]
        public void Model_DefinesEventEntityType()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext context = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();

            IEnumerable<string> entityNames = context.Model
                .GetEntityTypes()
                .Select(e => e.ClrType.Name);

            Assert.Contains("Event", entityNames);
        }

        [Fact]
        public void Model_HasModelSnapshot()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            GoCalGoDbContext context = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();

            IMigrationsAssembly migrationsAssembly = context.GetService<IMigrationsAssembly>()!;

            Assert.NotNull(migrationsAssembly.ModelSnapshot);
        }
    }
}
