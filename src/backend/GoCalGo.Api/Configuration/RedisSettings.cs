namespace GoCalGo.Api.Configuration
{
    public class RedisSettings
    {
        public const string SectionName = "Redis";

        public string Host { get; set; } = "localhost";
        public int Port { get; set; } = 6379;

        public string ConnectionString => $"{Host}:{Port}";
    }
}
