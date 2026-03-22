using GoCalGo.Contracts.Events;

namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    /// <summary>
    /// Fluent builder for creating <see cref="PokemonDto"/> instances in tests.
    /// </summary>
    public sealed class PokemonDtoBuilder
    {
        private string _name = "Bulbasaur";
        private string _imageUrl = "https://example.com/bulbasaur.png";
        private bool _canBeShiny;
        private PokemonRole _role = PokemonRole.Spawn;

        public PokemonDtoBuilder WithName(string name) { _name = name; return this; }
        public PokemonDtoBuilder WithImageUrl(string url) { _imageUrl = url; return this; }
        public PokemonDtoBuilder WithCanBeShiny(bool canBeShiny = true) { _canBeShiny = canBeShiny; return this; }
        public PokemonDtoBuilder WithRole(PokemonRole role) { _role = role; return this; }

        public PokemonDto Build()
        {
            return new()
            {
                Name = _name,
                ImageUrl = _imageUrl,
                CanBeShiny = _canBeShiny,
                Role = _role,
            };
        }
    }
}
