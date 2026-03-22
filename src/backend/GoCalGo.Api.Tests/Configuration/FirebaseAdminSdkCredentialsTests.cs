using System.Reflection;
using GoCalGo.Api.Configuration;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-16:
    /// "Firebase Admin SDK service account credentials generated for the .NET backend"
    ///
    /// The actual service account JSON is generated in the Firebase console and injected
    /// via environment variables at runtime. These tests verify the .NET backend is wired
    /// to receive and bind those credentials through configuration.
    /// </summary>
    public class FirebaseAdminSdkCredentialsTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void FirebaseSettings_HasCredentialsPathProperty()
        {
            // The settings class must have a CredentialsPath property
            // to bind the Firebase__CredentialsPath environment variable
            PropertyInfo? property = typeof(FirebaseSettings).GetProperty("CredentialsPath");

            Assert.NotNull(property);
            Assert.Equal(typeof(string), property.PropertyType);
        }

        [Fact]
        public void FirebaseSettings_BindsFromConfiguration()
        {
            // Verify that IOptions<FirebaseSettings> is registered and resolvable
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<FirebaseSettings> options = scope.ServiceProvider.GetRequiredService<IOptions<FirebaseSettings>>();

            Assert.NotNull(options.Value);
            Assert.NotNull(options.Value.CredentialsPath);
        }

        [Fact]
        public void CredentialsPath_CanBeOverriddenByEnvironment()
        {
            // Simulate injecting a service account path via environment variable override
            string fakePath = "/secrets/firebase-service-account.json";

            WebApplicationFactory<Program> customFactory = factory.WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["Firebase:CredentialsPath"] = fakePath
                    });
                });
            });

            using IServiceScope scope = customFactory.Services.CreateScope();
            IOptions<FirebaseSettings> options = scope.ServiceProvider.GetRequiredService<IOptions<FirebaseSettings>>();

            Assert.Equal(fakePath, options.Value.CredentialsPath);
        }

        [Fact]
        public void DockerCompose_PassesCredentialsPathToApi()
        {
            string repoRoot = FindRepoRoot();
            string composeContent = File.ReadAllText(Path.Combine(repoRoot, "docker-compose.yml"));

            // docker-compose must map FIREBASE_CREDENTIALS_JSON to Firebase__CredentialsPath
            Assert.Contains("Firebase__CredentialsPath", composeContent);
            Assert.Contains("FIREBASE_CREDENTIALS_JSON", composeContent);
        }

        [Fact]
        public void EnvExample_DocumentsCredentialsJsonVariable()
        {
            string repoRoot = FindRepoRoot();
            string envContent = File.ReadAllText(Path.Combine(repoRoot, ".env.example"));

            Assert.Contains("FIREBASE_CREDENTIALS_JSON", envContent);
            // Should indicate it's required and describe what it is
            Assert.Contains("service-account", envContent);
        }

        [Fact]
        public void Appsettings_DoNotContainActualCredentials()
        {
            string projectDir = FindProjectDirectory();

            foreach (string fileName in new[] { "appsettings.json", "appsettings.Development.json" })
            {
                string filePath = Path.Combine(projectDir, fileName);
                if (!File.Exists(filePath))
                {
                    continue;
                }

                string content = File.ReadAllText(filePath);

                // Must not contain actual service account key indicators
                Assert.DoesNotContain("\"private_key\"", content);
                Assert.DoesNotContain("\"client_email\"", content);
                Assert.DoesNotContain("\"type\": \"service_account\"", content);
            }
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
    }
}
