using System.Diagnostics.CodeAnalysis;

namespace GoCalGo.Api.Tests.Infrastructure
{
    [CollectionDefinition(Name)]
    [SuppressMessage("Naming", "CA1711:Identifiers should not have incorrect suffix", Justification = "xUnit collection definition convention")]
    public sealed class IntegrationTestDefinition : ICollectionFixture<PostgresRedisFixture>
    {
        public const string Name = "Integration";
    }
}
