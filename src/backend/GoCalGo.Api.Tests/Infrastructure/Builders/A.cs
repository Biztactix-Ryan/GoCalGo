namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    /// <summary>
    /// Short-hand entry point for test data builders.
    /// Usage: <c>var ev = A.Event.WithName("My Event").Build();</c>
    /// </summary>
    public static class A
    {
        public static EventBuilder Event => new();
        public static EventBuffBuilder EventBuff => new();
        public static EventDtoBuilder EventDto => new();
        public static PokemonDtoBuilder PokemonDto => new();
    }
}
