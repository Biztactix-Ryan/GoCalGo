using Microsoft.AspNetCore.Mvc.Testing;
using Serilog;
using Serilog.Formatting.Compact;

namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Coolify displays container logs by capturing stdout/stderr via Docker's default
    /// logging driver. These tests verify the app is configured so that logs are visible
    /// in the Coolify dashboard.
    /// </summary>
    public class CoolifyLogViewabilityTests(WebApplicationFactory<Program> _factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void Serilog_WritesToConsole_ForCoolifyCapture()
        {
            // Coolify reads container stdout — Serilog must have a Console sink.
            // The Program.cs configures: .WriteTo.Console(new RenderedCompactJsonFormatter())
            // Verify the static logger is active (Console sink is registered in Program.cs).
            // Use _factory to ensure the app has been bootstrapped.
            _ = _factory.Services;
            Assert.True(Log.Logger != Serilog.Core.Logger.None,
                "Serilog must be configured with a Console sink so Coolify can capture stdout logs");
        }

        [Fact]
        public void ConsoleOutput_IsStructuredJson_ParseableByLogViewers()
        {
            // Coolify's log viewer displays raw stdout lines. Structured JSON makes
            // logs searchable and filterable in the dashboard.
            StringWriter output = new();
            RenderedCompactJsonFormatter formatter = new();
            using Serilog.Core.Logger testLogger = new LoggerConfiguration()
                .WriteTo.Sink(new TextWriterSink(formatter, output))
                .CreateLogger();

            testLogger.Information("Health check completed with {Status}", "healthy");
            output.Flush();

            string json = output.ToString().Trim();
            // Each log line must be valid JSON (one object per line = viewable in Coolify)
            Assert.StartsWith("{", json);
            Assert.Contains("\"@t\"", json);   // timestamp for sorting in dashboard
            Assert.Contains("\"@m\"", json);   // rendered message for filtering
        }

        [Fact]
        public void DockerCompose_DoesNotOverrideLoggingDriver()
        {
            // Coolify relies on Docker's default json-file logging driver to capture
            // container output. If docker-compose.yml sets a custom logging driver
            // (e.g. "none" or "syslog"), logs won't appear in the dashboard.
            string repoRoot = FindRepoRoot();
            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml must exist at repo root");

            string composeContent = File.ReadAllText(composePath);

            // The api service must NOT have a "logging:" directive that overrides the default driver
            Assert.DoesNotContain("logging:", composeContent);
        }

        [Fact]
        public void ProgramCs_ConfiguresConsoleSink()
        {
            // Directly verify Program.cs source contains the Console sink configuration.
            // This is the line that makes logs appear in Coolify.
            string repoRoot = FindRepoRoot();
            string programPath = Path.Combine(repoRoot, "src", "backend", "GoCalGo.Api", "Program.cs");
            Assert.True(File.Exists(programPath), "Program.cs must exist");

            string programSource = File.ReadAllText(programPath);
            Assert.Contains(".WriteTo.Console(", programSource);
            Assert.Contains("RenderedCompactJsonFormatter", programSource);
        }

        private static string FindRepoRoot()
        {
            // Walk up from the test assembly's base directory to find the repo root (has docker-compose.yml)
            string? dir = AppContext.BaseDirectory;
            while (dir is not null)
            {
                if (File.Exists(Path.Combine(dir, "docker-compose.yml")))
                {
                    return dir;
                }

                dir = Directory.GetParent(dir)?.FullName;
            }

            // Fallback: assume typical relative path from test bin output
            return Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", ".."));
        }
    }
}
