using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using Serilog.Formatting.Compact;

namespace GoCalGo.Api.Tests.Configuration
{
    public class SerilogStructuredLoggingTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        private static readonly string[] ValidLogLevels = ["Information", "Debug", "Warning", "Error"];
        [Fact]
        public void Serilog_IsRegisteredAsLoggingProvider()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            ILoggerFactory loggerFactory = scope.ServiceProvider.GetRequiredService<ILoggerFactory>();

            Assert.NotNull(loggerFactory);
            // Serilog replaces the default logging providers when UseSerilog() is called.
            // Verify that the Serilog static logger is configured (not the default silent logger).
            Assert.True(Log.Logger != Serilog.Core.Logger.None,
                "Serilog should be configured as the logging provider");
        }

        [Fact]
        public void Serilog_WritesStructuredJsonOutput()
        {
            StringWriter output = new();
            RenderedCompactJsonFormatter formatter = new();
            // Create a test logger that writes compact JSON to a StringWriter
            using Serilog.Core.Logger testLogger = new LoggerConfiguration()
                .WriteTo.Sink(new TextWriterSink(formatter, output))
                .CreateLogger();

            testLogger.Information("Test message with {Property}", "value");
            output.Flush();

            string json = output.ToString().Trim();
            Assert.False(string.IsNullOrEmpty(json), "Serilog should produce output");
            Assert.StartsWith("{", json);
            Assert.Contains("\"@t\"", json); // Compact JSON format timestamp field
            Assert.Contains("\"Property\"", json); // Structured property preserved
        }

        [Fact]
        public void Serilog_ConfigurationIsReadFromAppSettings()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IConfiguration config = scope.ServiceProvider.GetRequiredService<IConfiguration>();

            IConfigurationSection serilogSection = config.GetSection("Serilog");
            string? defaultLevel = serilogSection["MinimumLevel:Default"];
            Assert.NotNull(defaultLevel);
            Assert.Contains(defaultLevel, ValidLogLevels);
        }

        [Fact]
        public void Serilog_ProductionLogLevelsFollowConvention()
        {
            // Convention: Information for business events, Warning for degraded states, Error for failures.
            // Validate the production appsettings.json directly (not the merged dev config).
            IConfiguration prodConfig = new ConfigurationBuilder()
                .SetBasePath(AppContext.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: false)
                .Build();

            IConfigurationSection serilogSection = prodConfig.GetSection("Serilog");

            // Production default level must be Information (business events logged at this level)
            string? defaultLevel = serilogSection["MinimumLevel:Default"];
            Assert.Equal("Information", defaultLevel);

            // Framework override must be Warning or higher to reduce noise
            string? aspNetLevel = serilogSection["MinimumLevel:Override:Microsoft.AspNetCore"];
            Assert.NotNull(aspNetLevel);
            string[] warningOrHigher = ["Warning", "Error", "Fatal"];
            Assert.Contains(aspNetLevel, warningOrHigher);
        }

        [Fact]
        public void Serilog_AllLogLevelsAreWritable()
        {
            // Verify Information, Warning, and Error levels all produce structured output
            StringWriter output = new();
            RenderedCompactJsonFormatter formatter = new();
            using Serilog.Core.Logger testLogger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .WriteTo.Sink(new TextWriterSink(formatter, output))
                .CreateLogger();

            testLogger.Information("Business event: {Action} completed", "import");
            testLogger.Warning("Degraded state: {Service} responding slowly", "Redis");
            testLogger.Error("Failure: {Operation} failed with {Reason}", "fetch", "timeout");
            output.Flush();

            string json = output.ToString();
            Assert.Contains("Business event", json);
            Assert.Contains("Degraded state", json);
            Assert.Contains("Failure", json);
        }
    }

    internal sealed class TextWriterSink(Serilog.Formatting.ITextFormatter formatter, TextWriter writer) : Serilog.Core.ILogEventSink
    {
        public void Emit(Serilog.Events.LogEvent logEvent)
        {
            formatter.Format(logEvent, writer);
        }
    }
}
