namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies that docker-compose.yml passes environment variables from .env to services,
    /// satisfying the acceptance criterion: "Docker Compose passes environment variables to services".
    /// </summary>
    public class DockerComposeEnvironmentTests
    {
        private readonly string _composeContent;
        private readonly string _envExampleContent;

        public DockerComposeEnvironmentTests()
        {
            string repoRoot = FindRepoRoot();

            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml should exist at repo root");
            _composeContent = File.ReadAllText(composePath);

            string envPath = Path.Combine(repoRoot, ".env.example");
            Assert.True(File.Exists(envPath), ".env.example should exist at repo root");
            _envExampleContent = File.ReadAllText(envPath);
        }

        [Theory]
        [InlineData("POSTGRES_DB")]
        [InlineData("POSTGRES_USER")]
        [InlineData("POSTGRES_PASSWORD")]
        public void PostgresService_ReceivesRequiredEnvVars(string variable)
        {
            Assert.Contains(variable, _envExampleContent);
            Assert.Contains($"${{{variable}}}", _composeContent);
        }

        [Theory]
        [InlineData("POSTGRES_PORT")]
        [InlineData("REDIS_PORT")]
        public void InfraServices_ExposeConfigurablePorts(string variable)
        {
            Assert.Contains(variable, _envExampleContent);
            Assert.Contains(variable, _composeContent);
        }

        [Theory]
        [InlineData("ASPNETCORE_ENVIRONMENT")]
        [InlineData("FIREBASE_PROJECT_ID")]
        [InlineData("FIREBASE_CREDENTIALS_JSON")]
        [InlineData("SCRAPEDDUCK_BASE_URL")]
        [InlineData("SCRAPEDDUCK_CACHE_EXPIRATION_MINUTES")]
        public void ApiService_ReceivesAppConfigEnvVars(string variable)
        {
            Assert.Contains(variable, _envExampleContent);
            Assert.Contains(variable, _composeContent);
        }

        [Fact]
        public void ApiService_MapsPostgresConnectionString_UsingEnvVars()
        {
            Assert.Contains("ConnectionStrings__PostgreSQL", _composeContent);
            Assert.Contains("${POSTGRES_DB}", _composeContent);
            Assert.Contains("${POSTGRES_USER}", _composeContent);
            Assert.Contains("${POSTGRES_PASSWORD}", _composeContent);
        }

        [Fact]
        public void ApiService_MapsRedisConnectionString()
        {
            Assert.Contains("ConnectionStrings__Redis", _composeContent);
        }

        [Fact]
        public void ApiService_UsesDoubleUnderscoreNotation_ForNestedConfig()
        {
            // .NET uses __ as section separator for env var configuration override
            Assert.Contains("ConnectionStrings__", _composeContent);
            Assert.Contains("ScrapedDuck__", _composeContent);
            Assert.Contains("Firebase__", _composeContent);
        }

        [Fact]
        public void ComposeFile_DoesNotContainHardcodedSecrets()
        {
            string[] secretPatterns = ["password=", "secret=", "api_key=", "credentials="];

            foreach (string pattern in secretPatterns)
            {
                // Find any line that has a secret pattern with a literal value (not a ${VAR} reference)
                string[] lines = _composeContent.Split('\n');
                foreach (string line in lines)
                {
                    if (line.Contains(pattern, StringComparison.OrdinalIgnoreCase))
                    {
                        // The value should reference an env var, not contain a literal secret
                        Assert.Contains("${", line);
                    }
                }
            }
        }

        [Fact]
        public void AllEnvExampleVariables_AreReferencedInCompose()
        {
            List<string> envVars = ParseEnvExampleVariables();
            List<string> unreferenced = [];

            foreach (string varName in envVars)
            {
                // Variable should appear in compose file either as ${VAR} or ${VAR:-default}
                if (!_composeContent.Contains(varName))
                {
                    unreferenced.Add(varName);
                }
            }

            // API_BASE_URL is Flutter-only, not used in Docker Compose
            unreferenced.Remove("API_BASE_URL");
            // POSTGRES_HOST and REDIS_HOST are for non-Docker local dev; Compose uses service names
            unreferenced.Remove("POSTGRES_HOST");
            unreferenced.Remove("REDIS_HOST");

            Assert.True(unreferenced.Count == 0,
                $"These .env.example variables are not referenced in docker-compose.yml:\n" +
                string.Join("\n", unreferenced.Select(v => $"  - {v}")));
        }

        private List<string> ParseEnvExampleVariables()
        {
            List<string> vars = [];
            foreach (string line in _envExampleContent.Split('\n'))
            {
                string trimmed = line.Trim();
                if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith('#'))
                {
                    continue;
                }

                string[] parts = trimmed.Split('=', 2);
                if (parts.Length == 2)
                {
                    vars.Add(parts[0].Trim());
                }
            }
            return vars;
        }

        private static string FindRepoRoot()
        {
            string? dir = AppContext.BaseDirectory;
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir, ".env.example")))
                {
                    return dir;
                }

                dir = Path.GetDirectoryName(dir);
            }

            string fallback = Path.GetFullPath(
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));

            return File.Exists(Path.Combine(fallback, ".env.example"))
                ? fallback
                : throw new DirectoryNotFoundException("Could not find repository root");
        }
    }
}
