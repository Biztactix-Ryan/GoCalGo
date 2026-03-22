using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Configuration
{
    public class SensitiveValuesFromEnvironmentTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        private static readonly string[] SensitivePatterns =
        [
            "password",
            "secret",
            "api_key",
            "apikey",
            "credentials",
            "private_key"
        ];

        private static readonly Regex PlaceholderPattern = new(
            @"^(REPLACE_ME|)$",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        [Theory]
        [InlineData("appsettings.json")]
        [InlineData("appsettings.Development.json")]
        public void AppSettings_DoNotContainHardcodedSecrets(string fileName)
        {
            string projectDir = FindProjectDirectory();
            string filePath = Path.Combine(projectDir, fileName);

            Assert.True(File.Exists(filePath), $"{fileName} should exist");

            string json = File.ReadAllText(filePath);
            using JsonDocument doc = JsonDocument.Parse(json);

            List<string> violations = [];
            ScanForHardcodedSecrets(doc.RootElement, "", violations);

            Assert.True(violations.Count == 0,
                $"Hardcoded sensitive values found in {fileName}:\n" +
                string.Join("\n", violations));
        }

        [Fact]
        public void ConnectionString_Password_CanBeOverriddenByEnvironment()
        {
            string envPassword = "env_test_password_" + Guid.NewGuid();

            WebApplicationFactory<Program> customFactory = factory.WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["ConnectionStrings:PostgreSQL"] =
                            $"Host=localhost;Port=5432;Database=test;Username=test;Password={envPassword}"
                    });
                });
            });

            using IServiceScope scope = customFactory.Services.CreateScope();
            IConfiguration configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();

            string? connectionString = configuration.GetConnectionString("PostgreSQL");

            Assert.NotNull(connectionString);
            Assert.Contains(envPassword, connectionString);
        }

        [Fact]
        public void Firebase_ProjectId_CanBeOverriddenByEnvironment()
        {
            string envProjectId = "env-test-project-" + Guid.NewGuid();

            WebApplicationFactory<Program> customFactory = factory.WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["Firebase:ProjectId"] = envProjectId
                    });
                });
            });

            using IServiceScope scope = customFactory.Services.CreateScope();
            IConfiguration configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();

            string? projectId = configuration["Firebase:ProjectId"];

            Assert.Equal(envProjectId, projectId);
        }

        [Fact]
        public void EnvExample_DocumentsAllSensitiveVariables()
        {
            string repoRoot = FindRepoRoot();
            string envExamplePath = Path.Combine(repoRoot, ".env.example");

            Assert.True(File.Exists(envExamplePath), ".env.example should exist");

            string content = File.ReadAllText(envExamplePath);

            Assert.Contains("POSTGRES_PASSWORD", content);
            Assert.Contains("FIREBASE_PROJECT_ID", content);
            Assert.Contains("FIREBASE_CREDENTIALS_JSON", content);
        }

        [Fact]
        public void EnvExample_DoesNotContainActualSecrets()
        {
            string repoRoot = FindRepoRoot();
            string envExamplePath = Path.Combine(repoRoot, ".env.example");
            string content = File.ReadAllText(envExamplePath);

            string[] lines = content.Split('\n');
            foreach (string line in lines)
            {
                if (line.TrimStart().StartsWith('#') || string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                string[] parts = line.Split('=', 2);
                if (parts.Length != 2)
                {
                    continue;
                }

                string key = parts[0].Trim();
                string value = parts[1].Split('#')[0].Trim();

                bool isSensitiveKey = SensitivePatterns.Any(p =>
                    key.Contains(p, StringComparison.OrdinalIgnoreCase));

                if (isSensitiveKey)
                {
                    Assert.True(string.IsNullOrEmpty(value),
                        $"Sensitive variable {key} should be empty in .env.example, but has value: '{value}'");
                }
            }
        }

        private static void ScanForHardcodedSecrets(JsonElement element, string path, List<string> violations)
        {
            switch (element.ValueKind)
            {
                case JsonValueKind.Object:
                    foreach (JsonProperty property in element.EnumerateObject())
                    {
                        string childPath = string.IsNullOrEmpty(path)
                            ? property.Name
                            : $"{path}:{property.Name}";
                        ScanForHardcodedSecrets(property.Value, childPath, violations);
                    }
                    break;

                case JsonValueKind.String:
                    string value = element.GetString() ?? "";
                    bool keyIsSensitive = SensitivePatterns.Any(p =>
                        path.Contains(p, StringComparison.OrdinalIgnoreCase));

                    if (keyIsSensitive && !PlaceholderPattern.IsMatch(value))
                    {
                        violations.Add($"  {path} = \"{value}\"");
                        break;
                    }

                    if (path.Contains("ConnectionString", StringComparison.OrdinalIgnoreCase))
                    {
                        Match pwMatch = Regex.Match(value, @"Password=([^;]*)", RegexOptions.IgnoreCase);
                        if (pwMatch.Success)
                        {
                            string pw = pwMatch.Groups[1].Value;
                            if (!PlaceholderPattern.IsMatch(pw))
                            {
                                violations.Add($"  {path} contains hardcoded Password=\"{pw}\"");
                            }
                        }
                    }
                    break;
            }
        }

        private static string FindProjectDirectory()
        {
            string? dir = AppContext.BaseDirectory;
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir, "GoCalGo.Api.csproj")))
                {
                    return dir;
                }

                string parent = Path.Combine(dir, "..", "..", "..", "..", "GoCalGo.Api");
                if (Directory.Exists(parent))
                {
                    return Path.GetFullPath(parent);
                }

                dir = Path.GetDirectoryName(dir);
            }

            string fallback = Path.GetFullPath(
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "GoCalGo.Api"));

            return Directory.Exists(fallback)
                ? fallback
                : throw new DirectoryNotFoundException("Could not find GoCalGo.Api project directory");
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
