using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Conex360.Api.Serialization;

public sealed class UInt64StringConverter : JsonConverter<ulong>
{
    public override ulong Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String
            || !ulong.TryParse(reader.GetString(), NumberStyles.None, CultureInfo.InvariantCulture, out var value))
        {
            throw new JsonException("An unsigned integer ID string is required.");
        }

        return value;
    }

    public override void Write(Utf8JsonWriter writer, ulong value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.ToString(CultureInfo.InvariantCulture));
}
