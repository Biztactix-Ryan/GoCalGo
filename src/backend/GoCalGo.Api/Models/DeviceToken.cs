namespace GoCalGo.Api.Models
{
    public class DeviceToken
    {
        public int Id { get; set; }
        public string Token { get; set; } = string.Empty;
        public string Platform { get; set; } = string.Empty;
        public string? Timezone { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
